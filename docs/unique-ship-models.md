# Closed-alpha ship models

Baseline inspected: 6b044971fd5df57dd65f8ac79c706819ef2813ec.

## Rendering dependencies

ShipData.model_scene is consumed by battle_setup.gd::_preview and
board_3d.gd::_enter_tree. Combat replaces the battlefield's placeholder before
child ready callbacks, preserving its root transform and mirrored enemy facing.
BattleEffects uses the shared ship_3d.gd animation API. No gameplay controller,
camera, navigation, stat, card, AI, or expedition logic changes are needed.

Before this pass all six player profiles and both capital profiles had no model
assignment. Marauder, Sentinel and Reclaimer also use battlefield fallback models.
Rustjack, Axiom-7 and Hollow Choir already have custom scenes.

## Editing

The eight scenes in scenes/ships match their profile filenames: endeavour,
thunderbolt, titania, ganymede, callisto, orion, marauder_vanguard,
sentinel_dreadnought. Open each scene directly in Godot to edit its geometry and
materials. Each contains its own embedded meshes/materials; editable mesh and
material resources are local to scene instances. Thunderbolt uses its own rotated
PrismMesh for the wedge, so its geometry is fully editable in the scene without
changing the existing enemy interceptor builder.

All eight reuse enemy_ship_model.gd, the existing accent-aware extension of
ship_3d.gd. Its name is historical; it contains no enemy AI. Preserve Body/Hull,
Body/Engine, Body/Details and Shield. Keep colored components under Details so
their palette survives initialization and receives existing damage/repair passes.
Profile hull_color tints the main Hull; update that visual field when changing
its palette. Nested accent materials remain scene-authored.

+X is forward. Root transforms, hover, recoil, explosions, repair and shield
triggers are unchanged. Body tilt matches the existing custom enemy convention.
Capital hulls emphasize layered mass within approximately the original footprint;
Dreadnought's shield is locally taller to cover its command tower. No global
camera or UI adjustments. Models use 11–25 primitive parts each plus the shield.

Engines use emissive surfaces with no dynamic lights. Replacing the placeholder
also discards its experimental engine lights. Ordinary enemies retain their
existing scenes and lighting.

## Validation

Run:
- Godot --headless --path . --editor --import --quit
- Godot --headless --path . --script tests/ship_models_test.gd
- Godot --path . --script tests/ship_models_test.gd

The new test checks eight distinct assignments, geometry/material isolation,
animation calls, real selection previews, combat loading across all six
battlefields, both capital overrides, ordinary enemies and projected camera
bounds at 1280×720 and 960×540. A rendered run saves selection pages and all
eight combat views under .godot/testlogs; CI includes them in godot-test-results.
Existing regression scripts continue to verify gameplay values. Obsolete shared
visual assertions are replaced and the replacement-model fixture restores its
original scene.

These are primitive closed-alpha models. Emission is intentionally simple; no
lighting/shader overhaul or final production detailing is included.
