# Shield collapse and synchronized Hull application

This implements the **revised** requirement: damage is determined once at impact,
Shields are applied immediately, and the Hull loss associated with that shield
collapse is applied at the fragment-burst cue. No damage formula is changed.
`CardEffects` and `CombatModifier` still determine the full outcome in temporary
state dictionaries, including conditional branches, costs and random rolls.

## Sequence

For 30 Hull / 3 Shields receiving 8 ordinary damage:

| Time | Authoritative state | Presentation |
| --- | --- | --- |
| 0.00 | Hull 30, Shields 0, pending Hull loss 5 | Cyan bubble flash and enhanced ripple |
| 0.10 | Hull 30, Shields 0 | Angular fracture lines appear |
| 0.20 | Hull 25, Shields 0, pending event consumed | Fragments launch; existing Hull impact starts once; Hull HUD updates |
| 0.35 | Hull 25, Shields 0 | Intact bubble is hidden; fragments remain |
| 0.75 | Hull 25, Shields 0 | Fragments cleaned up; original Shield mesh retained |

The pending clock seeks the effect to `shatter_burst_start` and commits damage in
that same step, even when a frame crosses the boundary. It then advances the visual
to the current elapsed time. Hull damage accounting, FTL disruption and win/death
checks occur after the commit. All Hull damage components belonging to a collapsing
shield event share one delayed impact, including mixed piercing/overflow attacks.
Piercing attacks that do not collapse the shield retain their immediate behavior.
Immediate healing is preserved while the already-calculated damage waits.

Conflicting card actions, EMP escape and allocation changes are blocked while damage
is pending. Existing card-motion/effect locks still govern the rest of the action.
Settings pause the inherited process clock along with other game animations.

## Ownership

- `scripts/board.gd` remains authoritative for Hull, Shields, damage accounting and
  results. `_stage_overflow()` temporarily withholds the reported Hull loss from the
  determined result; `_apply_pending_hull()` commits it exactly once. Both card
  attacks and asteroid overflow use this path.
- `scripts/combat/pending_hull_damage.gd` owns a deterministic elapsed-time clock and
  pending event payload. It does not calculate damage. It clears events before
  calling the controller so repeated flushes/cleanup cannot apply them twice.
- `scripts/battle_effects.gd` detects `old.shields > 0 && new.shields == 0`, starts the
  existing shared ship visual adapter, and retains cosmetic Tween job accounting.
  A non-breaking impact continues to use the existing ripple path.
- `scripts/ships/ship_3d.gd` retains the original Shield and material. It keeps that
  bubble visible for the collapse, then uses the original reactivation animation.
  Shield animation revisions prevent older hit/formation Tweens from overwriting
  a newer collapse. All player and enemy model subclasses share this adapter.
- `scenes/effects/shield_shatter_effect.tscn` and
  `scripts/effects/shield_shatter_effect.gd` provide the reusable visual component.
  Its `seek(time)` method follows the authoritative clock; it never changes game
  state or schedules damage from a Tween callback.

The effect uses **one MultiMesh with 32 shared triangular mesh instances**, one
fragment material per burst, and deterministic outward motion/rotation. It creates
two effect nodes per active ship rather than one node per fragment. There is no
physics, collision, dynamic light, external artwork, real-time subdivision or
post-processing. The existing shield shader gains a small gated fracture overlay;
normal shield opacity, hit ripples and reactivation remain in the same shader.

Fragment placement follows the original Shield mesh bounds and scale, so different
player/enemy sizes need no separate effect scenes. Gameplay RNG is not sampled.

## Interruptions and cleanup

- When effects/shatter are disabled before impact, damage uses the immediate path.
- Disabling effects during a pending sequence flushes the already-calculated damage
  once; visual cleanup cannot discard or duplicate it.
- Canceling the fragment visual cannot cancel the independent pending damage clock.
- Leaving/restarting/cleaning up the scene resolves pending damage without spawning
  more VFX. Lethal cleanup still records the logical result once.
- Public conflicting actions are rejected. A forced replacement damage event finishes
  the preceding interrupted sequence before starting the next one.
