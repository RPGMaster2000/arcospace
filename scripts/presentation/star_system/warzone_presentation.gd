extends Node3D
## Read-only presentation. Rebuilt only when committed fleet positions change.

const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const ALLIED := Color("65dee9")
const HOSTILE := Color("ff936d")
const CONTESTED := Color("ffdc85")
const NEUTRAL := Color("c6d2e0")

var paths := ImmediateMesh.new()
var allies: Dictionary = {}


func _ready() -> void:
	var lines := MeshInstance3D.new()
	lines.mesh = paths
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lines.material_override = material
	add_child(lines)


func refresh(operation: RefCounted) -> void:
	paths.clear_surfaces()
	var moving: Array = operation.fleets.filter(func(fleet):
		var target: Vector3 = operation.objectives[fleet.destination].position
		return operation.active(fleet) and (fleet.position as Vector3).distance_squared_to(target) > 0.1)
	if not moving.is_empty():
		paths.surface_begin(Mesh.PRIMITIVE_LINES)
		for fleet in moving:
			var target: Vector3 = operation.objectives[fleet.destination].position
			var tint := ALLIED if fleet.side == "allied" else HOSTILE
			paths.surface_set_color(Color(tint, 0.72))
			paths.surface_add_vertex(fleet.position + Vector3.UP * 0.1)
			paths.surface_set_color(Color(tint, 0.25))
			paths.surface_add_vertex(target + Vector3.UP * 0.1)
		paths.surface_end()
	for fleet in operation.fleets:
		if fleet.side != "allied": continue
		var marker: Label3D = allies.get(fleet.id)
		if marker == null:
			marker = Label3D.new()
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.pixel_size = 0.019
			marker.font_size = 34
			marker.outline_size = 9
			marker.modulate = ALLIED
			add_child(marker)
			allies[fleet.id] = marker
		marker.position = fleet.position + Vector3.UP * 0.55
		marker.visible = operation.active(fleet)
		marker.text = "%s ALLIED · %s" % ["⚔" if fleet.engaged >= 0 else "◆", fleet.role]


static func objective_status(objective: Dictionary) -> String:
	if objective.contested: return "Contested"
	return "%s controlled" % objective.owner.capitalize() if objective.owner != "neutral" else "Neutral"


static func objective_color(objective: Dictionary) -> Color:
	if objective.contested: return CONTESTED
	match objective.owner:
		"allied": return ALLIED
		"hostile": return HOSTILE
	return NEUTRAL
