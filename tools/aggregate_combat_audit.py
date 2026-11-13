"""Validate and aggregate deterministic combat audit JSONL shards."""

import argparse
from collections import Counter, defaultdict
import csv
import gzip
from itertools import product
import json
from math import sqrt
from pathlib import Path
from statistics import mean, median


def success(row):
    return row["outcome"].startswith("win_") or row["outcome"] == "emp_escape"


def wilson(wins, n, z=1.96):
    p = wins / n
    denominator = 1 + z**2 / n
    margin = z * sqrt(p * (1 - p) / n + z**2 / (4 * n**2))
    center = p + z**2 / (2 * n)
    return [max(0.0, (center - margin) / denominator), min(1.0, (center + margin) / denominator)]


def paired_interval(delta):
    n = len(delta)
    increase = wilson(delta.count(1), n, 2.2414)
    decrease = wilson(delta.count(-1), n, 2.2414)
    return [increase[0] - decrease[1], increase[1] - decrease[0]]


def summarize(rows):
    n = len(rows)
    outcomes = Counter(row["outcome"] for row in rows)
    wins = sum(value for key, value in outcomes.items() if key.startswith("win_"))
    successes = wins + outcomes["emp_escape"]
    return {
        "n": n, "outcomes": dict(outcomes), "combat_win": wins / n,
        "emp": outcomes["emp_escape"] / n, "success": successes / n,
        "win_ci95": wilson(wins, n), "success_ci95": wilson(successes, n),
        "mean_rounds": mean(row["rounds"] for row in rows),
        "median_rounds": median(row["rounds"] for row in rows),
        "hull_lost": mean(row["hull_lost"] for row in rows),
        "gross_hull_damage": mean(row["gross_hull_damage"] for row in rows),
        "mean_resources": [
            sum(row["resource_sum"][family] for row in rows)
            / max(1, sum(row["resource_samples"] for row in rows))
            for family in range(3)
        ],
        "failure_activations": [sum(row["failure_activations"][i] for row in rows) for i in range(2)],
        "unaffordable_turn_rate": [
            sum(row["dead_hands"][i] for row in rows) / max(1, sum(row["turns"][i] for row in rows))
            for i in range(2)
        ],
    }


def collect(paths):
    reference = None
    matches = {}
    cards = defaultdict(dict)
    shard_fields = {"type", "selected_ship", "first_seed", "last_seed", "policy_filter"}
    for path in sorted(paths):
        with path.open(encoding="utf-8") as source:
            records = [json.loads(line) for line in source]
        first, last = records[0], records[-1]
        if first["type"] != "config" or last["type"] != "complete":
            raise ValueError(f"Incomplete shard {path}")
        config = {key: val for key, val in first.items() if key not in shard_fields}
        if reference is not None and config != reference:
            raise ValueError(f"Mismatched configuration in {path}")
        reference = config
        ships = config["ships"] if first["selected_ship"] < 0 else [config["ships"][first["selected_ship"]]]
        policies = config["policies"] if first["policy_filter"] == "all" else [first["policy_filter"]]
        expected = set(product(ships, [enemy["name"] for enemy in config["enemies"]], config["modifiers"],
                               policies, range(first["first_seed"], first["last_seed"] + 1)))
        if len(expected) != last["matches"]:
            raise ValueError(f"Unexpected count in {path}")
        groups = set(product(ships, policies))
        for row in records[1:-1]:
            kind = row.pop("type")
            if kind == "match":
                key = tuple(row[name] for name in ("player", "enemy", "modifier", "policy", "seed"))
                if key in matches or key not in expected:
                    raise ValueError(f"Duplicate or out-of-scope match {key}")
                expected.remove(key)
                matches[key] = row
            elif kind == "cards":
                group = row["player"], row["policy"]
                groups.remove(group)
                for key, card in row["cards"].items():
                    total = cards[group].setdefault(key, {})
                    for metric, value in card.items():
                        total[metric] = total.get(metric, 0) + value if isinstance(value, int) and metric != "tier" else value
            else:
                raise ValueError(f"Unexpected row type {kind}")
        if expected or groups:
            raise ValueError(f"Missing results in {path}")
    return reference, matches, cards


