extends Node3D
## Read-only presentation of committed strategic positions and network state.

const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const ALLIED := Color("65dee9")
const HOSTILE := Color("ff817c")
const CONTESTED := Color("ffdc85")
const NEUTRAL := Color("c6d2e0")
const Aftermath = preload("res://scripts/ui/warzone_victory_banner.gd")
const BattleFX = preload("res://scripts/presentation/star_system/warzone_battle_fx.gd")

var paths := ImmediateMesh.new()
var allies: Dictionary = {}
var models: Dictionary = {}
var formations: Dictionary = {}
var motion: Dictionary = {}
var last_motion_tick := -1
var lattice_operation: RefCounted
var _last_rendered_clock := -1.0
var _replay_time := -1.0
var _replay_speed := 0.0
var _replay_start := 0.0
var _replay_positions: Dictionary = {}
var overlay_enabled := false
var influence: ShaderMaterial
var aftermath_started := false
var aftermath_elapsed := 0.0
var aftermath_routes := {}
var influence_target := PackedVector4Array()
var influence_display := PackedVector4Array()
var routes_signature := 0
var convoy_model: Node3D
var convoy_target := Vector3.ZERO
var displayed: Dictionary = {}
var cosmetic_contacts: Array[Vector2i] = []
var fx: Node3D
var last_volley := 0
var idle_countdown := 0.0
var beam_range := 4.0
var escort_mesh := PrismMesh.new()
var escort_materials: Dictionary


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
	escort_mesh.size = Vector3(0.28, 0.63, 0.32)
	escort_materials = {"allied": BattleFX._material(ALLIED), "hostile": BattleFX._material(HOSTILE)}
	fx = BattleFX.new()
	add_child(fx)


func refresh(operation: RefCounted, objects: Dictionary) -> void:
	beam_range = maxf(4.0, operation.tuning.engagement_radius * 1.35)
	if operation.is_lattice():
		lattice_operation = operation
		_refresh_lattice(operation)
	else:
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
	cosmetic_contacts.clear()
	for fleet in operation.fleets:
		_refresh_fleet(fleet, operation, objects)
		if not operation.complete and operation.active(fleet) and fleet.engaged >= 0:
			cosmetic_contacts.append(Vector2i(fleet.id, fleet.engaged))
	if lattice_operation == null:
		if last_motion_tick >= 0:
			for sample in operation.motion_samples:
				if sample.tick <= last_motion_tick: continue
				for fleet in operation.fleets:
					if operation.active(fleet):
						_queue_position(fleet.id, sample.positions[fleet.id])
		for fleet in operation.fleets:
			if operation.active(fleet): _queue_position(fleet.id, fleet.position)
		last_motion_tick = operation.clock_ms - posmod(operation.clock_ms, operation.STEP_MS)
	if operation.volley_tick > last_volley:
		last_volley = operation.volley_tick
		_fire(operation.volley)
		idle_countdown = 1.8


func _refresh_fleet(fleet: Dictionary, operation: RefCounted, objects: Dictionary) -> void:
	var id: int = fleet.id
	var target: Vector3 = operation.objectives[fleet.destination].position
	var foe: Dictionary = operation.fleet_at(fleet.engaged)
	if not foe.is_empty(): target = foe.position
	var facing: Vector3 = target - fleet.position
	var prior: Dictionary = displayed.get(id, {})
	var heading: float = atan2(-facing.z, facing.x) if facing.length_squared() > 0.001 else prior.get("heading", 0.0)
	var model: Node3D = models.get(id)
	var next: Vector3 = fleet.position
	if model == null:
		model = _create_fleet(fleet, operation, objects)
		model.position = next
		model.rotation.y = heading
	var previous_strength: int = prior.get("strength", fleet.strength)
	if previous_strength == 0 and fleet.strength > 0:
		model.position = next
	if fleet.strength < previous_strength:
		fx.impact(model.position, fleet.strength == 0)
	if not aftermath_started: model.visible = operation.active(fleet)
	var escorts: Array = formations[id]
	escorts[0].visible = fleet.strength >= 3
	escorts[1].visible = fleet.strength >= 5
	if allies.has(id):
		allies[id].visible = not operation.is_lattice()
		allies[id].text = "ALLIED · %s%s" % [fleet.role, " · ENGAGED" if fleet.engaged >= 0 else ""]
	displayed[id] = {"position": next, "strength": fleet.strength, "heading": heading}


func _queue_position(id: int, next: Vector3) -> void:
	var pending: Array = motion.get(id, [])
	var previous: Vector3 = pending.back() if not pending.is_empty() else models[id].position
	if previous.is_equal_approx(next): return
	pending.append(next)
	motion[id] = pending


