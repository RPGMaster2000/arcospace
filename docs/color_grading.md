# Battlefield color grading

## Renderer findings

The project remains on **Mobile**, with the Windows **D3D12** driver setting
unchanged. No Forward+ switch, new lighting, Lens Effects, bloom or other shader
package was introduced. Ship models and existing shield/damage shaders are unchanged.

Godot supports compositor hooks on Mobile and Forward+, but that does not make
every compute effect compatible with Mobile render targets. The supplied
`Compositor/Color grading/ColorGrading.gd` uses `get_color_image_uniform()` to bind
the scene color as a storage image. A Godot 4.7.2 **Mobile/Vulkan** probe on
llvmpipe produced `needs the TEXTURE_USAGE_STORAGE_BIT usage flag` errors followed
by invalid uniform sets. This is diagnostic evidence only: that compute effect
is **not instantiated or attached** in the shipped grading path.

References: [Godot compositor documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)
and [Mobile render-target restrictions discussed by Godot maintainers](https://github.com/godotengine/godot/issues/120019).

The allowed lightweight fallback is a local **CanvasItem shader on the existing
SubViewportContainer**, sampling its existing battlefield texture once. Rytelier's
shadow/midtone/highlight luminance weights and preferential low-saturation vibrance
are the behavior/reference model. This adaptation operates on display-referred
color after the 3D viewport, rather than duplicating the package's HDR/OKLab
compute pipeline. No other post-processing package is used. The original Color
Grading plugin, ColorGrading, LocalContrast and General files remain untouched.

LocalContrast is intentionally unused: it allocates several downsampled textures
and blur stages. Noise, curves and the package's advanced color-space transforms
are not exposed as if they were supported by the lightweight path.

The fallback passed rendering tests on **Mobile/Vulkan and Compatibility/OpenGL**.
These desktop tests used Mesa llvmpipe software rendering. Android hardware and
Windows D3D12 were not available for direct testing; Mobile renderer success is
not a measured Android-device guarantee.

## Integration and ownership

| File | Responsibility |
|---|---|
| `scripts/visual/battlefield_grade_preset.gd` | Inspector Resource, neutral defaults, change notifications, valid luminance ranges. |
| `resources/color_grading/*.tres` | Six independent saved preset Resources. |
| `scripts/visual/battlefield_grading.gd` | Shared SubViewportContainer controller, cached preset selection, per-encounter ShaderMaterial. |
| `shaders/battlefield_grade.gdshader` | Single-sample raster grading of the existing battlefield texture. |
| `scripts/board_3d.gd` | Select the preset once from the existing environment index. |
| `scenes/board_3d.tscn` | Attach the controller to BattleView; leave the viewport and HUD structure intact. |
| `scenes/tools/color_grading_preview.tscn`, `scripts/tools/color_grading_preview.gd` | Development-only F6 comparison/reload workflow. |
| `tests/color_grading_test.gd` | Presets, independence, persistence, bypasses, renderer output and UI isolation. |
| `tests/color_grading_benchmark.gd` | Reproducible alternating on/off frame measurements. |
| `tests/board_3d_test.gd` | Recoil assertion checks the authored Body rest position instead of assuming zero. |

The existing environment index selects presets in the same order as battlefields.
An environment keeps its look through inactive/active event phases; event timers
and rules are unchanged. Index 0 / no modifier restores Standard, including the
optional planetary-orbit battlefield. Neither frame updates nor modifier timers
are duplicated in the grading controller.

Resources are preloaded once. Each controller owns its own material and disconnects
from the previous preset when switching. Every parameter is refreshed when a preset
changes, so previous-encounter values cannot remain in the material. Uniforms
update only on changes; assigning an unchanged value does not trigger an upload.
Disabled, zero-strength and completely neutral presets detach the material,
returning to the original draw without grading arithmetic. No added render target,
screen copy, blur, downsampling pass or per-frame script allocation is required.

## Presets

| Environment | Resource | Direction |
|---|---|---|
| Standard | `resources/color_grading/standard.tres` | Cool shadows, gentle cyan mids, warm highlights, slightly desaturated shadows. |
| Asteroid belt | `resources/color_grading/asteroid_belt.tres` | Restrained dust/amber warmth, lower saturation, stronger contrast. |
| Ion storm | `resources/color_grading/ion_storm.tres` | Blue-violet shadows, cyan mids, brighter cool highlights and vibrance. |
| Solar flare | `resources/color_grading/solar_flare.tres` | Amber mids and warm luminous highlights with retained surface detail. |
| Nebula | `resources/color_grading/nebula.tres` | Violet shadows, magenta mids, cyan highlights, softer contrast. |
| Temporal rift | `resources/color_grading/temporal_rift.tres` | Violet shadows, cool neutral mids, magenta highlights and stronger contrast. |

The defaults are deliberately restrained. Standard uses strength 0.65; other
presets use 0.75. Existing environmental backgrounds, shields and VFX retain their
identities. The effect acts on BattleView's 3D texture only. Cards, resource
indicators, bars, warnings, EMP, allocation controls and result overlays are drawn
outside that material and retain their original colors.

## Inspector calibration

| Control | Neutral value / meaning |
|---|---|
| Enabled | True; False removes grading. |
| Strength | 0–1 blend; 0 removes grading entirely. |
| Shadow / Midtone / Highlight Tint | White multiplies channels by 1; alpha is not exposed. |
| Shadow / Midtone / Highlight Brightness | 1; independent multiplicative brightness. |
| Contrast | 1; gentle S-curve with fixed black and white endpoints. |
| Saturation | 1; global color intensity. |
| Shadow Saturation | 1; saturation multiplier only in the shadow range. |
| Vibrance | 0; preferential saturation adjustment for less saturated colors. |
| Shadow Range | Display-luminance interval where shadow weight fades out. |
| Highlight Range | Interval where highlight weight fades in. |

Ranges are sorted/clamped before use and never produce a zero-width smoothstep.
Completely neutral color controls bypass the material regardless of range settings.
Optional curves and LocalContrast are omitted rather than exposing nonfunctional
or expensive controls.

1. Open `scenes/tools/color_grading_preview.tscn` and press **F6**.
2. Choose the environment in its development toolbar. The battle is frozen for
   inspection; the toolbar is not added to normal gameplay.
3. Select that environment's `.tres` in Godot's FileSystem and change its Inspector
   controls. Save the Resource with Ctrl+S.
4. Press **Reload saved preset** in the running preview. This explicitly reloads
   the saved file rather than relying on cross-process editor live-reload.
5. Toggle **Grading** to compare with the original. The preview edits a local copy
   when toggling; it does not overwrite the saved Enabled setting.
6. Subsequent battles use the saved resource automatically after a new run. When
   inspecting a live controller within the same editor process, Resource.changed
   updates its material immediately.

Each file is independent. Editing Ion Storm does not modify Standard or the other
four environments. Do not edit script defaults to calibrate one environment.

## Validation

The dedicated suite passes **110 headless checks** and **128 rendered checks per
renderer**, covering all six environments, independent files/instances, immediate
and nonredundant parameter changes, neutral/zero/disabled bypasses, resource save
and uncached reload, fresh material isolation, return to Standard and the F6 preview.

Rendered checks on both Mobile/Vulkan and Compatibility/OpenGL prove that neutral
and zero-strength output are identical, grading visibly changes the battlefield,
and the entire cards/lower-HUD region remains pixel-identical. Before/after PNGs
are generated under `.godot/testlogs/grade-*.png` and were inspected. Production
render logs contain no grading shader compilation or uniform-set errors.

Run:

```sh
godot --headless --path . --script tests/color_grading_test.gd
godot --path . --rendering-method mobile --script tests/color_grading_test.gd
godot --path . --rendering-method gl_compatibility --script tests/color_grading_test.gd
```

The full suite contains 64 test scripts. The old 3D recoil assertion also failed
on unchanged main after the preceding shield-fit pass; it now asserts restoration
to the authored position and passes. The star-map timing test requires
`--fixed-fps 60` on this host. `enemy_models_visual_test.gd` requires a rendering
display, because it awaits frame_post_draw; it cannot complete headlessly.

All 64 scripts passed in their appropriate modes after the fixture correction:
63 headless scripts (star_map at fixed 60 fps), plus the rendered enemy-model
capture script. Dedicated grading output passed in both renderers.

## Measured performance

An isolated, warmed Ion Storm battle at 1280×720 was measured on Mesa llvmpipe
(LLVM 20.1.2, 256 bits), Godot 4.7.2. The existing 1280×395 battle viewport and
2.0 internal 3D scale were unchanged. Four warm-up blocks exercise both paths;
eight alternating ABBA blocks then measure 24 presented frames each. Values below
are medians of four block means per state. The benchmark includes the entire
frame and renderer scheduling, not just shader GPU time.

| Renderer | Grading off | Grading on | Observed change |
|---|---:|---:|---:|
| mobile | 42.63 ms | 42.65 ms | +0.03 ms (+0.06%) |
| gl_compatibility | 45.42 ms | 40.92 ms | -4.50 ms (-9.90%) |

The observed difference is smaller than block-to-block software-renderer noise
on Mobile; Compatibility even reports an apparent speed-up, so these samples do
not establish a reliable GPU overhead or performance benefit. Raw block timings
are retained in [color_grading_benchmark.json](color_grading_benchmark.json).
No Android hardware timing, Windows/D3D12 timing, power or thermal measurement
was available. The implementation adds arithmetic to the existing viewport draw,
without adding a full-resolution render pass.

Reproduce in a display-capable session:

```sh
godot --path . --rendering-method mobile --script tests/color_grading_benchmark.gd
godot --path . --rendering-method gl_compatibility --script tests/color_grading_benchmark.gd
```
