"""Validate full-roster balance shards and report paired enemy comparisons."""

import argparse
from collections import Counter, defaultdict
import csv
import gzip
from itertools import product
import json
from math import ceil
from pathlib import Path
from random import Random
from statistics import mean

from aggregate_combat_audit import collect, summarize


def opens(directory):
    cards = {}
    config, matches, player_cards = collect(directory.glob("ship-*.jsonl"), enemy_cards=cards)
    if not matches:
        raise ValueError(f"No complete matches in {directory}")
    return config, matches, cards, player_cards


def verify_grid(config, matches, seeds):
    profiles = {enemy["name"]: (enemy["rank"], enemy["resource"]) for enemy in config["enemies"]}
    expected = set(product(config["ships"], profiles, config["modifiers"], config["policies"], seeds))
    if matches.keys() != expected:
        raise ValueError(f"Incomplete simulation grid for {config['variant']}")
    for row in matches.values():
        if (row["rank"], row["enemy_resource"]) != profiles[row["enemy"]]:
            raise ValueError(f"Incorrect rank or source resource for {row['enemy']}")


def non_emp(key):
    return key[3] != "emp"


def combat_win(row):
    return row["outcome"].startswith("win_")


def metrics(rows):
    output = summarize(rows)
    # Shared seed blocks make a match-level binomial interval inappropriate here.
    del output["win_ci95"], output["success_ci95"]
    n = output["n"]
    rounds = sorted(row["rounds"] for row in rows)
    output["p90"] = rounds[ceil(.90 * n) - 1]
    output["over_rounds"] = {str(limit): sum(r > limit for r in rounds) / n for limit in (30, 40, 60)}
    output["loss"] = sum(r["outcome"].startswith("loss_") for r in rows) / n
    output["draw"] = sum(r["outcome"].startswith("draw_") for r in rows) / n
    output["unresolved"] = sum(r["outcome"].endswith("_limit") for r in rows) / n
    output["flow"] = []
    for side in (0, 1):
        turns = sum(row["turns"][side] for row in rows)
        flow = {name: mean(row["flows"][side][name] for row in rows) for name in (
            "hull_dealt", "hull_restored", "shields_gained", "shields_lost", "offensive_plays", "recovery_plays")}
        flow["damage_per_round"] = sum(row["flows"][side]["damage"] for row in rows) / sum(rounds)
        flow["failure_rate"] = sum(row["failure_activations"][side] > 0 for row in rows) / n
        for field in ("income", "spent", "reserves"):
            flow[field] = [
                sum(row["flows"][side][field][i] for row in rows) / (max(1, turns) if field == "reserves" else n)
                for i in range(3)]
        output["flow"].append(flow)
    return output


def paired(before, after, keys):
    """Resample whole paired seed blocks so shared RNG seeds stay together."""
    blocks = defaultdict(list)
    for key in sorted(keys):
        old, new = before[key], after[key]
        blocks[key[-1]].append([
            int(combat_win(new)) - int(combat_win(old)),
            new["rounds"] - old["rounds"],
            new["flows"][1]["damage"] / new["rounds"] - old["flows"][1]["damage"] / old["rounds"],
            new["flows"][1]["recovery_plays"] - old["flows"][1]["recovery_plays"],
        ])
    values = [tuple(map(mean, zip(*block, strict=True))) for block in blocks.values()]
    rng = Random(1)
    samples = [tuple(map(mean, zip(*rng.choices(values, k=len(values)), strict=True))) for _ in range(4000)]
    result = {"n": sum(map(len, blocks.values())), "seeds": sorted(blocks)}
    for i, metric in enumerate(("win", "rounds", "damage_per_round", "recovery_plays")):
        interval = sorted(s[i] for s in samples)
        result[metric] = [mean(v[i] for v in values), interval[100], interval[3899]]
    return result


def card_table(cards, names):
    output = {}
    for name in names:
        totals = defaultdict(Counter)
        for (enemy, policy), group in cards.items():
            if enemy != name or policy == "emp":
                continue
            for card in group.values():
                totals[card["name"]].update({key: card.get(key, 0) for key in (
                    "drawn", "held_turns", "affordable", "played", "discarded")})
        output[name] = dict(sorted(totals.items(), key=lambda item: (-item[1]["played"], item[0])))
    return output


def write_cards(path, before, after):
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(("enemy", "card", "version", "drawn", "held_turns", "affordable_turns",
                         "affordable_rate", "played", "discarded"))
        for version, cards in (("before", before), ("after", after)):
            for enemy, deck in cards.items():
                for card, counts in deck.items():
                    writer.writerow((enemy, card, version, counts["drawn"], counts["held_turns"], counts["affordable"],
                                     round(counts["affordable"] / counts["held_turns"], 5) if counts["held_turns"] else "",
                                     counts["played"], counts["discarded"]))


