# Validation

Pinned engine: Godot 4.7.2. Base main: `2dd340c` (PR68).

- The original real-input reproduction failed **two assertions** before the fix:
  the enabled Upgrade Cards button did not receive the click and the upgrade modal
  did not open. Hover tracing identified the decorative results VBoxContainer.
  The same test passed after the input fix.
- `result_upgrade_input_test` uses a real expedition/controller/board with a genuine
  committed upgrade event. It exercises normal reveal, real touch Skip, reduced
  presentation and actual mouse, native touch-to-pointer input and keyboard
  `ui_accept`. It selects and confirms every upgrade through the actual UI and
  returns through the existing Continue action to the map. It checks callback
  counts, exact remaining upgrades, reward preservation and four viewport sizes.
- `result_animation_test` covers Hull, Systems Failure, EMP, mothership Hull/EMP,
  defeat, draw and exhausted upgrade pools. It measures title movement/opacity,
  intermediate counter values and icon visibility; skips at multiple timeline
  stages; verifies all final values/transforms/actions; checks repeated reveal,
  full state/RNG immutability and the separation from Battle VFX.
- Existing card-management/lifecycle, battle-ending, HUD, Salvage economy,
  continuation, victory-music/audio, persistence and resume suites are run alongside
  the new tests. No baseline fixtures or combat assertions were changed.
- Both new tests are registered in GL Compatibility and Mobile Vulkan CI alongside
  the existing `weekend_results_test`. New software-renderer timeout budgets account
  for the measured cost of rendering three full input/upgrade transactions; existing
  test limits and assertions are unchanged. Scheduling costs are recorded for balanced
  shards.

Commands:

```sh
python3 tools/run_regressions.py --godot godot --skip-import --workers 2 --script result_upgrade_input_test --script result_animation_test --script card_management_test --script card_management_lifecycle_test --script battle_ending_sequence_test --script battle_hud_test --script salvage_economy_test --script expedition_resume_test --script expedition_persistence_session_test --script victory_music_test --script encounter_continue_test --script sfx_test --script weekend_results_test
DISPLAY=:99 python3 tools/run_rendered_regressions.py --godot godot --renderer gl_compatibility --skip-import --script result_upgrade_input_test --script result_animation_test --script weekend_results_test
DISPLAY=:99 python3 tools/run_rendered_regressions.py --godot godot --renderer mobile --skip-import --script result_upgrade_input_test --script result_animation_test --script weekend_results_test
python3 -m unittest discover -s tools -p 'test_*.py'
godot --headless --editor --import --quit
```

Some pre-existing suites report shutdown-only ObjectDB warnings, separately tracked
by the runner. Source import and runtime/parser errors remain failures.

The full GitHub matrix runs on the PR and may remain unmonitored per the user's
standing preference. Do not report pending CI as passing. Physical Android-device
validation remains recommended for real DPI/notches, native touch hardware and
background/resume; Mobile Vulkan here uses software Mesa/llvmpipe.

## Final local results

All commands below used the final source changes on the feature branch.

| Checks | Result |
| --- | --- |
| 13 targeted headless regression suites listed above | Passed |
| Additional alpha visual and cinematic lifecycle interruption suites | Passed |
| New real-input upgrade suite | 172 checks, 0 failures |
| New animation/Skip/outcome suite | 264 checks, 0 failures |
| GL Compatibility: new input, new animation, existing weekend results | All 3 passed (93.645s / 82.898s / 56.347s) |
| Mobile Vulkan: same three production-renderer suites | All 3 passed (103.031s / 78.982s / 50.977s) |
| Python regression-runner contracts | 22 passed |
| Godot editor import / parser validation | Passed, no parser/runtime errors |

Initial renderer runs exposed test synchronization issues rather than accepting
false success: one reduced-summary assertion ran before the existing destruction
presentation finished, and an input test shared one timeout across battle ending
and result reveal. The tests now wait separately for the real result phase and
animation completion, retain all functional assertions and fail explicitly if the
phase does not initialize. Final reruns above pass without suppressing diagnostics.

The continuous recording contains H.264 video and AAC audio at 1280×720, 5.4 seconds;
the UI portion lasts 1.55 seconds. These captures were made with software GL;
independent Mobile Vulkan captures and tests also passed. No physical Android
hardware was available for this pass.
