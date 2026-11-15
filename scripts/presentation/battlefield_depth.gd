extends Node3D
## Stationary scenery for the two standard arenas. No simulation, RNG or colliders.
## A frozen authored-camera basis anchors the panorama to world directions.
@export var orbital := false
const DEEP_ROCKS = [
	Vector3(51, 1.8, -45),
	Vector3(23, -12, -72),
	Vector3(-52, 23, -66),
	Vector3(-96, -32, -58),
	Vector3(112, 35, 12),
	Vector3(12, 52, 96),
	Vector3(-108, 30, 74),
	Vector3(-30, -48, -116)
]
const ORBIT_ROCKS = [
	Vector3(51, 1.8, -45),
	Vector3(23, -12, -72),
	Vector3(98, 32, 28),
	Vector3(-94, -34, 64),
	Vector3(-26, -46, -112)
]


func _ready() -> void:
	var arena := get_parent()
	var sky: MeshInstance3D = arena.get_node("MeshInstance3D")
	var camera: Camera3D = arena.get_node("Camera3D")
	sky.material_override.set_shader_parameter(
		"panorama_basis", camera.global_basis.orthonormalized().inverse()
	)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.25, 0.28)
	material.roughness = 1.0
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	var positions: Array = ORBIT_ROCKS if orbital else DEEP_ROCKS
	instances.instance_count = positions.size()
	for i in positions.size():
		var size := 0.85 + float(i % 3) * 0.45
		var basis := Basis.from_euler(Vector3(i * 0.73, i * 1.13, i * 0.41))
		basis = basis.scaled(Vector3(size, size * 0.62, size * 1.3))
		instances.set_instance_transform(i, Transform3D(basis, positions[i]))
	var debris := MultiMeshInstance3D.new()
	debris.name = "Debris"
	debris.multimesh = instances
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debris)
