"""Render the core balance audit tables from its validated summary."""

import json
from collections import Counter, defaultdict
from pathlib import Path
import sys


def rate(value):
    return f"{value:.1%}"


def table(headers, rows):
    print("| " + " | ".join(headers) + " |")
    print("|" + "---|" * len(headers))
    for row in rows:
        print("| " + " | ".join(str(value) for value in row) + " |")
    print()


def render(data):
    config = data["config"]
    ships = config["ships"]
    cells = {tuple(cell["group"]): cell for cell in data["cells"]}
    print("# Combat audit tables\n")
    for policy in ("combat-only", "emp"):
        print(f"## {policy.title()} outcomes by ship\n")
        rows = []
        for ship in ships:
            cell = cells[ship, policy]
            outcomes = cell["outcomes"]
            losses = sum(n for key, n in outcomes.items() if key.startswith("loss"))
            draws = sum(n for key, n in outcomes.items() if key.startswith("draw"))
            limits = outcomes.get("round_limit", 0) + outcomes.get("action_limit", 0)
            ci = "–".join(rate(x) for x in cell["success_ci95"])
            rows.append([ship, cell["n"], rate(cell["combat_win"]), rate(cell["emp"]),
                         rate(cell["success"]), ci, rate(losses / cell["n"]), draws, limits,
                         f'{cell["mean_rounds"]:.1f} / {cell["median_rounds"]:g}', f'{cell["hull_lost"]:.1f}',
                         f'{cell["gross_hull_damage"]:.1f}'])
        table(["Ship", "N", "Win", "Escape", "Success", "95% CI", "Defeat", "Draws", "Limits",
               "Rounds mean / median", "Net Hull lost", "Gross permanent Hull damage"], rows)
    print("## Combat wins by policy\n")
    policies = list(config["policies"])
    table(["Ship", *policies], [[ship, *(rate(cells[ship, p]["combat_win"]) for p in policies)] for ship in ships])
    print("## Paired effect of taking the first legal EMP escape\n")
    print("Each pair uses the same defensive policy, opponent, modifier and seed. Gains and losses count changes in the combined success outcome.\n")
    table(["Ship", "Pairs", "Success gain", "Success loss", "Net change (pp)"],
          [[row["ship"], row["n"], row["gains"], row["losses"], f'{row["delta"] * 100:+.1f}']
           for row in data["paired_emp"]])
    print("## Enemy matchup matrix\n")
    print("Cells show combat-only win rate. Ranks 0, 1 and 2 indicate ordinary, elite and boss.\n")
    table(["Enemy", "Rank", "N per ship", *ships],
          [[enemy["name"], enemy["rank"], cells[ships[0], enemy["name"], "combat-only"]["n"],
            *(rate(cells[ship, enemy["name"], "combat-only"]["combat_win"]) for ship in ships)]
           for enemy in config["enemies"]])
    print("## Environmental synergies\n")
    print("Cells show combat-only wins, then paired percentage-point change versus None. The JSON includes paired intervals and separate EMP cells.\n")
    effects = {(row["ship"], row["modifier"]): row for row in data["paired_modifiers"] if row["policy"] == "combat-only"}
    table(["Modifier", "N per ship", *ships],
          [[m, effects[ships[0], m]["n"], *(f'{rate(cells[ship, m, "combat-only"]["combat_win"])} ({effects[ship, m]["delta"] * 100:+.1f})'
                                            for ship in ships)] for m in config["modifiers"]])
    print("## Resources and failure\n")
    print("Combat-only policies, sampled after income at the start of each turn. Failure entries count activations.\n")
    table(["Ship", "Mean Materials / Energy / Crew", "Unaffordable player turns",
           "Unaffordable enemy turns", "Failure entries player / enemy", "Systems wins / defeats"],
          [[ship, " / ".join(f"{value:.1f}" for value in cell["mean_resources"]),
            *(rate(value) for value in cell["unaffordable_turn_rate"]),
            " / ".join(str(value) for value in cell["failure_activations"]),
            f'{cell["outcomes"].get("win_systems", 0)} / {cell["outcomes"].get("loss_systems", 0)}']
           for ship in ships for cell in [cells[ship, "combat-only"]]])
    print("## Starting-deck card observations\n")
    print("Combat-only policies. A card appears in the ranked samples after at least 200 draws. Usage includes each identity’s legal and illegal holdings and may reflect policy bias.\n")
    cards = defaultdict(Counter)
    labels = {}
    for group in data["cards"]:
        if group["policy"] == "emp":
            continue
        for identity, card in group["cards"].items():
            labels[identity] = card["name"], card["tier"], card["family"]
            cards[identity].update({key: value for key, value in card.items()
                                    if key not in {"name", "tier", "family"}})
    eligible = [key for key, row in cards.items() if row["drawn"] >= 200]
    ranked = sorted(eligible, key=lambda key: (cards[key]["played"] / cards[key]["drawn"], key))
    for title, identities in [("Lowest play per draw", ranked[:10]), ("Highest play per draw", ranked[-10:][::-1])]:
        print(f"### {title}\n")
        table(["Card", "Tier", "Family", "Drawn", "Played / drawn", "Affordable holdings", "Hull damage / play"],
              [[*labels[key], row["drawn"], rate(row["played"] / row["drawn"]),
                rate(row["affordable"] / max(1, row["held_turns"])),
                f'{row["target_hull"] / max(1, row["played"]):.1f}']
               for key in identities for row in [cards[key]]])


if __name__ == "__main__":
    render(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")))
