# Battle cinematics

The 3D board borrows its existing camera, ships, engine effects and background for short camera sequences. Combat execution, cards, modifiers, battle seeds and saved fields are unchanged. The 2D board retains its immediate presentation.

## Ownership and integration

- `scripts/presentation/battle_cinematic_director.gd` owns one camera tween and a temporary input/Skip overlay. It never reads expedition state, awards rewards or draws random numbers.
- `scripts/presentation/battle_cinematic_settings.gd` and `resources/presentation/battle_cinematics.tres` expose shot durations, ship-relative offsets, framing margin, FOV and the heavy-beam threshold. Assign a different settings resource on the 3D board to tune a scene.
- `scripts/board_3d.gd` connects confirmed presentation events and delays the first turn until the introduction ends. Resize updates the eventual gameplay FOV/background scale while the director controls the current shot.
- `scripts/battle_effects.gd` reports `weapon_presented(side, "beam")` when it creates the live beam. The cinematic turn starts on that signal. The existing beam contact callback still resolves the card and plays the impact.
- `scripts/board.gd` exposes presentation hooks before discharge, on contact, and after committed resolution or deferred Hull loss. The original damage timeline still owns commits and the turn waits for its VFX.
- `scripts/board_3d.gd` plays departure after terminal VFX finish and before revealing the existing Victory screen. Its own black curtain covers result construction. Presentation latches prevent replay or early continuation; committed rewards are never recalculated.
- `scripts/expedition.gd` removes the completed board at the existing result-confirmation boundary, opens required upgrades and returns to the map normally. No board is retained through upgrades and no departure/fade replays on the final return. Reward, encounter, upgrade and checkpoint transactions remain at their original boundaries.

```mermaid
flowchart LR
    Entry[Existing battle setup] --> Intro[Three-shot introduction]
    Intro --> Turn[Existing first turn]
    Turn --> Charge[Eligible beam charges in a two-ship frame]
    Charge --> Launch[Existing beam cue turns camera]
    Launch --> Contact[Existing contact commits damage]
    Contact --> Destruction[Confirmed destruction holds the victim frame]
    Destruction --> Orbit[Victory orbit and engine boost]
    Orbit --> Black[Opaque black curtain]
    Black --> Result[Existing Victory screen]
    Result --> Upgrades[Existing reward and upgrade confirmations]
    Upgrades --> Map[Existing system view]
```

## Shot parameters and framing

The authored introduction totals 3.45 seconds. The elevated establishing sweep, lower front-quarter flyby, and frontal pullback retain their paths. The opening shot fades in the enemy profile's name and class at lower left. The caption fades during the pullback and clears on Skip. The default `playback_speed` is .75, up from .50. The full introduction now runs in 4.60 seconds, down from 6.90. This rate applies only to presentation.

The director measures transformed mesh bounds beneath each model's `Body`; shield geometry is excluded. Offsets are expressed in measured hull radii and the model's local axes. The minimum distance also accounts for FOV and framing margin. Existing ship models face **local +X**. Future models should preserve the existing `Body`, `Shield` and engine interfaces.

The read-only combat forecast selects cinematic beams with at least **12 possible direct damage**, including Shield damage, or a possible lethal direct hit. The camera stays near the midpoint, offset perpendicular to the ship axis. It uses the measured hull sizes to put the attacker in the center during the charge and the victim in the center during impact. At the default rate, the charge takes .80 seconds, the turn takes about .27, and the minimum impact hold takes about .67. The existing launch signal turns the camera, and the existing contact callback plays one impact. The standard .45-second beam window gives the camera time to settle before contact. Lethal hits retain that angle through the original destruction VFX with the battle HUD visible.

Victory keeps the existing partial orbit, which now takes 3.00 seconds, followed by .40 seconds of engine buildup and about .51 seconds of acceleration. The camera stays fixed as the hull and shield travel up to 72 local units along +X. The fade starts after the boost and restores the model under black. See [depth and pacing](battlefield_depth_and_pacing.md) for battlefield background behavior.

## Standard battlefield lighting

Deep Space and Planetary Orbit retain their authored light colors. Key energy
rises from 1.45 to 1.65, rim energy from .35 to .45, and ambient energy from .60
to .68. Each ship gets one shadowless point fill on its own hull layer, with
a model-scaled range capped at 5.5 world units. The fill adds definition to
the camera-facing flank and follows the existing hull node. The destruction
callback switches off its lights as the fragments appear. Modifier arenas
continue using their authored lighting.

## Cancellation, settings and accessibility

`Skip Cinematics` bypasses introduction, optional attack cameras and victory orbit/boost. The short black transition remains. Battle VFX remains a separate preference. No new settings are added.

