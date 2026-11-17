"""Report the isolated enemy pacing trials and production-profile validation."""

import argparse
import gzip
import json
from pathlib import Path

from report_enemy_balance import (
    card_table, interval, inventory, metrics, non_emp, opens, paired, render, table, verify_grid, write_cards,
)

SCREENS = (
    "decisive-deck", "decisive-deck-alt", "decisive-shields", "decisive-production", "decisive-spore-trim",
    "decisive-spore-hull", "decisive-affordable",
)
STAGES = ("boss-early", "boss-middle", "boss-later")
SEEDS = range(1, 9)
HELD_SEEDS = range(21, 29)
EXTRA = {
    "over40": lambda r: int(r["rounds"] > 40),
    "unresolved": lambda r: int(r["outcome"].endswith("_limit")),
    "recovery_sequences": lambda r: r["recovery_sequences"],
    "hull_restored": lambda r: r["flows"][1]["hull_restored"],
    "shields_gained": lambda r: r["flows"][1]["shields_gained"],
}


def read(root, arm, seeds=SEEDS, combat_only=False):
    config, rows, cards, _ = opens(root / arm)
    grid_config = dict(config)
    if combat_only:
        grid_config["policies"] = {k: v for k, v in config["policies"].items() if k != "emp"}
    verify_grid(grid_config, rows, seeds)
    return config, rows, cards


def compare(before, candidate):
    if not candidate.keys() <= before.keys():
        raise ValueError("Candidate contains conditions absent from the baseline")
    names = sorted({key[1] for key in candidate})
    output = {}
    for name in names:
        keys = [key for key in candidate if key[1] == name and non_emp(key)]
        output[name] = {
            "overall": paired(before, candidate, keys, extra=EXTRA),
            "ships": {ship: paired(before, candidate, [key for key in keys if key[0] == ship], extra=EXTRA)
                      for ship in sorted({key[0] for key in keys})},
            "before": metrics([before[k] for k in keys]),
            "after": metrics([candidate[k] for k in keys]),
        }
    return output


def screening_table(label, changes):
    return "\n".join([f"### {label}", "", table(
        ["Enemy", "Pairs", "Victory Δ pp", "Mean rounds Δ", ">40 rounds Δ pp", "Unresolved Δ pp",
         "Damage/round Δ", "Recovery sequences Δ"], [
            [name, p["n"], interval(p["win"], 100), interval(p["rounds"]), interval(p["over40"], 100),
             interval(p["unresolved"], 100), interval(p["damage_per_round"]), interval(p["recovery_sequences"])]
            for name, result in changes.items() for p in [result["overall"]]
        ]), ""])


def activity_table(data):
    cells = []
    for name in data["targets"]:
        old, new = (data[phase][name] for phase in ("before", "after"))
        a, b = (m["flow"][1] for m in (old, new))
        cells.append([name, *(f"{a[key]:.2f} → {b[key]:.2f}" for key in ("damage_per_round", "hull_restored",
                     "shields_gained", "offensive_plays", "recovery_plays")),
                      f'{old["recovery_sequences"]:.2f} → {new["recovery_sequences"]:.2f}',
                      f'{a["failure_rate"]:.1%} → {b["failure_rate"]:.1%}',
                      f'{sum(a["income"]):.1f} → {sum(b["income"]):.1f}',
                      f'{sum(a["spent"]):.1f} → {sum(b["spent"]):.1f}'])
    return "\n".join(["## Targeted enemy activity", "", table(
        ["Enemy", "Damage/round", "Hull restored", "Shields gained", "Offense plays", "Recovery plays",
         "Recovery sequences", "Systems Failure", "Production", "Spend"], cells), ""])


