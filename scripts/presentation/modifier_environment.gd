extends Node3D
## Modifier-scene scenery only. Builds once from a private cosmetic seed; owns no
## combat/scheduler/navigation state. All large objects stay behind the clear arena.
const Meshes = preload("res://scripts/presentation/environment_meshes.gd")
@export_enum("asteroid", "ion", "solar", "nebula", "rift", "metal", "psionic")
var environment_kind := "asteroid"
@export var scenery_seed: int = 1701
@export_range(12, 120, 1) var instance_budget: int = 72
@export_range(0.05, 0.3, 0.01) var cloud_opacity: float = 0.18
@export_range(0.0, 2.0, 0.05) var motion_scale: float = 1.0
@export_range(0.25, 1.0, 0.05) var android_density: float = 0.55
## Preview Android's small-instance budget on desktop without changing landmarks.
@export var reduced_density := false
var rng := RandomNumberGenerator.new()
var visible_fraction := 1.0


func _ready() -> void:
	rng.seed = scenery_seed
	visible_fraction = android_density if reduced_density or OS.has_feature("android") else 1.0
	var arena := get_parent()
	var camera: Camera3D = arena.get_node("Camera3D")
	var center: Vector3 = (
		(arena.get_node("PlayerShip").position + arena.get_node("EnemyShip").position) * 0.5
	)
	transform = Transform3D(camera.basis.orthonormalized(), center)
	var sky: MeshInstance3D = arena.get_node("MeshInstance3D")
	sky.material_override.set_shader_parameter(
		"panorama_basis", camera.global_basis.orthonormalized().inverse()
	)
	match environment_kind:
		"asteroid":
			_asteroids()
		"ion":
			_ion()
		"solar":
			_solar()
		"nebula":
			_nebula()
		"rift":
			_rift()
		"metal":
			_metal()
		"psionic":
			_psionic()


func _energy(color: Color, phase: float = 0.0, electrical: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/battle_environment_energy.gdshader")
	material.set_shader_parameter("energy_color", color)
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("electrical", electrical)
	material.set_shader_parameter("motion_scale", motion_scale)
	return material


func _field(
	count: int,
	near_depth: float,
	far_depth: float,
	spread: float,
	minimum_size: float,
	maximum_size: float
) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in count:
		var at := Vector3(
			rng.randf_range(-spread, spread),
			rng.randf_range(-spread * 0.4, spread * 0.4),
			-rng.randf_range(near_depth, far_depth)
		)
		var size := rng.randf_range(minimum_size, maximum_size)
		var basis := Basis.from_euler(
			Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		)
		basis = basis.scaled(
			Vector3(size, size * rng.randf_range(0.55, 1), size * rng.randf_range(0.7, 1.3))
		)
		at = _clear_departure(at, size * 5.0)
		result.append(Transform3D(basis, at))
	return result


func _cloud(
	label: String, at: Vector3, size: Vector2, tint: Color, density: float, angle: float
) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/space_storm.gdshader")
	material.set_shader_parameter("storm_color", tint)
	material.set_shader_parameter("phase", angle)
	material.set_shader_parameter("density", density)
	material.set_shader_parameter("layer", angle)
	var node := Meshes.part(self, label, mesh, at, material)
	node.rotation = Vector3(0.10, angle * 0.04, angle * 0.10)


func _asteroids() -> void:
	var material := Meshes.material(Color("635d54"))
	Meshes.instances(
		self,
		"RockyMiddleField",
		Meshes.rock(),
		material,
		_field(instance_budget * 2 / 3, 42, 82, 58, 0.6, 2.2),
		visible_fraction
	)
	var distant := _field(instance_budget / 3, 100, 155, 85, 1.0, 3.0)
	var centers := [Vector3(-42, 18, -120), Vector3(38, -17, -150), Vector3(5, 22, -185)]
	for i in distant.size():
		var at := distant[i].origin
		at = centers[i % centers.size()] + Vector3(at.x * 0.16, at.y * 0.2, (at.z + 127) * 0.25)
		distant[i].origin = _clear_departure(at, distant[i].basis.get_scale().length() * 2.0)
	Meshes.instances(
		self, "DistantRockClusters", Meshes.rock(), material, distant, visible_fraction
	)
	for i in range(3):
		var node := Meshes.part(
			self,
			"ForegroundFormation%d" % i,
			Meshes.rock(),
			[Vector3(-24, -9, -31), Vector3(27, 14, -38), Vector3(-38, 14, -50)][i],
			material
		)
		node.scale = Vector3(4 + i, 2.5 + i, 3.5 + i)
		node.rotation = Vector3(i * 0.8, i * 0.5, i * 0.6)
	# Keep the authored, Inspector-editable drift and count interface.
	var authored: Node3D = get_parent().get_node("Asteroids")
	authored.transform = transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -30))


