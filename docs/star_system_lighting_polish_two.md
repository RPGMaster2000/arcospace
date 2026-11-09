# Planetary contrast and atmospheric depth

Baseline: PR #52, `de58e952ea09ea909991a39ed60f673fb4a8ad45`. This pass changes map material response and the existing sun billboard, with no gameplay or procedural generation changes.

## Sources and calibration

The shadowless sunlight and ambient fill in `star_map_3d.gd`, and opt-in calibration in `stellar_lighting.gd`, remain the lighting foundation. The shared shader include calculates sunlight direction from the physical star position, independently of whether the camera sees the star. Existing imported body, cloud and atmosphere materials retain procedural palettes and textures.

| Source | Adjustment |
|---|---|
| `map_settings.gd` | Contrast 1.18 → 1.28; corona spread 0.75, strength 0.72, core whitening 0.38 |
| `star_system_lighting.gdshaderinc`, body/cloud/fallback surface shaders | Smooth directional albedo gain: night 1/contrast, day 1.10 (rocky) or 1.06 (gas/cloud); existing terminator retained |
| `planet_models.gd` | Minimum roughness 0.72 for gas, 0.55 otherwise; specular 0.18/0.26; existing atmospheric categories get alpha 0.16/intensity 1.55, thinner shells 0.08/0.9; gas Fresnel exponent 3.8, others 4.5 |
| Imported atmosphere shader | Sunward scattering gain 0.035–1.35, limb-shaped opacity; face opacity attenuated to reduce the uniform veil |
| `menu_sun.gdshader`, `star_map_3d.gd` | Narrower exponential corona and restrained white center, enabled only by map uniforms; shared shader defaults preserve other scenes |

Ambient energy (0.28), sunlight energy (3.2), dark fill (0.72) and spacecraft rim calibration are unchanged. Rocky/barren bodies still have no atmosphere shells. No geometry, shadow maps, lights, passes or texture lookups were added. Calibration remains a build-time operation.

The broad halo originates in the sun billboard's exponential corona. The lens compositor also contributes rays/ghosts, while solar shaders provide separate localized prominences and influence visuals. This pass tunes the billboard source; `sun_lens_effects.gd`, compositor shaders, global lens multiplier (0.32), edge fade and solar shaders are unchanged. The core radius remains unchanged, including its relationship to saved solar geometry.

## Reproduction and visual review

Both supplied Android screenshots informed the art direction. Their exact seed and camera transform are unavailable. The gallery uses equivalent production views with seed 1042, 1280×720, Godot 4.7.2, identical camera fixtures and renderer settings on each side. Baseline production code is untouched; the same updated capture script runs in both worktrees (`-- baseline` on main). The gas specimen uses the existing production planet builder with a test-only gas type override. Cosmetic node processing and planet/cloud motion are paused; shader TIME animations remain live, so animated background/solar pixels are not strict pixel-diff fixtures.

Visual review shows a more contained halo, stronger illuminated detail and readable dark surface patterns, and a directional atmospheric edge without a uniform bright outline. Existing PoI clutter and procedural texture style are preserved. Close-up views can still include the large sun billboard in their background. The cyan fixture does not reproduce the supplied blue-purple star exactly.

| Renderer | Offscreen day/night ratio before → after | Overview draw calls before → after |
|---|---|---|
| GL Compatibility | 4.147 → 5.266 | 326 → 326 |
| Mobile Vulkan | 3.832 → 4.204 | 231 → 231 |

Ratios support the image review; they are not physical radiometry or an Android performance benchmark. Rendering used Mesa llvmpipe software GL/Vulkan, not a physical Android GPU. Added work is a few scalar operations and one atmosphere limb power, without per-frame material reconstruction. Check frame time, thermal behavior, touch/PoI readability and centered/edge/offscreen flare continuity on a representative Android device before merging.

## Validation

Godot 4.7.2 commands (set `GODOT` to the matching binary):

```sh
$GODOT --headless --path . --script res://tests/star_system_lighting_material_test.gd
$GODOT --headless --path . --script res://tests/star_system_lighting_test.gd
$GODOT --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --path . --script res://tests/star_system_lighting_test.gd
$GODOT --display-driver x11 --rendering-method mobile --audio-driver Dummy --path . --script res://tests/star_system_lighting_test.gd
python3 tools/run_regressions.py --godot "$GODOT" --workers 3 --skip-import
```

Focused material checks: 87 passed; headless lighting: 62 passed; rendered GL: 75 passed; rendered Mobile: 78 passed. Baseline captures: GL 15 and Mobile 16 checks passed. Existing assertions remain intact; new checks cover material-family response and shell counts. Full local headless results and the complete GitHub matrix are reported in the PR. GitHub runs are left unmonitored as requested; pending runs are not counted as passing. The existing workflow covers headless, rendered GL/Mobile, exported lens checks and exported startup. No established baseline fixtures were changed.

