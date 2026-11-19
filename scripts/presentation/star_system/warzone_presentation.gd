extends Node3D
## Read-only presentation of committed strategic positions and network state.

const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const ALLIED := Color("65dee9")
const HOSTILE := Color("ff936d")
const CONTESTED := Color("ffdc85")
const NEUTRAL := Color("c6d2e0")
const BattleFX = preload("res://scripts/presentation/star_system/warzone_battle_fx.gd")

var paths := ImmediateMesh.new()
var allies: Dictionary = {}
var models: Dictionary = {}
var formations: Dictionary = {}
var motion: Dictionary = {}
var last_motion_tick := -1
var overlay_enabled := false
var influence: ShaderMaterial
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
		if operation.active(fleet) and fleet.engaged >= 0:
			cosmetic_contacts.append(Vector2i(fleet.id, fleet.engaged))
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
		model = _create_fleet(fleet, objects)
		model.position = next
		model.rotation.y = heading
	var previous_strength: int = prior.get("strength", fleet.strength)
	if fleet.strength < previous_strength:
		fx.impact(model.position, fleet.strength == 0)
	model.visible = operation.active(fleet)
	var escorts: Array = formations[id]
	escorts[0].visible = fleet.strength >= 3
	escorts[1].visible = fleet.strength >= 5
	if allies.has(id):
		allies[id].text = "ALLIED · %s%s" % [fleet.role, " · ENGAGED" if fleet.engaged >= 0 else ""]
	displayed[id] = {"position": next, "strength": fleet.strength, "heading": heading}


func _queue_position(id: int, next: Vector3) -> void:
	var pending: Array = motion.get(id, [])
	var previous: Vector3 = pending.back() if not pending.is_empty() else models[id].position
	if previous.is_equal_approx(next): return
	pending.append(next)
	motion[id] = pending


func animate_movement(delta: float) -> void:
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
	if is_instance_valid(convoy_model) and convoy_model.visible:
		convoy_model.position = convoy_model.position.move_toward(convoy_target, delta * 2.8)
	if influence != null and influence_display != influence_target:
		for index in influence_display.size():
			var gap := influence_display[index].distance_to(influence_target[index])
			influence_display[index] = influence_display[index].lerp(influence_target[index], minf(1.0, delta * 1.6 / maxf(0.001, gap)))
		influence.set_shader_parameter("sources", influence_display)


func _refresh_lattice(operation: RefCounted) -> void:
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
		overlay_enabled, operation.fleets.map(func(fleet): return fleet.destination) if overlay_enabled else []])
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
	if overlay_enabled:
		for fleet in operation.fleets:
			if operation.active(fleet) and fleet.at != fleet.destination:
				_line(operation.objectives[fleet.at].position + Vector3.UP * 0.15,
					operation.objectives[fleet.destination].position + Vector3.UP * 0.15,
					ALLIED if fleet.side == "allied" else HOSTILE)
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
	badge.text = "A · Convoy" if side == "allied" else "H · Convoy"
	badge.modulate = ALLIED if side == "allied" else HOSTILE
	convoy_model.get_child(0).material_override = escort_materials[side]
	convoy_model.show()


func _line(from: Vector3, to: Vector3, tint: Color) -> void:
	for point in [from, to]:
		paths.surface_set_color(tint)
		paths.surface_add_vertex(point - Vector3.UP * 0.12)


func _create_fleet(fleet: Dictionary, objects: Dictionary) -> Node3D:
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
		model = objects[id - Warzone.ALLIED_GROUPS]
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
