# Procedural star-system visual foundation

Starting revision: `8cded05b5254`. This feature changes presentation, not encounter
composition, travel legality, rewards, FTL, battle rules, RNG streams or saves.

## Ownership and integration

| Layer | Owner | Inputs and output |
|---|---|---|
| Cosmetic system data | `visual_system.gd` | Seed + system number + presentation entries + settings → names, planets, ellipse parameters and anchors |
| Generated geometry | `planet_models.gd`, map's `GeneratedSystem` root | Planet surfaces, orbit strips and noninteractive planet labels |
| Encounter representations | `destination_models.gd`, map's `EncounterRepresentations` root | Existing model_kind/profile → visual nodes; optional PackedScene overrides |
| Background | `space_environment.gd`, map's `BackgroundEnvironment` root | Camera-relative star sphere, replaceable layers and two MultiMeshes |
| Navigation and choreography | Existing `star_map_3d.gd` and `map_camera.gd` | Same markers, destination indices, callbacks, gestures, travel and cinematics |
| Gameplay and persistence | Existing State/Deck/Save | Unchanged; no cosmetic data stored in version 1 saves |

Expedition supplies the existing seed and system number. The existing `visual_seed`
configure argument remains supported for direct/legacy map callers. The 2D map and
original grid remain available. The controller additions pass read-only seed
context and display the cosmetic system name in the existing title.

## Generation and names

Cosmetic RandomNumberGenerators use derived, versioned string seeds for planets,
assignments, individual destination models/anchors, the star, backgrounds and dust.
They never consume State, reward, station, Chasedown, combat or AI random streams.
Changing a background layer does not reshuffle planets or stardust.

Planet count is uniformly drawn from 0 through the configured maximum (default 4,
clamped to 0–4). Count does not depend on encounter count. Each planet records its
index, type, radius, semi-major axis, eccentricity, inclination, orientation, phase,
initial spin, spin speed, material seed and optional encounter index.

Four maximum-capacity radial shells span radii 1.4–9.8 world units. Irregular
semi-major axes are drawn within each available shell. Radius and eccentricity are
constrained to leave the configured shell clearance; high-count systems therefore
use more conservative eccentricities than sparse systems. This prevents planets,
orbits and the star from intersecting without any orbital simulation.

For eccentric anomaly E, the unrotated point is:

```
x = a × (cos(E) − e)
z = a × sqrt(1 − e²) × sin(E)
position = yaw(orientation) × pitch(inclination) × (x, 0, z)
```

The star is at one focus. Inclination ranges −15°…+15°, orientation 0…360°, and
eccentricity 0…0.25 subject to clearance. Planets remain on their initial orbital
positions; only surface spin and optional cloud motion animate. One triangle strip
per orbit uses 64 segments by default, rather than many line nodes.

The 100 names are IAU WGSN-approved names with designation, constellation, language,
adoption date and source in [astronomical_names.md](astronomical_names.md). They
were retrieved from the WGSN catalog hosted on exopla.net on 2026-10-25. A seeded
Fisher–Yates permutation supplies unique names for the first 100 systems of an
expedition; the sequence wraps afterward. Planets use I–IV in increasing orbital
order. The stored authoritative `system_name` remains unchanged, preserving the
old name-generation RNG draw order and save compatibility. Map headers use the
new cosmetic display name; this is never written back into State.

## Planetary encounters and navigation

The mapping uses the actual presentation `model_kind`, derived from registered
PoI resource basenames by existing EncounterPresentation, not title substrings:

| Existing kind | Eligible planetary appearance | Standalone fallback |
|---|---|---|
| mining_operation | Rocky | Asteroids + industrial platform |
| research_station | Frozen | Station |
| gas_giant | Gas giant | Collection facility |
| quarantined_colony | Terrestrial | Habitat station |
| Other PoIs / enemies / outpost | Never assigned to planets | Existing category-specific space representation |

Assignments use their own seed and can leave planets decorative. Each planet gets
at most one encounter; no encounter is duplicated. The same six encounter indices
plus an optional separate outpost remain selectable. Decorative planets have only
read-only Label3D names and no interactive marker. Assigned labels retain the real
encounter name and append the planet's name. Label placement separates nearby tags
while retaining dynamic connectors to their exact projected anchors.

The existing ship travels to the same selected index and emits arrival once, using
the original timing/interception callbacks. Orbit/arrival distance has a minimum
planet-radius clearance. Initial ship placement avoids planet surfaces. Camera
focus accepts an optional visual radius to avoid clipping, while keeping the
existing settings, pan/zoom, return pose and cinematic lifecycle. Straight-line
travel remains deliberately simple; there is no obstacle solver or orbital revolution.

## Planet Generator subset and quality

Downloaded directly from https://github.com/remijean/godot-3d-planet-generator .
Pinned source revision: `2d17d1699d7440b17f34e3ae1654084244bd2f7d`.
Godot's Asset Library lists release 1.0 for Godot 4.5; the source project targets
4.5 Forward Plus. Arcospace includes only three shaders, six noise examples and
six extracted body materials under `third_party/naejimer_planets/`.

