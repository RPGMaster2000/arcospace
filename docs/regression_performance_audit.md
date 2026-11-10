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


## Cloud implementation and first complete CI result

[Run 42872168078](https://github.com/RPGMaster2000/arcospace/actions/runs/42872168078)
on `59323fd` passed every job: all 159 headless scripts, 46 GL scripts, 16 Mobile
scripts, Python contracts, complete/disjoint aggregate checks, exported lens checks
once per renderer, and the unchanged exported-startup/ship-model job.

| Suite | PR55 baseline job seconds | Longest shard + aggregate seconds | Difference | Change |
|---|---:|---:|---:|---:|
| Headless | ~399 | 314 + 11 = 325 | ~74 s | ~18.5% shorter |
| GL Compatibility | ~834 | 548 + 9 = 557 | ~277 s | ~33.2% shorter |
| Mobile Vulkan | ~350 | 285 + 9 = 294 | ~56 s | ~16.0% shorter |

These are job execution times, excluding queue and inter-job scheduling gaps.
This is one new hosted sample compared with a historical baseline, not a controlled
causal speedup estimate. Historical GL alone varied 834–1183 seconds. The new GL
and Mobile paths meet the requested 12/6 minute execution targets in this sample;
headless does not meet five minutes including aggregate overhead. More samples
are required to estimate variance. Queue delays can offset critical-path savings.

Sharding adds hosts and repeats imports/setup. Execution plus aggregate jobs in
this sample sum to about 40 runner-minutes, versus about 28.5 minutes for the PR55
baseline jobs. This resource trade-off is deliberate and must not be described as
less total compute. Test-process scheduling estimates are 493.5/493.3 seconds for
headless, 449.9/450.7 GL and 176.0/168.8 Mobile, before headless two-worker overlap.
These estimates are scheduling inputs, not measurements of this run.

Implementation:
- Two independent hosts per suite; two headless workers per host; no concurrent
  software renderers on one host. Static historical longest-first bin packing.
- Full-suite aggregate checks validate every source-discovered name exactly once,
  successful completion, shard indices, and absence of focused/incomplete results.
- Strict completion evidence in addition to exit/diagnostic/timeout checks. Only
  the two existing intentional headless pixel-skip messages have explicit mode-
  specific completion patterns. No new skips or removed renderer tests.
- Atomic partial summaries and per-shard Actions timing tables; first output,
  completion and post-completion timings distinguish coarse lifecycle overhead.
- `docs/.gdignore` avoids importing report screenshots; clean CI import and all
  exported-pack checks pass with the exclusion. Source FileAccess data remains.
- One immutable per-system test signature is reused in trading-outpost comparisons;
  all 200 seeds × 30 systems × three actual generation streams are retained.

The readiness follow-up preserves 24 startup frames and replaces only repeated
HUD layout waits with bounded stable-geometry checks. The first attempt did not
preserve shader warmup and failed; it was corrected rather than weakening the new
assertion. Corrected local GL result: 401 checks, zero failures, 86 readiness calls
and 258 observed layout frames, 48.857 seconds. The original matrix has 315 checks;
all remain, plus one readiness assertion per call. The unchanged baseline passed locally in 200.964 seconds on the same Godot/Mesa fixture, versus 48.857 seconds for the readiness version (152.107 seconds / 75.7% shorter). This is one local pair; the optimized invocation overlapped a headless workload, so it is not a controlled variance estimate. Both passed. Other large randomized workloads, compact camera tween
waits and the 40-frame shaft transition observation are unchanged.

Local clean import passes. The initial local full run used incomplete imported
audio and is not a clean-suite pass. After import, focused progression passes 3185
checks and both intentional headless pixel cases complete correctly. Trading-outpost
still reaches the unchanged 120-second timeout on this constrained machine, while
clean hosted shards pass. No timeout increase or simulation reduction hides that
local result. The known local star-map service-arrival assertion also occurs on
unchanged baseline; hosted full checks pass. Windows timeout descendant cleanup
remains unverified here and uses taskkill; a descendant retaining output fails even
if its parent has exited. No Windows Job Object support is claimed.

Limits: total scene initialization versus GPU waits versus screenshot encoding has
not been fully instrumented in every test. Process timings include those costs;
first output is only a coarse initialization proxy. HUD layout metrics are nested,
not additional disjoint costs. Repeated renderer initialization remains intentional
for process isolation. No gameplay, visual appearance, RNG, save or camera code
was modified. Remaining large sampling workloads are meaningful coverage.

Final implementation CI: [42875150569](https://github.com/RPGMaster2000/arcospace/actions/runs/42875150569) passed the complete matrix on `ad643d6`, including the HUD readiness follow-up and 22 Python contract tests. No remaining automated CI failures. The final documentation-only commit records these results.
