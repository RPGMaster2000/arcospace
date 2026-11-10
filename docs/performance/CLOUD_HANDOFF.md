# Regression performance audit — paused checkpoint

Paused at the user's explicit request on 2026-11-10 (Europe/Stockholm).
Do not interpret this checkpoint as finished, tested infrastructure or a merge-ready PR.

## Resume in Codex Cloud

Repository: `RPGMaster2000/arcospace`.
Check out **`codex/regression-suite-performance`**, not main. Read this file,
`request.md` (the complete original task), and `../regression_performance_audit.md`.
Resume implementation and validation only when the user asks to continue.
Do not merge the new performance work automatically.

PR #55 was verified green and **merged** before this audit began. The feature
branch starts from main `4680da69085648e8e21021d7aa1c0c7b723d972a` (that merge).
No performance PR has been opened; this is a pushed WIP branch so Cloud can resume.

## Completed investigation

- Read the workflow, both Python runners, runner unit tests, and priority Godot
  regressions. Documented bottlenecks **before modifying test/runner behavior**.
- Downloaded job logs for the four requested historical runs plus PR #55.
  `baseline-ci.json` preserves per-test times, job-log start/end timestamps,
  process sums and import times. Queue time is excluded. PR #55's successful
  headless retry is recorded separately from its original rendered jobs.
- Ran the original priority tests sequentially on Windows / Intel Arc 140V,
  Godot 4.7.2, with already imported assets. Every baseline invocation passed.
  `baseline-local-windows.json` contains the results. Its log paths point to the
  original local checkout; these logs are not required to resume in Cloud.
- Local baseline seconds: trading_outpost 75.755; poi_reward_overhaul 70.154;
  card_progression 45.779; GL power_allocation 71.023; unified_hud 30.086;
  compact_poi_focus 33.370; stellar_shafts_render 8.278;
  stellar_shafts_prototype 4.716; star_system_lighting 5.094;
  solar_render 5.314; starfront_presentation 26.176.
- No benchmark process remains running. No gameplay/rendering files were changed.

## Partial implementation — NOT validated

- `tools/regression_support.py`: completion-message patterns, deterministic
  longest-first shard selection, atomic JSON timing summaries and Markdown output.
- `tools/regression_costs.json`: arithmetic mean process durations from PR #54
  and #55, used only as scheduling estimates; never as a reason to omit a test.
- `tools/run_regressions.py`: WIP focused selection/sharding and cost scheduling;
  Popen-based lifecycle timing, completion-message enforcement, output metrics,
  Linux process-group timeout cleanup and Windows per-test APPDATA isolation.
- `tools/run_rendered_regressions.py`: WIP shard selection/completion enforcement
  and timing output using the shared helpers.
- `tests/regression_wait.gd`: WIP test-only layout readiness, rendered-frame fence,
  screenshot timing and aggregate metrics. It is **not yet used by any test**.

No Python tests, Godot tests or full CI matrix have been run against these partial
changes. Baseline passes are not validation of the new runner. No performance
improvement has yet been demonstrated. Workflow and existing Godot tests are
still unchanged.

## Known unfinished work / hazards

1. Update runner contract tests before treating the scaffold as functional:
   existing fake `run_process(command, log, timeout)` callbacks need to support
   the new completion-pattern argument. Add tests for empty/banner-only output,
   incomplete successful exits, nonzero exits/crashes, partial logs, timeouts,
   child-process cleanup, durable partial summaries, invalid/duplicate selections,
   shard union/disjointness and full-matrix manifest validation.
2. Windows timeout cleanup currently uses taskkill on the parent PID. A parent
   that exits while a descendant holds stdout open can leave an orphan. Consider
   a Windows Job Object, and test cleanup on both Linux and Windows. Review reader
   thread cleanup and exception paths; do not silently pass partial executions.
3. The proposed aggregate coverage validator / Actions timing reporter does not
   exist yet. It must reject missing, duplicated or incomplete shards and retain
   all 159 headless, 46 GL and 16 Mobile tests plus export/startup checks.
4. Shared readiness helper needs verification and integration. Keep every existing
   assertion, seed, exhaustive iteration and screenshot filename. Do not shorten
   intentional simulation/animation observation periods or the 40-frame shaft
   camera-transition regression. Readiness failures must fail the invoking test.
5. Complete timing measurement/reporting for scene initialization, rendering waits,
   screenshot readback/encoding, process startup/shutdown, setup/import/export and
   resource contention. Nested phase timings must not be added as disjoint costs.
6. Do not claim the missing-output contract is comprehensive until all existing
   test completion formats are verified. Most print `0 failures`; seven custom
   success formats are currently listed in regression_support.py.

## Investigated next optimizations (not implemented)

- Godot currently imports documentation screenshots during clean CI imports;
  historical headless imports cost 27–49 seconds. Consider `docs/.gdignore` after
  verifying no runtime ResourceLoader dependency. Current direct docs references
  are report-writing tools and a FileAccess JSON baseline in an AI test; verify
  source tests and all exported-pack checks still work. Keep screenshot artifacts.
- Use two independent CI shards for headless (two workers per host) and two per
  renderer, with deterministic cost balancing. Avoid parallel software renderers
  on a single host. Retain existing required-check names through aggregate jobs;
  validate complete/disjoint manifests, not just successful child job exits.
- Upload logs/screenshots per shard with distinct artifact names and small timing
  summary artifacts for aggregation. Run exported-pack lens checks once per
  renderer, and keep the independent export/startup/ship-model job mandatory.
- Replace unnecessary 24-frame/8-frame layout waits in unified_hud/power_allocation
  and uniform-only render fixtures with bounded readiness/render fences. Compact
  PoI focus must still wait for the actual 0.8-second camera tween and focus fade,
  rather than just shortening its current 0.9-second timer. Do not change cameras.
- Trading outpost has repeated pure encounter_signature(run) construction in each
  seed/system iteration; caching that test helper result within the same immutable
  iteration may help. Keep 200 seeds × 30 systems × three real generation streams.
- Large card/PoI draw samples are meaningful actual game-code workloads. Do not
  cache actual draw results or reduce the 512/1,000/20,000 sample guarantees.

## Delivery still required

Finish implementation; verify contracts and focused regressions; obtain equivalent
before/after measurements with runner variability acknowledged; open a dedicated
PR from this branch and attach it to the chat; run the complete existing CI matrix
to green; document timing savings, extra runner/import costs, isolation guarantees
and remaining bottlenecks. Preserve all scope restrictions in request.md.
