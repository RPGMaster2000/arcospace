# Battlefield environments: Inspector editing

All battlefield scenes are independent `.tscn` files. Open one directly in Godot
and use F6 for a 3D-only preview, or run `board_3d.tscn` to see its combat HUD.

| Modifier index | Scene under `scenes/` | Visual identity |
|---|---|---|
| 0 / None | `battlefield_3d.tscn` | Deep Space: sparse fixed stars, near-black space, neutral blue-white key and cool rim. |
| 1 / Asteroid Belt | `battlefield_asteroid_belt.tscn` | Muted warm-white key, blue-grey fill, six slowly drifting rocky silhouettes. |
| 2 / Ion Storm | `battlefield_ion_storm.tscn` | Violet/blue clouds, cyan streaks, cool violet key and cyan rim. |
| 3 / Solar Flare | `battlefield_solar_flare.tscn` | Dark warm space, bright stellar disc/corona, orange-yellow key and restrained red rim. |
| 4 / Nebula | `battlefield_nebula.tscn` | Broad teal/rose clouds moving slowly; teal key and complementary rose rim. |
| 5 / Temporal Rift | `battlefield_temporal_rift.tscn` | Green/cyan distorted ring and slow cloud motion; mint key and cool cyan rim. |
| 0 / None, random normal variant | `battlefield_planetary_orbit.tscn` | Standalone Deep Space duplicate with a large, partly visible dark blue-grey planet. |

There is no radiation battlefield in the current modifier registry. The modifier
scenes communicate the encounter environment for the whole battle; scheduled
activation/expiry is still communicated by the existing modifier HUD and effects.
Environment animation is deliberately independent of modifier timing and mechanics.

## What to select in the Scene tree

- **WorldEnvironment → Environment**: solid fallback/background color, ambient color
  and ambient energy. Resources are scene-local; changing a scene does not recolor others.
- **Sun** (`DirectionalLight3D`): primary light color, energy and rotation. **RimLight**:
  restrained secondary light color/energy/rotation. Neither casts shadows. Existing
  ship engine lights and their escape-charge feedback remain unchanged.
- **MeshInstance3D → Material Override → Shader Parameters**: the opaque procedural
  backdrop. Keep this node name: `board_3d.gd` resizes it for responsive framing. Its
  material is named **Procedural Space Backdrop**. The script does not set its colors,
  speed, shader or light values. Toggle Visibility to compare with the solid fallback.
- **Asteroids**: `asteroid_count` (0–8; default 6), `drift_velocity` in background-local
  units/second, `spin_speed` in radians/second and `wrap_width` / `wrap_height`. Its eight **Rock** child
  meshes expose initial positions, rotations, scale, mesh and rocky material. Duplicate
  or reposition authored rocks when extending the decoration; there is no runtime spawn
  or collision logic. The `@tool` script updates count visibility in the editor but does
  not move the saved editor poses. Runtime drift wraps both background-plane axes, without accumulating offscreen objects. Setting the velocity to zero disables translation.
- **BackgroundObjects/Planet** in Planetary Orbit: position, scale, SphereMesh detail and
  Material Override. The opaque planet uses normal scene lighting, procedural surface
  variation and a faint shader rim, without an extra transparent atmospheric sphere.

Keep decorative objects behind both ships. The Asteroids/BackgroundObjects parent
transforms define a camera-aligned background plane at approximately 28 world units
from the camera; ships are closer. No body, collision, physics or gameplay hooks are
attached to these decorations. Changing a parent transform changes the whole group.

## Shader parameters

| Shader | Editable parameters | Cost / behavior |
|---|---|---|
| `shaders/space_background.gdshader` | `space_color`, `cloud_color`, `accent_color`, `cloud_intensity`, `cloud_scale`, `animation_speed`, `star_density`, `star_brightness`, `variation_seed`, `streak_intensity`, `rift_intensity`, `feature_center` | Three interpolated 2D value-noise samples, one sparse star layer; smooth streak/ring formulas. Set optional intensities to zero for normal space. Speed 0 is static. |
| `shaders/solar_background.gdshader` | `space_color`, `corona_color`, `star_color`, `star_center`, `star_radius`, `corona_intensity`, `animation_speed`, `band_scale` | Radial disc/corona and slowly shifting bands; brightness pulse is only ±4%, without full-screen flashes. UV position controls the star framing; the authored disc avoids the top modifier HUD. |
| `shaders/planet_surface.gdshader` | `ocean_color`, `land_color`, `rim_color`, `surface_scale`, `rim_intensity` | Opaque lit sphere, simple surface pattern and small view-angle rim emission. No rotation/orbit simulation. |

