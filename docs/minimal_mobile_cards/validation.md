# Validation record

Base: `0c0e51a30841c1941e32276f4b02346e30549eb4` (main / PR #69).
Engine: official Godot 4.7.2 Linux binary. Rendering: Mesa software OpenGL and
Mobile Vulkan, Xvfb. No physical Android or Windows hardware was available.

| Check | Result |
|---|---|
| Final editor import | Complete, no parse/import errors |
| Regression runner Python unit tests | 22 tests; pass |
| Complete card-library layout, headless / GL / Mobile | 240 variants; 5,244 checks; 0 failures |
| Resource palette, shared gradient, blank placeholder and selection lifecycle | 68 checks; 0 failures in headless / GL / Mobile |
| Data-derived face semantics | 488 checks; 0 failures |
| Card effect baseline parity | 2,220 exact baseline checkpoints match; state/RNG unchanged |
| Production battle hand, GL / Mobile | 141 checks each; 0 failures |
| Existing inspection, GL / Mobile | 1,023 checks each; 0 failures |
| Existing inspection, final headless recheck | Pass |
| Existing alpha visual interactions, GL | Pass |
| Existing effect contract, card icons, discard, player hand | Pass |
| Existing result animation and upgrade input | Pass on focused recheck / full headless respectively |
| Existing UI overhaul | 961 checks; 0 failures on focused recheck |

The resource-theme follow-up passes **17 focused headless executions**, **5 GL
scripts** and **4 Mobile Vulkan scripts**. This includes actual held-card selection,
restoration of its highlight, keyboard/controller preview, right-click/normal
discard, card upgrades/motion, tactical resize and HUD ownership. An exact
comparison confirms that all 240 card-face descriptions match the prior PR
revision; only their layout and typography changed.

```sh
python3 tools/run_regressions.py --godot GODOT --skip-import --script card_theme_test --script minimal_card_layout_test --script card_face_text_test --script card_icon_cue_test --script card_inspection_test --script discard_test --script player_hand_test --script ui_overhaul_test --script card_effect_parity_test --script card_effect_contract_test --workers 2 --results /workspace/card-theme-headless
python3 tools/run_regressions.py --godot GODOT --skip-import --script tactical_cards_test --script tactical_resize_test --script hud_ownership_test --script card_upgrade_ui_test --script card_motion_test --script card_vfx_timing_test --script card_theme_test --workers 2 --results /workspace/card-theme-interactions
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer gl_compatibility --script card_theme_test --script minimal_card_layout_test --script minimal_card_hand_test --script card_inspection_test --script alpha_visual_test --results /workspace/card-theme-gl
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer mobile --script card_theme_test --script minimal_card_layout_test --script minimal_card_hand_test --script card_inspection_test --results /workspace/card-theme-mobile
```

The earlier complete local headless run executed **183 scripts**, initially passing 177.
All six initial failures were investigated, rather than treating the run as green:

| Initial failure | Investigation / final result |
|---|---|
| `trading_outpost_test` 120s timeout | Same base test takes 244.753s on this host. Feature passes in 219.285s with `--timeout 300`; no assertion changes. |
| `result_animation_test` title timing | Focused rechecks pass (32.868s and 37.203s); baseline passes too. Existing assertions preserved. |
| `board_3d_test` Hull flash timing | Final focused recheck passes (5.933s); baseline passes (6.594s). Existing assertions preserved. |
| `ui_overhaul_test` old artwork rectangle | Updated the exact visual contract from the old rectangle to the new shared template; all existing gameplay assertions retained. Recheck passes. |
| `player_hand_test` uppercase title | Updated the visual assertion to require the full authored resource name, allowing only explicit line wrapping; cost/hand/action assertions retained. Recheck passes. |
| `star_map_test` “Service arrival grants no access or pressure” | **Unresolved pre-existing failure:** unchanged main reproduces the identical assertion (452 checks, 1 failure). No navigation or strategic gameplay code was changed. |

The discard test now checks the exact refund number, resource symbol and resource
name, replacing its old `Discard +` text-prefix check. Inspection tests require
data-derived copy at every prose length rather than the removed 50-character
fallback. These are deliberate presentation-contract changes, not relaxed
gameplay assertions. No baseline fixture was changed.

Commands used (replace `GODOT` with the 4.7.2 executable):

```sh
GODOT --headless --editor --import --path .
python3 tools/run_regressions.py --godot GODOT --skip-import --workers 2 --results /workspace/cards-headless
python3 tools/run_regressions.py --godot GODOT --skip-import --script card_face_text_test --script card_effect_parity_test --script card_effect_contract_test --script card_icon_cue_test --script discard_test --script minimal_card_layout_test --results /workspace/cards-core-focused
python3 tools/run_regressions.py --godot GODOT --skip-import --timeout 300 --script discard_test --script result_animation_test --script trading_outpost_test --results /workspace/cards-recheck
python3 tools/run_regressions.py --godot GODOT --skip-import --script result_animation_test --script ui_overhaul_test --script discard_test --results /workspace/cards-ui-recheck
python3 tools/run_regressions.py --godot GODOT --skip-import --script player_hand_test --results /workspace/cards-player-hand-final
python3 tools/run_regressions.py --godot GODOT --skip-import --script board_3d_test --script card_inspection_test --results /workspace/cards-final-recheck
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer gl_compatibility --script minimal_card_layout_test --script minimal_card_hand_test --script card_inspection_test --script alpha_visual_test --results /workspace/cards-gl-focused
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer gl_compatibility --script minimal_card_hand_test --results /workspace/cards-gl-input-final
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer mobile --script minimal_card_layout_test --script minimal_card_hand_test --script card_inspection_test --results /workspace/cards-mobile-focused
python3 tools/run_rendered_regressions.py --godot GODOT --skip-import --renderer mobile --script minimal_card_hand_test --results /workspace/cards-mobile-final
```

Focused rendered runs used `DISPLAY=:101` and the extracted Mesa runtime libraries;
Mobile explicitly selected the Lavapipe ICD. The complete recurring GL/Mobile and
source/exported-startup suites are left to the existing GitHub Actions matrix.
Those remote checks may remain unmonitored per the user's instruction; their
completion is not claimed here. Physical Android review remains recommended.
