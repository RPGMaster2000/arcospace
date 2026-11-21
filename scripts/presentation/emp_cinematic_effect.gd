extends Node3D
## Battle-local power and pose overrides. Battle rules and the result remain with Board.

const Sound = preload("res://scripts/audio/sfx.gd")
const ARC_COUNT := 8
const SEGMENTS := 5

var _rng := RandomNumberGenerator.new()
var _mesh := ImmediateMesh.new()
var _arc_material := StandardMaterial3D.new()
var _wave_material := ShaderMaterial.new()
var _arcs: MeshInstance3D
var _wave: MeshInstance3D
var _center: Vector3
var _radius: float
var _enemy: Node3D
var _enemy_pose: Transform3D
var _pivot: Vector3
var _axis: Vector3
var _enemy_process: bool
var _visible: Dictionary = {}
var _materials: Array[Dictionary] = []
var _arc_sample := -1
var _hit_at: float
var _max_radius: float
var _disabled := false


func setup(origin: Vector3, radius: float, victim: Node3D, enemy_center: Vector3, enemy_radius: float, seed_value: int) -> void:
	_center = origin
	_radius = radius
	_enemy = victim
	_pivot = enemy_center
	var distance := origin.distance_to(enemy_center)
	_max_radius = maxf(radius * 2.0, distance + enemy_radius * 0.9)
	_hit_at = maxf(radius, distance - enemy_radius * 0.65)
	_rng.seed = hash([seed_value, "emp-visual"])
	_axis = Vector3(_rng.randf_range(0.30, 1.0), _rng.randf_range(-0.8, 0.8), _rng.randf_range(0.30, 1.0)).normalized()
	if _rng.randf() < 0.5: _axis = -_axis
	_arcs = MeshInstance3D.new()
	_arcs.mesh = _mesh
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arc_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_material.vertex_color_use_as_albedo = true
	_arcs.material_override = _arc_material
	add_child(_arcs)
	_arcs.global_position = origin
	_wave = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_wave.mesh = sphere
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave_material.shader = preload("res://shaders/emp_wave.gdshader")
	_wave.material_override = _wave_material
	add_child(_wave)
	_wave.global_position = origin
	_wave.scale = Vector3.ONE * (_radius * 0.60)
	_wave_material.set_shader_parameter("intensity", 0.10)
	Sound.play(&"emp_charge", self)


func charge(progress: float, camera: Camera3D) -> void:
	# A few short, faceted arcs radiate from different points on the hull.
	# Rebuild one small mesh at 16 Hz, with a soft sheath and a bright core.
	var sample := floori(progress * 24.0)
	_wave_material.set_shader_parameter("intensity", lerpf(0.10, 0.28, progress))
	if _arc_sample == sample: return
	_arc_sample = sample
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in roundi(lerpf(3.0, ARC_COUNT, progress)):
		var direction := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.7, 0.7), _rng.randf_range(-1.0, 1.0)).normalized()
		var sideways := direction.cross(Vector3.UP).normalized()
		var point := direction * _radius * _rng.randf_range(0.20, 0.52)
		var reach := _radius * lerpf(0.5, 1.7, progress) * _rng.randf_range(0.65, 1.15)
		for segment in SEGMENTS:
			var fraction := float(segment + 1) / SEGMENTS
			var next := direction * (_radius * 0.35 + reach * fraction) + sideways * _rng.randf_range(-0.20, 0.20) * _radius
			var width := maxf(0.009, _radius * 0.016) * lerpf(0.65, 1.3, progress) * (1.0 - fraction * 0.45)
			var ribbon := (next - point).cross(camera.global_position - _center).normalized()
			_strip(point, next, ribbon * width * 2.5, Color(0.11, 0.50, 1.0, lerpf(0.2, 0.5, progress)))
			_strip(point, next, ribbon * width, Color(0.70, 0.91, 1.0, lerpf(0.4, 0.95, progress)))
			point = next
	_mesh.surface_end()


func _strip(first: Vector3, last: Vector3, width: Vector3, tint: Color) -> void:
	for point in [first - width, first + width, last + width, first - width, last + width, last - width]:
		_mesh.surface_set_color(tint)
		_mesh.surface_add_vertex(point)


func discharge() -> void:
	_arcs.hide()
	_wave.show()
	_wave.scale = Vector3.ONE * _radius
	_wave_material.set_shader_parameter("intensity", 1.0)
	Sound.play(&"emp_fire", self)


func expand(progress: float) -> void:
	var size := lerpf(_radius, _max_radius, progress)
	_wave.scale = Vector3.ONE * size
	_wave_material.set_shader_parameter("intensity", clampf(1.0 - smoothstep(0.84, 1.0, progress), 0.0, 1.0))
	if not _disabled and size >= _hit_at: _disable_enemy()


func _disable_enemy() -> void:
	_disabled = true
	_enemy_pose = _enemy.global_transform
	_enemy_process = _enemy.is_processing()
	_enemy.set_process(false)
	for node in _enemy.find_children("*", "", true, false):
		if node is Light3D or node is GPUParticles3D or node is CPUParticles3D or node == _enemy.get_node_or_null("Shield"):
			_visible[node] = node.visible
			node.hide()
		if not node is MeshInstance3D or node.mesh == null: continue
		if node.material_override != null:
			_dim(node, -1, node.material_override)
		else:
			for surface in node.mesh.get_surface_count():
				_dim(node, surface, node.get_active_material(surface))


func _dim(part: MeshInstance3D, surface: int, source: Material) -> void:
	if not source is StandardMaterial3D or not source.emission_enabled: return
	var prior := part.material_override if surface < 0 else part.get_surface_override_material(surface)
	_materials.append({"part": part, "surface": surface, "material": prior})
	var dark := source.duplicate() as StandardMaterial3D
	dark.emission_enabled = false
	dark.albedo_color = dark.albedo_color.darkened(0.52)
	if surface < 0: part.material_override = dark
	else: part.set_surface_override_material(surface, dark)


func drift(progress: float) -> void:
	_wave.hide()
	if not _disabled: _disable_enemy()
	var turn := Basis(_axis, deg_to_rad(39.0) * progress)
	_enemy.global_transform = Transform3D(turn * _enemy_pose.basis, _pivot + turn * (_enemy_pose.origin - _pivot))


func restore_power() -> void:
	if not _disabled or not is_instance_valid(_enemy): return
	_enemy.global_transform = _enemy_pose
	_enemy.set_process(_enemy_process)
	for node in _visible:
		if is_instance_valid(node): node.visible = _visible[node]
	for record in _materials:
		if not is_instance_valid(record.part): continue
		if record.surface < 0: record.part.material_override = record.material
		else: record.part.set_surface_override_material(record.surface, record.material)
	_disabled = false
