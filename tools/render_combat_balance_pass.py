"""Render the tables embedded in the Pass 1 review report."""

import argparse
import json
from pathlib import Path


def percent(value):
    return f"{value:.1%}"


def delta(result):
    low, high = result["ci95"]
    return f'{result["delta"] * 100:+.1f} [{low * 100:+.1f}, {high * 100:+.1f}]'


def rates(result, metric):
    return f'{percent(result["before"][metric])} → {percent(result["after"][metric])}'


def table(headers, rows):
    return "\n".join("| " + " | ".join(map(str, row)) + " |"
                     for row in [headers, ["---"] * len(headers), *rows])


def paired_table(results):
    return table(["Group", "Pairs", "Combat wins", "Δ pp [95% interval]", "EMP escapes", "Δ pp [95% interval]"],
                 [(name, f'{r["n_total"]:,}', rates(r["combat"], "combat_win"), delta(r["combat"]["paired"]),
                   rates(r["emp"], "emp"), delta(r["emp"]["paired"])) for name, r in results.items()])


def render(data):
    final = data["final"]
    matchups = final["matchups"]
    enemies = list(next(iter(matchups.values())))
    rows = ["# Combat Balance Pass 1 results", "",
            "## Full combined rerun versus PR #65", "",
            paired_table({"All ships": final["overall"], **final["ships"]}), "",
            "Combat rates use the four non-EMP policies. EMP rates use the EMP policy only. "
            "Pairs include both groups. All intervals are paired 95% seed-block bootstrap intervals.", "",
            "### Combat-win matchup matrix", "",
            "Each cell uses 512 combat pairs. Bold marks a change of at least five percentage points.", ""]
    cells = []
    for ship, values in matchups.items():
        row = [ship]
        for enemy in enemies:
            result = values[enemy]["combat"]
            text = f'{rates(result, "combat_win")} ({result["paired"]["delta"] * 100:+.1f} pp)'
            row.append(f"**{text}**" if abs(result["paired"]["delta"]) >= .05 else text)
        cells.append(row)
    rows += [table(["Ship", *enemies], cells), "",
             "### Storm cells in the combined rerun", "", paired_table(final["storms"]), "",
             "## Isolated changes", "", "### Guaranteed amplification alone", "",
             paired_table(data["storm_only"]), "",
             f'All {data["unchanged_nonstorm_rows"]:,} nonstorm battle records matched PR #65 field for field.', "",
             "### Individual experiments versus the guaranteed-amplification control", "",
             paired_table({name: result["overall"] for name, result in data["candidates"].items()}), "",
             "### Enemy shield trials by player ship", ""]
    for name in ("choir", "rustjack"):
        rows += [f'**{"The Hollow Choir" if name == "choir" else "Rustjack"}**', "",
                 paired_table(data["candidates"][name]["ships"]), ""]
    rows += ["### Card trials by player ship", "",
             "Card rates cover all five policies. Systems Failure counts use combat policies and list "
             "player/enemy activations. Hull damage and net resource change are observed per play. "
             "Net resource change includes the card cost.", ""]
    cards = []
    for name in ("fabrication", "infiltration", "boarding"):
        candidate = data["candidates"][name]
        for ship, detail in candidate["cards"].items():
            result = candidate["ships"][ship]["combat"]
            failure = " → ".join("/".join(map(str, result[side]["failure_activations"])) for side in ("before", "after"))
            damage = " → ".join(f'{detail[side]["hull_per_play"]:.2f}' for side in ("before", "after"))
            resource = " → ".join(f'{detail[side]["family_net_per_play"]:+.2f}' for side in ("before", "after"))
            cards.append([name, ship, rates(detail, "affordable_per_hold"), rates(detail, "plays_per_draw"),
                          damage, resource, failure, delta(result["paired"])])
    rows += [table(["Trial", "Ship", "Affordable per held turn", "Plays per draw", "Hull damage per play",
                    "Net family resources per play", "Systems Failure", "Combat Δ pp [95% interval]"], cards), ""]
    if "holdout" in data:
        rows += ["## Held-out seeds 17–24", "",
                 "The control has guaranteed storms and the original decks and Choir shields. "
                 "The combined arm includes both deck swaps and the Choir adjustment.", "",
                 paired_table(data["holdout"]), ""]
    return "\n".join(rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("comparison", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(render(json.loads(args.comparison.read_text(encoding="utf-8"))), encoding="utf-8")
