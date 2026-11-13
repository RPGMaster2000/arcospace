# Validation

Engine: Godot `4.7.2.stable.official.ed1daf0bf`. No combat fixtures were regenerated.

Passed locally:
- Editor import/parse validation (network-enabled runtime, no script errors).
- `weekend_clearance_test`: homeworld geometry, bounded/deterministic retries, gas
  orbital envelopes, full region/save roundtrip and restored collision-body parity.
- `weekend_locator_test`, `weekend_homeworld_test`, `weekend_results_test`.
- `starfront_v2_test`, `starfront_presentation_test`, `space_storm_test`, touch tests.
- `battle_ending_sequence_test`, `systems_failure_test`, `encounter_continue_test`,
  `cinematic_lifecycle_test`, `expedition_resume_test`.
- New UI suites through GL Compatibility and Mobile Vulkan/llvmpipe. Actual production
  images were inspected; camera distance, damage-label placement and backing contrast
  were corrected after capture review.
- 40 seeded generated-state comparisons against unchanged base main `59d24f3`:
  Defense and Exploration seeds 1–20. All saved gameplay fields, encounter identities,
  fleet/PoI anchors and persisted RNG states are equal. Only environmental definitions
  and deliberately adjusted cosmetic battle coordinates are excluded. Reproducible
  export helper: `tools/weekend_generation_signature.gd`; compare its JSON outputs
  from both revisions after copying the helper into the base checkout.

Commands (substitute the path of the pinned Godot executable):

```sh
godot --headless --editor --import --quit
python3 tools/run_regressions.py --godot godot --skip-import --workers 2
python3 tools/run_regressions.py --godot godot --skip-import --script weekend_clearance_test --script weekend_homeworld_test --script weekend_results_test
DISPLAY=:99 python3 tools/run_rendered_regressions.py --godot godot --skip-import --renderer gl_compatibility --script weekend_homeworld_test --script weekend_results_test --script weekend_locator_test
DISPLAY=:99 python3 tools/run_rendered_regressions.py --godot godot --skip-import --renderer mobile --script weekend_homeworld_test --script weekend_results_test --script weekend_locator_test
godot --headless --script res://tools/weekend_generation_signature.gd -- /tmp/gameplay-signature.json
```

The full local headless run was started. Its existing `trading_outpost_test` reached
its unchanged 120-second timeout; the same timeout was reproduced on **unchanged
main** in a separate worktree. No assertions or timing limits were weakened. The
outdated Starfront defeat presentation assertions were updated to verify the new
required rendered backdrop, cause text, terminal state and blocked navigation;
that focused suite passes after the update.

Full CI (headless shards, GL Compatibility shards, Mobile Vulkan shards,
exported-startup and exported lens checks) is triggered by the PR. Its status is
reported by GitHub; results still running must not be described as passing.
Per the user's standing preference, GitHub regression runs may be left unmonitored.
Some existing suites emit shutdown-only ObjectDB leak warnings; runner reports
separate these from runtime/assertion errors.

Manual physical-device Android validation remains recommended: app background/resume,
notches, touch skip/Continue, long travel interrupted by multiple impacts and low-end
GPU performance. Software Mobile Vulkan validation does not certify an Android device.
