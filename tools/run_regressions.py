"""Run isolated headless Godot regressions with bounded execution and durable logs."""
import argparse
import json
import os
import re
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


TIMEOUTS = {"card_progression_test": 600, "card_tier_test": 300, "poi_reward_overhaul_test": 600, "power_allocation_test": 300, "trading_outpost_ui_test": 600, "travel_battle_test": 600, "ui_overhaul_test": 600}

RENDER_ONLY = {"enemy_models_visual_test.gd"}  # Awaits frame_post_draw.
ERRORS = re.compile(r"SCRIPT ERROR|ERROR:|Parse Error|Compile Error|Assertion failed|\b[1-9][0-9]* failures\b")
LEAKS = re.compile(r"ObjectDB.*leaked", re.IGNORECASE)


def discover(project):
    scripts = [p for p in sorted((project / "tests").glob("*_test.gd"))
               if p.name not in RENDER_ONLY]
    # Keep progression failures visible early, without executing the test twice.
    return sorted(scripts, key=lambda p: p.name != "expedition_milestones_test.gd")


def run_process(command, log_path, timeout):
    started = time.monotonic()
    timed_out = False
    exit_code = None
    launch_error = None
    with log_path.open("w", encoding="utf-8") as log:
        try:
            environment = os.environ.copy()
            environment["XDG_DATA_HOME"] = str((log_path.parent / "userdata" / log_path.stem).resolve())
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=environment,
                                    timeout=timeout, check=False)
            exit_code = result.returncode
        except subprocess.TimeoutExpired:
            # subprocess.run kills and waits for the engine before returning here.
            timed_out = True
        except OSError as error:
            launch_error = str(error)
            log.write(launch_error + "\n")
    output = log_path.read_text(encoding="utf-8", errors="replace")
    diagnostics = [line for line in output.splitlines() if ERRORS.search(line)]
    return {
        "status": "failed" if timed_out or exit_code != 0 or diagnostics else "passed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "launch_error": launch_error,
        "error_lines": diagnostics,
        "shutdown_warning_lines": [line for line in output.splitlines() if LEAKS.search(line)],
        "seconds": round(time.monotonic() - started, 3),
        "log": str(log_path),
    }


def positive_seconds(value):
    number = float(value)
    if not 0 < number < float("inf"):
        raise argparse.ArgumentTypeError("timeout must be finite and greater than zero")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="engine executable or command on PATH")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--results", type=Path, default=Path("test-results"))
    parser.add_argument("--timeout", type=positive_seconds, default=120)
    parser.add_argument("--import-timeout", type=positive_seconds, default=180)
    parser.add_argument("--skip-import", action="store_true", help="use an already imported checkout")
    parser.add_argument("--workers", type=int, default=1, help="concurrent isolated test processes (default: 1)")
    args = parser.parse_args(argv)
    if args.workers < 1:
        parser.error("--workers must be at least 1")
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        parser.error("--project must contain project.godot")
    scripts = discover(project)
    if not scripts:
        parser.error("no headless regression scripts found")
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)
    summary = {"project": str(project), "complete": False,
               "skipped_render_only": sorted(RENDER_ONLY), "runs": []}

    def save():
        temporary = results / "summary.json.tmp"
        temporary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        temporary.replace(results / "summary.json")

    def process(name, extra, timeout):
        # Every test has a unique engine log and XDG user-data directory.
        command = [args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(project),
                   "--log-file", str(results / (name + ".engine.log"))] + extra
        result = run_process(command, results / (name + ".log"), timeout)
        result["name"] = name
        return result

    def record(result):
        summary["runs"].append(result)
        summary["running"] = None
        save()
        print(f"{result['status'].upper()} {result['name']} ({result['seconds']}s, "
              f"shutdown warnings: {len(result['shutdown_warning_lines'])})", flush=True)
        if result["status"] == "failed":
            print(Path(result["log"]).read_text(encoding="utf-8", errors="replace"), flush=True)

    save()
    if not args.skip_import:
        summary["running"] = "import"
        save()
        imported = process("import", ["--editor", "--import", "--quit"], args.import_timeout)
        record(imported)
        if imported["status"] != "passed":
            return 1

    # Import must finish before parallel readers start. Preserve the progression-first
    # order in the final summary regardless of worker completion order.
    def run_test(script):
        return process(script.stem, ["--script", str(script)],
                       TIMEOUTS.get(script.stem, args.timeout))

    summary["running"] = [script.stem for script in scripts]
    save()
    if args.workers == 1:
        for script in scripts:
            record(run_test(script))
    else:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(run_test, script): script.stem for script in scripts}
            ordered = {}
            for future in as_completed(futures):
                result = future.result()
                ordered[result["name"]] = result
                summary["running"] = [name for name in (script.stem for script in scripts)
                                      if name not in ordered]
                # Persist finished runs even if cancelled later, in discovery order.
                summary["runs"] = [ordered[script.stem] for script in scripts
                                   if script.stem in ordered]
                save()
                print(f"{result['status'].upper()} {result['name']} ({result['seconds']}s, "
                      f"shutdown warnings: {len(result['shutdown_warning_lines'])})", flush=True)
                if result["status"] == "failed":
                    print(Path(result["log"]).read_text(encoding="utf-8", errors="replace"), flush=True)
    summary["complete"] = True
    summary["running"] = None
    save()
    return int(any(run["status"] != "passed" for run in summary["runs"]))

if __name__ == "__main__":
    raise SystemExit(main())
