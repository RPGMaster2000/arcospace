"""Runner contract tests; no Godot installation required."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run_regressions as runner


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def process(self, code, timeout=10):
        return runner.run_process([sys.executable, "-c", code], self.root / "run.log", timeout)

    def test_zero_exit_diagnostics_fail(self):
        for message in ["SCRIPT ERROR: bad", "ERROR: bad", "Parse Error: bad",
                        "Compile Error: bad", "Assertion failed", "12 checks, 2 failures"]:
            with self.subTest(message=message):
                result = self.process(f"print({message!r})")
                self.assertEqual(result["exit_code"], 0)
                self.assertEqual(result["status"], "failed")

    def test_shutdown_warnings_are_preserved_and_separate(self):
        result = self.process("print('28 checks, 0 failures'); print('WARNING: 2 ObjectDB instances were leaked at exit')")
        self.assertEqual(result["status"], "passed")
        self.assertEqual(len(result["shutdown_warning_lines"]), 1)
        self.assertIn("leaked", Path(result["log"]).read_text())

    def test_nonzero_exit_fails(self):
        self.assertEqual(self.process("raise SystemExit(7)")["exit_code"], 7)
        self.assertEqual(self.process("raise SystemExit(7)")["status"], "failed")

    def test_timeout_preserves_partial_output(self):
        result = self.process("import time; print('started', flush=True); time.sleep(30)", timeout=1)
        self.assertTrue(result["timed_out"])
        self.assertEqual(result["status"], "failed")
        self.assertIn("started", Path(result["log"]).read_text())

    def test_missing_executable_fails(self):
        result = runner.run_process([str(self.root / "missing")], self.root / "missing.log", 1)
        self.assertEqual(result["status"], "failed")
        self.assertIsNotNone(result["launch_error"])

    def project(self):
        (self.root / "project.godot").touch()
        tests = self.root / "tests"
        tests.mkdir()
        for name in ["a_test.gd", "expedition_milestones_test.gd", "enemy_models_visual_test.gd", "diagnostic.gd"]:
            (tests / name).touch()

    def test_discovery_excludes_rendering_and_simulations(self):
        self.project()
        self.assertEqual([p.name for p in runner.discover(self.root)],
                         ["expedition_milestones_test.gd", "a_test.gd"])

    def invoke(self, *extra):
        with contextlib.redirect_stdout(io.StringIO()):
            return runner.main(["--project", str(self.root), "--results", str(self.root / "results"), *extra])

    def test_failed_import_stops_suite_and_saves_result(self):
        self.project()
        with patch.object(runner, "run_process", return_value={"status": "failed", "seconds": 0,
                          "shutdown_warning_lines": [], "log": str(self.root / "project.godot")}) as run:
            self.assertEqual(self.invoke(), 1)
        self.assertEqual(run.call_count, 1)
        summary = json.loads((self.root / "results/summary.json").read_text())
        self.assertFalse(summary["complete"])
        self.assertEqual(summary["runs"][0]["name"], "import")

    def test_suite_continues_after_failure_and_records_each_result(self):
        self.project()
        def run(command, log, timeout):
            summary = json.loads((self.root / "results/summary.json").read_text())
            self.assertEqual(len(summary["runs"]), 0 if "expedition_milestones" in str(log) else 1)
            log.write_text("fixture output")
            return {"status": "failed" if "expedition_milestones" in str(log) else "passed",
                    "seconds": 0, "shutdown_warning_lines": [], "log": str(log)}
        with patch.object(runner, "run_process", side_effect=run):
            self.assertEqual(self.invoke("--skip-import"), 1)
        summary = json.loads((self.root / "results/summary.json").read_text())
        self.assertTrue(summary["complete"])
        self.assertEqual(len(summary["runs"]), 2)

    def test_parallel_suite_retains_every_result_and_failure(self):
        self.project()
        def run(command, log, timeout):
            import time
            if "a_test" in str(log):
                time.sleep(0.02)
            log.write_text("fixture output")
            return {"status": "failed" if "a_test" in str(log) else "passed",
                    "seconds": 0, "shutdown_warning_lines": [], "log": str(log)}
        with patch.object(runner, "run_process", side_effect=run):
            self.assertEqual(self.invoke("--skip-import", "--workers", "3"), 1)
        summary = json.loads((self.root / "results/summary.json").read_text())
        self.assertTrue(summary["complete"])
        self.assertEqual([r["name"] for r in summary["runs"]],
                         ["expedition_milestones_test", "a_test"])
        self.assertEqual([r["status"] for r in summary["runs"]], ["passed", "failed"])

    def test_rejects_zero_workers(self):
        self.project()
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            self.invoke("--workers", "0")
        self.assertEqual(error.exception.code, 2)

    def test_empty_suite_is_an_error(self):
        (self.root / "project.godot").touch()
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            self.invoke()
        self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
