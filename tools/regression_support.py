"""Small shared scheduling/reporting helpers; no engine or third-party dependency."""
import json
import re
import time
from pathlib import Path

COSTS = Path(__file__).with_name("regression_costs.json")
SUCCESS = {
    "ai_forecast_compatibility_test": r"AI forecast compatibility: \d+ baseline decisions and RNG states match",
    "card_effect_parity_test": r"Card effect parity: \d+ exact baseline checkpoints; live state and RNG unchanged by analysis",
    "combat_state_test": r"Combat state ownership checks passed",
    "combat_trace_test": r"Combat trace parity: \d+ exact baseline traces passed",
    "enemy_models_visual_test": r"Three enemy combat model captures complete",
    "expedition_fresh_process_test": r"Fresh-process persistence: write, forced termination, resume, reward and permadeath passed",
    "storm_ion_parity_test": r"Ion baseline: 32 seeded schedules / 960 round checkpoints match",
}


def completion_for(name):
    return SUCCESS.get(name, r"\b0 failures\b")


def select_shard(names, suite, index=1, count=1):
    """Stable longest-first bin packing; costs only affect order, never membership."""
    if count < 1 or not 1 <= index <= count:
        raise ValueError("shard index must be in 1..shard-count")
    if len(names) != len(set(names)):
        raise ValueError("duplicate tests in suite")
    costs = json.loads(COSTS.read_text(encoding="utf-8")).get(suite, {})
    ordered = sorted(names, key=lambda name: (-costs.get(name, 1.0), name))
    bins = [[] for _ in range(count)]
    totals = [0.0] * count
    for name in ordered:
        target = min(range(count), key=lambda slot: (totals[slot], slot))
        bins[target].append(name)
        totals[target] += costs.get(name, 1.0)
    return bins[index - 1]


def write_summary(path, summary, started):
    summary["elapsed_seconds"] = round(time.monotonic() - started, 3)
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def markdown(summary):
    runs = summary.get("runs", [])
    tests = [run for run in runs if run["name"] != "import"]
    imports = sum(run["seconds"] for run in runs if run["name"] == "import")
    lines = ["### " + summary.get("suite", "regressions") +
             f" — shard {summary.get('shard_index', 1)}/{summary.get('shard_count', 1)}",
             "", f"Complete: **{summary.get('complete', False)}**; "
             f"tests: {len(tests)}/{len(summary.get('selected', tests))}; "
             f"wall: {summary.get('elapsed_seconds', 0):.3f}s; import: {imports:.3f}s; "
             f"sum of test processes: {sum(run['seconds'] for run in tests):.3f}s.",
             "", "| Slowest tests | Seconds | Result | Timeout |", "|---|---:|---|---|"]
    for run in sorted(tests, key=lambda item: -item["seconds"])[:12]:
        lines.append(f"| {run['name']} | {run['seconds']:.3f} | {run['status']} | {run.get('timed_out', False)} |")
    return "\n".join(lines) + "\n"
