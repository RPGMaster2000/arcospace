"""Run the explicit rendered suites with the headless runner's timeout/error contract.

Run under an existing display, e.g. xvfb-run -a python3 tools/run_rendered_regressions.py.
The renderer must be selected explicitly in CI; Mobile uses Vulkan, never GL fallback.
"""
import argparse
import json
from pathlib import Path

from run_regressions import positive_seconds, run_process

# One selection shared by local verification and CI. These are presentation checks,
# rather than all rule simulations running a second time through a renderer.
COMPATIBILITY = (
    "cinematic_visual_test", "cinematic_touch_test", "cinematic_launch_test",
    "expedition_resume_test", "systems_failure_test", "battle_layout_test",
    "shield_shatter_test", "alpha_visual_test", "power_allocation_test",
    "expedition_milestones_test", "star_map_test", "battlefield_environments_test",
    "field_repairs_ui_test", "outpost_screen_test", "repair_selection_test",
    "six_ship_profiles_test", "chasedown_ui_test", "deck_replacement_ui_test",
    "card_inspection_test", "enemy_models_visual_test", "ship_models_test",
    "settings_menu_test", "startup_flow_test", "unified_hud_test",
    "tactical_focus_test", "compact_poi_focus_test", "tactical_resize_test",
    "hud_ownership_test", "star_system_render_smoke_test", "layout_invalidation_test",
    "star_map_navigation_test", "metagame_ui_test",
)
MOBILE = ("star_system_render_smoke_test", "tactical_resize_test", "hud_ownership_test", "star_map_navigation_test", "metagame_ui_test")
SUITES = {"gl_compatibility": COMPATIBILITY, "mobile": MOBILE}
TIMEOUTS = {"power_allocation_test": 300}


def command(godot, project, renderer, name):
    return [godot, "--display-driver", "x11", "--rendering-method", renderer,
            "--audio-driver", "Dummy", "--path", str(project),
            "--script", "res://tests/" + name + ".gd", "--", renderer]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--renderer", choices=SUITES, default="gl_compatibility")
    parser.add_argument("--results", type=Path, default=Path("test-results/rendered"))
    parser.add_argument("--timeout", type=positive_seconds, default=120)
    parser.add_argument("--skip-import", action="store_true", help="Use an already imported checkout")
    parser.add_argument("--script", action="append", choices=COMPATIBILITY,
                        help="Optional focused subset of the same registered suite")
    args = parser.parse_args(argv)
    project = args.project.resolve()
    names = args.script or SUITES[args.renderer]
    for name in names:
        if not (project / "tests" / (name + ".gd")).is_file():
            parser.error("Missing rendered test: " + name)
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)
    (project / ".godot" / "testlogs").mkdir(parents=True, exist_ok=True)
    summary = {"renderer": args.renderer, "complete": False, "runs": [], "running": None}

    def save():
        temporary = results / "summary.json.tmp"
        temporary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        temporary.replace(results / "summary.json")

    save()
    if not args.skip_import:
        summary["running"] = "import"
        save()
        imported = run_process([args.godot, "--headless", "--path", str(project),
                                "--editor", "--import", "--quit"], results / "import.log", 180)
        imported["name"] = "import"
        summary["runs"].append(imported)
        summary["running"] = None
        save()
        if imported["status"] != "passed":
            print((results / "import.log").read_text(encoding="utf-8", errors="replace"), flush=True)
            return 1
    for name in names:
        summary["running"] = name
        save()
        result = run_process(command(args.godot, project, args.renderer, name),
                             results / (name + ".log"), TIMEOUTS.get(name, args.timeout))
        result["name"] = name
        summary["runs"].append(result)
        summary["running"] = None
        save()
        print(f"{result['status'].upper()} {name} ({args.renderer}, {result['seconds']}s)", flush=True)
        if result["status"] != "passed":
            print(Path(result["log"]).read_text(encoding="utf-8", errors="replace"), flush=True)
    summary["complete"] = True
    save()
    return int(any(result["status"] != "passed" for result in summary["runs"]))


if __name__ == "__main__":
    raise SystemExit(main())