func animate_movement(delta: float) -> void:
	if aftermath_started:
		_animate_aftermath(delta)
	elif lattice_operation != null:
		_interpolate_lattice(delta)
	else:
		_play_committed_routes(delta)
	if is_instance_valid(convoy_model) and convoy_model.visible:
		convoy_model.position = convoy_model.position.move_toward(convoy_target, delta * 2.8)
	if influence != null and influence_display != influence_target:
		for index in influence_display.size():
			var gap := influence_display[index].distance_to(influence_target[index])
			influence_display[index] = influence_display[index].lerp(influence_target[index], minf(1.0, delta * 1.6 / maxf(0.001, gap)))
		influence.set_shader_parameter("sources", influence_display)


func begin_aftermath(operation: RefCounted, grade: String, bounds: Rect2) -> void:
	if aftermath_started: return
	aftermath_started = true
	cosmetic_contacts.clear()
	paths.clear_surfaces()
	if is_instance_valid(convoy_model): convoy_model.hide()
	var command: Vector3 = operation.objectives[operation.final_command if operation.final_command >= 0 else operation.ALLIED_ROOT].position
	var center := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
	var costly := grade == "Pyrrhic Victory"
	for fleet in operation.fleets:
		if not operation.active(fleet): continue
		var model: Node3D = models[fleet.id]
		var start := model.position
		var hostile: bool = fleet.side == "hostile"
		var target: Vector3
		if hostile:
			# Withdraw away from the secured command toward the first sector edge.
			var heading := (start - command).normalized()
			if heading.length_squared() < 0.001: heading = Vector3.RIGHT
			var x_edge := bounds.end.x if heading.x > 0.0 else bounds.position.x
			var z_edge := bounds.end.y if heading.z > 0.0 else bounds.position.y
			var x_distance := (x_edge - start.x) / heading.x if absf(heading.x) > 0.01 else INF
			var z_distance := (z_edge - start.z) / heading.z if absf(heading.z) > 0.01 else INF
			target = start + heading * (maxf(0.0, minf(x_distance, z_distance)) + 5.0)
			if not bounds.has_point(Vector2(start.x, start.z)):
				target = start + (start - center).normalized() * 5.0
		else:
			var slot := Vector3(cos(fleet.id * 2.4), 0, sin(fleet.id * 2.4)) * 1.65
			target = start.move_toward(command + slot, 3.5 if costly else 6.5)
		aftermath_routes[fleet.id] = {"start": start, "target": target, "hostile": hostile}
	_stabilize_influence(costly)


func _stabilize_influence(costly: bool) -> void:
	for index in influence_target.size():
		var source := influence_target[index]
		source.w *= 0.44 if costly else 0.16
		if source.z > 0.0: source.z *= 1.04 if costly else 1.22
		influence_target[index] = source


func _animate_aftermath(delta: float) -> void:
	if aftermath_elapsed >= Aftermath.DURATION: return
	aftermath_elapsed = minf(Aftermath.DURATION, aftermath_elapsed + delta)
	var fraction := aftermath_elapsed / Aftermath.DURATION
	for id in aftermath_routes:
		var route: Dictionary = aftermath_routes[id]
		var model: Node3D = models[id]
		var direction: Vector3 = route.target - route.start
		var weight := pow(fraction, 1.6) if route.hostile else smoothstep(0.0, 1.0, fraction)
		model.position = route.start + direction * weight
		if direction.length_squared() > 0.001:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.z, direction.x), 1.0 - exp(-4.0 * delta))
		if fraction >= 1.0 and route.hostile: model.hide()


func finish_aftermath() -> void:
	_animate_aftermath(Aftermath.DURATION)
	influence_display = influence_target.duplicate()
	if influence != null: influence.set_shader_parameter("sources", influence_display)


