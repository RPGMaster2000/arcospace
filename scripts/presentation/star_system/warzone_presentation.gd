extends Node3D
## Read-only presentation of committed strategic positions and network state.

const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const ALLIED := Color("65dee9")
const HOSTILE := Color("ff817c")
const CONTESTED := Color("ffdc85")
const NEUTRAL := Color("c6d2e0")
const Aftermath = preload("res://scripts/ui/warzone_victory_banner.gd")
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const ALLIED_SHIPS := [
	preload("res://ships/player/endeavour.tres"),
	preload("res://ships/player/thunderbolt.tres"),
	preload("res://ships/player/callisto.tres"),
]
const BattleFX = preload("res://scripts/presentation/star_system/warzone_battle_fx.gd")

const CONNECTION_WIDTH := 0.27
const ORDER_WIDTH := 0.115
var paths := ImmediateMesh.new()
var order_paths := ImmediateMesh.new()
var _order_endpoints := PackedVector3Array()
var _order_colors := PackedColorArray()
var _last_scramble := -1
var _legacy_material: Material
var _connection_mesh: MeshInstance3D
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
var influence_field: MeshInstance3D
var aftermath_started := false
var aftermath_elapsed := 0.0
var aftermath_routes := {}
var influence_target := PackedVector4Array()
var influence_display := PackedVector4Array()
var routes_signature := 0
var bottlenecks: Array[int] = []
var convoy_model: Node3D
var convoy_target := Vector3.ZERO
var displayed: Dictionary = {}
var cosmetic_contacts: Array[Vector2i] = []
var fx: Node3D
var last_volley := 0
var idle_countdown := 0.0
var beam_range := 4.0
var convoy_ships := {}


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
	var connections := ShaderMaterial.new()
	connections.shader = preload("res://shaders/warzone_routes.gdshader")
	lines.material_override = connections
	_legacy_material = material
	_connection_mesh = lines
	var orders := MeshInstance3D.new()
	orders.mesh = order_paths
	orders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moving := connections.duplicate() as ShaderMaterial
	moving.set_shader_parameter("moving", true)
	moving.render_priority = 1
	orders.material_override = moving
	add_child(orders)
	fx = BattleFX.new()
	add_child(fx)


func refresh(operation: RefCounted, objects: Dictionary) -> void:
	beam_range = maxf(4.0, operation.tuning.engagement_radius * 1.35)
	if operation.is_lattice():
		lattice_operation = operation
	else:
		_connection_mesh.material_override = _legacy_material
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
	if operation.is_lattice():
		_refresh_lattice(operation)
		if _last_scramble >= 0 and operation.scramble_until > _last_scramble:
			fx.transmission(operation.objectives[operation.scramble_site].position)
		_last_scramble = operation.scramble_until
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
	var target: Vector3 = operation.fleet_target_position(fleet) if operation.is_lattice() \
		else operation.objectives[fleet.destination].position
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
	displayed[id] = {"position": next, "strength": fleet.strength, "heading": heading, "target": target}


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
	if overlay_enabled and lattice_operation != null and not aftermath_started:
		_update_orders()
	if is_instance_valid(convoy_model) and convoy_model.visible:
		convoy_model.position = convoy_model.position.move_toward(convoy_target, delta * 2.8)
	if overlay_enabled and influence != null and influence_display != influence_target:
		for index in influence_display.size():
			var gap := influence_display[index].distance_to(influence_target[index])
			influence_display[index] = influence_display[index].lerp(influence_target[index], minf(1.0, delta * 1.6 / maxf(0.001, gap)))
		influence.set_shader_parameter("sources", influence_display)


func begin_aftermath(operation: RefCounted, grade: String, bounds: Rect2) -> void:
	if aftermath_started: return
	aftermath_started = true
	order_paths.clear_surfaces()
	cosmetic_contacts.clear()
	paths.clear_surfaces()
	if is_instance_valid(convoy_model): convoy_model.hide()
	var command: Vector3 = operation.objectives[operation.final_command if operation.final_command >= 0 else operation.root("allied")].position
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
		if not model.visible or id >= before.positions.size() or id >= after.positions.size(): continue
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
	if is_instance_valid(influence_field): influence_field.visible = overlay_enabled
	if not overlay_enabled:
		paths.clear_surfaces()
		order_paths.clear_surfaces()
		_order_endpoints.clear()
		_order_colors.clear()
	if aftermath_started: return
	_refresh_convoy(operation)
	if influence == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(140, 140)
		influence_field = MeshInstance3D.new()
		influence_field.name = "TerritorialInfluence"
		influence_field.mesh = plane
		influence_field.position.y = -0.8
		influence_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		influence = ShaderMaterial.new()
		influence.shader = preload("res://shaders/warzone_influence.gdshader")
		influence.render_priority = -40
		influence.set_shader_parameter("source_count", operation.objectives.size())
		var total := 0.0
		for edge: Vector2i in operation.links:
			total += operation.objectives[edge.x].position.distance_to(operation.objectives[edge.y].position)
		influence.set_shader_parameter("reach", clampf(total / operation.links.size() * 1.22, 9.0, 16.0))
		bottlenecks = operation.Lattice.bottlenecks(operation.objectives, operation.links)
		influence_field.material_override = influence
		influence_field.visible = overlay_enabled
		add_child(influence_field)
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
		operation.objectives.map(func(node): return node.owner)])
	if not overlay_enabled:
		routes_signature = 0
		return
	if signature == routes_signature: return
	routes_signature = signature
	paths.clear_surfaces()
	paths.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in operation.links:
		var first: Dictionary = operation.objectives[edge.x]
		var second: Dictionary = operation.objectives[edge.y]
		var live: bool = operation.link_active(edge)
		var tint := CONTESTED if first.owner != second.owner else objective_color(first)
		var alpha := 0.78
		if not live:
			_ribbon(paths, CONNECTION_WIDTH, first.position, first.position.lerp(second.position, 0.32), Color(NEUTRAL, alpha * 0.65))
			_ribbon(paths, CONNECTION_WIDTH, second.position, second.position.lerp(first.position, 0.32), Color(NEUTRAL, alpha * 0.65))
		else:
			_ribbon(paths, CONNECTION_WIDTH, first.position, second.position, Color(tint, alpha))
	paths.surface_end()


