"""Audit the authored and fallback enemy decks and report paired changes."""

import argparse
from collections import Counter
import csv
import gzip
import json
from pathlib import Path
import sys

from report_decisive_balance import compare, screening_table, activity_table
from report_enemy_balance import card_table, inventory, opens, render, table, verify_grid, write_cards

ARMS = ("faction-existing", "faction-prototypes", "faction-siege-hull")
BUILD_TYPES = ("offense", "defense", "economy", "balanced")
BOSS_RUNS = tuple(f"boss-{stage}-{build}" for stage in ("early", "middle", "later") for build in BUILD_TYPES) + (
    "boss-later-balanced-fixed", "boss-later-balanced-starter",
)
HELD_SEEDS = range(21, 29)
ROLES = {"Offense": {"damage"}, "Defense": {"shields"}, "Hull recovery": {"hull"},
         "Economy": {"economy", "production"}, "Disruption": {"disruption", "steal"}}


def read(path, seeds, policy_names=None):
    config, matches, cards, _ = opens(path)
    grid = dict(config)
    if policy_names is not None:
        grid["policies"] = {key: val for key, val in config["policies"].items() if key in policy_names}
    verify_grid(grid, matches, seeds)
    return config, matches, cards


def group_by_arm(arguments):
    assignments = {}
    for argument in arguments:
        name, separator, arm = argument.partition("=")
        if not separator or not name or arm not in ARMS:
            raise ValueError(f"Expected NAME=ARM, got {argument}")
        assignments.setdefault(arm, set()).add(name)
    return assignments


def ratio(value, total):
    return value / total if total else 0


def deck_audit(path, authored, activity, cards):
    columns = ["Faction", "Ship", "Role", "Pool", "M/E/C slots", "M/E/C start", "S/R/Q", "Hull / Shields",
               "Mean rounds", "Player wins", "Off / def / recovery / econ / disrupt"]
    profiles = authored["profiles"]
    definitions = authored["cards"]
    lines = ["# Enemy deck audit", "", "Card roles overlap. An effect in a conditional branch counts toward its role.",
             "Affordability samples cards held at turn start. Plays and discards are battle totals.", ""]
    rows = []
    details = []
    with (path / "baseline-deck-cards.csv").open("w", encoding="utf-8", newline="") as handle:
        output = csv.writer(handle, lineterminator="\n")
        output.writerow(("enemy", "faction", "card_id", "card", "family", "cost", "tier", "roles", "drawn", "held_turns",
                         "affordable", "affordable_fraction", "played", "discarded", "discard_share", "effects"))
        for name, profile in sorted(profiles.items(), key=lambda item: (item[1]["faction"], item[1]["rank"], item[0])):
            combat = activity[name]
            state = profile["starting_state"]
            counts = Counter(definitions[key]["family"] for key in profile["cards"])
            role_cards = {role: [] for role in ROLES}
            examples = {}
            for identity in profile["cards"]:
                card = definitions[identity]
                usage = cards.get(name, {}).get(card["name"], {})
                drawn, held, affordable, played, discarded = (usage.get(key, 0) for key in (
                    "drawn", "held_turns", "affordable", "played", "discarded"))
                roles = [role for role, tags in ROLES.items() if tags.intersection(card["tags"])]
                for role in roles:
                    role_cards[role].append(card["name"])
                examples[card["name"]] = (played, held, ratio(affordable, held), ratio(discarded, played + discarded), roles)
                output.writerow((name, profile["faction"], identity, card["name"], card["family"], card["cost"],
                                 card["tier"], " / ".join(roles), drawn, held, affordable, ratio(affordable, held),
                                 played, discarded, ratio(discarded, played + discarded), json.dumps(card["effects"], sort_keys=True)))
            kind = "shared" if profile["fallback"] else "authored"
            rows.append([profile["faction"], name, profile["role"], f'{len(profile["cards"])} {kind}',
                         "/".join(str(counts[k]) for k in ("materials", "energy", "crew")),
                         "/".join(str(state[k]) for k in ("materials", "energy", "crew")),
                         "/".join(str(state[k]) for k in ("synthesizer", "reactor", "quarters")),
                         f'{state["hull"]} / {state["shields"]}', f'{combat["mean_rounds"]:.1f}', f'{combat["combat_win"]:.1%}',
                         " / ".join(str(len(cards_by_role)) for cards_by_role in role_cards.values())])
            defensive = [(card, counts[0]) for card, counts in examples.items() if {"Defense", "Hull recovery"}.intersection(counts[4])]
            frequent = sorted(defensive, key=lambda item: (-item[1], item[0]))[:4]
            scarce = [(card, stats[2], stats[3]) for card, stats in examples.items()
                      if stats[1] >= 80 and stats[2] <= .2 and stats[0] <= 0.10 * combat["n"]]
            blends = sorted(((card, stats[0], [role for role in stats[4] if role != "Offense"])
                             for card, stats in examples.items() if "Offense" in stats[4] and len(stats[4]) > 1),
                            key=lambda item: (-item[1], item[0]))[:3]
            overlap = Counter(definitions[k]["family"] for k in profile["cards"]
                              if set(definitions[k]["tags"]) & {"shields", "hull"})
            details.extend([f"## {name}", "", profile["summary"] or profile["role"], "",
                            f'Tactics `{json.dumps(profile["tactics"], sort_keys=True)}`, variation {profile["tactical_variation"]}.',
                            f'Family draw weights `{json.dumps(profile["family_weights"], sort_keys=True)}`.',
                            f'Effect draw weights `{json.dumps(profile["effect_weights"], sort_keys=True)}`.', "",
                            "**Most-used recovery or Shield cards per combat**  " +
                            (", ".join(f"{card} {uses / combat['n']:.2f}" for card, uses in frequent if uses) or "none observed") + ".", "",
                            "**Recovery and Shield slots sharing a resource family**  " +
                            (", ".join(f"{family} {count}" for family, count in sorted(overlap.items())) or "none") + ".", "",
                            "**Frequently played multi-role attacks**  " +
                            (", ".join(f"{card} ({'/'.join(roles).lower()})" for card, uses, roles in blends if uses) or "none observed") + ".", "",
                            "**Low-affordability, low-play examples**  " +
                            (", ".join(f"{card} ({affordable:.0%} affordable, {discard:.0%} discarded among removals)"
                                       for card, affordable, discard in sorted(scarce, key=lambda item: item[1])[:5]) or "none at the reporting cutoff") + ".", ""])
    lines.extend([table(columns, rows), "", *details])
    (path / "deck-audit.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")