Both existing export presets explicitly include the third-party LICENSE file, so
it accompanies exported builds as well as the source tree. The full MIT license,
Copyright (c) 2023 Rémi, is preserved, along with upstream
shader provenance comments. No editor plugin, demo scene, demo animation player,
project settings, icon or installation step is imported. See the subset's README
for exact adaptations. In particular, undefined modulo-by-zero animation UVs are
replaced with fract/repeating samples, paths replace demo UIDs, and shared noise
textures are reduced to 128×128. Per-planet detached materials vary coordinates,
scale and palette without modifying the imported presets.

Seven types use six editable sample palettes: rocky/barren, terrestrial, desert,
frozen, volcanic and gas giant. Optional cloud shells and Fresnel atmospheres use
no screen/depth-texture dependency, volumetrics or Forward+-only bloom.
The original `shaders/planet_surface.gdshader` is byte-unchanged and remains the
explicit fallback. `Imported Planets = Off` omits imported cloud/atmosphere shells.

## Model replacement and background artwork

Open **resources/presentation/star_system_settings.tres** in the Inspector.

- **Planet generation / Orbit appearance**: count, clearance, size range, eccentricity,
  inclination, segment count, line color/alpha and thickness.
- **Background and quality**: imported-planet fallback, clouds, atmospheres,
  background strength and Background Layers.
- **Stardust**: enabled state, bounded density, opacity and parallax strength.
- **Replaceable encounter scenes → Destination Scenes**: assign a PackedScene by
  model_kind (for example `research_station`). Author a visual Node3D centered on
  its origin; optional radius metadata controls ship clearance. Enemies continue
  using their existing profile/model_scene path rather than a second registry.

Trading outposts use a hub, rings, docks and emissive windows. Mining sites add
asteroid clusters and machinery. Wrecks reuse a detached, tinted existing enemy
ship plus debris. Pirate battles retain their enemy models. Spatial anomalies use
a dark sphere/accretion ring; wormholes use an animated vertical ring; radiation
nebulae use a restrained billboard cloud. No new lights or physics are introduced. The existing PoI header backing is made
more opaque in 3D focus mode so bright secondary planets cannot wash out its text;
its controls, geometry and the resource bar are unchanged.

To replace a nebula/galaxy with PNG artwork:

1. Import a transparent PNG into the project.
2. Expand a **Background Layers** entry, or open `sky_nebula.tres` / `sky_galaxy.tres`.
3. Assign its **Texture**, adjust tint/opacity, apparent size, rotation and angular
   azimuth/elevation, then save. No shader or gameplay changes are required.

Empty Texture uses the procedural source. Quads sit at a fixed 55-unit camera-relative
radius; Apparent Size is quad size at that distance. Layer parallax defaults to zero.
The map restores its overview before recording the dust reference, so rebuilding
after a cinematic does not inherit the old camera pose. The existing starfield shader
is reused on a 70-unit sphere centered on the camera,
with finer jittered stars. A pre-draw callback follows camera transforms after tweens,
so panning/zooming cannot reveal a nearby starbox or a one-frame sky lag. Camera far
clipping is unchanged. There is still exactly one map SubViewport.

Dust uses two MultiMeshInstance3D layers, 64 small soft particles total by default
(maximum 160). Distribution is deterministic; only two transforms change with the
camera. No per-particle Nodes, physics, continuous texture generation or runtime
Python is required. Map deactivation disables its viewport and disconnects background
pre-draw updates. Backgrounds can be reduced through strength or removed by clearing
Background Layers; clouds, atmosphere and dust each have a reduced/disabled setting.

## Verification and limits

Newly verified with Godot 4.7.2:

- Baseline before edits: import plus 3D map, transitions, resume and deck determinism passed.
- Shared `tools/run_regressions.py`: **105 scripts + import, all 106 runs passed**.
- Pure generation: **4,050 checks**, including 300 seeded systems, full 0–4 count
  coverage, ellipse positions, bounds/clearance, assignments and 100 unique names.
- Final focused presentation: **143 checks** (headless and rendered); includes all
  seven planet types, all procedural PoI categories, PNG-compatible texture binding,
  PackedScene replacement, reduced settings, safe arrival, exact save reconstruction
  and a forced full visual rebuild leaving saved state/RNG streams unchanged.
- Rendered **Mobile/Vulkan** and **Compatibility/OpenGL** (llvmpipe): **143 checks
  each passed** at 1280×720, 960×540 and 1680×720. Extra cases cover high inclination/
  eccentricity, a large gas giant, planet/ship focus and dark/bright quality settings.
- After the final PoI-header readability adjustment, Android layout, map, transition,
  resume and zoom/fade suites were rerun successfully. After the dust-reference fix,
  presentation, map, transition, resume and zoom/fade tests were rerun again.
  The resource bar/layout did not change.
- Existing **2,220 card checkpoints, 72 combat traces, 43 ownership checks and 1,044
  expedition/deck checkpoints** matched unchanged fixtures. The last fixture retains
  its established historical six-modifier sampler; it was not regenerated.
