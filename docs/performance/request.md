# Arcospace — Regression Suite Performance Audit & Optimization

**Repository:** `RPGMaster2000/arcospace`  
**Engine:** Godot 4.7.x  
**Platforms:** Windows and Android  
**Starting point:** Latest `main`

## Objective

Investigate and optimize Arcospace's increasingly long automated regression tests.

Recent GitHub Actions runs have shown significant execution times, particularly in the rendered test suites.

The goal is to **reduce test execution time substantially while preserving all meaningful regression coverage, assertions and platform compatibility checks**.

This is an infrastructure optimization task, not a gameplay or rendering-feature change.

## 1. Establish the baseline

Inspect the current GitHub Actions workflows, regression runners and individual tests.

Use recent workflow runs as references:

| PR | Headless | GL Compatibility | Mobile Vulkan |
|---|---:|---:|---:|
| #49 | 7.7 min | 14.4 min | 5.8 min |
| #52 | 7.6 min | 18.0 min | 6.0 min |
| #53 | 7.8 min | 15.1 min | 7.1 min |
| #54 | 6.6 min | 19.7 min | 9.0 min |

Relevant GitHub Actions runs:

- #49: https://github.com/RPGMaster2000/arcospace/actions/runs/42509083295
- #52: https://github.com/RPGMaster2000/arcospace/actions/runs/42631736701
- #53: https://github.com/RPGMaster2000/arcospace/actions/runs/42779059404
- #54: https://github.com/RPGMaster2000/arcospace/actions/runs/42796171697

Measure:

- Total workflow duration.
- Individual job duration.
- Setup and dependency installation.
- Godot import time.
- Scene initialization.
- Per-test execution time.
- Frame waits and screenshot capture overhead.
- Process startup and shutdown.
- Parallel execution contention.
- Time spent on exported-pack checks.

Document the biggest bottlenecks before changing anything.

## 2. Investigate slow existing regressions

Prioritize these tests, which have shown particularly long execution times:

- `unified_hud_test`
- `trading_outpost_test`
- `poi_reward_overhaul_test`
- `power_allocation_test`
- `card_progression_test`
- `compact_poi_focus_test`

Investigate whether their runtimes are caused by:

- Excessive iteration counts.
- Repeated setup or teardown.
- Unnecessary scene reloads.
- Waiting for fixed time intervals.
- Rendering frames that are not required.
- Expensive initialization.
- Resource contention.
- Redundant calculations.
- Inefficient test harness behavior.

Optimize test execution while preserving the behavioral scenarios and assertions being tested.

Do not simply reduce iteration counts or test coverage to improve timing.

Where tests intentionally use large randomized or exhaustive workloads, preserve their statistical or exhaustive guarantees.

## 3. Optimize rendered regressions

Focus especially on the GL Compatibility and Mobile Vulkan runners.

Recent expensive tests include:

- `stellar_shafts_render_test`
- `stellar_shafts_prototype_test`
- `star_system_lighting_test`
- `solar_render_test`
- `starfront_presentation_test`
- `unified_hud_test`

Investigate:

- Repeated renderer initialization.
- Duplicate visual fixtures.
- Excessive frame settling.
- Unnecessary screenshot captures.
- Repeated full-scene construction.
- Redundant resource imports.
- Overly conservative fixed delays.
- Sequential execution that could safely be parallelized.

Where possible:

- Reuse initialized fixtures without leaking state.
- Replace unnecessary fixed waits with explicit readiness checks.
- Reduce redundant rendering work.
- Consolidate equivalent setup steps.
- Preserve deterministic screenshot framing.
- Maintain isolation between tests.

Do not eliminate visual tests merely because they are expensive.

## 4. Review test-runner architecture

Inspect the existing regression infrastructure, including:

- `tools/run_regressions.py`
- `tools/run_rendered_regressions.py`
- GitHub Actions workflow definitions.
- Godot test registration and execution.
- Timeout handling.
- Failure reporting.
- Test artifacts and screenshots.

Look for opportunities to improve:

- Scheduling and safe parallelism.
- Process management.
- Shared import/cache initialization.
- Test discovery.
- Logging overhead.
- Resource cleanup.
- Timeout handling.
- CI artifact generation.

Avoid introducing shared mutable state between parallel tests.