func _interpolate_lattice(delta: float) -> void:
	var samples: Array = lattice_operation.motion_samples
	if samples.size() < 2:
		return
	var clock: float = lattice_operation.clock_ms + lattice_operation.travel_ms_remainder
	var step: int = lattice_operation.motion_step_ms()
	var draw_time := clock if lattice_operation.complete else clock - step
	# Buyable waits and operations advance the ledger immediately. Briefly
	# replay their sampled route; ordinary motion is one interpolation step behind.
	if _last_rendered_clock >= 0.0 and clock - _last_rendered_clock > 500.0 and _replay_time < 0.0:
		_replay_start = _last_rendered_clock - step
		_replay_time = _replay_start
		_replay_speed = maxf(4000.0, (draw_time - _replay_start) / 0.65)
		for id in models:
			_replay_positions[id] = models[id].position
	_last_rendered_clock = clock
	if _replay_time >= 0.0:
		_replay_time += delta * _replay_speed
		if _replay_time >= draw_time:
			_replay_time = -1.0
			_replay_positions.clear()
		else:
			draw_time = _replay_time
	var index := clampi(floori((draw_time - samples[0].tick) / step), 0, samples.size() - 2)
	var before: Dictionary = samples[index]
	var after: Dictionary = samples[index + 1]
	var bridging: bool = _replay_time >= 0.0 and draw_time < before.tick
	var alpha := clampf((draw_time - before.tick) / step, 0.0, 1.0)
	if bridging:
		alpha = clampf((draw_time - _replay_start) / maxf(1.0, before.tick - _replay_start), 0.0, 1.0)

	for id in models:
		var model: Node3D = models[id]
		if not model.visible: continue
		var first: Vector3 = _replay_positions.get(id, model.position) if bridging else before.positions[id]
		var last: Vector3 = before.positions[id] if bridging else after.positions[id]
		var direction := last - first
		model.position = first.lerp(last, alpha)
		var fleet: Dictionary = lattice_operation.fleet_at(id)
		var contact: Dictionary = lattice_operation.fleet_at(fleet.engaged)
		if not contact.is_empty():
			direction = (contact.position as Vector3) - model.position
		if direction.length_squared() > 0.00001:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.z, direction.x), 1.0 - exp(-8.0 * delta))


func _play_committed_routes(delta: float) -> void:
	for id in models:
		var model: Node3D = models[id]
		var pending: Array = motion.get(id, [])
		# Consume a bounded backlog at a higher constant speed. Refreshes append
		# committed waypoints without restarting or cutting the current segment.
		var budget := delta * maxf(2.8, pending.size() * 0.72)
		while budget > 0.0 and not pending.is_empty() and model.visible:
			var target: Vector3 = pending.front()
			var distance := model.position.distance_to(target)
			if distance > 0.001:
				var facing := target - model.position
				model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing.z, facing.x), minf(1.0, delta * 8.0))
			model.position = model.position.move_toward(target, budget)
			budget -= distance
			if model.position.distance_squared_to(target) <= 0.000001:
				model.position = target
				pending.pop_front()
		if not model.visible: pending.clear()
		if pending.is_empty() and displayed.has(id):
			model.rotation.y = lerp_angle(model.rotation.y, displayed[id].heading, minf(1.0, delta * 8.0))


func _refresh_lattice(operation: RefCounted) -> void:
	if aftermath_started: return
	_refresh_convoy(operation)
	if influence == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(140, 140)
		var field := MeshInstance3D.new()
		field.name = "TerritorialInfluence"
		field.mesh = plane
		field.position.y = -0.8
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		influence = ShaderMaterial.new()
		influence.shader = preload("res://shaders/warzone_influence.gdshader")
		influence.render_priority = -40
		influence.set_shader_parameter("source_count", operation.objectives.size())
		field.material_override = influence
		add_child(field)
		influence_display.resize(12)
	var strengths := {}
	for fleet in operation.fleets:
		if operation.active(fleet):
			var key: Vector2i = Vector2i(fleet.at, int(fleet.side == "hostile"))
			strengths[key] = minf(0.45, strengths.get(key, 0.0) + fleet.strength * 0.035)
	var sources := PackedVector4Array()
	sources.resize(12)
	for index in operation.objectives.size():
		var node: Dictionary = operation.objectives[index]
		var weight := 1.0 if operation.is_supplied(index) else 0.40
		if node.contested: weight *= 0.62
		sources[index] = Vector4(node.position.x, node.position.z,
			(weight if node.owner == "allied" else 0.0) + strengths.get(Vector2i(index, 0), 0.0),
			(weight if node.owner == "hostile" else 0.0) + strengths.get(Vector2i(index, 1), 0.0))
		if influence_display[index] == Vector4.ZERO:
			influence_display[index] = sources[index]
	if sources != influence_target:
		influence_target = sources
		influence.set_shader_parameter("sources", influence_display)
	var signature := hash([operation.links, operation.disrupted.keys(),
		operation.objectives.map(func(node): return [node.owner, node.contested]),
		overlay_enabled, operation.fleets.map(func(fleet): return [fleet.at, fleet.destination, fleet.engaged, operation.active(fleet)])])
	if signature == routes_signature: return
	routes_signature = signature
	paths.clear_surfaces()
	paths.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in operation.links:
		var first: Dictionary = operation.objectives[edge.x]
		var second: Dictionary = operation.objectives[edge.y]
		var live: bool = operation.link_active(edge)
		var tint := CONTESTED if first.owner != second.owner else objective_color(first)
		var alpha := 0.78 if overlay_enabled else 0.26
		if not live:
			_line(first.position, first.position.lerp(second.position, 0.32), Color(NEUTRAL, alpha * 0.65))
			_line(second.position, second.position.lerp(first.position, 0.32), Color(NEUTRAL, alpha * 0.65))
		else:
			_line(first.position, second.position, Color(tint, alpha))
	for fleet in operation.fleets:
		if not operation.active(fleet) or fleet.engaged >= 0 or fleet.at == fleet.destination:
			continue
		var start: Vector3 = operation.objectives[fleet.at].position + Vector3.UP * 0.15
		var finish: Vector3 = operation.objectives[fleet.destination].position + Vector3.UP * 0.15
		var tint := Color(ALLIED if fleet.side == "allied" else HOSTILE, 0.86 if overlay_enabled else 0.52)
		if overlay_enabled: _line(start, finish, tint)
		var arrow := start.lerp(finish, 0.68)
		var heading := (finish - start).normalized()
		var side := heading.cross(Vector3.UP)
		var base := arrow - heading * 0.53
		_line(base + side * 0.23, arrow, tint)
		_line(base - side * 0.23, arrow, tint)
	paths.surface_end()


