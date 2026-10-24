@tool
extends SubViewportContainer
## Grades only this container's existing 3D texture, never sibling HUD controls.
## Inspector changes update uniforms via Resource.changed; no per-frame polling.
const GRADE_SHADER = preload("res://shaders/battlefield_grade.gdshader")
const PRESETS = [
	preload("res://resources/color_grading/standard.tres"),
	preload("res://resources/color_grading/asteroid_belt.tres"),
	preload("res://resources/color_grading/ion_storm.tres"),
	preload("res://resources/color_grading/solar_flare.tres"),
	preload("res://resources/color_grading/nebula.tres"),
	preload("res://resources/color_grading/temporal_rift.tres")
]
@export var preset: BattlefieldGradePreset = PRESETS[0]:
	set(value):
		if preset == value:
			return
		if preset != null and preset.changed.is_connected(_apply):
			preset.changed.disconnect(_apply)
		preset = value
		if preset != null and not preset.changed.is_connected(_apply):
			preset.changed.connect(_apply)
		if is_node_ready():
			_apply()
var grade_material: ShaderMaterial
var parameter_updates: int = 0

func _ready() -> void:
	if preset != null and not preset.changed.is_connected(_apply):
		preset.changed.connect(_apply)
	_apply()

func set_environment(kind: int) -> void:
	preset = PRESETS[0 if kind in [6,7] else clampi(kind, 0, PRESETS.size()-1)]

func _apply() -> void:
	parameter_updates += 1
	if preset == null or not preset.enabled or preset.strength <= 0 or preset.is_neutral():
		material = null
		return
	if grade_material == null:
		grade_material = ShaderMaterial.new()
		grade_material.shader = GRADE_SHADER
	var parameters: Dictionary = preset.parameters()
	for key in parameters:
		grade_material.set_shader_parameter(key, parameters[key])
	material = grade_material
