extends Node3D
## The battle beam's colored sheath and pale core at map scale.
## Shared primitive geometry, with no lights, particles, or combat scene instances.

const LIMIT := 12
const CYAN := Color("68ccff")
const AMBER := Color("ff8750")

var beam_mesh := BoxMesh.new()
var impact_mesh := SphereMesh.new()
var signal_mesh := TorusMesh.new()
var beam_materials: Dictionary
var emitted_beams := 0
var emitted_impacts := 0


func _ready() -> void:
	beam_mesh.size = Vector3.ONE
	impact_mesh.radius = 0.5
	impact_mesh.height = 1.0
	impact_mesh.radial_segments = 8
	impact_mesh.rings = 4
	signal_mesh.inner_radius = 0.46
	signal_mesh.outer_radius = 0.50
	signal_mesh.rings = 20
	signal_mesh.ring_segments = 5
	for side in ["allied", "hostile"]:
		var tint := CYAN if side == "allied" else AMBER
		beam_materials[side] = [_material(Color(tint, 0.34)), _material(tint.lerp(Color.WHITE, 0.7))]
	beam_materials.impact = _material(Color(CYAN, 0.42))
	beam_materials.destroyed = _material(Color(AMBER, 0.65))


func beam(from: Vector3, to: Vector3, side: String) -> void:
	var distance := from.distance_to(to)
	if get_child_count() >= LIMIT or distance < 0.1: return
	var flash := Node3D.new()
	add_child(flash)
	var offset := (to - from).normalized().cross(Vector3.UP) * 0.11 + Vector3.UP * 0.12
	flash.position = (from + to) * 0.5 + offset
	flash.look_at(to + offset)
	var materials: Array = beam_materials[side]
	_part(flash, beam_mesh, materials[0], Vector3(0.14, 0.14, distance * 0.89))
	_part(flash, beam_mesh, materials[1], Vector3(0.045, 0.045, distance * 0.89))
	emitted_beams += 1
	var fade := flash.create_tween()
	fade.tween_property(flash, "scale", Vector3(0.05, 0.05, 1), 0.26)
	fade.tween_callback(flash.queue_free)


func impact(at: Vector3, destroyed: bool) -> void:
	if get_child_count() >= LIMIT: return
	var pulse := _part(self, impact_mesh, beam_materials.destroyed if destroyed else beam_materials.impact, Vector3.ONE * 0.38)
	pulse.position = at + Vector3.UP * 0.1
	emitted_impacts += 1
	var fade := pulse.create_tween()
	fade.tween_property(pulse, "scale", Vector3.ONE * (0.9 if destroyed else 0.62), 0.18)
	fade.tween_property(pulse, "scale", Vector3.ONE * 0.04, 0.14)
	fade.tween_callback(pulse.queue_free)


func transmission(at: Vector3) -> void:
	var material := _material(Color(CYAN, 0.6))
	var pulse := _part(self, signal_mesh, material, Vector3.ONE)
	pulse.position = at + Vector3.UP * 0.2
	var fade := pulse.create_tween().set_parallel()
	fade.tween_property(pulse, "scale", Vector3.ONE * 14.0, 0.8)
	fade.tween_property(material, "albedo_color:a", 0.0, 0.8)
	fade.chain().tween_callback(pulse.queue_free)


static func _material(tint: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = tint
	if tint.a < 1: result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result


static func _part(parent: Node3D, mesh: Mesh, material: Material, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.scale = size
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
