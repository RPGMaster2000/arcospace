# World-space stellar dust and shadow corridors

Baseline: main 6d3aa8e, including merged PR #53. The previous work is retained;
no competing planetary gain/contrast tuning is added here.

## Problem and technique selection

The lens addon synthesizes ghosts, anamorphic flare and radial depth-sampled rays
around the projected source. It is intentionally absent offscreen. Those optical
terms cannot represent persistent three-dimensional shadowed dust. They remain
unchanged in this implementation, including centered-sun settings and safeguards.

The prototype first used uniformly integrated finite cones. Inspection rejected
that version: obvious flat end boundaries and bright shell contours appeared at
oblique angles. Raising opacity would have made the problem worse.

The selected alternative analytically integrates a quadratic longitudinal density
profile through nested finite cones. Density reaches zero at both ends. Three
weighted radial envelopes soften the outer boundary; subtracting the planet's
finite umbra makes a darker corridor between illuminated dust. This is closed-form
ray/cone intersection and integration, not ray marching. A tiny static subpixel
alpha dither reduces visible LDR gradient bands.

A one-star/one-planet fixture was reviewed before production integration. Its
side and oblique views show the same world-anchored corridor; camera movement does
not rotate/reallocate it. The first rectangular-cap version was not integrated.

## Architecture

- `stellar_shafts.gd`: one shared unit box mesh and one shared shader material;
  at most three major-body instances. Vertex instance parameters size the bounded
  proxies, with matching CPU culling bounds. No collision, light or shadow-map nodes.
- `stellar_dust_volume.gdshader`: four analytic path integrals, one scene-depth
  sample per covered pixel, no texture noise or sampling loop. Resolved opaque depth
  truncates each ray so scattering does not draw through solid surfaces. Compatibility
  and Mobile use their respective projection/depth conventions.
- Map construction reads existing final physical positions and radius metadata.
  Largest planets and substantial gas-giant PoIs are preferred; bodies below radius
  0.5 are skipped. Generated appearance, positions, RNG and gameplay records are not
  changed. There are no separately generated moons currently; substantial spherical
  bodies use the same radius/position path.
- Geometry points away from the authoritative rendered star. Stellar radius comes
  from the same saved/core-scale definition as existing solar visuals. Umbra slope
  is `(body_radius-star_radius)/distance`: larger stars converge the shadow, larger
  occluders can diverge it. Surrounding dust spread is a bounded stylized approximation.
- A cheap maximum-three-body transform/radius comparison runs each frame. Geometry
  is never rebuilt; changed body/star positions update transforms, bounds and instance
  parameters only. Static frames retain mesh/material identities.
- Dust draws behind atmospheric/PoI ribbons at priority -20. This fixes transparent
  ordering across camera angles rather than allowing distance-sort changes to pop.
  Opaque depth still clips the ray. The result represents shadowed medium, not an
  eclipse applied to another object's surface.

Map tuning: `stellar_shafts_enabled=true`, `stellar_dust_density=0.035`. Length is
clamped to 5-12 units from eight body radii; spread is clamped to 0.08-0.22 from
stellar angular size. Gas giants use 75% density. Opacity is capped at 0.26. Quality
is visual only. No new player graphics interface is added.

## Cost and limits

At most three additional bounded transparent draws share resources. No new lights,
shadow maps, full-screen compositing shader or per-frame material allocation is
introduced. Sampling depth can require Godot's existing resolved-depth/copy path,
particularly on GL; this is not free and is a reason to cap coverage/object count.
The existing lens compositor is neither disabled nor modified. Overdraw depends
on camera proximity, and physical Android thermal/frame-time testing is outstanding.

This is deliberately stylized dust, not full volumetric radiative transfer or
inter-object eclipse simulation. The finite tapered envelopes can still read as
localized dust lobes in a sparse black-space close-up. Overlapping transparent
volumes are not a global participating medium; the three-body budget limits clutter.
The ordinary overview is more restrained than the controlled side view. No claim
is made that numerical checks alone establish art-direction acceptance.

## Validation and matched comparisons

`stellar_shafts_prototype_test.gd`: controlled star/planet, centered, fully offscreen,
oblique and backlit captures; checks the entire physical source disc is outside the
frustum in the offscreen fixture; forty transition frames verify world transforms
and mesh identity remain unchanged by camera movement.

`stellar_shafts_render_test.gd`: production seed 1042 with matched enabled/disabled
captures, same geometry/camera/viewport/renderer, major-body budget, shadow direction,
mesh reuse and position-update checks, collider-free effects and unchanged saved
state/RNG. Existing lighting, solar, asteroid, touch and navigation suites remain.
Both suites are registered for GL and Mobile CI. Final full CI status is in the PR.

PNG files are original renderer output, not postprocessed. Before/after differ only
in the new subtree's visibility; shader TIME remains live. Prototype framing is a
test scene and does not change production camera controls. Windows production
Mobile captures explicitly use Vulkan. No encoded motion video was recorded.

| Production view | Before | After |
|---|---|---|
| Centered sun | ![](world_shafts_screenshots/centered-before-mobile.png) | ![](world_shafts_screenshots/centered-after-mobile.png) |
| Edge | ![](world_shafts_screenshots/edge-before-mobile.png) | ![](world_shafts_screenshots/edge-after-mobile.png) |
| Multiple bodies/PoIs/asteroids | ![](world_shafts_screenshots/asteroids-pois-before-mobile.png) | ![](world_shafts_screenshots/asteroids-pois-after-mobile.png) |

| Controlled prototype | Before | After |
|---|---|---|
| Fully offscreen source | ![](world_shafts_screenshots/prototype-offscreen-before-mobile.png) | ![](world_shafts_screenshots/prototype-offscreen-after-mobile.png) |
| Oblique | ![](world_shafts_screenshots/prototype-oblique-before-mobile.png) | ![](world_shafts_screenshots/prototype-oblique-after-mobile.png) |
| Backlit | ![](world_shafts_screenshots/prototype-backlit-before-mobile.png) | ![](world_shafts_screenshots/prototype-backlit-after-mobile.png) |

GL equivalents and the remaining production close-ups are included in the gallery
folder. Combat, environmental selection/snapshots, save formats, procedural systems,
navigation, camera controls, PoI interaction and unrelated RNG are unchanged.