def report(config, matches, cards):
    cells = defaultdict(list)
    pairs = defaultdict(list)
    emp_pairs = defaultdict(list)
    ship_pairs = defaultdict(list)
    for key, row in sorted(matches.items()):
        ship, enemy, modifier, policy, seed = key
        for dimensions in ((ship,), (ship, policy), (ship, enemy, policy),
                           (ship, modifier, policy), (ship, enemy, modifier, policy), (enemy, policy),
                           (ship, "combat-only"), (ship, enemy, "combat-only"), (ship, modifier, "combat-only")):
            if dimensions[-1] == "combat-only" and policy == "emp":
                continue
            cells[dimensions].append(row)
        baseline = matches.get((ship, enemy, config["modifiers"][0], policy, seed))
        if baseline is not None:
            pairs[ship, modifier, policy].append(int(success(row)) - int(success(baseline)))
            if policy != "emp":
                pairs[ship, modifier, "combat-only"].append(int(success(row)) - int(success(baseline)))
        if policy == "emp":
            defensive = matches.get((ship, enemy, modifier, "defensive", seed))
            if defensive is not None:
                emp_pairs[ship].append(int(success(row)) - int(success(defensive)))
        else:
            for other in config["ships"]:
                if ship >= other:
                    continue
                comparison = matches.get((other, enemy, modifier, policy, seed))
                if comparison is not None:
                    ship_pairs[ship, other].append(int(success(row)) - int(success(comparison)))
    effects = []
    for (ship, modifier, policy), delta in sorted(pairs.items()):
        counts = Counter(delta)
        changed = counts[-1] + counts[1]
        # Bonferroni-adjusted Wilson bounds for the two discordant proportions.
        effects.append({"ship": ship, "modifier": modifier, "policy": policy,
                        "n": len(delta), "delta": mean(delta), "discordant": changed,
                        "ci_conservative": paired_interval(delta)})
    return {
        "config": config, "completed": len(matches),
        "seeds": sorted({key[-1] for key in matches}),
        "cells": [{"group": key, **summarize(rows)} for key, rows in sorted(cells.items())],
        "paired_modifiers": effects,
        "paired_emp": [{"ship": ship, "n": len(delta), "delta": mean(delta),
                        "gains": delta.count(1), "losses": delta.count(-1), "ci_conservative": paired_interval(delta)}
                       for ship, delta in sorted(emp_pairs.items())],
        "paired_ships_combat_only": [{"ship": ship, "other": other, "n": len(delta),
                                      "delta": mean(delta), "gains": delta.count(1), "losses": delta.count(-1),
                                      "ci_conservative": paired_interval(delta)}
                                     for (ship, other), delta in sorted(ship_pairs.items())],
        "cards": [{"ship": group[0], "policy": group[1], "cards": totals}
                  for group, totals in sorted(cards.items())],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("shards", nargs="+", type=Path)
    args = parser.parse_args()
    config, matches, cards = collect(args.shards)
    data = report(config, matches, cards)
    data["missing_full_factorial_cells"] = sorted(
        set(product(config["ships"], [enemy["name"] for enemy in config["enemies"]],
                    config["modifiers"], config["policies"], data["seeds"])) - set(matches)
    )
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "summary.json").write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8")
    with (args.output / "matches.jsonl.gz").open("wb") as output:
        with gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as archive:
            for key in sorted(matches):
                archive.write((json.dumps(matches[key], separators=(",", ":")) + "\n").encode())
    with (args.output / "card_usage.csv").open("w", encoding="utf-8", newline="") as output:
        fields = ["ship", "policy", "id", "name", "family", "tier", "drawn", "played",
                  "discarded", "held_turns", "affordable", "target_hull", "shield_gain",
                  "hull_gain", "family_net"]
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        for (ship, policy), group in sorted(cards.items()):
            for key, metrics in sorted(group.items()):
                writer.writerow({"ship": ship, "policy": policy, "id": key, **metrics})
    print(f"Validated {len(matches):,} matches")


if __name__ == "__main__":
    main()
