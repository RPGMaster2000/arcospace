extends Node3D
# Presentation-only adapter: snapshots and actual rendered displacement, no rules.
var map: Control
var home_panel: PanelContainer
var integrity_bar: ProgressBar
var integrity_text: Label
var home_label: Label3D
var displayed_integrity: int = -1
var hit_remaining: float = 0.0
var histories: Dictionary = {}
var ribbons: Dictionary = {}
var plumes: Dictionary = {}
var ages: Dictionary = {}
var cinematic_previous: Vector3
var cinematic_tracking: bool = false
const LIMIT = 96
const SPACING = 0.16

static func point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
static func layout(data: Dictionary, snapshot: Dictionary) -> void:
	# The gameplay layout supplies every navigable anchor. Cosmetic RNG only
	# controls the planet surface, star and atmosphere; it cannot move the base.
	var generated_planets: Array = data.planets.duplicate(true)
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
	home.distance = point(snapshot.home).length()
	home.position = point(snapshot.home)
	home.encounter = -1
	home.eccentricity = 0.0
	home.inclination = 0.0
	home.orientation = 0.0
	home.phase = atan2(home.position.z, home.position.x)
	data.planets = [home]
	# Keep procedural planet appearances while choosing clear cosmetic positions
	# around the already-authoritative fleet and PoIs.
	var obstacles: Array = [point(snapshot.home)]
	for anchor in snapshot.anchors.values(): obstacles.append(point(anchor))
	for unit in snapshot.units:
		if unit.status != "reserve": obstacles.append(point(unit.position))
	for original in generated_planets.slice(0, mini(3, generated_planets.size() - 1)):
		var planet: Dictionary = original.duplicate(true)
		planet.index = data.planets.size()
		planet.encounter = -1
		planet.radius = minf(float(planet.radius), 0.75)
		planet.eccentricity = 0.0
		planet.inclination = 0.0
		planet.orientation = 0.0
		var best: Vector3 = Vector3.ZERO
		var best_gap: float = -INF
		for distance in [5.0, 7.0, 9.0, 12.0]:
			for attempt in range(72):
				var phase: float = float(original.phase) + TAU * float(attempt) / 72.0
				var candidate: Vector3 = Vector3(cos(phase), 0, sin(phase)) * float(distance)
				var gap: float = INF
				for other in obstacles: gap = minf(gap, candidate.distance_to(other))
				if gap > best_gap:
					best_gap = gap
					best = candidate
		if best_gap >= 4.0:
			planet.position = best
			planet.distance = best.length()
			planet.phase = atan2(best.z, best.x)
			planet.name = data.name + " " + str(planet.index)
			data.planets.append(planet)
			obstacles.append(best)

func configure(source: Control) -> void:
	map = source
	home_label = map.planet_nodes[0].get_node("OverviewName")
	home_label.modulate.a = 0.0
	home_panel = PanelContainer.new()
	home_panel.name = "HomeworldIntegrity"
	home_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_panel.custom_minimum_size = Vector2(160, 38)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.01, 0.04, 0.08, 0.9)
	backing.set_corner_radius_all(5)
	backing.set_content_margin_all(3)
	home_panel.add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	home_panel.add_child(column)
	integrity_text = Label.new()
	integrity_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	integrity_text.add_theme_font_size_override("font_size", 14)
	integrity_text.add_theme_color_override("font_color", Color("ddfaff"))
	column.add_child(integrity_text)
	integrity_bar = ProgressBar.new()
	integrity_bar.custom_minimum_size = Vector2(150, 8)
	integrity_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("64d7ad")
	integrity_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(integrity_bar)
	map.add_child(home_panel)
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
	integrity_bar.max_value = float(snapshot.get("maximum_integrity", 100))
	integrity_bar.value = snapshot.integrity
	integrity_text.text = "HOMEWORLD  %d / %d" % [snapshot.integrity, integrity_bar.max_value]
	if displayed_integrity >= 0 and snapshot.integrity < displayed_integrity:
		hit_remaining = 1.5
		integrity_text.add_theme_color_override("font_color", Color("ff765e"))
	displayed_integrity = snapshot.integrity
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
	var home_position: Vector3 = map.planet_nodes[0].position
	home_panel.position = map.camera.unproject_position(home_position + Vector3.UP * 3.2) - Vector2(80, 45)
	home_panel.visible = map.visible and not map.focused and not map.introducing and not map.camera.is_position_behind(home_position)
	var planning: bool = map.visible and map.is_processing() and map.interactive and not map.focused and map.input_allowed.is_valid() and map.input_allowed.call()
	var eligible: bool = planning and map.traveling
	if planning:
		if hit_remaining > 0:
			hit_remaining = maxf(0.0, hit_remaining - delta)
			if hit_remaining == 0:
				integrity_text.add_theme_color_override("font_color", Color("ddfaff"))
		for index in ages:
			ages[index] += delta
			ribbons[index].material_override.albedo_color.a = clampf((30.0 - ages[index]) / 8.0, 0, 1)
	if eligible:
		cinematic_tracking = false
		_sample(-999, map.ship.position, true)
	elif map.visible and map.traveling and not map.interactive and map.camera.viewing == &"ftl":
		var direction: Vector3 = map.ship.position - cinematic_previous
		plumes[-999].visible = cinematic_tracking and direction.length_squared() > 0.000001
		if plumes[-999].visible:
			plumes[-999].position = map.ship.position - direction.normalized() * 0.7
			plumes[-999].quaternion = Quaternion(Vector3.UP, direction.normalized())
		cinematic_previous = map.ship.position
		cinematic_tracking = true
	else:
		cinematic_tracking = false
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

func _exit_tree() -> void:
	if is_instance_valid(home_panel): home_panel.queue_free()
