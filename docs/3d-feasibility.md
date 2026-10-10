# Optional 3D feasibility experiment

Open `scenes/board_3d.tscn` and press F6 (Run Current Scene).
F5 still starts the original 2D board. No project settings were changed.

Open `scenes/battlefield_3d.tscn` to arrange the ships, planet, light and camera
in Godot's 3D viewport. Open `scenes/ship_3d.tscn` to edit the primitive mesh
parts. These are saved editor nodes, not runtime-generated geometry.

The experiment inherits board.tscn and board.gd: cards, resources, AI, rules,
input and victory handling are shared. A transparent SubViewport renders the
3D scene beneath the existing UI. BattleEffects has optional ship paths and
three animation hooks; its original 2D defaults and timing remain intact.

Prototype effects: hull recoil/red flash, green repair flash, and a pulsing
shield shell that disappears at zero. The 2D frontal shield arc and repair
sweep are not reproduced; there are no projectiles or external assets yet.

Validation: Godot 4.6 headless import and all five existing test scripts passed,
plus board_3d_test.gd covering material isolation, hull flash/restoration,
zero/recovered shields, repair card resolution and turn timing. A real frame
was rendered and inspected using the software OpenGL Compatibility renderer.
The project's configured Mobile renderer fell back to OpenGL because this
host lacks Vulkan surface support. Godot 4.7, D3D12, Android performance and
interactive touch input have not been verified here.

This proves that a 3D presentation can reuse the current gameplay. It is not
an art pass or a full effects conversion.
