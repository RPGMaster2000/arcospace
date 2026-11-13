extends Node
## Transient, presentation-only homeworld feedback. Owns no integrity or clock.
## Pending impacts are intentionally discarded on scene exit/save/load. The save
## already contains their committed damage; restoration must never replay damage.
signal finished
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Hit = preload("res://scripts/effects/imported_combat_vfx.gd")
var owner_state: Resource
var system := -1
var pending: Dictionary = {}
var active := false
var terminal := false
var map: Control
var motion: Tween
var travel: Tween
var camera_before: Dictionary = {}
var overlay: Control
var impacts: Array[Node3D] = []
var number_rise := 0.0
var number: Label

func record(state: Resource, event: Dictionary) -> void:
	if owner_state != state or system != state.system_number:
		pending.clear()
		owner_state = state
		system = state.system_number
	if event.get("homeworld_damage",0) <= 0: return
	if pending.is_empty():
		pending = {"before":event.integrity_before,"after":event.integrity_after,"damage":event.homeworld_damage}
	else:
		pending.after = event.integrity_after
		pending.damage += event.homeworld_damage

func available(state: Resource) -> bool:
	if owner_state != state or system != state.system_number:
		pending.clear()
	return not active and not pending.is_empty()

func begin(source: Control, state: Resource, defeat: bool = false, exit_action: Callable = Callable()) -> void:
	if active: return
	map = source
	active = true
	number_rise = 0.0
	terminal = defeat
	var event := pending.duplicate()
	pending.clear() # Consume before animation; cancellation cannot replay a hit.
	map.presentation_blocked = true
	travel = map.motion
	if travel and travel.is_valid(): travel.pause()
	var camera: Camera3D = map.camera
	camera_before = {"transform":camera.transform,"viewing":camera.viewing,"pan":camera.pan_offset,
		"zoom":camera.zoom_scale,"target":camera.zoom_target}
	camera.cancel()
	camera.viewing = &"homeworld"
	var home: Vector3 = state.defense.home
	var direction: Vector3 = (camera.position-home).normalized()
	if direction.length_squared() < 0.1: direction = Vector3(0,0.6,1).normalized()
	var destination := Transform3D(Basis.IDENTITY,home+direction*21.0).looking_at(home,Vector3.UP)
	overlay = Control.new()
	overlay.name = "HomeworldSequence"
	map.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var reduced := Preferences.skip_cinematics() or not Preferences.battle_vfx()
	motion = create_tween()
	motion.tween_property(camera,"transform",destination,0.01 if reduced else 0.35).set_trans(Tween.TRANS_SINE)
	if defeat:
		motion.tween_callback(show_defeat.bind(state,exit_action))
		return
	var skip := Button.new()
	skip.text = "Skip Animation"
	skip.custom_minimum_size = Vector2(180,48)
	overlay.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip.position = Vector2((map.size.x-180)*0.5,map.size.y-76)
	skip.pressed.connect(complete)
	var effects: Node3D = map.defense_effects
	effects.set_display_integrity(float(event.before))
	number = Label.new()
	number.text = "−%d" % int(event.damage)
	number.add_theme_font_size_override("font_size",40)
	number.add_theme_color_override("font_color",Color("ff9a88"))
	number.add_theme_color_override("font_shadow_color",Color.BLACK)
	number.add_theme_constant_override("shadow_offset_x",2)
	number.add_theme_constant_override("shadow_offset_y",2)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(number)
	number.hide()
	motion.tween_callback(func():
		number.show()
		effects.hit_remaining = 1.5
		var sound := get_node_or_null("/root/Sfx")
		if sound != null: sound.play_event(&"hull_hit",self))
	if not reduced:
		for offset in [Vector2(-0.35,0.2),Vector2(0.32,-0.15),Vector2(0.05,0.4)]:
			motion.tween_callback(impact.bind(home,offset))
			motion.tween_interval(0.12)
	motion.tween_method(effects.set_display_integrity,float(event.before),float(event.after),0.12 if reduced else 0.5)
	motion.parallel().tween_property(number,"modulate:a",0.0,0.5)
	motion.parallel().tween_property(self,"number_rise",24.0,0.5)
	motion.tween_property(camera,"transform",camera_before.transform,0.01 if reduced else 0.35).set_trans(Tween.TRANS_SINE)
	motion.tween_callback(complete)

func impact(home: Vector3, offset: Vector2) -> void:
	var camera: Camera3D = map.camera
	var forward := (camera.position-home).normalized()
	var surface := (forward+camera.basis.x*offset.x+camera.basis.y*offset.y).normalized()
	var anchor := Node3D.new()
	map.visual_root.add_child(anchor)
	anchor.position = home+surface*(1.8*1.5)
	Hit.hull_hit(anchor,0.4)
	impacts.append(anchor)

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(number) or not is_instance_valid(map): return
	var projected: Vector2 = map.camera.unproject_position(map.planet_nodes[0].position+map.camera.basis.y*1.0)
	number.size = Vector2(220,60)
	number.position = (projected-Vector2(110,30+number_rise)).clamp(Vector2(20,70),map.size-Vector2(240,170))

static func defeat_subtitle(state: Resource) -> String:
	if state.defense.mothership_arrived(): return "Enemy forces have captured the homeworld."
	if state.defense.integrity <= 0: return "Homeworld defenses have collapsed."
	return "All attackers reached the homeworld before the mothership could be located."

func show_defeat(state: Resource, exit_action: Callable) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.005,0.01,0.025,0.78)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation",20)
	overlay.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	for item in [["HOMEBASE LOST",44],[defeat_subtitle(state),22],
		["⚔  %d combat victories     ·     Final system %d" % [state.battles_won,state.system_number],22]]:
		var text := Label.new()
		text.text = item[0]
		text.add_theme_font_size_override("font_size",item[1])
		if item[1] == 44: text.add_theme_color_override("font_color",Color("ff9a88"))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(text)
	var button := Button.new()
	button.text = "Return to Main Menu"
	button.custom_minimum_size = Vector2(260,56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(button)
	button.pressed.connect(func():
		button.disabled = true
		if exit_action.is_valid(): exit_action.call())

func complete() -> void:
	if not active or terminal: return
	cleanup(true)
	finished.emit()

func cleanup(resume: bool) -> void:
	if motion and motion.is_valid(): motion.kill()
	if is_instance_valid(map):
		if not camera_before.is_empty():
			map.camera.transform = camera_before.transform
			map.camera.viewing = camera_before.viewing
			map.camera.pan_offset = camera_before.pan
			map.camera.zoom_scale = camera_before.zoom
			map.camera.zoom_target = camera_before.target
		map.presentation_blocked = false
		if is_instance_valid(map.defense_effects): map.defense_effects.clear_display_integrity()
	for anchor in impacts:
		if is_instance_valid(anchor): anchor.queue_free()
	impacts.clear()
	if is_instance_valid(overlay): overlay.queue_free()
	number = null
	if resume and not terminal and travel and travel.is_valid(): travel.play()
	camera_before.clear()
	active = false

func cancel() -> void:
	if active: cleanup(false)

func _exit_tree() -> void:
	cancel()
