# Tactical card preview and Game Reference

Combat holds use the existing `CardHold` threshold and release suppression. The hold adapter delegates only combat hands to `TacticalPreview`; galleries retain their existing read-only inspection workflow. Short taps and right-click discard still use the existing action pipeline. Middle-click opens `CardInspection` directly; I or controller Y previews the focused card, then opens inspection while raised.

`BattleHUD` binds hand cards and indicator labels once, then supplies its existing detached display snapshot. The coordinator owns one raised card, its INSPECT button, temporary target glows and spotlight dimmer. It restores position and z-order, cancels when turn/action/result/card context becomes invalid, and defers to existing modals. The card renderer and full inspector remain shared. Opening full inspection preserves a valid raised preview underneath it.

`CardTargets` reads effective `CardData.effects`, including the existing Ion preview, and returns indicator categories with positive, negative, uncertain and cost meanings. It never samples RNG or mutates the supplied state. For conditions after base effects, it invokes the existing resolver in simulation mode on detached copies and reuses `condition_matches`. Random precursors conservatively expose both branches as uncertain. Nebula marks combat effects uncertain; explicit top-level self-damage remains unavoidable. Solar Flare uses zero active Shields and suppresses reserved-Shield highlights. This is category guidance, not an exact numerical forecast; it intentionally avoids a second combat resolver.

Larger additive halos pulse above the existing icon graphics and below target label text. A 30% black spotlight dims unrelated screen content while leaving the raised card, relevant stat labels and defense bars clear. INSPECT sits beneath the card in the vacated bottom slot; the raise reserves enough room for its touch target. They do not run committed damage/repair feedback or change label values. Symbols (+, −, ?, $) distinguish meanings beyond color. Random targets and uncertain branches are not promised outcomes. Payment remains separate even when the same reserve also gains from an effect.

Calibration: select `resources/card_presentation.tres`. Existing Inspection input controls the hold threshold and motion cancellation. Tactical preview controls enablement, displayed-height raise fraction (0.30), raise/lower durations, easing, button spacing and fade. Tactical target highlights controls pulse duration/intensity, four colors, reduced animation, **Preview Dim Opacity** (0.30) and **Target Glow Padding** (28×22). Two small Godot canvas shaders render the halo and bounded spotlight mask; no new autoload or viewport is used. The tactical dimmer hides while full card inspection uses its existing modal backdrop.

`GameReference` owns shared player-facing text, with modifier descriptions and the icon legend sourced from existing definitions. `InfoOverlay.show_reference(section)` opens the complete scrollable reference with the requested section first; topic links use that same content. Existing legend entry points now say GAME REFERENCE. Exact HUD labels for reserves/production, Hull/Shields, EMP charge and Systems Failure open contextual sections; active EMP and action buttons retain their actions. The first successful combat preview shows a nonblocking hint, recorded in the existing preferences file under presentation/preview_hint_seen.

Tests: tactical_preview_test, card_targets_test and game_reference_test cover interaction/lifecycle, all card/upgrades' read-only analysis and reference entry/layout. card_inspection_test retains gallery, touch/drag, middle-click and unaffordable-card coverage; combat_trace_test verifies the 72 seeded baseline traces. Rendered screenshots are saved in `.godot/testlogs/tactical-{normal,preview,inspection}-{width}.png` and `game-reference-{width}.png`.

Remaining coupling is explicit: the HUD binds scene labels/modals and hands the coordinator detached snapshots. A new effect key should follow the [effect contract and consumer checklist](card_effect_contract.md), extending CardTargets with an executable category test. Android gesture events and landscape layout are exercised on desktop; physical-device audio/input/performance and Android export still require device/CI validation.


## Validation recorded 2026-10-23

- Shared runner completed import and all 82 headless suites. Its initial run passed 81 suites; combat_modifier_test exposed a pre-existing fixture collision with an existing user save. The fixture now uses a dedicated save and waits for its actual scene transition. It passes in the final shared-runner subset, along with the eight affected/integrity suites. Latest results across all 82 suites are passing.
- 34 tactical interaction/lifecycle checks at 1280×720 and 960×540; 23 target-analysis checks including all card/upgrade read-only scans; 30 reference checks; existing inspection suite: 951 checks; combat trace parity: 72 exact baseline traces.
- Rendered Compatibility checks: tactical preview, reference, full inspection, cinematic touch and battle layout. Tactical preview also passed the Mobile renderer on Intel hardware (Forward Mobile via D3D12).
- Exported resource pack: tactical preview, card targets and Game Reference tests passed. Nine Python runner-contract tests passed.
- Existing shutdown ObjectDB leak warnings remain in several suites; no new gameplay-state or RNG divergence was observed. Physical Android and APK/export runtime validation remain outstanding.


## Selection polish verified 2026-10-24

INSPECT-under-card geometry and spotlight exclusions pass at 1280×720 and 960×540 in
`tactical_preview_test`. Mobile/Vulkan rendering was inspected at both sizes. Focused
`ui_feedback_test` (33 checks), `card_inspection_test` (951 checks) and
`expedition_lifecycle_test` (26 checks) pass. Existing combat state/RNG invariants remain
in the tactical tests. This pass did not rerun the entire shared suite or test a physical
Android device. The overlay ignores pointer input and is removed on dismissal/context change.