func _update_orders() -> void:
	var endpoints := PackedVector3Array()
	var colors := PackedColorArray()
	if not lattice_operation.complete:
		for fleet in lattice_operation.fleets:
			if not lattice_operation.active(fleet) or fleet.engaged >= 0: continue
			if fleet.get("arriving", false) and lattice_operation.supplied[fleet.side].size() < 2: continue
			var finish: Vector3 = displayed[fleet.id].target if fleet.has("intercept") \
				else lattice_operation.objectives[fleet.destination].position
			var position: Vector3 = fleet.position
			if position.distance_squared_to(finish) < 0.0025: continue
			endpoints.append(models[fleet.id].position)
			endpoints.append(finish)
			colors.append(Color("4da7d6") if fleet.side == "allied" else Color("cf5365"))
	if endpoints == _order_endpoints and colors == _order_colors: return
	_order_endpoints = endpoints
	_order_colors = colors
	order_paths.clear_surfaces()
	if endpoints.is_empty(): return
	order_paths.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in colors.size():
		_ribbon(order_paths, ORDER_WIDTH, endpoints[i * 2], endpoints[i * 2 + 1], colors[i])
	order_paths.surface_end()


func _ribbon(mesh: ImmediateMesh, width: float, start: Vector3, finish: Vector3, tint: Color) -> void:
	var edge := (finish - start).cross(Vector3.UP).normalized() * width * 0.5
	var length := start.distance_to(finish)
	var points := [start - edge, start + edge, finish + edge, finish - edge]
	var uvs := [Vector2.ZERO, Vector2(0, 1), Vector2(length, 1), Vector2(length, 0)]
	for index in [0, 1, 2, 0, 2, 3]:
		mesh.surface_set_color(tint)
		mesh.surface_set_uv(uvs[index])
		mesh.surface_add_vertex(points[index] - Vector3.UP * 0.12)


func _refresh_convoy(operation: RefCounted) -> void:
	if operation.convoy.is_empty():
		if is_instance_valid(convoy_model): convoy_model.hide()
		return
	convoy_target = operation.convoy_position()
	if not is_instance_valid(convoy_model):
		convoy_model = Node3D.new()
		convoy_model.name = "SupplyConvoy"
		add_child(convoy_model)
		var enemy_model: Node3D = models.get(Warzone.ALLIED_GROUPS)
		var enemy_profile: Resource = enemy_model.get_meta("ship_profile") if is_instance_valid(enemy_model) and enemy_model.has_meta("ship_profile") else ALLIED_SHIPS[2]
		convoy_ships["allied"] = _fleet_ship(convoy_model, ALLIED_SHIPS[2], Vector3.ZERO, 0.8)
		convoy_ships["hostile"] = _fleet_ship(convoy_model, enemy_profile, Vector3.ZERO, 0.8)
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
	for key in convoy_ships: convoy_ships[key].visible = side == key
	var direction: Vector3 = convoy_target - convoy_model.position
	if direction.length_squared() > 0.001:
		convoy_model.rotation.y = atan2(-direction.z, direction.x)
	convoy_model.show()


func _line(from: Vector3, to: Vector3, tint: Color) -> void:
	for point in [from, to]:
		paths.surface_set_color(tint)
		paths.surface_add_vertex(point - Vector3.UP * 0.12)


func _create_fleet(fleet: Dictionary, operation: RefCounted, objects: Dictionary) -> Node3D:
	var id: int = fleet.id
	var model: Node3D
	var profile: Resource
	if fleet.side == "allied":
		model = Node3D.new()
		model.name = "AlliedGroup%d" % id
		add_child(model)
		profile = ALLIED_SHIPS[id % ALLIED_SHIPS.size()]
		model.set_meta("ship_profile", profile)
		_fleet_ship(model, profile, Vector3.ZERO, 1.6)
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
		profile = model.get_meta("ship_profile", null)
	var frame := Node3D.new()
	model.add_child(frame)
	frame.scale = Vector3.ONE / maxf(0.001, model.scale.x)
	formations[id] = [_fleet_ship(frame, profile, Vector3(-0.64, 0, 0.64), 0.67),
		_fleet_ship(frame, profile, Vector3(-0.70, 0, -0.64), 0.67)]
	models[id] = model
	return model


func _fleet_ship(parent: Node3D, profile: Resource, at: Vector3, length: float) -> Node3D:
	var mount := Models.ship(profile, true)
	mount.position = at
	mount.scale = Vector3.ONE * (length / 4.0)
	parent.add_child(mount)
	return mount


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