def inventory(rows, config):
    by_enemy = defaultdict(list)
    matchups = defaultdict(list)
    by_rank = defaultdict(list)
    by_policy = defaultdict(list)
    by_modifier = defaultdict(list)
    for key, row in rows.items():
        player, enemy, modifier, policy, _ = key
        by_policy[enemy, policy].append(row)
        if non_emp(key):
            by_enemy[enemy].append(row)
            matchups[enemy, player].append(row)
            by_rank[row["rank"]].append(row)
            by_modifier[enemy, modifier].append(row)
    result = {}
    for enemy in config["enemies"]:
        name = enemy["name"]
        result[name] = metrics(by_enemy[name])
        result[name]["policies"] = {policy: metrics(by_policy[name, policy]) for policy in config["policies"]}
        result[name]["modifiers"] = {modifier: metrics(by_modifier[name, modifier]) for modifier in config["modifiers"]}
        result[name]["matchups"] = {ship: metrics(matchups[name, ship]) for ship in config["ships"]}
    return result, {rank: metrics(group) for rank, group in by_rank.items()}


def comparisons(before, after):
    if not after.keys() <= before.keys():
        raise ValueError("Candidate has unmatched conditions")
    groups = defaultdict(list)
    for key in after:
        if non_emp(key):
            groups[key[1]].append(key)
    return {
        enemy: {
            "overall": paired(before, after, keys),
            "ships": {ship: paired(before, after, [k for k in keys if k[0] == ship])
                      for ship in sorted({k[0] for k in keys})},
        } for enemy, keys in sorted(groups.items())
    }


def table(columns, rows):
    return "\n".join("| " + " | ".join(map(str, row)) + " |" for row in [columns, ["---"] * len(columns), *rows])


def rates(before, after, name):
    return f"{before[name]:.1%} → {after[name]:.1%}"


def interval(values, scale=1):
    point, low, high = (x * scale for x in values)
    return f"{point:+.2f} [{low:+.2f}, {high:+.2f}]"


