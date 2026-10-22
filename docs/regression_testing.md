# Running regression tests

The headless runner is shared by local development and GitHub Actions. It requires
Python 3.9+ (standard library only) and the project's pinned Godot 4.7.2 executable.
From the repository root:

```sh
python3 tools/run_regressions.py --godot /path/to/godot
python3 -m unittest discover -s tools -p 'test_*.py' -v
```

On Windows, use `python` and a path to the console Godot executable. Quote paths
containing spaces. `--project` can point to another checkout; `--results` selects
the output directory (default: `test-results` relative to the working directory).
Use a separate results directory for concurrent runs.

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
bounds. Exported-startup validation remains a separate job. Lifecycle ownership
investigation and splitting headless/rendered jobs remain future work.
