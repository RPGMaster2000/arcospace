import unittest
from pathlib import Path
from run_rendered_regressions import COMPATIBILITY, MOBILE, command


class RenderedSelectionTests(unittest.TestCase):
    def test_every_selected_script_exists_and_is_unique(self):
        project = Path(__file__).resolve().parents[1]
        for suite in [COMPATIBILITY, MOBILE]:
            self.assertEqual(len(suite), len(set(suite)))
            for name in suite:
                self.assertTrue((project / "tests" / (name + ".gd")).is_file(), name)

    def test_new_foundation_checks_are_recurring(self):
        for name in ["unified_hud_test", "tactical_focus_test", "compact_poi_focus_test",
                     "tactical_resize_test", "hud_ownership_test", "star_system_render_smoke_test", "layout_invalidation_test"]:
            self.assertIn(name, COMPATIBILITY)
        self.assertIn("star_system_render_smoke_test", MOBILE)

    def test_mobile_command_requests_mobile_not_compatibility(self):
        args = command("godot", Path("project"), "mobile", "star_system_render_smoke_test")
        self.assertEqual(args[args.index("--rendering-method") + 1], "mobile")
        self.assertEqual(args[-1], "mobile")
        self.assertNotIn("--headless", args)


if __name__ == "__main__":
    unittest.main()