func _ion() -> void:
	_cloud(
		"IonBankLeft", Vector3(-21, 8, -58), Vector2(55, 32), Color("477bd0"), cloud_opacity, 0.6
	)
	_cloud(
		"IonBankRight",
		Vector3(27, -8, -90),
		Vector2(65, 38),
		Color("426d94"),
		cloud_opacity * 0.9,
		2.2
	)
	_cloud(
		"VioletFarBank",
		Vector3(4, 18, -145),
		Vector2(86, 44),
		Color("7061ba"),
		cloud_opacity * 0.8,
		4.1
	)
	var concentrations: Array[Transform3D] = []
	for i in range(3):
		var points := PackedVector3Array()
		for j in range(11):
			points.append(
				Vector3(
					-28 + j * 5.6,
					sin(j * 1.7 + i) * 2.0 + (i - 1) * 13,
					-65 - i * 20 + cos(j * 1.3) * 3
				)
			)
		Meshes.part(
			self,
			"DistantDischarge%d" % i,
			Meshes.tube(points, 0.10),
			Vector3.ZERO,
			_energy(Color("72d9ef"), 0.3 + i * 2.0, true)
		)
		for at in [points[0], points[points.size() - 1]]:
			concentrations.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4), at))
	var particles := SphereMesh.new()
	particles.radius = 0.18
	particles.height = 0.36
	particles.radial_segments = 6
	particles.rings = 3
	Meshes.instances(self, "DischargeAnchors", particles, _energy(Color("72bbed")), concentrations)
	Meshes.instances(
		self,
		"ChargedConcentrations",
		particles,
		_energy(Color("8ec4ed"), 2.0),
		_field(instance_budget / 3, 35, 100, 55, 0.6, 1.8),
		visible_fraction
	)


func _solar() -> void:
	var star := SphereMesh.new()
	star.radius = 38
	star.height = 76
	star.radial_segments = 48
	star.rings = 20
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://shaders/battle_stellar_surface.gdshader")
	surface.set_shader_parameter("motion_scale", motion_scale)
	Meshes.part(self, "DistantStellarLimb", star, Vector3(-30, -3, -102), surface)
	var plasma := _energy(Color("ff9843"), 0.8)
	for i in range(3):
		var loop := Meshes.part(
			self,
			"Prominence%d" % i,
			Meshes.tube(Meshes.arc(7 + i * 2, -0.5, 3.8, 1.8), 0.24),
			Vector3(-13 + i * 7, 17 - i * 11, -66),
			plasma
		)
		loop.rotation = Vector3(0.35, -0.3 + i * 0.35, 0.4 + i * 0.8)
	for i in range(3):
		var points := PackedVector3Array(
			[
				Vector3(-13, -16 + i * 14, -74),
				Vector3(-6, -15 + i * 15, -61),
				Vector3(2, -13 + i * 16, -49),
				Vector3(9, -11 + i * 17, -41)
			]
		)
		Meshes.part(self, "RadialPlasma%d" % i, Meshes.tube(points, 0.055), Vector3.ZERO, plasma)


func _nebula() -> void:
	_cloud(
		"PurpleNearVeil",
		Vector3(-18, 12, -48),
		Vector2(67, 36),
		Color("9a63b7"),
		cloud_opacity,
		1.0
	)
	_cloud(
		"BlueMiddleVeil",
		Vector3(30, -10, -86),
		Vector2(82, 44),
		Color("437cac"),
		cloud_opacity * 1.2,
		3.0
	)
	_cloud(
		"TealFarVeil",
		Vector3(-5, 22, -145),
		Vector2(105, 62),
		Color("548d86"),
		cloud_opacity * 0.9,
		5.0
	)
	_cloud(
		"DenseCloudKnot",
		Vector3(34, 13, -40),
		Vector2(26, 18),
		Color("ad72c1"),
		cloud_opacity * 1.3,
		2.0
	)


