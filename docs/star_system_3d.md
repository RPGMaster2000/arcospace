# Minimal 3D star-system map

The default expedition map is `scenes/star_system_3d.tscn`. It uses one SubViewport with
an ordinary 2D top bar above it, the existing space/sun/planet shaders, selected player
ship models and enemy profile `model_scene` references. Standard enemies without a
custom model use the same legacy `ship_3d.tscn` fallback as the battle scene.
Asteroids, wrecks, installations and the separate outpost are low-poly primitives.
There are no new autoloads, runtime dependencies, physics or gameplay RNG calls.

## Inspector calibration

Open **FileSystem → resources/presentation/star_system_settings.tres**. Alternatively,
select **scenes/expedition.tscn → Expedition → Star System Settings** and expand it.

| Setting | Purpose |
| --- | --- |
| Overview Position / Overview Target / Field Of View | Further-back three-quarter camera and 29° vertical FOV; focal distance and FOV are calibrated together to reduce perspective distortion |
| Default Zoom / Minimum Zoom / Maximum Zoom | Overview distance multipliers: 1.20 default, bounded to 0.95–6.0; higher means closer |
| Wheel Zoom Step | Mouse-wheel increment (default 6%); pinch uses finger-distance ratio |
| System Bounds | X/Z destination-center rectangle, default X −16…16 and Z −10…10; changes only visual arrangement |
| Pan Bounds / Pan Drag Threshold | Camera-center X/Z limits (default ±16 / ±10) and tap-to-drag threshold (12 pixels) |
| Label Offset | Screen-space offset from a projected model to its label center (default 0, 58) |
| Screen Border | Minimum inset for projected destination hit regions, default 8 logical pixels |
| Destination Offset | Camera distance, height and angle relative to the focused destination; horizontal framing adapts to the viewport aspect |
| Camera Duration | Overview/focus transition and FTL ship zoom (default 0.8 s) |
| Orbit Radius / Orbit Speed | Circular ship orbit in world units and radians/second |
| Battle Zoom Duration | Ship zoom before battle (default 0.9 s) |
| Departure Side Offset | Camera-space flyby clearance, default 1.4 world units to the right |
| Departure Turn Duration | Stationary, eased turn before camera zoom and acceleration (default 1.1 s) |
| Departure Speed / Departure Duration | Accelerating FTL flight distance per second and flight duration |
| White Fade Duration | White curtain fade at battle/FTL boundaries |
| Result Suspense Duration | Presentation pause after an approach commits, before its flash (default 2 s) |

**Expedition → Star Map Travel Duration** retains the existing sublight travel timing.
Disable **Use 3d Star Map** to retain the 2D map; disable **Use Star Map** for the original
grid. Both fallbacks use the same state methods. Scene defaults and `.tres` tuning can
be changed without changing expedition rules.

## Ownership and extension points

| Component | Responsibility |
| --- | --- |
| `expedition_state.gd` (unchanged) | Destinations, travel legality, Chasedown, outcomes, rewards, FTL and saves |
| `expedition.gd` | Supplies destination dictionaries and ship profiles; connects travel callbacks; sequences existing UI, battle and progression calls |
| `star_map_3d.gd` | Scene, projected button labels, models, ship tween, orbit and interception impact |
| `map_camera.gd` | Overview, destination, battle and FTL camera transforms; cancels superseded camera tweens |
| `destination_models.gd` | Small primitive assemblies and existing ship instantiation; replace `build()` branches with authored PackedScenes here later |
| `expedition_screen.gd` | Existing top bar, full-width reward galleries, split PoI sidebar and scroll area |
| `white_transition.gd` | Expedition-owned CanvasLayer; stays white while a battle child initializes or the next system is generated |

Destination entries contain the actual encounter title, index, completion, category and
optional existing enemy profile. Geometry selection never creates or resolves encounters.
A local seeded RandomNumberGenerator uses expedition seed/system to vary colors, object
sizes, orientation and modest position offsets. It never consumes any run generator.

Projected buttons provide 140×64 logical-pixel hit regions, ordinary keyboard focus and
mouse/touch activation. Labels use bright bold text on rounded dark sci-fi plates. Category-colored connector
lines join each plate edge to the projected destination, updating on pan, zoom and resize.
`poi_marker.gd` owns tag styling/connector drawing; **Label Offset** in the shared map
settings tunes plate spacing. Both the plate and the projected model remain tappable;
tags move above a model near the lower edge to preserve the connector. Labels ignore
model occlusion and remain readable. Completed
entries have a check mark and disabled input. Labels hide during camera transitions and
inspection. The top UI keeps its existing position and controls. Overview mouse-wheel and
two-finger pinch zoom smoothly within the configured limits; one-finger or left-mouse
drag pans on the system plane within Pan Bounds. Small movements remain taps. Existing
overview pan/zoom is retained when returning from a destination. UI overlays block camera
gestures; pinching cancels any held
destination button and suppresses release activation. Camera pan/zoom stays available during sublight PoI travel; selecting another destination remains locked until arrival. PoI interaction-panel scrolling does not zoom the map.
The bottom overflow cue is a stationary gradient overlay (`ui/scroll_edge_fade.gd`),
outside container layout and excluding the live scrollbar. Its opacity tracks remaining
content; it never changes scroll range, page size, input or layout when shown/hidden.

Sublight movement uses a sine tween, smooth facing and restrained turn banking. Arrival
emits once, starts an orbit and delegates the encounter to the controller. The map is
retained outside the replaceable PoI UI, so returning does not recreate the system or
reset ship position. Orbiting pauses only for cinematic control. The existing interception
callback runs once at departure, stops movement after 0.5 s, plays the familiar two red
pulses/decaying shake and opens the existing Chasedown flow without emitting arrival.