Shader source can be shared; the per-scene `ShaderMaterial` and `Environment`
Resources use `resource_local_to_scene = true`. Do not extract mutable materials to a
shared `.tres` unless you intentionally want coupled editing. The rocky material is
shared by the rocks *within* the Asteroid scene so one edit updates that group.
The normal variant is a full duplicate, not inherited from a modifier scene.

## Why a backdrop quad rather than animated Sky Resources?

The existing board already renders a single camera-facing opaque background mesh.
Reusing it avoids a second star layer, texture sampling from the former dense 5 MB
starfield and animated sky/radiance cubemap updates. A solid `WorldEnvironment` supplies
ambient lighting and a simple fallback. No `Sky`, fog, SSR, bloom, post-process or
transparent full-screen layers are needed for these stylized scenes.

The former starfield texture is no longer referenced by these battlefield scenes.
The asset itself and star-system navigation are retained. Hiding the procedural mesh
reveals the scene's authored solid background; it does not enable another star layer.

## Selecting Planetary Orbit

`board_3d.gd` still indexes the original six `BATTLEFIELDS` by the original modifier.
The **Normal Battlefield** exported `PackedScene` is an optional override **only when
modifier = 0**. Leave it empty to randomly choose Deep Space or Planetary Orbit. In `scenes/board_3d.tscn`, select the root
Board3D and drag `battlefield_planetary_orbit.tscn` into that property to use the orbit
variant for normal encounters. Alternatively assign `board.normal_battlefield` before
adding a board in a test fixture. Overrides never replace modifier scenes.

Normal-variant selection uses a separate presentation RNG with equal probability.
Encounter probabilities, gameplay RNG, progression and modifier values do not change.
Planetary Orbit can also be opened and played directly.

## Performance and validation

The project remains on its existing **Mobile** renderer; no global project settings
change. Backdrops are one opaque unshaded quad each. Decorations have no shadow casting,
collisions, particles or extra lights. Lighting adds one shadow-free rim directional
light to the original primary light and existing ship engine lights. Asteroids are
low-segment primitives; the planet is one 48-segment / 24-ring sphere. Materials avoid
screen/depth textures, compute, ray marching and volumetrics.

`tests/battlefield_environments_test.gd` verifies original scene selection, normal-only
overrides, resource isolation, drift/wrapping/count, background depth, ship statistics
and unchanged hand geometry. Run it headless for logic; with a rendering driver it also
captures all seven environments at 1280×720, 1680×720 and 960×540 in
`.godot/testlogs/environment-*.png`. The regression workflow includes this rendered test.

Desktop Compatibility rendering provides a portable shader-compilation and visual
check, not an Android performance claim. Physical Android runtime/performance must be
checked on a device; it is not available in this environment. For a slower device,
reduce Asteroids count or hide the planet, set optional backdrop effect intensities
and speed to zero, or hide the quad for the solid authored background. None of these
presentation edits changes combat rules.

### Validation for this visual pass

Godot 4.7.2 import and all **40 headless regression scripts** passed. The focused
scene/presentation suite passed **226 checks**, including rendered captures of all
seven environments at the three sizes above with Compatibility/OpenGL. Render logs
contained no shader compilation errors. The Mobile/Vulkan desktop attempt could not
initialize `VK_KHR_surface` and automatically fell back to OpenGL, so it is **not**
a successful Mobile-renderer validation. Android hardware testing remains outstanding.
The diff audit confirms card/ship/rule Resources, combat resolution/AI, expedition
state, HUD layout and `project.godot` are unchanged. Available render hardware is
software Mesa; it cannot establish device performance. The runtime also lacks audio
hardware and uses Godot's existing Dummy audio fallback during rendered tests.

Normal battles now choose Deep Space or the existing Planetary Orbit scene with equal
probability, using a separate presentation RNG. Modifier-specific arenas and the explicit
`Board3D.normal_battlefield` override retain their existing selection behavior.
