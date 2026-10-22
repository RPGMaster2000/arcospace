"""Run isolated headless Godot regressions with bounded execution and durable logs."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path


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
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
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
    args = parser.parse_args(argv)
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

    def execute(name, extra, timeout):
        # Absolute engine log path also works in restricted local environments.
        command = [args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(project),
                   "--log-file", str(results / (name + ".engine.log"))] + extra
        summary["running"] = name
        save()
        result = run_process(command, results / (name + ".log"), timeout)
        result["name"] = name
        summary["runs"].append(result)
        summary["running"] = None
        save()
        print(f"{result['status'].upper()} {name} ({result['seconds']}s, "
              f"shutdown warnings: {len(result['shutdown_warning_lines'])})", flush=True)
        if result["status"] == "failed":
            print(Path(result["log"]).read_text(encoding="utf-8", errors="replace"), flush=True)
        return result["status"] == "passed"

    save()
    if not args.skip_import and not execute("import", ["--editor", "--import", "--quit"], args.import_timeout):
        # Do not run scripts against an import that failed or timed out.
        return 1
    for script in scripts:
        execute(script.stem, ["--script", str(script)], args.timeout)
    summary["complete"] = True
    save()
    return int(any(run["status"] != "passed" for run in summary["runs"]))


if __name__ == "__main__":
    raise SystemExit(main())