- Existing Chasedown, PoI, outpost, save/fresh-process, battle-entry, FTL, card-management,
  music and other shared regressions passed. No original test expectation/fixture changed.
- Web-preset resource-only PCK export succeeded. The complete MIT LICENSE bytes were
  found verbatim in that pack; both Web and Android presets explicitly include it.
- `git diff --check` passed. State, Deck, save codec, combat/card/AI sources, original
  shaders and existing JSON baselines are byte-unchanged from the starting revision.

Earlier development runs exposed a typed-Array assignment in the new test fixture;
that fixture was corrected without changing gameplay or expected baselines. Final
runs contain no shader/import/script errors or failed assertions. Some scene tests
retain ObjectDB shutdown warnings (also present in baseline scene tests); the runner
records them separately. Compatibility software rendering reports unsupported V-Sync
control, which does not prevent rendering or shader compilation.

Representative four-planet, warmed software-render diagnostics (30 frames): Mobile
31.49 ms mean / 101 draw calls; Compatibility 20.26 ms / 129 draw calls. These include
viewport/UI overhead and concurrent host load. No pre-feature GPU benchmark or
physical Android comparison was captured, so these are observations, not device FPS
claims. Defaults limit planets to four, dust to two MultiMeshes/64 instances, orbit
strips to 64 segments, noise to shared 128×128 textures and lighting to one existing
directional light. There are no per-frame mesh rebuilds or new physics objects.

Run checks with:

```sh
godot --headless --path . --script tests/visual_system_test.gd
godot --headless --path . --script tests/planet_presentation_test.gd
python tools/run_regressions.py --godot /path/to/godot --timeout 360
```

The presentation script saves rendered captures under `.godot/testlogs/` when run
with a display. Documentation screenshots below are excluded from Godot import/export.
The bright-nebula capture intentionally calibrates opacity/strength upward to test
the replaceable layer; default systems remain more restrained.

The surfaces and special objects remain stylized placeholders. Exact orbital motion,
physical atmosphere scattering, lensing, volumetric nebulae and advanced ship pathfinding
are intentionally absent. Small decorative planet labels become readable when zooming;
playable markers retain normal interface text and hit areas. Highly packed systems
constrain eccentricity to preserve clearance. Configuration changes that rebuild
materials/models take effect on the next map construction/system, not a new editor plugin.

No physical Android device, Windows build, APK or browser/WebGL gameplay was tested.
The resource-only PCK license check is not a runnable application/export-device test.
Desktop software rendering through Mobile/Vulkan and Compatibility/OpenGL is shader and
layout evidence, not a mobile GPU performance measurement.

## Code size and files

Counts include the cosmetic name catalog and exclude unchanged shared UI/combat code.

| Runtime group | Before | After |
|---|---:|---:|
| Expedition coordinator | 1214 | 1220 |
| Existing map, models, camera and settings | 672 | 783 |
| ExpeditionScreen | 410 | 412 |
| New data/name/planet/background/layer components | 0 | 383 |
| New authored shaders | 0 | 46 |
| Authored combined | 2296 | 2844 |
| Imported/adapted shader code | 0 | 127 |
| Combined including imported shaders | 2296 | 2971 |

New runtime scripts: `visual_system.gd`, `astronomical_names.gd`, `planet_models.gd`,
`space_environment.gd`, `sky_layer.gd` under `scripts/presentation/star_system/`.
Modified: that folder's map, camera, models and settings; `scripts/expedition.gd`;
`scripts/ui/expedition_screen.gd`. New authored shaders: `cosmic_layer.gdshader`,
`anomaly_ring.gdshader`, `stardust.gdshader`. New resources: `sky_nebula.tres`,
`sky_galaxy.tres` and the explicitly licensed third-party subset. New tests:
`visual_system_test.gd`, `planet_presentation_test.gd` plus generated UID files.
`export_presets.cfg` includes the license in both existing presets. Developer/map
documentation, the astronomical catalog and this report are added/updated; eight
actual captures plus `.gdignore` live in `docs/procedural_system_screenshots/`. No existing runtime file
was removed, no plugin was added, and no original regression fixture was changed.

The controller grew by six lines. Generation, models and background synchronization
have focused presentation owners instead of adding gameplay responsibilities to it.
No new global manager, event bus, save data structure or duplicate enemy registry exists.

## Rendered examples

Actual Compatibility/OpenGL captures; the same cases also passed Mobile/Vulkan.

| Zero planets | One planet | Four planets |
|---|---|---|
| ![Zero](procedural_system_screenshots/0-960.png) | ![One](procedural_system_screenshots/1-960.png) | ![Four](procedural_system_screenshots/4-960.png) |

| Tilted/eccentric orbit | Large gas giant |
|---|---|
| ![Inclined](procedural_system_screenshots/tilted.png) | ![Gas giant](procedural_system_screenshots/giant.png) |

![Existing PoI UI and planet focus](procedural_system_screenshots/expedition-poi.png)
![Standalone ship focus](procedural_system_screenshots/ship-focus.png)
![Calibrated nebula layer](procedural_system_screenshots/bright-nebula.png)
