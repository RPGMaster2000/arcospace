# Planetary Exploration surface proof of concept

This is **a standalone visual and navigation experiment**, not a replacement for the existing Exploration mode. It does not affect systems 1–5, campaign progression, saves, card battles or the existing Godot startup scene. There are **no external asset dependencies**.

## Start the preview

1. Open the Arcospace project in Godot 4.7.x.
2. Open `res://scenes/prototypes/planet_surface_poc.tscn`.
3. Press **F6** (Run Current Scene). Alternatively run `godot --path . res://scenes/prototypes/planet_surface_poc.tscn` from the repository root.
4. **Click or tap** ground to fly there, or select one of the four buttons under **Surface Contacts**. Use the mouse wheel or the onscreen **Zoom + / Zoom −** controls. Press Escape to exit on desktop.

The ship flies continuously over the terrain at a fixed clearance. Arriving near a structure displays a brief description; these are **non-living, non-combat inspection PoIs** with no economy, cards or rewards.

## Included structures

- **Ancient Signal Spire** — tall transmitter with glowing antenna ring.
- **Sealed Research Vault** — bunker with illuminated access hatch.
- **Crashed Survey Probe** — damaged craft lying in the sand.
- **Geothermal Extractor** — industrial platform with twin towers.

A single seeded landscape is created from `FastNoiseLite` and a low-poly `SurfaceTool` mesh. PoIs sit on locally leveled pads. Nearby rocks are drawn using a `MultiMesh`; crystals and station models use Godot primitive meshes and the existing `destination_models.gd` helpers. A terrain triangle collision mesh supports selecting real terrain points. Everything is generated at runtime.

**Scope intentionally excluded:** No orbital-to-surface transition, new gameplay rules, card encounters, living wildlife, pathfinding, save integration or fully spherical planet. This is a first experiment to assess camera scale, terrain readability, navigation and recognizable locations before integrating with the expedition.

## Test

Run `godot --headless --path . --script res://tests/planet_surface_poc_test.gd` to check deterministic terrain, generated mesh, PoIs, labels and basic travel commands.

**Verification note:** Review the scene in both desktop and Android renderers. Android hardware and full Godot regression coverage have not yet been verified as part of this proof of concept.

## Relevant source

- `scripts/prototypes/planet_surface_terrain.gd` — seeded heightmap and flat-shaded terrain geometry.
- `scripts/prototypes/planet_surface_poc.gd` — environment, PoIs, ship, camera and input.
- `scenes/prototypes/planet_surface_poc.tscn` — directly runnable scene.