- Reactivating Shields cancels any old collapse visual and restores the original
  shield formation. Finished/canceled fragment batches queue themselves for deletion.

## Inspector settings

Open `resources/visual/shield_shatter_settings.tres`, or expand **Shield Collapse →
Shield Shatter** in `resources/visual/alpha_visual_settings.tres`. Shared settings are
read-only during effects. Each burst snapshots its visual settings so changing a
duration mid-animation cannot strand fragments. For a custom per-board configuration, assign a distinct
nested Resource rather than mutating the shared asset at runtime.

Times are seconds. Fragment speed/scale use ship-local 3D units; rotation speed is
radians/second. Randomness varies direction-independent speed and scale without RNG.
`shatter_shake_strength` is mapped to pixels at ×25 (default 0.08 → 2 pixels) through
existing modifier feedback; stronger active hazard shakes keep priority. Fade power
controls fragment opacity falloff. The total duration is clamped above the burst cue.

| Property | Default |
| --- | --- |
| `shatter_enabled` | `true` |
| `shatter_fragment_count` | `32` |
| `shatter_flash_duration` | `0.10` |
| `shatter_fracture_start` | `0.10` |
| `shatter_fracture_end` | `0.35` |
| `shatter_burst_start` | `0.20` |
| `shatter_total_duration` | `0.75` |
| `shatter_fragment_speed` | `2.5` |
| `shatter_fragment_rotation_speed` | `3.0` |
| `shatter_brightness` | `1.0` |
| `shatter_shake_strength` | `0.08` |
| `shatter_shake_duration` | `0.12` |
| `shatter_fragment_color` | `Color(0.25, 0.85, 1.0)` |
| `shatter_fragment_scale` | `0.14` |
| `shatter_randomness` | `0.35` |
| `shatter_fade_power` | `1.5` |

The Hull commit uses the **same** `shatter_burst_start` as fragment launch; there is
no independent hardcoded Hull delay. `shatter_fracture_end` is the additional
adjustment for the end of the overlapping crack/intact-surface stage.

## Reference and compatibility

[ShardShatter](https://github.com/Joy-less/ShardShatter) was inspected for its
fade-overlay → fragment-burst approach. Its README specifies Godot 4.4+ for v1 and
4.7+ for v2, whose particle rotation uses a newer API. No addon code/assets were
copied or installed; this is an independent, much smaller MultiMesh implementation.

Arcospace declares Godot **4.7 / Mobile** in `project.godot`; CI installs **4.7.2**.
The implemented effect uses Godot-native meshes, materials and instancing. Rendered
validation here uses OpenGL Compatibility. The Mobile/Vulkan probe falls back to
OpenGL because this environment lacks `VK_KHR_surface`; it does not establish
Android Mobile performance. Test native Android frame time on a device before release.

## Validation and files

`tests/shield_shatter_test.gd` covers ordinary hits, exact Shield depletion, staged
overflow, already-unshielded Hull damage, reactivation/repeated collapse, both sides,
lethal results, custom burst timing, action locks, overlapping hits, skip/cancel,
cleanup, simultaneous damage to both ships, piercing and healing combinations,
and asteroid overflow. It also captures fracture/burst frames in
`.godot/testlogs/shatter-*.png` with a rendering driver. Existing damage, combat,
progression, UI, ship and card regression suites remain applicable.

New files are the effect scene, effect/settings scripts, fragment shader, pending
clock script, settings Resource, this document and the regression test. Modified
integration files are Board, BattleEffects, shared ship visuals, the shared visual
settings schema and the original Shield shader. CI includes the new rendered test.
The broader regressions also exposed a pre-existing POI flash teardown issue: its
coroutine now lets the emitting signal unwind before returning to a caller that may
free the screen immediately. No POI rules or durations were changed by that fix.

Validation completed with Godot 4.7.2: all 58 headless regression scripts passed,
and five rendered suites passed (shield shatter, alpha visuals, card motion,
modifier cinematics and enemy models). The dedicated shield-shatter suite passed
61 checks, including the Stage 3 Hull/HUD boundary. Captured player/enemy frames
were inspected with the Compatibility renderer. Android hardware and native
Mobile/Vulkan performance remain unverified for the environment reason above.
