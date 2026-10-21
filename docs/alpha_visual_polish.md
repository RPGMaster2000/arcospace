# Closed alpha visual settings

Edit `resources/visual/alpha_visual_settings.tres` in the Godot Inspector. This shared
Resource owns the parameters listed below. Consumers read it; they do not change the
shared settings during effects. Ship materials remain duplicated per model instance.
Custom ship settings Resources can be assigned to a model's Visual Settings field.

## Existing systems and scope

- CardMotion already owns play, discard, refill and cancellation. Its independent
  `resources/card_motion.tres` remains the source for those satisfactory effects.
- `resources/card_presentation.tres` still owns card typography, hold-to-inspect and
  enlarged inspection layout. These input and readability settings are unchanged.
- BattleEffects still schedules combat feedback and owns its Tween lifecycle. Its
  existing timing values now read the alpha Resource; their defaults are unchanged.
- Existing hull damage patches, repair sweeps, shield formation and impact shader
  remain. The shield shader gains three tuning uniforms; its geometry and ripple
  calculation are otherwise preserved. Shield-only damage has no hull recoil; it produces a brief two-pixel screen shake using the existing modifier feedback controller. Stronger active hazard shakes take priority.
- Ships retain their idle hover, geometry and authored engine colors. Existing engine
  meshes receive isolated emissive materials and a small idle pulse. No dynamic
  lights or post-processing were added. Escape boosts emission while the ship remains
  on the result screen; it does not add an FTL travel sequence.
- POI success/failure uses the existing flash controller, shortened from one second
  to the configured 0.6 seconds. Headings and reward text reveal without disabling
  actions or changing rewards. Battle-result headings/panels reveal once per display,
  rather than restarting on each HUD refresh.

## Interaction and layout

Card hover/press feedback zooms and elevates the contained artwork, with an inset
border highlight. Whole-card transforms remain unchanged, so six-card hand positions,
inspection geometry, discard buttons and touch rectangles do not move or overlap.
There is no new persistent card-selection mechanic: selected emphasis means the
existing pressed state; release/exit restores it. Galleries reuse the same adapter.

Existing shared button/panel styling, margins, typography and screen layouts were
already consistent enough for this pass. Settings, outpost, ship selection and combat
were checked with their existing layout tests; no redesign or new navigation actions
were introduced. The shared approach confirmation now uses the configured UI duration.

## Parameter reference

Seconds are used for durations, pixels for `card_hover_elevation` and `shake_pixels`,
3D units for `hull_shake_strength`, cycles/second for `engine_pulse_speed`. Flash colors
for POIs include opacity; other colors are opaque. Engine pulse amplitude is fractional.
Hover and reveal easing share `interaction_transition` and `interaction_ease`.
`hit_seconds` retains the existing combat feedback envelope; the visible hull flash
and recoil can finish sooner without changing that turn-resolution wait.