## Matched screenshot gallery

Original, unedited production-renderer PNGs; before is left, after is right.

### mobile

| View | Before | After |
|---|---|---|
| centered | ![Before centered](lighting_polish_two_screenshots/before-centered-mobile.png) | ![After centered](lighting_polish_two_screenshots/after-centered-mobile.png) |
| edge | ![Before edge](lighting_polish_two_screenshots/before-edge-mobile.png) | ![After edge](lighting_polish_two_screenshots/after-edge-mobile.png) |
| offscreen | ![Before offscreen](lighting_polish_two_screenshots/before-offscreen-mobile.png) | ![After offscreen](lighting_polish_two_screenshots/after-offscreen-mobile.png) |
| terminator | ![Before terminator](lighting_polish_two_screenshots/before-terminator-mobile.png) | ![After terminator](lighting_polish_two_screenshots/after-terminator-mobile.png) |
| gas-giant | ![Before gas-giant](lighting_polish_two_screenshots/before-gas-giant-mobile.png) | ![After gas-giant](lighting_polish_two_screenshots/after-gas-giant-mobile.png) |
| dark-nebula | ![Before dark-nebula](lighting_polish_two_screenshots/before-dark-nebula-mobile.png) | ![After dark-nebula](lighting_polish_two_screenshots/after-dark-nebula-mobile.png) |
| asteroids-pois | ![Before asteroids-pois](lighting_polish_two_screenshots/before-asteroids-pois-mobile.png) | ![After asteroids-pois](lighting_polish_two_screenshots/after-asteroids-pois-mobile.png) |
| dark-side | ![Before dark-side](lighting_polish_two_screenshots/before-dark-side-mobile.png) | ![After dark-side](lighting_polish_two_screenshots/after-dark-side-mobile.png) |
| spacecraft | ![Before spacecraft](lighting_polish_two_screenshots/before-spacecraft-mobile.png) | ![After spacecraft](lighting_polish_two_screenshots/after-spacecraft-mobile.png) |

### gl_compatibility

| View | Before | After |
|---|---|---|
| centered | ![Before centered](lighting_polish_two_screenshots/before-centered-gl_compatibility.png) | ![After centered](lighting_polish_two_screenshots/after-centered-gl_compatibility.png) |
| edge | ![Before edge](lighting_polish_two_screenshots/before-edge-gl_compatibility.png) | ![After edge](lighting_polish_two_screenshots/after-edge-gl_compatibility.png) |
| offscreen | ![Before offscreen](lighting_polish_two_screenshots/before-offscreen-gl_compatibility.png) | ![After offscreen](lighting_polish_two_screenshots/after-offscreen-gl_compatibility.png) |
| terminator | ![Before terminator](lighting_polish_two_screenshots/before-terminator-gl_compatibility.png) | ![After terminator](lighting_polish_two_screenshots/after-terminator-gl_compatibility.png) |
| gas-giant | ![Before gas-giant](lighting_polish_two_screenshots/before-gas-giant-gl_compatibility.png) | ![After gas-giant](lighting_polish_two_screenshots/after-gas-giant-gl_compatibility.png) |
| dark-nebula | ![Before dark-nebula](lighting_polish_two_screenshots/before-dark-nebula-gl_compatibility.png) | ![After dark-nebula](lighting_polish_two_screenshots/after-dark-nebula-gl_compatibility.png) |
| asteroids-pois | ![Before asteroids-pois](lighting_polish_two_screenshots/before-asteroids-pois-gl_compatibility.png) | ![After asteroids-pois](lighting_polish_two_screenshots/after-asteroids-pois-gl_compatibility.png) |
| dark-side | ![Before dark-side](lighting_polish_two_screenshots/before-dark-side-gl_compatibility.png) | ![After dark-side](lighting_polish_two_screenshots/after-dark-side-gl_compatibility.png) |
| spacecraft | ![Before spacecraft](lighting_polish_two_screenshots/before-spacecraft-gl_compatibility.png) | ![After spacecraft](lighting_polish_two_screenshots/after-spacecraft-gl_compatibility.png) |

## Full local headless result

The initial three-worker run completed with {'passed': 154, 'failed': 3}. `star_map_test` fails the same service-arrival assertion on unchanged main. `expedition_lifecycle_test` failed its arrival assertion under the parallel run but passed all 26 checks on isolated rerun (and on main). `trading_outpost_test` timed out at 120 seconds under the parallel run but passed all 100008 checks on isolated rerun (and on main). These results do not establish a fully green suite. No assertions, timing thresholds or gameplay files were changed to hide these failures. Some tests report ObjectDB shutdown warnings; isolated reruns also report a font-cache permission warning. The GitHub matrix remains the final automated check.
