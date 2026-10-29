# Imported combat VFX experiment

Source: user-provided `combat.zip` (29 October 2026). Runtime-ready Binbun3D
Vol2 assets are grouped under `third_party/combat_vfx/binbun/`:

| Folder | Purpose | Integration |
| --- | --- | --- |
| StylizedHitFX | Small hits, impacts, large impacts | `vfx_hit_01` on hull damage |
| ExplosionFX | Explosion variants | Available for experiments |
| ElectricFX | Electric balls, zaps, lightning impacts | Available for experiments |
| DarkMagicFX | Projectile, ball and area effects | Available for experiments |
| StatusFX | Status effects and overlays | Available for experiments |
| shared/script | Shared controllers | One copy shared by all packs |

Each pack retains its supplied CC0 license. Asset paths were remapped, and stale
external resource UIDs removed so Godot resolves the relocated files by path.
The shared controller uses the Hit pack's version; the Explosion copy only added
a debug print. Demo scenes, preview images, HDR environments and demo characters
are omitted. The ZIP's duplicate lens addon is omitted to preserve the existing
integration. Older beam/projectile and standalone lightning packs remain in the
original uploaded ZIP: they were not imported in this first integration pass.

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