| Group | Inspector property | Default |
| --- | --- | --- |
| Card interaction | `card_hover_scale` | `1.06` |
| Card interaction | `card_selected_scale` | `1.10` |
| Card interaction | `card_hover_elevation` | `2.0` |
| Card interaction | `card_hover_duration` | `0.12` |
| Card interaction | `card_selected_duration` | `0.10` |
| Card interaction | `card_selection_color` | `Color(0.55, 0.9, 1.0)` |
| Card interaction | `card_glow_intensity` | `0.35` |
| Card interaction | `interaction_transition` | `Tween.TRANS_CUBIC` |
| Card interaction | `interaction_ease` | `Tween.EASE_OUT` |
| Hull impact | `hull_flash_color` | `Color(1, 0.08, 0.04)` |
| Hull impact | `hull_flash_opacity` | `0.85` |
| Hull impact | `hull_flash_duration` | `0.18` |
| Hull impact | `hull_shake_strength` | `0.08` |
| Hull impact | `hull_shake_duration` | `0.22` |
| Shield impact | `shield_impact_color` | `Color(0.2, 0.65, 1)` |
| Shield impact | `shield_flash_opacity` | `0.9` |
| Shield impact | `shield_flash_duration` | `0.35` |
| Shield impact | `shield_ripple_strength` | `1.8` |
| Shield impact | `shield_ripple_speed` | `24.0` |
| Shield impact | `shield_screen_shake_pixels` | `2.0` |
| Shield impact | `shield_screen_shake_duration` | `0.18` |
| Engines | `engine_glow_intensity` | `0.7` |
| Engines | `engine_pulse_amplitude` | `0.08` |
| Engines | `engine_pulse_speed` | `0.35` |
| Engines | `override_engine_color` | `false` |
| Engines | `engine_glow_color` | `Color(0.15, 0.75, 1)` |
| Engines | `engine_ftl_multiplier` | `1.6` |
| Engines | `engine_ftl_transition_duration` | `0.2` |
| POI and UI | `poi_success_color` | `Color(0.15, 0.85, 0.35, 0.24)` |
| POI and UI | `poi_failure_color` | `Color(0.95, 0.18, 0.15, 0.24)` |
| POI and UI | `poi_reveal_duration` | `0.60` |
| POI and UI | `ui_transition_duration` | `0.20` |
| POI and UI | `reward_text_emphasis` | `0.20` |
| Battle results | `result_heading_duration` | `0.20` |
| Battle results | `result_heading_start_scale` | `0.96` |
| Battle results | `victory_accent_color` | `Color(0.65, 1.0, 0.75)` |
| Battle results | `defeat_accent_color` | `Color(1.0, 0.55, 0.5)` |
| Existing combat feedback timing | `count_step_seconds` | `0.065` |
| Existing combat feedback timing | `hit_seconds` | `0.6` |
| Existing combat feedback timing | `production_seconds` | `0.48` |
| Existing combat feedback timing | `repair_seconds` | `0.75` |
| Existing combat feedback timing | `shield_seconds` | `0.55` |
| Existing combat feedback timing | `shake_pixels` | `4.0` |
| Existing combat feedback timing | `icon_peak_scale` | `1.07` |

## Files and extension points

- `scripts/visual/visual_effect_settings.gd`: Inspector schema.
- `resources/visual/alpha_visual_settings.tres`: shared defaults.
- `scripts/visual/visual_effects.gd`: interruptible text/panel reveal helper, with reset.
- `scripts/card_view.gd`, `scripts/ui/card_portrait.gd`: contained interaction feedback.
- `scripts/ships/ship_3d.gd`, `enemy_ship_model.gd`: emission and impact parameters.
- `scripts/battle_effects.gd`: existing scheduler, centralized timings and 2D fallback.
- `scripts/ui/outcome_flash.gd`, `approach_confirmation.gd`: existing transitions.
- `scripts/ui/battle_hud.gd`, `scripts/expedition.gd`: result/outcome text presentation.
- `scripts/board_3d.gd`: forwards the existing escape state to the engine visual.
- `shaders/shield_3d.gdshader`: additional uniforms for the existing impact ripple.
- `tests/alpha_visual_test.gd`: interaction, damage reset, engine isolation/boost and
  interruption regression checks; rendered captures in `.godot/testlogs/alpha-*.png`.
- `tests/reward_feedback_test.gd`: checks the configured POI duration.
- `.github/workflows/tests.yml`: includes the new test in rendered CI as well as the
  existing automatic headless test discovery.

Keep new cosmetic parameters here when they belong to these effects. Reuse existing
controllers; never perform state mutations in a visual Tween callback. A new subsystem
may retain its own small Resource, as card motion and inspection already do.

## Limitations

Compatibility rendering supplies emission color without an expensive bloom pass:
engines read as luminous surfaces, not light sources illuminating nearby geometry.
Damage-based intensity scaling was left out; distinct flashes and existing damage
patches already communicate the hit without adding more tuning. No new assets, ship
geometry, card balance, enemy rules, progression or project settings were changed.
Native Android hardware/export performance requires device testing; Linux rendering
at the existing mobile viewport sizes cannot establish device frame rates.

## Validation for this pass

Godot 4.7.2 editor import and 20 focused regression scripts passed. Five suites were
also run with an actual X11/OpenGL Compatibility renderer (software Mesa): alpha
visuals, card inspection, POI reward feedback, six-ship profiles and settings.
The new visual suite passes 48 checks. Existing suites cover play/discard, turn/input
flow, Hull/shield effects, rewards, result music, continuation, repair selection,
all ship models, outpost controls and Android-size layouts. Captures include pressed
card feedback, Hull/combined impacts, victory/defeat, POI success/failure and both
ship-selection pages. Existing viewport coverage includes 1280×720, 1680×720,
960×540, 800×450 and 686×384 where supported by each runner.

No script/shader errors or failed assertions remained. Some existing runners still
report ObjectDB shutdown warnings; native Android performance and exported builds
were not tested in this pass.
