extends Node3D
## Read-only presentation. Rebuilt only when committed fleet positions change.

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
	if model.visible and (prior.get("position", next) != next or not is_equal_approx(prior.get("heading", heading), heading)):
		var existing: Tween = motion.get(id)
		if existing: existing.kill()
		var duration := clampf(0.36 + model.position.distance_to(next) * 0.10, 0.42, 0.95)
		var easing := model.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		easing.tween_property(model, "position", next, duration)
		easing.tween_property(model, "rotation:y", model.rotation.y + angle_difference(model.rotation.y, heading), duration)
		motion[id] = easing
	displayed[id] = {"position": next, "strength": fleet.strength, "heading": heading}


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
