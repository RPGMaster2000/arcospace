# Regression performance audit

Baseline captured before changing runners or tests, 2026-11-10. Starting main:
4680da6 (merged PR #55). Scope is test/CI infrastructure only.

## Baseline observations

User reference runs #49, #52, #53 and #54 were inspected via original GitHub job
logs, plus #55 as the most recent code-equivalent reference. Durations below use
first/last job log timestamps, excluding queue time. PR #55's headless row is its
successful retry; its workflow elapsed wall time also included waiting to retry a
Godot signal-11 crash in sfx_test. Retries must not be counted as optimization.

| PR | Headless job min | GL job min | Mobile job min | Startup job min |
|---|---:|---:|---:|---:|
| #49 | 7.72 | 14.42 | 5.78 | 1.94 |
| #52 | 7.58 | 17.99 | 6.04 | 2.19 |
| #53 | 7.82 | 15.14 | 7.09 | 2.39 |
| #54 | 6.61 | 19.72 | 9.04 | 2.66 |
| #55 | 6.65 | 13.90 | 5.84 | 2.10 |

GL dominates the critical path. Most time is actual test execution rather than
engine installation or artifact upload:

| Run | GL job min | Sum of test processes min | Other job overhead seconds |
|---|---:|---:|---:|
| 42509083295 | 14.42 | 13.45 | 58.2 |
| 42631736701 | 17.99 | 16.52 | 88.6 |
| 42779059404 | 15.14 | 13.86 | 76.9 |
| 42796171697 | 19.72 | 17.79 | 115.7 |
| 42819905218 | 13.90 | 12.23 | 100.2 |

The last two GL runs differ from 19.72 to 13.90 minutes before this audit; runner
variability is substantial. Historical differences are not causal measurements
of changes to graphics features. Equivalent local paired runs and new full CI
runs will be reported separately.

### Largest measured bottlenecks

- GL power_allocation_test: 153–259 seconds, largest single test in every run.
  All statistical draws and all ship/resolution/mouse/touch combinations matter.
- GL unified_hud_test: 71–119 seconds. It renders 24 settling frames repeatedly
  through the complete enemy/modifier matrix. Existing timeout is 300 seconds.
- GL compact_poi_focus_test: 42–53 seconds; its settle function always waits
  0.9 seconds plus eight frames, including repeated visits and layout-only resizes.
- Headless trading_outpost_test: 71–98 seconds, scheduled near the end of the
  alphabetical queue. It must preserve 200 seeds × 30 systems × three streams.
- Headless poi_reward_overhaul_test: 67–112 seconds. It preserves 512 opening-hand
  samples for every profile/scenario and real board setup assertions.
- Headless card_progression_test: 46–69 seconds. Its 20,000-draw enemy samples,
  1,000 reward offers per ship and real successive-battle scenarios are meaningful.
- Headless total test-process CPU wall sums are 989–1,208 seconds on three workers;
  the complete job is 397–469 seconds, including 27–49 seconds import. Worker
  contention and a late long-test tail need explicit scheduling measurements.
- Current GL/Mobile runners launch a fresh Godot process per test, preserving
  isolation, but run all 46/16 selected tests sequentially. Imports are once per
  job, not once per test. Exported-pack checks remain additional mandatory work.
- Recent stellar_shafts_render_test costs 25–35 seconds on GL and 41–67 on Mobile;
  it repeats eight-frame settling for every uniform-only capture. Lighting/solar
  tests have similar fixed waits. Every named screenshot and camera-motion check
  must remain.

### Integrity gaps to address

The existing runner correctly fails diagnostics, nonzero exits and timeouts, but
currently accepts an empty successful process or one containing only the engine
banner. It also does not explicitly validate a complete test completion message.
Durable partial summaries exist; focused selection is available only for rendered
tests. Timing information is printed per process but no compact Actions summary
or setup/import/test phase breakdown is produced.

## Measurement plan and constraints

Retain all 159 headless tests, 46 GL tests, 16 Mobile tests and all export/startup
checks. Keep seeded/exhaustive loop counts and every assertion. Measure unmodified
priority tests locally before optimization, then repeat on the same executable and
machine; local hardware timings are not comparable to Mesa CI.

Investigate readiness-based layout/camera waits, test-only fixture overhead,
longest-first scheduling and deterministic independent CI shards. Avoid concurrent
software renderers on one runner; use isolated processes/userdata and separate
runner hosts when sharding. Report added runner-minutes/import overhead alongside
critical-path savings. No gameplay, rendering, RNG, save or production camera
changes are permitted.

Implementation and final measurements will be added after the baseline.

