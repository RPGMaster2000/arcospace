extends Node3D
# Presentation-only adapter: snapshots and actual rendered displacement, no rules.
var map: Control
var home_label: Label3D
var displayed_integrity: int = -1
var hit_remaining: float = 0.0
var histories: Dictionary = {}
var ribbons: Dictionary = {}
var plumes: Dictionary = {}
var ages: Dictionary = {}
const LIMIT = 96
const SPACING = 0.16

static func point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
static func layout(data: Dictionary, snapshot: Dictionary) -> void:
	# The gameplay layout supplies every navigable anchor. Cosmetic RNG only
	# controls the planet surface, star and atmosphere; it cannot move the base.
	data.assignments.clear()
	data.anchors.clear()
	data.placement.clear()
	for key in snapshot.anchors:
		var index: int = int(key)
		data.anchors[index] = point(snapshot.anchors[key])
		data.placement[index] = {"radius": 1.2}
	for unit in snapshot.units:
		var index: int = int(unit.encounter)
		data.anchors[index] = point(unit.position)
		data.placement[index] = {"radius": 1.2}
	var home: Dictionary = data.planets.back().duplicate(true)
	home.index = 0
	home.name = "HOMEWORLD"
	home.type = "terrestrial"
	home.radius = 1.8
	home.distance = 20.0
	home.position = point(snapshot.home)
	home.encounter = -1
	home.eccentricity = 0.0
	home.inclination = 0.0
	home.orientation = 0.0
	home.phase = atan2(home.position.z, home.position.x)
	data.planets = [home]

func configure(source: Control) -> void:
	map = source
	home_label = map.planet_nodes[0].get_node("OverviewName")
	var identities: Array = [-999]
	for unit in map.defense_view.units: identities.append(int(unit.encounter))
	for index in identities:
		var tint := Color("58dcff") if index == -999 else Color("ff7943")
		var ribbon := MeshInstance3D.new()
		ribbon.mesh = ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ribbon.material_override = material
		add_child(ribbon)
		ribbons[index] = ribbon
		histories[index] = []
		ages[index] = 0.0
		var plume := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.12
		shape.height = 0.6
		shape.radial_segments = 8
		shape.rings = 4
		plume.mesh = shape
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = tint
		glow.emission_enabled = true
		glow.emission = tint
		glow.emission_energy_multiplier = 2.0
		plume.material_override = glow
		plume.visible = false
		add_child(plume)
		plumes[index] = plume

func refresh(snapshot: Dictionary) -> void:
	if is_instance_valid(home_label):
		if displayed_integrity >= 0 and snapshot.integrity < displayed_integrity:
			hit_remaining = 1.5
			home_label.text = "HOMEWORLD HIT −%d" % (displayed_integrity - snapshot.integrity)
			home_label.modulate = Color("ff765e")
		displayed_integrity = snapshot.integrity
		if hit_remaining <= 0: home_label.text = "HOMEWORLD · %d integrity" % displayed_integrity
	for unit in snapshot.units:
		var index: int = int(unit.encounter)
		if not map.objects.has(index): continue
		if unit.status in ["neutralized", "arrived", "secured"]:
			_release(index)
			continue
		if unit.status == "reserve": continue
		_sample(index, map.objects[index].position, map.objects[index].visible)
		if not unit.mothership and map.objects[index].visible:
			var direction: Vector3 = point(snapshot.home) - map.objects[index].position
			if direction.length_squared() > 0.001:
				var model: Node3D = map.objects[index]
				var original_scale: Vector3 = model.scale
				model.basis = map._facing_basis(direction) * Basis.from_scale(original_scale)

func _process(delta: float) -> void:
	if not is_instance_valid(map) or not is_instance_valid(map.ship): return
	var planning: bool = map.visible and map.is_processing() and map.interactive and not map.focused and map.input_allowed.is_valid() and map.input_allowed.call()
	var eligible: bool = planning and map.traveling
	if planning:
		if hit_remaining > 0:
			hit_remaining = maxf(0.0, hit_remaining - delta)
			if hit_remaining == 0:
				home_label.text = "HOMEWORLD · %d integrity" % displayed_integrity
				home_label.modulate = Color(0.65, 0.78, 0.9, 0.8)
		for index in ages:
			ages[index] += delta
			ribbons[index].material_override.albedo_color.a = clampf((30.0 - ages[index]) / 8.0, 0, 1)
	if eligible: _sample(-999, map.ship.position, true)
	else:
		for plume in plumes.values(): plume.visible = false

func _sample(index: int, at: Vector3, active: bool) -> void:
	var history: Array = histories[index]
	if history.is_empty():
		history.append(at)
		return
	var previous: Vector3 = history.back()
	var moved: bool = active and previous.distance_to(at) >= SPACING
	plumes[index].visible = moved
	if not moved: return
	ages[index] = 0.0
	ribbons[index].material_override.albedo_color.a = 1.0
	var direction: Vector3 = (at - previous).normalized()
	plumes[index].position = at - direction * 0.7
	plumes[index].quaternion = Quaternion(Vector3.UP, direction)
	history.append(at)
	if history.size() > LIMIT: history.pop_front()
	var mesh: ImmediateMesh = ribbons[index].mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var tint := Color("58dcff") if index == -999 else Color("ff7943")
	for i in history.size():
		var alpha: float = float(i + 1) / history.size()
		mesh.surface_set_color(Color(tint, alpha * 0.65))
		mesh.surface_add_vertex(history[i] + Vector3(0, 0.045, 0.07 * alpha))
		mesh.surface_add_vertex(history[i] + Vector3(0, 0.045, -0.07 * alpha))
	mesh.surface_end()

# Recycle terminal units immediately; no hidden exhaust or trail geometry remains.
func _release(index: int) -> void:
	if ribbons.has(index):
		ribbons[index].queue_free()
		ribbons.erase(index)
	if plumes.has(index):
		plumes[index].queue_free()
		plumes.erase(index)
	histories.erase(index)
	ages.erase(index)
