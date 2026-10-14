extends Resource
class_name ShipData
# RESPONSIBILITY: Inspector-editable ship starting values and optional model.
## TUNE: All statistics here apply when starting a fresh encounter.
@export var ship_name: String = "Wayfarer"
@export var role: String = "Balanced"
@export_multiline var summary: String = ""
@export_range(1, 1000, 1) var hull_capacity: int = 35
@export var shields: int = 10
@export var materials: int = 10
@export var energy: int = 10
@export var crew: int = 10
@export var synthesizer: int = 2
@export var reactor: int = 2
@export var quarters: int = 2
@export_range(1, 1000, 1) var ftl_turns: int = 14
## TUNE: Fractional resistance: 0.25 reduces probability by 25%; -0.10 increases it by 10%.
@export_range(-1.0, 1.0, 0.01) var ftl_resistance: float = 0.0
## TUNE: Hull-only tint; shields, engines and effect materials stay separate.
@export var hull_color: Color = Color(0.52, 0.67, 0.73)
## EDIT: Optional replacement model; empty retains the existing battlefield ship.
## Custom models must support the ship_3d.gd animation API and Body/Shield nodes.
@export var model_scene: PackedScene
