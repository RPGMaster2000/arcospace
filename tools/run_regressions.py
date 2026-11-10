"""Run isolated headless Godot regressions with bounded execution and durable logs."""
import argparse
import json
import os
import re
import signal
import subprocess
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from regression_support import completion_for, markdown, select_shard, write_summary


TIMEOUTS = {"card_progression_test": 600, "card_tier_test": 300, "poi_reward_overhaul_test": 600, "power_allocation_test": 300, "trading_outpost_ui_test": 600, "travel_battle_test": 600, "ui_overhaul_test": 600}

RENDER_ONLY = {"enemy_models_visual_test.gd"}  # Awaits frame_post_draw.
ERRORS = re.compile(r"SCRIPT ERROR|ERROR:|Parse Error|Compile Error|Assertion failed|\b[1-9][0-9]* failures\b")
LEAKS = re.compile(r"ObjectDB.*leaked", re.IGNORECASE)


def discover(project):
    scripts = [p for p in sorted((project / "tests").glob("*_test.gd"))
               if p.name not in RENDER_ONLY]
    # Keep progression failures visible early, without executing the test twice.
    return sorted(scripts, key=lambda p: p.name != "expedition_milestones_test.gd")


def _kill_tree(process):
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    if process.poll() is None:
        process.kill()
    process.wait()


def run_process(command, log_path, timeout, completion_pattern=None):
    started = time.monotonic()
    timed_out = False
    exit_code = None
    launch_error = None
    lifecycle = {"first_output_seconds": None, "completion_seconds": None}
    reader_error = []
    lingering_output = False
    pattern = re.compile(completion_pattern) if completion_pattern else None
    with log_path.open("w", encoding="utf-8") as log:
        try:
            environment = os.environ.copy()
            userdata = (log_path.parent / "userdata" / log_path.stem).resolve()
            environment["XDG_DATA_HOME"] = str(userdata)
            if os.name == "nt":
                # Godot uses APPDATA on Windows, not XDG_DATA_HOME.
                environment["APPDATA"] = str(userdata / "AppData")
                environment["LOCALAPPDATA"] = str(userdata / "LocalAppData")
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace", env=environment,
                                       start_new_session=os.name != "nt",
                                       creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)

            def read_output():
                try:
                    for line in process.stdout:
                        elapsed = time.monotonic() - started
                        if lifecycle["first_output_seconds"] is None:
                            lifecycle["first_output_seconds"] = round(elapsed, 3)
                        if pattern and pattern.search(line):
                            lifecycle["completion_seconds"] = round(elapsed, 3)
                        log.write(line)
                        log.flush()
                except (OSError, ValueError) as error:
                    reader_error.append(str(error))

            reader = threading.Thread(target=read_output, daemon=True)
            reader.start()
            try:
                exit_code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                _kill_tree(process)
            except BaseException:
                _kill_tree(process)
                raise
            reader.join(timeout=2)
            if reader.is_alive():
                # A descendant holding stdout open must not turn an incomplete run green.
                lingering_output = True
                _kill_tree(process)
                reader.join(timeout=5)
            if not reader.is_alive():
                process.stdout.close()
        except OSError as error:
            launch_error = str(error)
            log.write(launch_error + "\n")
    output = log_path.read_text(encoding="utf-8", errors="replace")
    diagnostics = [line for line in output.splitlines() if ERRORS.search(line)]
    metrics = []
    for line in output.splitlines():
        if line.startswith("REGRESSION_METRIC "):
            try:
                metrics.append(json.loads(line.removeprefix("REGRESSION_METRIC ")))
            except json.JSONDecodeError:
                diagnostics.append("Malformed regression timing metric: " + line)
    completed = lifecycle["completion_seconds"] is not None if pattern else None
    elapsed = round(time.monotonic() - started, 3)
    return {
        "status": "failed" if timed_out or exit_code != 0 or diagnostics or reader_error or lingering_output or completed is False else "passed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "launch_error": launch_error,
        "completion_pattern": completion_pattern,
        "test_completed": completed,
        "reader_errors": reader_error,
        "lingering_output": lingering_output,
        **lifecycle,
        "after_completion_seconds": round(elapsed - lifecycle["completion_seconds"], 3) if completed else None,
        "metrics": metrics,
        "error_lines": diagnostics,
        "shutdown_warning_lines": [line for line in output.splitlines() if LEAKS.search(line)],
        "seconds": elapsed,
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
    parser.add_argument("--script", action="append", help="focused test stem; full discovery remains the default")
    parser.add_argument("--shard-index", type=int, default=1)
    parser.add_argument("--shard-count", type=int, default=1)
    args = parser.parse_args(argv)
    if args.workers < 1:
        parser.error("--workers must be at least 1")
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        parser.error("--project must contain project.godot")
    scripts = discover(project)
    if not scripts:
        parser.error("no headless regression scripts found")
    available = {script.stem: script for script in scripts}
    if args.script and (len(args.script) != len(set(args.script)) or set(args.script) - available.keys()):
        parser.error("--script must name distinct discovered headless tests")
    try:
        names = select_shard(args.script or list(available), "headless", args.shard_index, args.shard_count)
    except ValueError as error:
        parser.error(str(error))
    # Retain the existing early progression check, then run expensive tests first.
    names.sort(key=lambda name: name != "expedition_milestones_test")
    scripts = [available[name] for name in names]
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    summary = {"project": str(project), "complete": False, "suite": "headless",
               "selected": names, "focused": bool(args.script), "shard_index": args.shard_index,
               "shard_count": args.shard_count, "workers": args.workers,
               "setup_seconds": float(os.environ.get("REGRESSION_SETUP_SECONDS", 0)),
               "skipped_render_only": sorted(RENDER_ONLY), "runs": []}

    def save():
        write_summary(results / "summary.json", summary, started)
        (results / "timing.md").write_text(markdown(summary), encoding="utf-8")

    def process(name, extra, timeout):
        # Every test has a unique engine log and XDG user-data directory.
        command = [args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(project),
                   "--log-file", str(results / (name + ".engine.log"))] + extra
        result = run_process(command, results / (name + ".log"), timeout,
                             completion_pattern=completion_for(name) if name != "import" else None)
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
