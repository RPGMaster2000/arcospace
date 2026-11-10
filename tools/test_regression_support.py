import copy
import os
from pathlib import Path
import sys
import tempfile
import unittest
from check_regression_matrix import validate
from regression_support import completion_for, select_shard
from run_regressions import run_process


class IntegrityTests(unittest.TestCase):
    def test_shards_cover_exactly_once_and_stable(self):
        names = ['a_test', 'b_test', 'c_test', 'd_test']
        shards = [select_shard(names, 'headless', n, 2) for n in [1, 2]]
        self.assertEqual(sorted(sum(shards, [])), sorted(names))
        self.assertFalse(set(shards[0]) & set(shards[1]))
        self.assertEqual(shards[0], select_shard(list(reversed(names)), 'headless', 1, 2))
        for index, count in [(0, 2), (3, 2), (1, 0)]:
            with self.assertRaises(ValueError): select_shard(names, 'headless', index, count)
        with self.assertRaises(ValueError): select_shard(['a', 'a'], 'headless')

    def test_matrix_rejects_missing_failed_duplicate_and_incomplete(self):
        names = ['a_test', 'b_test', 'c_test']
        rows = []
        for n in [1, 2]:
            selected = select_shard(names, 'headless', n, 2)
            rows.append(dict(suite='headless', shard_index=n, shard_count=2, focused=False,
                             complete=True, selected=selected, runs=[dict(name=x, status='passed', test_completed=True) for x in selected]))
        validate(rows, 'headless', names)
        bad = [rows[:1], [rows[0], rows[0]]]
        for key, value in [('complete', False), ('focused', True), ('selected', [])]:
            changed = copy.deepcopy(rows); changed[0][key] = value; bad.append(changed)
        for key, value in [('status', 'failed'), ('test_completed', False), ('name', 'unknown')]:
            changed = copy.deepcopy(rows); changed[0]['runs'][0][key] = value; bad.append(changed)
        changed = copy.deepcopy(rows); changed[0]['runs'].append(changed[0]['runs'][0]); bad.append(changed)
        for changed in bad:
            with self.subTest(changed=changed), self.assertRaises(ValueError): validate(changed, 'headless', names)

    def test_atomic_partial_summary_reports_incomplete(self):
        import json
        import time
        from regression_support import write_summary
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"summary.json"
            summary = dict(complete=False, runs=[dict(name="finished", status="passed")], running="next")
            write_summary(path, summary, time.monotonic())
            restored = json.loads(path.read_text())
            self.assertFalse(restored['complete'])
            self.assertEqual(restored['running'], 'next')
            self.assertEqual(len(restored['runs']), 1)
            self.assertFalse(path.with_suffix('.json.tmp').exists())

    def test_headless_skip_messages_are_not_rendered_completion(self):
        import re
        for name, message in [("orbit_visibility_test", "Orbit visibility: skipped without rendering device"),
                              ("space_parallax_test", "Space parallax pixel checks: skipped without a rendering device")]:
            self.assertIsNotNone(re.search(completion_for(name, headless=True), message))
            self.assertIsNone(re.search(completion_for(name), message))

    def test_completion_required_and_crash_after_completion_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            for code, status in [("pass", 'failed'), ("print('Godot Engine')", 'failed'),
                                 ("print('12 checks, 0 failures')", 'passed'),
                                 ("print('12 checks, 0 failures'); raise SystemExit(3)", 'failed')]:
                result = run_process([sys.executable, '-c', code], Path(directory)/'run.log', 5, completion_for('fixture'))
                self.assertEqual(result['status'], status)

    @unittest.skipIf(os.name == 'nt', 'POSIX process group contract')
    def test_descendant_holding_stdout_is_killed(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory)/'orphan'
            child = f'import time; from pathlib import Path; time.sleep(5); Path({str(marker)!r}).touch()'
            code = f'import subprocess,sys; subprocess.Popen([sys.executable,"-c",{child!r}]); print("0 failures",flush=True)'
            result = run_process([sys.executable, '-c', code], Path(directory)/'run.log', 5, r'0 failures')
            self.assertEqual(result['status'], 'failed')
            self.assertTrue(result['lingering_output'])
            self.assertLess(result['seconds'], 5)
