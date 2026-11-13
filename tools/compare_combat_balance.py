"""Compare Pass 1 audit and candidate shards against the archived audit."""

import argparse
from collections import Counter, defaultdict
import gzip
import json
from pathlib import Path
from random import Random
from statistics import mean

from aggregate_combat_audit import collect, summarize


STORMS = ("Ion storm", "Metal storm", "Psionic storm")
CANDIDATES = ("ganymede_deck", "ganymede_reactor", "ganymede_both", "thunderbolt",
              "fabrication", "infiltration", "boarding", "choir", "rustjack", "progressed_boss")


def key(row):
    return tuple(row[name] for name in ("player", "enemy", "modifier", "policy", "seed"))


def load_candidate(path):
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    matches = {key(row): row for row in rows if row["type"] == "match"}
    if (rows[0]["type"] != "config" or rows[0]["variant"] != path.stem
            or rows[-1] != {"type": "complete", "matches": len(matches)}
            or len(matches) != sum(row["type"] == "match" for row in rows)):
        raise ValueError(f"Incomplete or duplicate matches in {path}")
    cards = defaultdict(lambda: {"before": Counter(), "after": Counter()})
    for row in rows:
        if row["type"] == "cards":
            for label, field in (("before", "reference"), ("after", "card")):
                cards[row["player"]][label].update(
                    {k: v for k, v in row[field].items() if type(v) is int and k != "tier"})
    return matches, cards


def changed(before, after, predicate):
    by_seed = defaultdict(list)
    for old, new in zip(before, after, strict=True):
        by_seed[old["seed"]].append(int(predicate(new)) - int(predicate(old)))
    blocks = [mean(values) for _, values in sorted(by_seed.items())]
    rng = Random(1)
    samples = sorted(mean(rng.choices(blocks, k=len(blocks))) for _ in range(4000))
    return {"delta": mean(blocks), "ci95": [samples[100], samples[3899]],
            "seed_blocks": len(blocks)}


def compare(reference, variant, keys):
    keys = sorted(keys)
    combat = [k for k in keys if k[3] != "emp"]
    escape = [k for k in keys if k[3] == "emp"]
    result = {"n_total": len(keys)}
    for name, subset, predicate in (
        ("combat", combat, lambda row: row["outcome"].startswith("win_")),
        ("emp", escape, lambda row: row["outcome"] == "emp_escape"),
    ):
        before = [reference[k] for k in subset]
        after = [variant[k] for k in subset]
        result[name] = {"before": summarize(before), "after": summarize(after),
                        "paired": changed(before, after, predicate)}
    return result


def card_rates(metrics):
    return {"draws": metrics["drawn"], "held_turns": metrics["held_turns"], "plays": metrics["played"],
            "affordable_per_hold": metrics["affordable"] / max(1, metrics["held_turns"]),
            "plays_per_draw": metrics["played"] / max(1, metrics["drawn"]),
            "hull_per_play": metrics["target_hull"] / max(1, metrics["played"]),
            "family_net_per_play": metrics["family_net"] / max(1, metrics["played"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("storm_shards", type=Path)
    parser.add_argument("candidate_shards", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--final-shards", type=Path)
    parser.add_argument("--holdout-shards", type=Path)
    args = parser.parse_args()
    with gzip.open(args.baseline, "rt", encoding="utf-8") as archive:
        baseline = {key(row): row for row in map(json.loads, archive)}
    config, storm, _ = collect(args.storm_shards.glob("ship-*.jsonl"))
    if len(baseline) != 30720 or set(storm) != set(baseline):
        raise ValueError("The storm-only run must cover the original 30,720 matches")
    nonstorm = [k for k in storm if k[2] not in STORMS]
    if any(storm[k] != baseline[k] for k in nonstorm):
        raise ValueError("The storm-only change affected a non-storm match")
    ships = config["ships"]
    enemies = [enemy["name"] for enemy in config["enemies"]]
    data = {
        "storm_only": {name: compare(baseline, storm, (k for k in storm if k[2] == name))
                       for name in STORMS},
        "unchanged_nonstorm_rows": len(nonstorm),
        "candidates": {},
    }
    for name in CANDIDATES:
        path = args.candidate_shards / f"{name}.jsonl"
        variant, cards = load_candidate(path)
        affected = [ship for ship in ships if any(k[0] == ship for k in variant)]
        data["candidates"][name] = {
            "overall": compare(storm, variant, variant),
            "ships": {ship: compare(storm, variant, (k for k in variant if k[0] == ship))
                      for ship in affected},
            "cards": {ship: {label: card_rates(metrics) for label, metrics in groups.items()}
                      for ship, groups in cards.items() if groups["before"]["drawn"]},
        }
    data["choir_diagnosis"] = {
        ship: {policy: summarize([row for k, row in baseline.items()
                                 if k[:2] == (ship, "The Hollow Choir") and k[3] == policy])
               for policy in config["policies"]} for ship in ships
    }
    if args.final_shards:
        final_config, final, _ = collect(args.final_shards.glob("ship-*.jsonl"))
        if set(final) != set(baseline):
            raise ValueError("The combined run must cover the original 30,720 matches")
        data["final"] = {
            "revision": final_config["revision"],
            "overall": compare(baseline, final, final),
            "ships": {ship: compare(baseline, final, (k for k in final if k[0] == ship)) for ship in ships},
            "matchups": {ship: {enemy: compare(baseline, final, (k for k in final if k[:2] == (ship, enemy)))
                                for enemy in enemies} for ship in ships},
            "storms": {name: compare(baseline, final, (k for k in final if k[2] == name)) for name in STORMS},
        }
        if args.holdout_shards:
            _, control, _ = collect((args.holdout_shards / "control").glob("ship-*.jsonl"))
            _, combined, _ = collect((args.holdout_shards / "combined").glob("ship-*.jsonl"))
            if not control or set(control) != set(combined) or set(control) & set(final):
                raise ValueError("Held-out keys must match across arms and use new seeds")
            data["holdout"] = {
                ship: compare(control, combined, (k for k in control if k[0] == ship))
                for ship in sorted({k[0] for k in control})
            }
    args.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
