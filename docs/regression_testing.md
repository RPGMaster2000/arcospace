# Running regression tests

## Required test review for every behavior change

Treat test impact analysis as part of implementation, **before the first push/CI run**.
For each gameplay, animation, UI, save, or system change:

1. Search `tests/` and rendered test scripts for affected assertions, fixtures,
   timing assumptions, deterministic hashes, and hard-coded counts.
2. Define the new behavioral contract and which existing guarantees remain.
3. Update affected tests **in the same change as the implementation**. Add focused
   positive and negative coverage for the new behavior; preserve unaffected checks.
4. Prefer observable event/state boundaries to brittle fixed step counts or sleeps.
   For intended timing changes, explicitly test the new sequence and durations.
5. Before opening/updating a PR, review the implementation diff and test diff together;
   identify any tests not run locally and use CI to validate them.
6. Do not weaken/delete a failing assertion just to make CI green. Establish whether
   it checks an obsolete expectation or exposes a real regression, and document why
   any assertion is revised.
7. Merge only after required checks pass. If a failing test is unrelated, investigate
   it separately rather than silently changing its expectations.

This is a default development requirement, including narrow one-line changes.
A docs-only change does not require new behavioral tests.


The headless runner is shared by local development and GitHub Actions. It requires
Python 3.9+ (standard library only) and the project's pinned Godot 4.7.2 executable.
From the repository root:

```sh
python3 tools/run_regressions.py --godot /path/to/godot --workers 3
python3 -m unittest discover -s tools -p 'test_*.py' -v
```

On Windows, use `python` and a path to the console Godot executable. Quote paths
containing spaces. `--project` can point to another checkout; `--results` selects
the output directory (default: `test-results` relative to the working directory).
Use a separate results directory for concurrent runs.

Use `--workers 1` for the original sequential behavior (the local default). CI runs
three independent Godot processes concurrently, retaining separate logs, user-data
paths, test timeouts and all assertions. The import remains serialized. Completed
results are saved as tests finish, and the final summary follows discovery order.
Newer commits cancel older runs of the same pull request or branch to save CI time.

The runner imports the project first (180-second timeout), then runs each
`tests/*_test.gd` in its own headless process with Dummy audio and a 120-second
timeout. Override these bounds with `--import-timeout` and `--timeout`.
`--skip-import` is only for an already imported checkout. Progression milestones
run first, once. Balance simulations are not part of this regression selection.
`enemy_models_visual_test.gd` is excluded because it waits for a rendered frame;
the workflow runs it separately with the existing rendered UI checks.

Nonzero exits, timeouts, launch errors, engine/script errors and reported assertion
failures make the command fail. A failed import stops execution; a failed test
does not prevent collecting the remaining test results. Shutdown leak warnings
are retained in logs and listed separately, not suppressed or treated as proof
of a first-party memory leak. Audio playback quality is not verified by Dummy audio.

Each process has a combined stdout/stderr `.log` and a separate `.engine.log`.
`summary.json` is replaced after each result and records the currently running
process, elapsed times, exit codes, errors and shutdown warning lines. If a job is
cancelled, completed results remain available and `complete` stays false. A true
`complete` means every selected test ran, not that every test passed. CI uploads
partial logs even when the job fails. These generated files are not source files.

Godot 4.7.2's shader importer emitted a `ShaderFile` UI-thread error during clean
CI import. The project disables parallel resource import via the editor-only
[`editor/import/use_multiple_threads` setting](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-editor-import-use-multiple-threads).
This leaves runtime threading unchanged and keeps import errors fatal instead of
adding an error-message exception. Reassess this workaround when upgrading Godot.

The workflow runs on pull requests as well as its existing push/manual triggers.
Rendered tests retain their existing selection and now have individual 120-second
bounds, except Power Allocation (300 seconds for its statistical sampling and
all-ship/viewport UI matrix on software rendering). The combined regression job
has a 20-minute bound. Exported-startup validation remains a separate job. Lifecycle ownership
investigation and splitting headless/rendered jobs remain future work.