def boss_table(data):
    rows = []
    for stage, scenario in data.items():
        for name, result in scenario["enemies"].items():
            rows.append([stage, name, result["n"], f'{result["combat_win"]:.1%}', f'{result["loss"]:.1%}',
                         f'{result["median_rounds"]:.1f}', f'{result["mean_rounds"]:.1f}', result["p90"],
                         f'{result["unresolved"]:.1%}', f'{result["policies"]["emp"]["emp"]:.1%}'])
    return "\n".join(["## Progression-equipped mothership fixtures", "", table(
        ["Stage", "Enemy", "Combat matches", "Win", "Loss", "Median rounds", "Mean rounds", "P90",
         "Unresolved", "EMP escape (separate policy)"], rows), ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("shards", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--retain", action="append", default=[])
    args = parser.parse_args()
    config, baseline, original_cards = read(args.shards, "full")
    before, old_ranks = inventory(baseline, config)
    targets = set()
    trials = {}
    for arm in SCREENS:
        arm_config, candidate, arm_cards = read(args.shards, arm, combat_only=True)
        changes = compare(baseline, candidate)
        targets.update(changes)
        trials[arm] = {"configuration": arm_config, "changes": changes, "cards": card_table(arm_cards, changes)}
        print(screening_table(arm, changes))
    if args.output is None:
        return
    tuned_config, tuned, tuned_cards = read(args.shards, "final")
    held_config, held, _ = read(args.shards, "held", HELD_SEEDS)
    held_tuned_config, held_tuned, _ = read(args.shards, "held-final", HELD_SEEDS)
    held_names = {key[1] for key in held_tuned}
    held_control = {k: v for k, v in held.items() if k[1] in held_names}
    if held_control.keys() != held_tuned.keys() or held.keys() & baseline.keys():
        raise ValueError("Held-out conditions must match exactly and use independent seeds")
    retained = set(args.retain)
    if not retained <= {key[1] for key in tuned}:
        raise ValueError("Every retained profile must have a production-profile rerun")
    final = baseline | {k: v for k, v in tuned.items() if k[1] in retained}
    after, new_ranks = inventory(final, config)
    affordable_config, affordable_held, _ = read(args.shards, "affordable-held", HELD_SEEDS)
    selections = {"Independent affordable-candidate validation": compare(held, affordable_held),
                  "Production profile selection seeds": compare(baseline, tuned),
                  "Production profile held-out seeds": compare(held_control, held_tuned)}
    bosses = {}
    for arm in STAGES:
        boss_config, boss_rows, _ = read(args.shards, arm)
        bosses[arm] = {"configuration": boss_config, "enemies": inventory(boss_rows, boss_config)[0]}
    names = list(before)
    cards_before = card_table(original_cards, names)
    cards_after = card_table(original_cards | {k: v for k, v in tuned_cards.items() if k[0] in retained}, names)
    report = {"configuration": config, "before": before, "after": after, "ranks": {"before": old_ranks, "after": new_ranks},
              "targets": sorted(targets), "trials": trials, "validation": selections, "bosses": bosses, "comparisons": {},
              "baseline_matches": len(baseline), "tuned_revision": tuned_config["revision"], "retained": sorted(retained),
              "held_revisions": [held_config["revision"], held_tuned_config["revision"]], "held_seeds": list(HELD_SEEDS),
              "held_candidate_configuration": affordable_config}
    args.output.mkdir(parents=True, exist_ok=True)
    sections = [render(report), activity_table(report), "## Paired scenario results", ""]
    sections.extend(screening_table(name, trial["changes"]) for name, trial in trials.items())
    sections.extend(screening_table(name, results) for name, results in selections.items())
    sections.append(boss_table(bosses))
    (args.output / "tables.md").write_text("\n".join(sections), encoding="utf-8", newline="\n")
    write_cards(args.output / "enemy-cards.csv", cards_before, cards_after)
    with (args.output / "summary.json.gz").open("wb") as stream:
        with gzip.GzipFile(fileobj=stream, mode="wb", filename="", mtime=0) as archive:
            archive.write(json.dumps(report, sort_keys=True, separators=(",", ":")).encode("utf-8"))


if __name__ == "__main__":
    main()