Ensure tests cannot silently pass after crashes, missing output or incomplete execution.

## 5. Preserve regression integrity

**This is a strict requirement.**

Do not:

- Remove existing regression tests.
- Disable expensive tests.
- Skip tests on particular renderers merely to reduce runtime.
- Weaken assertions.
- Increase numerical tolerances without justification.
- Change expected outputs to conceal failures.
- Artificially shorten simulations at the expense of coverage.
- Suppress genuine Godot errors.
- Treat timed-out tests as successful.
- Modify gameplay code to accommodate test-runner limitations.

Preserve existing CI failure semantics.

Any timeout adjustments must be justified by measured runtime behavior.

## 6. Improve development feedback

Investigate whether the test infrastructure can provide faster feedback during development.

Consider two execution modes:

**Focused validation**

Run only the relevant regressions for the changed subsystem during intermediate development.

**Full validation**

Run the entire existing regression matrix before a PR is considered ready for merging.

Focused validation must supplement, not replace, full validation.

The complete CI matrix should remain mandatory for PR validation.

Avoid adding a complicated dependency-detection framework unless the benefit clearly outweighs maintenance costs.

## 7. Add useful performance reporting

Improve regression reporting so future slowdowns are easy to identify.

Where practical, provide:

- Total test duration.
- Per-test execution time.
- Slowest tests.
- Setup/import overhead.
- Renderer-specific timing.
- Timeout and failure information.

Consider generating a compact timing summary in GitHub Actions.

The goal is to detect performance regressions in the testing infrastructure before they accumulate.

Keep the reporting lightweight and avoid introducing unnecessary external dependencies.

## 8. Measure the improvements

Before and after optimization, compare execution times using equivalent test coverage and runner conditions.

Prefer repeated measurements where practical to account for GitHub-hosted runner variability.

Report:

- Original duration.
- Optimized duration.
- Absolute time saved.
- Percentage improvement.
- Changes to test scheduling or setup.
- Any trade-offs.

Do not attribute timing fluctuations to code changes without sufficient evidence.

### Performance targets

| Suite | Baseline | Target |
|---|---:|---:|
| GL Compatibility | ~20 min | Under 12 min |
| Mobile Vulkan | ~9 min | Under 6 min |
| Headless regressions | ~7 min | Under 5 min |

These are **optimization goals, not permission to reduce coverage**.

If a target cannot be achieved safely, explain the limiting factors and report the actual improvement.

Prioritize GL Compatibility because it currently determines the overall CI completion time.

## 9. Compatibility and stability

Maintain:

- Godot 4.7.x compatibility.
- Existing Linux CI execution.
- Windows and Android project compatibility.
- GL Compatibility rendering.
- Mobile Vulkan rendering.
- Existing export/startup validation.
- Existing screenshot artifact behavior.

Ensure the optimized runners remain reliable during both passing and failing test executions.

Test failure propagation, process crashes, timeouts, missing output and partial results explicitly.

## 10. Scope restrictions

Do not modify:

- Gameplay or card mechanics.
- Combat modifiers.
- Star-system generation.
- Lighting or visual appearance.
- Camera behavior.
- PoI interactions.
- Environmental simulation.
- Expedition saves.
- RNG behavior.

Changes should be limited to test infrastructure, CI configuration and test code where necessary.

Avoid unrelated refactoring.

## 11. Delivery

Create a dedicated feature branch and open a PR.

Include:

1. Baseline performance analysis.
2. Identified bottlenecks.
3. Optimizations implemented.
4. Before/after timing comparisons.
5. Confirmation that regression coverage is preserved.
6. Changes to runner scheduling and resource handling.
7. Test results and CI links.
8. Remaining bottlenecks.

Run the complete CI matrix and verify that all jobs pass.

**Do not merge automatically.**

## Acceptance criteria

The task is successful when:

- GL Compatibility execution time is meaningfully reduced.
- Mobile Vulkan execution time is improved where practical.
- Headless test overhead is reduced where safe.
- All existing regression scenarios remain covered.
- Assertions and failure detection remain intact.
- CI timing information becomes easier to inspect.
- No gameplay or rendering behavior changes.
- The complete CI matrix passes.

**Prioritize measurable improvements, reliable failure detection and long-term maintainability. Do not trade correctness for faster green checks.**