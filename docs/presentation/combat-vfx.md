# Imported combat VFX experiment

Source: user-provided `combat.zip` (29 October 2026). Runtime-ready Binbun3D
Vol2 assets are grouped under `third_party/combat_vfx/binbun/`:

| Folder | Purpose | Integration |
| --- | --- | --- |
| BeamFX | Generic beam | One beam per resolved opposing damage card |
| StylizedHitFX | Small hits, impacts, large impacts | `vfx_hit_01` on hull damage |
| ExplosionFX | Explosion variants | Available for experiments |
| ElectricFX | Electric balls, zaps, lightning impacts | Available for experiments |
| DarkMagicFX | Projectile, ball and area effects | Available for experiments |
| StatusFX | Status effects and overlays | Available for experiments |
| shared/script | Shared controllers | One copy shared by all packs |

Each Vol2 pack retains its supplied CC0 license. Asset paths were remapped, and stale
external resource UIDs removed so Godot resolves the relocated files by path.
The shared controller uses the Hit pack's version; the Explosion copy only added
a debug print. Demo scenes, preview images, HDR environments and demo characters
are omitted. The ZIP's duplicate lens addon is omitted to preserve the existing
integration. Older projectile and standalone lightning packs remain in the original uploaded ZIP.
Stage 1 imports the supplied `beam_vfx/effects/base/base_beam_vfx.tscn` and its
controller/shaders under `BeamFX`. No beam-specific license file was present in
the supplied archive; the Vol2 licenses above do not establish its license.
No replacement or downloaded asset was used.

`imported_combat_vfx.gd` adapts one small effect to a camera-facing hull location.
It disables dynamic lights and supplied audio, caps each particle emitter at 8,
and plays one shot within the existing hit duration. BattleEffects owns cleanup
and cancellation. Disable `BattleEffects.imported_hits_enabled` in the inspector
for comparison. No card logic, damage values, turn sequencing or save data changes.
Existing hull flashes, shield reactions and destruction sequences remain intact.

The regression loads all imported scenes, checks hull-only dispatch, toggle,
particle/audio/light limits, cleanup, cancellation and unchanged combat state.
It is registered for headless and rendered Mobile/Compatibility CI and captures
a rendered hit. Physical Android performance still requires device testing.


## Stage 1: generic beam and player setting

Settings → **Battle VFX** (default On) persists in the existing `music.cfg`
presentation section. It is shared by normal Settings and battle Settings and
by subsequent battles. Turning it off hides/removes all live imported combat
nodes immediately, even while paused. Existing feedback and scheduled timeline
completion remain active; star-map lens effects, audio settings and save-game
schema are unaffected. `imported_hits_enabled` is still a developer-only gate
for impacts; the player preference takes precedence.

`CardEffects` reports actual opposing direct damage at the ordinary damage
resolution site, including shield absorption and selected conditional branches.
`CombatExecution.Resolution.direct_damage` carries this presentation-only value
to Board after modifier/upgraded resolution. Board dispatches one beam, without
reapplying damage or calling another hit effect. Misses, discards, self-only
damage, repairs, shield-only disruption, resource changes and environmental
modifier damage do not dispatch a beam.

Both directions use the same vendor scene and the actual hull positions. The
beam follows recoil for 0.45 seconds, fading over the final 35%. BattleEffects
owns its tween and exit cleanup and bounds visible beams to one per battle.
The same 0.45-second job runs with the preference off, preserving turn timing.
Only the core mesh is visible: vendor particles, flares, endpoint ball, lights
and audio are disabled. Core geometry uses 12 radial segments and one ring;
material/mesh resources are local to each instance. The core shader alone has
integration changes: a shared-opacity fade and a full-length mask so it reaches
the target on both Mobile and Compatibility.

Examples supported: Boarding Party, Breach Charge, Siege Driver, conditional
Missile Team, and their damage upgrades. Shield Disruptor upgrades qualify only
when they actually deal ordinary damage; the base shield-only version does not.
Card names do not select weapon families: all ordinary opposing damage uses
this one generic beam. Overloaded Warhead uses one opposing beam; its self-damage
does not produce a second beam. Drain Beam's resource-only effect produces none.

`combat_beam_test.gd` covers directions/endpoints, shield absorption, conditional
and upgraded resolution, misses/exclusions, state invariance, paused toggling,
persistence/subsequent battles, cleanup and scene exit. It runs headlessly and
in both rendered CI suites. Physical Android GPU cost, thermals, touch usability
and device-specific shader behavior remain unverified without device testing.
