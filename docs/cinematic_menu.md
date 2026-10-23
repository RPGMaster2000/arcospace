# Cinematic menu

The entry point remains `scenes/battle_setup.tscn`. It contains one shared
SubViewport and instances the independent `scenes/main_menu_3d.tscn` presentation.
The Mobile renderer and gameplay scenes are unchanged.

## Ownership

- `scripts/battle_setup.gd`: selected profile index, information/deck UI, existing
  save validation, overwrite confirmation, expedition construction and screen handoff.
- `scripts/presentation/main_menu_3d.gd`: a single explicit phase machine, title,
  camera interpolation, persistent fleet models, idle rotation and departure.
  It receives profiles and a selected index; it never accesses expedition/save data.
- Existing `ExpeditionState`, battle setup/result contracts and `ExpeditionSave`
  continue to own run initialization, combat and persistence.
- `scripts/ui/menu_preferences.gd`: one cinematic flag in the existing
  `user://music.cfg` ConfigFile. Music writes preserve other sections. No new autoload.

The first valid press during either fade completes the introduction and stops at
Press to Play. A distinct second press reveals selection. Key repeats and mouse
input synthesized from touch are ignored. Settings and modal input take priority.
Selection retargets one camera tween and clamps at the endpoints. Models are
instantiated once; their combat processing, shields and local lights are disabled
for the showcase. Source scenes, geometry and profile Resources are not edited.

New-run confirmation and successful initialization/save precede departure. Launch
locks controls, aligns the model's +X forward axis with a camera-relative upper-right
direction, pauses, and accelerates along that heading. A white cover hides scene
construction. The destination owns the temporary reveal tween/cover and pause
restoration, including early scene exit. Continue validates the slot and uses a
short transition, with no departure. It retains the saved ship and existing pending
reward/interrupted-battle restoration behavior.

## Inspector calibration

Open `scenes/main_menu_3d.tscn` directly for the world; open `battle_setup.tscn` for
its UI and destination transition timings. Exports apply at scene startup; use the
Remote Inspector to inspect runtime models. Keep a local test slot for calibration.

| Scene/node | Inspector controls |
|---|---|
| `MainMenu3D` / Title | Text, optional logo texture, font sizes, title/prompt vertical anchors; background/logo fade durations (2 seconds each); prompt blink duration and opacity range |
| `MainMenu3D/Title/Logo` | Container offsets; Text font/contrast treatment; Image aspect-preserving fit |
| `MainMenu3D/Space` | Material Override → Shader Parameters: space/cloud/accent colors, cloud intensity/scale, speed, star density/brightness, variation seed and streak/rift intensity |
| `MainMenu3D/Planet` | Authored position/scale, sphere mesh, Material Override → existing planet shader colors/rim settings |
| `WorldEnvironment`, `Sun`, `Rim`, `Fleet/ShowcaseLight` | Existing ambient/directional lighting and one local, shadow-free showcase light |
| `TitleView`, `ShipSelectionView` | Authored camera transforms; defaults differ by 90 degrees |
| `MainMenu3D` / Camera | Anchor references, transition duration, easing and transition curve |
| `Camera3D` | FOV, clipping and aspect behavior |
| `Fleet` | Root placement in the continuous world |
| `MainMenu3D` / Fleet | Spacing, shallow curvature, initial orientation, rotation speed, selection duration, framing offset, optional per-ship camera offsets in library order |
| `MainMenu3D` / Launch | Turn duration/easing; camera-space departure direction (+X right, +Y up, -Z away); pause (1 second); acceleration and travel duration |
| `BattleSetup` / Gameplay transition | White fade, map reveal and Continue fade durations |
| `BattleSetup/Selection` | Heading; information panel anchors/scroll; footer container; 20%-width side navigation zones confined above the information/actions |

Library order is Endeavour, Thunderbolt, Titania, Ganymede, Callisto, Orion.
ShipData remains the source of identity, role, description, statistics and model.
No presentation override changes starting attributes or owned decks.

## Preferences and development

Settings → Skip Cinematics defaults off. When enabled, the completed title/prompt
appears immediately; camera movement becomes brief, departure is skipped and screen
transitions stay short. Confirmations, save validation and input locks still apply.
The preference can be inspected/reset under `[presentation]` in `user://music.cfg`.
Run-save inspection/reset remains documented in [quit_resume.md](quit_resume.md).

Use the shared regression runner with Godot 4.7.2:

```sh
python3 tools/run_regressions.py --godot /path/to/Godot
```

New tests: `cinematic_title_test`, `cinematic_fleet_test`, `cinematic_launch_test`,
`cinematic_preferences_test`, `cinematic_lifecycle_test`, `cinematic_visual_test`.
The visual test also runs headlessly for layout/geometry assertions. With a rendering
driver it writes `.godot/testlogs/cinematic/`: black, starfield, title, Endeavour,
Titania and Orion across 1280×720, 960×540, 19.5:9 and 21:9 (plus a smaller
landscape size), heading, acceleration, transition and the revealed map.
CI runs the new suites through the shared runner and captures the cinematic visual
suite with its existing rendered workflow.

## Verification results

Godot 4.7.2: all 77 discovered headless suites and 25 rendered suites passed,
including targeted retests after UI fixture updates. Nine Python runner tests
passed. Exact seeded combat traces and fresh-process save/battle interruption
regressions passed. Startup for all six ships and interrupted-battle Continue were
also verified with an exported resource pack, running outside the source checkout.
Some existing engine fixtures still report ObjectDB shutdown warnings; the shared
runner retains these in logs. Windows/Android hardware was not available.

## Code health and platform limits

The superseded three-card paging UI, preview construction, page controls and
per-card fitting logic are removed. Main menu controller: 322 → 240 lines; entry scene: 295 → 154 lines. Preview viewports: 6 → 1.
Presentation adds a focused 181-line scene script and a small preference codec.
First-party runtime lines: 12,213 → 12,350 (137 added).
Total runtime code increases to implement the new choreography and lifecycle
behavior; this is not a claim of overall line-count reduction. Duplication in ship
information/preview setup is reduced, while new animation complexity is isolated
from save and gameplay logic. No managers, external assets or rendering dependencies
were introduced. Six authored model instances remain loaded for smooth navigation.

Desktop checks use Godot 4.7.2, headless rules/integration tests and X11 software
OpenGL rendering. This validates layouts and scene behavior, not Android GPU frame
time or touch hardware. The Mobile renderer configuration is retained; physical
Android/Windows hardware and driver performance still need device testing. No new
particles, blur, volumetrics, shadow maps or compositor effects are used.