def boss_report(bosses):
    rows = []
    for mode, scenario in bosses.items():
        for enemy, result in scenario["enemies"].items():
            rows.append([mode.removeprefix("boss-"), enemy, result["n"], f'{result["combat_win"]:.1%}',
                         f'{result["median_rounds"]:.1f}', f'{result["unresolved"]:.1%}',
                         f'{result["policies"]["emp"]["emp"]:.1%}'])
    return "\n".join(["## Progression-equipped opponents", "",
                      table(["Loadout", "Mothership", "Matches", "Combat wins", "Median rounds",
                             "Unresolved", "EMP escape (separate policy)"], rows), ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("shards", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--retain", action="append", default=[])
    args = parser.parse_args()
    config, baseline, original_cards = read(args.baseline, range(1, 9))
    replay, sample, _ = read(args.shards / "replay", range(1, 2), {"balanced"})
    if replay["revision"] != config["revision"] or any(baseline.get(k) != row for k, row in sample.items()):
        raise ValueError("Current-main replay did not match the reused baseline")
    authored = json.loads((args.shards / "inventory-before.json").read_text(encoding="utf-8"))
    fallback_names = {name for name, profile in authored["profiles"].items() if profile["fallback"]}
    fallback_info, fallback, fallback_cards = read(args.shards / "expedition-fallback", range(1, 9))
    if (not fallback_info.get("expedition_pool") or fallback_info["revision"] != config["revision"]
            or fallback.keys() != {k for k in baseline if k[1] in fallback_names}):
        raise ValueError("The expedition fallback reruns must match the five legacy profile grids")
    baseline |= fallback
    original_cards |= fallback_cards
    before, original_ranks = inventory(baseline, config)
    arms = {}
    screen_records = {}
    combat_policies = set(config["policies"]) - {"emp"}
    for arm in ARMS:
        scenario, sample, cards = read(args.shards / arm, range(1, 9), combat_policies)
        if scenario["revision"] != config["revision"]:
            raise ValueError("Screening must use the same production baseline")
        changes = compare(baseline, sample)
        arms[arm] = {"configuration": scenario, "changes": changes, "cards": card_table(cards, changes)}
        screen_records[arm] = sample
    if args.output is None:
        sys.stdout.reconfigure(encoding="utf-8")
        for arm, row in arms.items():
            print(screening_table(arm, row["changes"]))
        return

    retained_arms = group_by_arm(args.retain)
    retained = set().union(*retained_arms.values())
    if len(retained) != len(args.retain):
        raise ValueError("A retained ship must come from exactly one arm")
    if not retained:
        raise ValueError("Choose the retained profiles with --retain")
    held_config, held, _ = read(args.shards / "held", HELD_SEEDS)
    if held_config["revision"] != config["revision"] or held.keys() & baseline.keys():
        raise ValueError("The held controls must use the merged baseline and independent seeds")
    held_arms = {}
    hold_records = {}
    for arm in ARMS:
        held_path = args.shards / f"{arm}-held"
        if held_path.is_dir():
            info, cases, _ = read(held_path, HELD_SEEDS)
            if info["revision"] != config["revision"]:
                raise ValueError("Independent scenarios must use the same production baseline")
            held_arms[arm] = compare(held, cases)
            hold_records[arm] = cases
    final_config, tuned, revised_cards = read(args.shards / "final", range(1, 9))
    final_held_config, tuned_held, _ = read(args.shards / "held-final", HELD_SEEDS)
    if final_config["revision"] != final_held_config["revision"]:
        raise ValueError("Both production reruns must use the same revision")
    if any({k[1] for k in rows} != retained for rows in (tuned, tuned_held)):
        raise ValueError("Production reruns must cover exactly the retained profiles")
    for arm, names in retained_arms.items():
        for key, row in tuned.items():
            if key[1] in names and key[3] != "emp" and screen_records[arm].get(key) != row:
                raise ValueError(f"Production lost candidate parity on {key}")
        for key, row in tuned_held.items():
            if key[1] in names and hold_records[arm].get(key) != row:
                raise ValueError(f"Production lost held-out parity on {key}")
    after, final_ranks = inventory(baseline | tuned, config)
    final_comparisons = {"Production baseline seeds": compare(baseline, tuned),
                         "Production independent seeds": compare(held, tuned_held)}
    bosses = {}
    for arm in BOSS_RUNS:
        info, matches, _ = read(args.shards / arm, range(1, 5), {"balanced", "emp"})
        live_info, live_matches, _ = read(args.shards / f"expedition-{arm}", range(1, 5), {"balanced", "emp"})
        if (not live_info.get("expedition_pool") or live_info["revision"] != info["revision"]
                or live_info["loadouts"] != info["loadouts"]
                or live_matches.keys() != {k for k in matches if k[1] in fallback_names}):
            raise ValueError("The expedition fallback boss rerun differs from its intended scenario")
        matches |= live_matches
        bosses[arm] = {"configuration": info, "enemies": inventory(matches, dict(info, policies={
            k: v for k, v in info["policies"].items() if k in ("balanced", "emp")}))[0]}
    report = {"configuration": config, "before": before, "after": after, "comparisons": {},
              "ranks": {"before": original_ranks, "after": final_ranks}, "baseline_matches": len(baseline),
              "targets": sorted(set().union(*(arm["changes"] for arm in arms.values()))),
              "trials": arms, "independent_trials": held_arms, "validation": final_comparisons,
              "bosses": bosses, "retained": sorted(retained), "production_revision": final_config["revision"],
              "expedition_fallback": fallback_info}
    args.output.mkdir(parents=True, exist_ok=True)
    names = list(before)
    cards_before = card_table(original_cards, names)
    write_cards(args.output / "enemy-cards.csv", cards_before, card_table(original_cards | revised_cards, names))
    if authored["profiles"].keys() != before.keys():
        raise ValueError("Authored profile inventory differs from the loaded simulation roster")
    deck_audit(args.output, authored, before, cards_before)
    report["authored_inventory"] = authored
    lines = [render(report), activity_table(report), "## Isolated experiments", ""]
    lines.extend(screening_table(arm, run["changes"]) for arm, run in arms.items())
    lines.extend(screening_table(f"{arm} independent trials", run) for arm, run in held_arms.items())
    lines.extend(screening_table(label, run) for label, run in final_comparisons.items())
    lines.append(boss_report(bosses))
    (args.output / "tables.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    with (args.output / "summary.json.gz").open("wb") as handle:
        with gzip.GzipFile(fileobj=handle, mode="wb", filename="", mtime=0) as archive:
            archive.write(json.dumps(report, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    print(f"Generated the {len(before)}-enemy deck audit and {len(tuned_held):,} production validation pairs")


if __name__ == "__main__":
    main()