PoI approaches reuse the original tiles, descriptions, eligibility and confirmation modal,
in a single-column scrollable right pane, including outpost services. The model is framed on the left. Outcomes
commit and autosave once before `_result_suspense()`; that function is the insertion
point for a future animation. Return/approach input is locked during suspense. The
existing result color flash and rewards follow it. Mandatory card/replacement/upgrade
choices keep their full-width galleries and state navigation guards.

Battle entry keeps the existing preview/Enter Combat interaction. `_enter_battle()`
zooms at the player, fades white, then calls unchanged combat setup/checkpoint logic.
The map viewport sleeps during battle. FTL locks immediately, completes a slow stationary turn toward the calibrated flyby path, then zooms and pauses, flies
the ship beside and past the camera with acceleration, fades white, calls `generate_system()` once
and reveals the newly seeded map. Existing music calls and all eight tracks are intact.

No camera/tween state is serialized. Continue uses the existing last committed navigation
origin, pending travel/interception and battle checkpoint. A suspended cosmetic transition
restarts from that authoritative state; background autosave keeps the old system until
FTL generation commits the new one. Scene-owned tweens and overlays are released with
the expedition. Detached/stale UI buttons are ignored by the shared SFX binding.

## Validation and limits

Run `tools/run_regressions.py` as described in [regression_testing.md](regression_testing.md).
Focused tests: `star_system_3d_test.gd`, `star_system_transition_test.gd` and
`star_system_resume_test.gd`. The original map/Chasedown/PoI geometry fixtures explicitly
exercise the 2D fallback. The transition test also writes rendered captures to
`.godot/testlogs/system3d-*.png` when run with a display (headless runs skip captures).
It checks 1280×720 and 960×540 framing, labels, top bar, simulated screen touch,
visual RNG isolation, FTL single execution and battle fade cleanup. The other focused
tests cover all six arrivals, the independent outpost, orbit, interrupted travel, result suspense and save/resume.

This is deliberately crude art: no orbit lines, detailed destination textures, warp tunnel,
free camera rotation or particle effects. Non-planet categories share small geometric families.
The ship is small in overview and enlarged by destination/battle framing. Shadows are
disabled, and the inactive map viewport stops rendering. Godot-native meshes/materials
and existing shaders were rendered successfully with both Compatibility/OpenGL and
Forward Mobile/Vulkan using Mesa llvmpipe on Linux, at 1280×720 and 960×540.
Android hardware performance, physical
touch, Windows exports and on-device audio have not been measured in this environment.


Validation for this implementation: Godot 4.7.2 import and **all 87 shared regression
scripts passed**. The focused rendered transition test passed **104 checks** with both
Compatibility/OpenGL and Forward Mobile/Vulkan. Existing headless ObjectDB shutdown
warnings remain in several older fixtures; the runner records them separately from
errors. No parse errors, runtime errors or failed checks remain in the final suite.

Files added: `scenes/star_system_3d.tscn`, `resources/presentation/star_system_settings.tres`,
the five scripts under `scripts/presentation/star_system/` (and their Godot UIDs),
three `tests/star_system_*_test.gd` fixtures, and this document. Integration modifies
`expedition.gd` and `ui/expedition_screen.gd`. Legacy map, PoI, milestone, outpost and
expedition fixtures explicitly select their fallback presentation where they assert
immediate/2D behavior. `audio/sfx.gd` has a two-line stale-button guard, covered by
`sfx_test.gd`; this prevents detached UI callbacks accessing a missing SceneTree.
`DEVELOPER_GUIDE.md` and `expeditions.md` link here. No gameplay state, save format,
combat rules, ship definitions, soundtrack or project renderer setting changed.


Follow-up polish validation: `map_zoom_fade_test.gd` verifies default/wheel/pinch zoom,
limits, calibrated bounds, gesture release suppression, FTL clearance, fade/scrollbar
separation and stable scroll geometry. Map navigation, resume, Android layout, cinematic
launch, PoI confirmation and the 104-check Mobile/Vulkan rendered transition fixture
also passed. Physical Android pinch/performance testing remains outstanding.

Camera-drag follow-up: mouse and single-finger pan, drag-release suppression, UI-overlay
blocking and pan bounds are covered by `map_zoom_fade_test.gd`. Default zoom is 1.20×.


## Expedition lifecycle boundary

See [controller phases and cancellation](expedition_controller_lifecycle.md). The map now
executes the existing battle-entry and FTL choreography through `battle_entry(curtain)` and
`ftl_departure(curtain)`; Expedition validates/commits and requests the shared reveal. Camera,
ship, impact and curtain owners cancel their own tweens. `travel_started` reports presentation
entry only; State's existing callback still decides travel/interception once. No camera,
input, model, label, timing or calibration value changed. Returning retains the same camera
pan/zoom, and ordinary travel still allows camera interaction. 3D/2D/grid use the same State.


FTL turn polish (2026-10-24): turn and flight share the same ship-facing basis and projected
camera-side path. The turn completes before `close_ship` and the subsequent acceleration;
cancelling the sequence also cancels the rotation tween. Tune **Departure Turn Duration**
in the existing settings Resource. Updated transition tests verify stationary turn timing,
completed heading, exactly-once progression and fade cleanup: 130 checks pass headless and
under Mobile/Vulkan at the two landscape sizes. The lifecycle test uses a local shortened
turn only; shipping duration is 1.1 seconds. No travel legality, saves, rewards or music changed.