func _refresh_convoy(operation: RefCounted) -> void:
	if operation.convoy.is_empty():
		if is_instance_valid(convoy_model): convoy_model.hide()
		return
	convoy_target = operation.convoy_position()
	if not is_instance_valid(convoy_model):
		convoy_model = Node3D.new()
		convoy_model.name = "SupplyConvoy"
		add_child(convoy_model)
		_escort(convoy_model, Vector3.ZERO, ALLIED, 0.85)
		var badge := Label3D.new()
		badge.name = "Badge"
		badge.position.y = 0.50
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.font_size = 30
		badge.pixel_size = 0.017
		convoy_model.add_child(badge)
		convoy_model.hide()
	if not convoy_model.visible: convoy_model.position = convoy_target
	var side: String = operation.convoy.side
	var badge: Label3D = convoy_model.get_node("Badge")
	badge.text = "◇"
	badge.modulate = ALLIED if side == "allied" else HOSTILE
	convoy_model.get_child(0).material_override = escort_materials[side]
	convoy_model.show()


func _line(from: Vector3, to: Vector3, tint: Color) -> void:
	for point in [from, to]:
		paths.surface_set_color(tint)
		paths.surface_add_vertex(point - Vector3.UP * 0.12)


func _create_fleet(fleet: Dictionary, operation: RefCounted, objects: Dictionary) -> Node3D:
	var id: int = fleet.id
	var model: Node3D
	if fleet.side == "allied":
		model = Node3D.new()
		model.name = "AlliedGroup%d" % id
		add_child(model)
		_escort(model, Vector3.ZERO, ALLIED, 1.1)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.019
		label.font_size = 34
		label.outline_size = 9
		label.modulate = ALLIED
		label.position.y = 0.55
		model.add_child(label)
		allies[id] = label
	else:
		model = objects[operation.encounter_for_fleet(fleet)]
	var frame := Node3D.new()
	model.add_child(frame)
	frame.scale = Vector3.ONE / maxf(0.001, model.scale.x)
	var tint := ALLIED if fleet.side == "allied" else HOSTILE
	formations[id] = [_escort(frame, Vector3(-0.45, 0, 0.44), tint, 0.72),
		_escort(frame, Vector3(-0.46, 0, -0.44), tint, 0.72)]
	models[id] = model
	return model


func _escort(parent: Node3D, at: Vector3, tint: Color, amount: float) -> MeshInstance3D:
	var ship := MeshInstance3D.new()
	ship.mesh = escort_mesh
	ship.material_override = escort_materials.allied if tint == ALLIED else escort_materials.hostile
	ship.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship.position = at
	ship.rotation.z = -PI * 0.5
	ship.scale = Vector3.ONE * amount
	parent.add_child(ship)
	return ship


func animate_engagements(delta: float) -> void:
	if cosmetic_contacts.is_empty(): return
	idle_countdown -= delta
	if idle_countdown <= 0:
		# Idle views can show an ongoing exchange. Only committed volleys
		# change fleet strength or produce impacts.
		_fire(cosmetic_contacts)
		idle_countdown = 1.8


func _fire(contacts: Array[Vector2i]) -> void:
	for contact in contacts:
		var from: Vector3 = models[contact.x].position
		var to: Vector3 = models[contact.y].position
		# A bulk wait can commit a fight at a point the animated models
		# haven't reached yet. Avoid a beam across the intervening space.
		if from.distance_squared_to(to) <= beam_range * beam_range:
			fx.beam(from, to, "allied" if allies.has(contact.x) else "hostile")


static func objective_status(objective: Dictionary) -> String:
	if objective.contested: return "Contested"
	return "%s controlled" % objective.owner.capitalize() if objective.owner != "neutral" else "Neutral"


static func objective_color(objective: Dictionary) -> Color:
	if objective.contested: return CONTESTED
	match objective.owner:
		"allied": return ALLIED
		"hostile": return HOSTILE
	return NEUTRAL