def render(data):
    config = data["configuration"]
    before, after = data["before"], data["after"]
    lines = ["# Full enemy balance results", "",
             "Combat tables use the four non-EMP policies. EMP escape is shown for its own policy. "
             "Before → after values use matched seeds and conditions.", ""]
    lines += [table(["Rank", "Combat matches", "Win", "Median rounds", ">40 rounds"], [
        [label, old["n"], rates(old, new, "combat_win"), f'{old["median_rounds"]} → {new["median_rounds"]}',
         rates(old["over_rounds"], new["over_rounds"], "40")]
        for rank, label in enumerate(("Standard", "Elite", "Boss and mothership"))
        for old, new in [(data["ranks"]["before"][rank], data["ranks"]["after"][rank])]]), ""]
    for rank, label in enumerate(("Standard", "Elite", "Boss and mothership")):
        names = [e["name"] for e in config["enemies"] if e["rank"] == rank]
        names.sort(key=lambda name: before[name]["combat_win"])
        cells = []
        for name in names:
            old, new = before[name], after[name]
            cells.append([name, rates(old, new, "combat_win"), rates(old, new, "loss"),
                          rates(old, new, "draw"), rates(old, new, "unresolved"), rates(old["policies"]["emp"], new["policies"]["emp"], "emp"),
                          " / ".join(f"{old[k]:.1f} → {new[k]:.1f}" for k in ("median_rounds", "mean_rounds", "p90")),
                          " / ".join(rates(old["over_rounds"], new["over_rounds"], cap) for cap in ("30", "40", "60"))])
        lines += [f"## {label}", "", table(
            ["Enemy (hardest first)", "Win", "Loss", "Draw", "Unresolved", "EMP escape", "Rounds median / mean / P90",
             ">30 / >40 / >60 rounds"], cells), ""]
        lines += [table(["Enemy", *config["ships"]], [
            [name, *(rates(before[name]["matchups"][ship], after[name]["matchups"][ship], "combat_win")
                     for ship in config["ships"])] for name in names]), ""]
    lines += ["## Longest baseline encounters", "",
              table(["Enemy", "Median rounds", "P90", ">40 rounds"], [
                  [name, row["median_rounds"], row["p90"], f'{row["over_rounds"]["40"]:.1%}']
                  for name, row in sorted(before.items(), key=lambda kv: (-kv[1]["over_rounds"]["40"], -kv[1]["mean_rounds"]))]), ""]
    lines += ["## Baseline enemy activity", "",
              "Damage per round includes Shields absorbed by direct attacks. Hull, Shield and play counts are per match.", "",
              table(["Enemy", "Dmg/round", "Hull dealt / restored", "Shields gained / lost", "Offense / recovery plays",
                     "Systems Failure", "Income / spend", "Held reserves"], [
                  [name, f'{flow["damage_per_round"]:.2f}', f'{flow["hull_dealt"]:.1f} / {flow["hull_restored"]:.1f}',
                   f'{flow["shields_gained"]:.1f} / {flow["shields_lost"]:.1f}', f'{flow["offensive_plays"]:.1f} / {flow["recovery_plays"]:.1f}',
                   f'{flow["failure_rate"]:.1%}', f'{sum(flow["income"]):.1f} / {sum(flow["spent"]):.1f}', f'{sum(flow["reserves"]):.1f}']
                  for name, row in before.items() for flow in [row["flow"][1]]]), ""]
    lines += ["Per-card draw, affordability and play counts are in [enemy-cards.csv](enemy-cards.csv). "
              "The compressed summary includes both sides' activity by matchup and the player card counts.", ""]
    for heading, results in data["comparisons"].items():
        lines += [f"## {heading}", "",
                  table(["Enemy", "Combat pairs", "Win Δ pp", "Mean rounds Δ", "Enemy damage/round Δ", "Enemy recovery plays Δ"], [
                      [name, result["n"], interval(result["win"], 100), interval(result["rounds"]),
                       interval(result["damage_per_round"]), interval(result["recovery_plays"])]
                      for name, stats in results.items() for result in [stats["overall"]]]), ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("shards", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--retain", action="append", default=None, help="Name of a validated change to include in final results; repeat as needed")
    parser.add_argument("--release-revision", help="Production revision if any tested resource changes were reverted")
    args = parser.parse_args()
    config, baseline, original_cards, player_cards = opens(args.shards / "full")
    verify_grid(config, baseline, range(1, 9))
    report, ranks = inventory(baseline, config)
    data = {"configuration": config, "baseline_matches": len(baseline), "before": report,
            "ranks": {"before": ranks}, "comparisons": {}, "baseline_seeds": list(range(1, 9)),
            "screening_configs": {}}
    for variant in ("offense", "repair", "draw", "economy", "sentinel-offense", "sentinel-draw"):
        candidate_config, matches, _, _ = opens(args.shards / variant)
        verify_grid(candidate_config, matches, range(1, 7))
        data["screening_configs"][variant] = candidate_config
        data["comparisons"][variant] = comparisons(baseline, matches)
        if variant == "economy":
            economy = matches

    tuned_config, revised, revised_cards, revised_player_cards = opens(args.shards / "final")
    verify_grid(tuned_config, revised, range(1, 9))
    data["tuned_revision"] = args.release_revision or tuned_config["revision"]
    data["validation_revision"] = tuned_config["revision"]
    validation_names = {enemy["name"] for enemy in tuned_config["enemies"]}
    retained = validation_names if args.retain is None else set(args.retain)
    if not retained <= validation_names:
        raise ValueError("Retained names must come from the validation roster")
    if retained != validation_names and not args.release_revision:
        raise ValueError("Specify the production revision when retaining a subset of the tested profiles")
    if any(revised[key] != economy[key] for key in revised.keys() & economy.keys()):
        raise ValueError("The production validation did not reproduce the corresponding candidate matches")
    data["retained"] = sorted(retained)
    data["comparisons"]["Validation on selection seeds"] = comparisons(baseline, revised)
    final = baseline | {key: row for key, row in revised.items() if key[1] in retained}
    data["rerun_matches"] = len(revised)
    data["after"], data["ranks"]["after"] = inventory(final, config)
    held_config, held, _, _ = opens(args.shards / "held")
    verify_grid(held_config, held, range(9, 17))
    held_tuned_config, held_tuned, _, _ = opens(args.shards / "held-final")
    verify_grid(held_tuned_config, held_tuned, range(9, 17))
    held = {key: row for key, row in held.items() if key[1] in validation_names}
    if held.keys() != held_tuned.keys() or baseline.keys() & held.keys():
        raise ValueError("Held-out keys do not match or overlap selection seeds")
    data["comparisons"]["Held-out confirmation"] = comparisons(held, held_tuned)
    data["held_out"] = {"n": len(held), "before_revision": held_config["revision"], "after_revision": held_tuned_config["revision"],
                        "seeds": list(range(9, 17)), "before": inventory(held, held_tuned_config)[0],
                        "after": inventory(held_tuned, held_tuned_config)[0]}
    names = [enemy["name"] for enemy in config["enemies"]]
    data["enemy_cards_before"] = card_table(original_cards, names)
    data["enemy_cards_after"] = card_table(original_cards | {key: row for key, row in revised_cards.items() if key[0] in retained}, names)
    data["player_cards_baseline"] = [{"ship": ship, "policy": policy, "cards": cards}
                                     for (ship, policy), cards in sorted(player_cards.items())]
    data["player_cards_validation_encounters"] = [{"ship": ship, "policy": policy, "cards": cards}
                                             for (ship, policy), cards in sorted(revised_player_cards.items())]
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "tables.md").write_text(render(data), encoding="utf-8", newline="\n")
    write_cards(args.output / "enemy-cards.csv", data["enemy_cards_before"], data["enemy_cards_after"])
    with (args.output / "summary.json.gz").open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as compressed:
            compressed.write(json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    print(f"{len(baseline):,} baseline matches, {len(revised):,} tuned matches, {len(held):,} held-out pairs")


if __name__ == "__main__":
    main()