The 140×48 Skip button supports mouse and emulated Android touch, with keyboard/controller Accept or Cancel and native Android Back. Repeated Skip is harmless. Cancellation kills camera tweens, releases pending presentation waiters, restores the viewport, camera/FOV, background, UI visibility and previous valid keyboard focus. Skipping destruction does not skip or repeat its existing damage/VFX transaction. App suspension saves the already committed expedition normally; leaving the battle disposes its director and curtain. Destruction camera moves keep the normal viewport and HUD visible, with terminal actions disabled.

## Validation and captures

`tests/battle_cinematic_test.gd` exercises measured light/heavy/mothership framing, all modifier arenas, action locking, real touchscreen Skip at four viewport sizes, resize ownership, first-turn/RNG/save equivalence, actual beam damage, both attacker directions and lethal priority/result synchronization.

`tests/battle_departure_test.gd` exercises the real destruction → departure → Victory → upgrade → return flow, each skip stage, the preference bypass, result construction under opaque black, no replay on return, restored map input and equality with the original return's serialized expedition. Ordinary EMP escape retains its original path.

The standalone `ship_models_test.gd` audit explicitly dismisses the optional introduction through normal Skip before projecting geometry into the authored gameplay camera. All original geometry assertions remain; a restoration assertion guards that handoff.

Both are registered in the GL Compatibility and Mobile Vulkan rendered suites. Capture files are written to `.godot/testlogs/battle-camera/` and uploaded by CI. Legacy timing-sensitive scene tests explicitly disable the new optional camera presentation through the regression runner's `ARCOSPACE_BATTLE_CINEMATICS=0` environment default; these two tests explicitly enable it. This does not change user preferences, existing assertions, result animations or fixtures. Outside that test environment cinematics are enabled normally.

```sh
python3 tools/run_regressions.py --godot godot --script battle_cinematic_test --script battle_departure_test
python3 tools/run_rendered_regressions.py --godot godot --renderer gl_compatibility --script battle_cinematic_test --script battle_departure_test
python3 tools/run_rendered_regressions.py --godot godot --renderer mobile --script battle_cinematic_test --script battle_departure_test
```

The two hull fills use the existing forward lighting path and require no
shadow maps, extra viewports, or postprocessing. Rendered regressions check
the hull pixels with the fills enabled and disabled. Physical Android
frame pacing was not measured.

## Rendered gallery

These 1280×720 frames come from one production battle rendered in Godot
with GL Compatibility. The capture helper samples the live sequence and
writes separate frame folders for each renderer.

| Sequence | Frames |
| --- | --- |
| Introduction | [Frontal enemy close-up](battle_cinematic_direction_screenshots/enemy-close-up.webp) · [Settling into battle framing](battle_cinematic_direction_screenshots/intro-settling.webp) |
| Beam attack | [Charge](battle_cinematic_direction_screenshots/beam-charge.webp) · [Discharge during the camera turn](battle_cinematic_direction_screenshots/beam-launch.webp) · [Hull impact with HUD](battle_cinematic_direction_screenshots/hull-impact.webp) |
| Victory | [Engine buildup](battle_cinematic_direction_screenshots/engine-charge.webp) · [Departure before fade](battle_cinematic_direction_screenshots/departure.webp) |

### Original implementation captures

These are actual Godot production-scene captures, with no generated artwork. [Motion sequence](battle_cinematics_screenshots/cinematic-motion.webp) contains sampled frames encoded at **8 fps**, downscaled from 1280×720 to 640×360 for review. Playback is normalized: the software-renderer wall time is not an Android performance measurement. The reproducible capture helper is `tests/battle_cinematic_capture.gd`; it stages a real Missile Barrage against a 3-Hull, unshielded target with sufficient Crew to demonstrate confirmed destruction, then completes the normal result/upgrades and return.

| Stage | Capture |
| --- | --- |
| Wide approach, light hull | [Establishing](battle_cinematics_screenshots/establishing.webp) |
| Lower close flyby, heavy hull | [Flyby](battle_cinematics_screenshots/flyby.webp) |
| Both ships, Command Nexus | [Confrontation](battle_cinematics_screenshots/confrontation.webp) |
| Actual nonlethal beam confirmation | [Attack pan](battle_cinematics_screenshots/heavy-beam.webp) |
| Existing destruction fragments | [Destruction hold](battle_cinematics_screenshots/impact_hold.webp) |
| Surviving player showcase | [Victory orbit](battle_cinematics_screenshots/victory_orbit.webp) |
| Acceleration with shield, fading out | [Boost and fade](battle_cinematics_screenshots/fade_to_black.webp) |

![Sampled production motion](battle_cinematics_screenshots/cinematic-motion.webp)