func _rift() -> void:
	var center := Vector3(15, 5, -64)
	var opening := QuadMesh.new()
	opening.size = Vector2(43, 36)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/temporal_rift.gdshader")
	material.set_shader_parameter("visibility", 0.75)
	material.set_shader_parameter("phase", 1.7)
	Meshes.part(self, "SpatialOpening", opening, center, material)
	var gold := _energy(Color("e8c170"), 0.0)
	var blue := _energy(Color("70bfee"), 3.0)
	for i in range(5):
		var arc := Meshes.part(
			self,
			"BrokenArc%d" % i,
			Meshes.tube(Meshes.arc(14, i * 1.25, i * 1.25 + 0.75, 1.2), 0.22),
			center + Vector3(0, 0, (i % 2) * 4),
			gold if i % 2 else blue
		)
		arc.rotation.x = 0.12 * (i - 2)
	var fragment := BoxMesh.new()
	fragment.size = Vector3(0.4, 1.4, 0.35)
	Meshes.instances(
		self,
		"SuspendedFragments",
		fragment,
		blue,
		_field(instance_budget / 2, 40, 110, 48, 0.5, 1.7),
		visible_fraction
	)


func _metal() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/battle_wreckage.gdshader")
	material.set_shader_parameter("motion_scale", motion_scale)
	var plate := BoxMesh.new()
	plate.size = Vector3(3.8, 0.10, 2.1)
	Meshes.instances(
		self,
		"HullPlating",
		plate,
		material,
		_field(instance_budget / 2, 32, 95, 60, 0.7, 1.9),
		visible_fraction
	)
	Meshes.instances(
		self,
		"TwistedGirders",
		Meshes.wreckage(),
		material,
		_field(instance_budget / 4, 42, 125, 72, 0.6, 1.5),
		visible_fraction
	)
	Meshes.instances(
		self,
		"BrokenHullFrames",
		Meshes.wreckage(true),
		material,
		_field(instance_budget / 6, 55, 140, 68, 1.0, 2.0),
		visible_fraction
	)
	var landmark := Meshes.part(
		self, "AbandonedHullSection", Meshes.wreckage(true), Vector3(-30, 10, -44), material
	)
	landmark.scale = Vector3(3, 2.2, 2.2)
	landmark.rotation = Vector3(0.3, 0.7, 0.4)


func _psionic() -> void:
	var violet := _energy(Color("b078e8"), 1.0)
	var pink := _energy(Color("e083c5"), 3.0)
	violet.set_shader_parameter("distortion", 0.04)
	pink.set_shader_parameter("distortion", 0.04)
	for i in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 10 + i * 3
		ring.outer_radius = ring.inner_radius + 0.18
		ring.rings = 40
		ring.ring_segments = 6
		var node := Meshes.part(
			self,
			"AnomalousRing%d" % i,
			ring,
			Vector3(13, 8, -74 - i * 10),
			violet if i % 2 else pink
		)
		node.rotation = Vector3(PI * 0.5 + i * 0.3, i * 0.5, i * 0.4)
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.8, 3, 0.8)
	Meshes.instances(
		self,
		"GeometricShards",
		crystal,
		violet,
		_field(instance_budget / 2, 35, 110, 52, 0.5, 1.6),
		visible_fraction
	)
	for i in range(3):
		var node := Meshes.part(
			self,
			"DistantMonolith%d" % i,
			crystal,
			[Vector3(-24, 12, -48), Vector3(38, -13, -94), Vector3(-43, -16, -125)][i],
			pink
		)
		node.scale = Vector3(3, 4.5 + i, 3)
		node.rotation = Vector3(0.15 + i * 0.3, 0.7, i * 0.6)
	_cloud(
		"PsionicHaze",
		Vector3(-8, 6, -110),
		Vector2(80, 38),
		Color("8f4d98"),
		cloud_opacity * 0.8,
		4.0
	)


func _clear_departure(at: Vector3, radius: float) -> Vector3:
	var player: Node3D = get_parent().get_node("PlayerShip")
	var start := player.global_position
	var finish := player.to_global(Vector3.RIGHT * 80.0)
	var world_at := to_global(at)
	var closest := Geometry3D.get_closest_point_to_segment(world_at, start, finish)
	if world_at.distance_to(closest) < radius + 4.0:
		at.y = (radius + 6.0) * (-1.0 if at.y < 0 else 1.0)
	return at
