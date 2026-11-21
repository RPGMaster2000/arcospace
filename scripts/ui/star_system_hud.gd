extends Control
# Shared edge HUD layout and introduction typography. Reuses the screen's actual controls.
signal settled
signal geometry_changed
signal system_details_requested
signal warzone_wait_requested
signal lattice_overlay_changed(enabled: bool)

enum Mode { HIDDEN, OVERVIEW, FOCUS }
const WarzoneIcons = preload("res://scripts/ui/warzone_indicators.gd")
var mode: Mode = Mode.HIDDEN
var _resource_bar: Control
var _jump_button: Button
var _utility_actions: Array[Button] = []
var _resource_actions: Array[Button] = []
var _zoom_actions: Array[Button] = []
var _zoom_source: WeakRef
var panels: Array[Control] = []
var reserved: Array[Rect2] = []
var resources: HBoxContainer
var status: VBoxContainer
var utilities: HBoxContainer
var metagame: Label
var defense_mode := false
var warzone_mode := false
var lattice_mode := false
var lattice_button: Button
var war_effort_bar: ProgressBar
var war_effort_gain: Label
var warzone_summary: HBoxContainer
var warzone_counts: Array[Label] = []
var territory_bar: ProgressBar
var warzone_warning: HBoxContainer
var warzone_warning_text: Label
var _warzone_instance := 0
var _warzone_effort := 0
var _warzone_event := 0
var _gain_fade: Tween
var _warning_fade: Tween
var wait_button: Button
var pressure_bar: ProgressBar
var pressure_fill: StyleBoxFlat
var pressure_gap: Control
var status_actions: VBoxContainer
var details_button: Button
var turret_count: Label
var hull_bar: ProgressBar
var identifier: Label
var title: Label
var subtitle: Label
var active: bool:
	get: return mode != Mode.HIDDEN
var focused: bool:
	get: return mode == Mode.FOCUS
var economy: HBoxContainer
var originals: Dictionary = {}
var blocked_buttons: Dictionary = {}
var motion: Tween
var revision := 0
var _layout_queued := false
var system_name := ""
var faction_label: Label
var system_number := 1

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	for corner in range(5):
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025,0.055,0.085,0.8)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(5)
		panel.add_theme_stylebox_override("panel",style)
		add_child(panel)
		panels.append(panel)
		panel.minimum_size_changed.connect(queue_layout)
	identifier = Label.new()
	identifier.add_theme_font_size_override("font_size",30)
	economy = HBoxContainer.new()
	economy.add_theme_constant_override("separation",4)
	panels[0].add_child(economy)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation",0)
	economy.add_child(names)
	names.add_child(identifier)
	faction_label = Label.new()
	faction_label.name = "ControllingFaction"
	faction_label.add_theme_font_size_override("font_size",14)
	faction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_label.hide()
	names.add_child(faction_label)
	resources = HBoxContainer.new()
	resources.add_theme_constant_override("separation",2)
	economy.add_child(resources)
	panels[1].hide()
	status = VBoxContainer.new()
	status.add_theme_constant_override("separation",2)
	panels[2].add_child(status)
	metagame = Label.new()
	metagame.name = "SystemPressure"
	metagame.add_theme_font_size_override("font_size", 14)
	metagame.mouse_filter = MOUSE_FILTER_IGNORE
	status.add_child(metagame)
	war_effort_bar = WarzoneIcons.bar(WarzoneIcons.ALLIED, 8)
	status.add_child(war_effort_bar)
	war_effort_gain = Label.new()
	war_effort_gain.mouse_filter = MOUSE_FILTER_IGNORE
	war_effort_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	war_effort_gain.add_theme_color_override("font_color", WarzoneIcons.ALLIED)
	war_effort_gain.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	war_effort_gain.position = Vector2(-48, -27)
	war_effort_gain.size.x = 46
	war_effort_bar.add_child(war_effort_gain)
	warzone_summary = HBoxContainer.new()
	warzone_summary.mouse_filter = MOUSE_FILTER_IGNORE
	warzone_summary.add_theme_constant_override("separation", 7)
	status.add_child(warzone_summary)
	for group in ["allied", "hostile", "combat"]:
		var tint: Color = Color("ffdc85") if group == "combat" else WarzoneIcons.tint(group)
		var icon := WarzoneIcons.icon("combat" if group == "combat" else "fleet", tint)
		warzone_summary.add_child(icon)
		var count := Label.new()
		count.accessibility_name = "Engagements" if group == "combat" else group.capitalize() + " fleets"
		count.add_theme_color_override("font_color", tint)
		count.mouse_filter = MOUSE_FILTER_IGNORE
		warzone_summary.add_child(count)
		warzone_counts.append(count)
	territory_bar = WarzoneIcons.bar(WarzoneIcons.ALLIED, 4)
	var hostile_track := territory_bar.get_theme_stylebox("background") as StyleBoxFlat
	hostile_track.bg_color = WarzoneIcons.HOSTILE
	status.add_child(territory_bar)
	warzone_warning = HBoxContainer.new()
	warzone_warning.mouse_filter = MOUSE_FILTER_IGNORE
	warzone_warning.add_child(WarzoneIcons.icon("warning", Color("ffdc85"), 18))
	warzone_warning_text = Label.new()
	warzone_warning_text.mouse_filter = MOUSE_FILTER_IGNORE
	warzone_warning_text.add_theme_font_size_override("font_size", 13)
	warzone_warning.add_child(warzone_warning_text)
	status.add_child(warzone_warning)
	for control in [war_effort_bar, warzone_summary, territory_bar, warzone_warning]: control.hide()
	pressure_bar = ProgressBar.new()
	pressure_bar.name = "StrategicPressure"
	pressure_bar.custom_minimum_size = Vector2(210,6)
	pressure_bar.show_percentage = false
	pressure_bar.mouse_filter = MOUSE_FILTER_IGNORE
	var pressure_track := StyleBoxFlat.new()
	pressure_track.bg_color = Color("263d4f")
	pressure_track.set_corner_radius_all(2)
	pressure_bar.add_theme_stylebox_override("background",pressure_track)
	pressure_fill = StyleBoxFlat.new()
	pressure_bar.add_theme_stylebox_override("fill",pressure_fill)
	status.add_child(pressure_bar)
	pressure_gap = Control.new()
	pressure_gap.custom_minimum_size.y = 18
	pressure_gap.mouse_filter = MOUSE_FILTER_IGNORE
	status.add_child(pressure_gap)
	# Reuse the unused edge slot for a transparent group above the utility row.
	panels[1].add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	panels[1].mouse_filter = MOUSE_FILTER_IGNORE
	status_actions = VBoxContainer.new()
	status_actions.add_theme_constant_override("separation",4)
	status_actions.mouse_filter = MOUSE_FILTER_IGNORE
	panels[1].add_child(status_actions)
	details_button = Button.new()
	preload("res://scripts/ui/encounter_presentation.gd").action(details_button)
	details_button.name = "SystemStatus"
	details_button.tooltip_text = "System Status"
	details_button.icon = preload("res://assets/ui/system_status.svg")
	details_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	details_button.custom_minimum_size = Vector2(48,48)
	details_button.add_theme_font_size_override("font_size",18)
	details_button.pressed.connect(system_details_requested.emit)
	turret_count = Label.new()
	turret_count.add_theme_font_size_override("font_size",14)
	turret_count.mouse_filter = MOUSE_FILTER_IGNORE
	turret_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_actions.add_child(turret_count)
	status_actions.add_child(details_button)
	wait_button = Button.new()
	wait_button.name = "WarzoneWait"
	wait_button.custom_minimum_size = Vector2(96, 48)
	preload("res://scripts/ui/encounter_presentation.gd").action(wait_button)
	wait_button.pressed.connect(warzone_wait_requested.emit)
	status_actions.add_child(wait_button)
	lattice_button = Button.new()
	lattice_button.text = "Lattice"
	lattice_button.custom_minimum_size = Vector2(96, 48)
	lattice_button.toggle_mode = true
	lattice_button.toggled.connect(func(enabled: bool):
		_sync_strategic_controls()
		lattice_overlay_changed.emit(enabled))
	preload("res://scripts/ui/encounter_presentation.gd").action(lattice_button)
	status_actions.add_child(lattice_button)
	lattice_button.hide()
	wait_button.hide()
	for node in [pressure_bar,pressure_gap,details_button,turret_count]: node.hide()
	hull_bar = ProgressBar.new()
	hull_bar.custom_minimum_size.y = 4
	hull_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("6dc7d7")
	hull_bar.add_theme_stylebox_override("fill",fill)
	hull_bar.mouse_filter = MOUSE_FILTER_IGNORE
	utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation",4)
	panels[4].add_child(utilities)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",96)
	title.add_theme_color_override("font_outline_color",Color("03101d"))
	title.add_theme_constant_override("outline_size",4)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",44)
	subtitle.add_theme_color_override("font_outline_color",Color("03101d"))
	subtitle.add_theme_constant_override("outline_size",3)
	subtitle.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(subtitle)
	resized.connect(queue_layout)
	hide()

# Screen supplies existing controls once. This component alone owns their mounting/style.
# No State, screen owner or gameplay callback is retained here.
func bind_controls(bar: Control, jump: Button, utilities_actions: Array[Button]) -> void:
	assert(_resource_bar == null, "HUD controls must only be bound once")
	_resource_bar = bar
	_jump_button = jump
	_utility_actions = utilities_actions


func _borrow(control: Control, parent: Node) -> void:
	if not originals.has(control):
		originals[control] = {
			"parent": weakref(control.get_parent()),
			"index": control.get_index(),
			"minimum": control.custom_minimum_size,
		}
	control.reparent(parent)


func _restore_controls() -> void:
	var controls: Array = originals.keys()
	controls.sort_custom(func(a, b): return originals[a].index < originals[b].index)
	for control in controls:
		if not is_instance_valid(control): continue
		var saved: Dictionary = originals[control]
		var parent: Node = saved.parent.get_ref()
		if parent == null:
			control.get_parent().remove_child(control)
			control.queue_free()
			continue
		control.reparent(parent)
		parent.move_child(control, mini(saved.index, parent.get_child_count() - 1))
		control.custom_minimum_size = saved.minimum
	originals.clear()


func set_mode(next: Mode) -> void:
	if mode == next: return
	var was_active := active
	mode = next
	_sync_strategic_controls()
	if active and not was_active:
		_mount_controls()
	elif not active and was_active:
		_unmount_controls()
	visible = active
	panels[3].visible = mode == Mode.OVERVIEW
	panels[4].visible = mode == Mode.OVERVIEW
	if mode != Mode.OVERVIEW:
		for button in [_jump_button] + _utility_actions + _zoom_actions:
			if is_instance_valid(button): button.release_focus()
	layout()


func _mount_controls() -> void:
	# Snapshot siblings before moving any of them out of the same container.
	_resource_actions.assign(_resource_bar.entries.values())
	for control in [_resource_bar] + _resource_actions + [_jump_button] + _utility_actions:
		originals[control] = {"parent": weakref(control.get_parent()), "index": control.get_index(), "minimum": control.custom_minimum_size}
	_borrow(_resource_bar, self)
	_resource_bar.position = Vector2(-1000, -1000)
	_resource_bar.show() # Its existing CanvasLayer modal and heartbeat retain their lifecycle.
	for key in ["salvage", "materials", "energy", "crew"]:
		_borrow(_resource_bar.entries[key], resources)
	_borrow(_resource_bar.entries.hull, status)
	status.add_child(hull_bar)
	var row := HBoxContainer.new()
	row.name = "ShieldEmp"
	status.add_child(row)
	for key in ["shields", "jump"]:
		_borrow(_resource_bar.entries[key], row)
	_style_resources(17, 44)
	_borrow(_jump_button, panels[3])
	_jump_button.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	for button in _utility_actions:
		_borrow(button, utilities)
	refresh()


func _unmount_controls() -> void:
	cancel()
	_style_resources(20, 48)
	_release_zoom()
	_restore_controls()
	if hull_bar.get_parent() != null: hull_bar.get_parent().remove_child(hull_bar)
	var row := status.get_node_or_null("ShieldEmp")
	if row != null: row.free()
	_jump_button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_resource_actions.clear()


func _style_resources(font_size: int, height: int) -> void:
	for button in _resource_actions:
		button.custom_minimum_size.y = height
		button.add_theme_font_size_override("font_size", font_size)
		for label in button.get_node("Values").get_children():
			label.add_theme_font_size_override("font_size", font_size)


func refresh() -> void:
	identifier.text = "%02d | %s" % [system_number,system_name]
	queue_layout()

func queue_layout() -> void:
	if _layout_queued or not is_inside_tree(): return
	_layout_queued = true
	_flush_layout.call_deferred()


func _flush_layout() -> void:
	_layout_queued = false
	if is_inside_tree(): layout()


func layout() -> void:
	if not active: return
	var inset := Vector4(12,12,12,12)
	if OS.has_feature("android"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		if window.x>0 and window.y>0 and safe.size.x>0:
			var ratio := size/Vector2(window)
			inset += Vector4(safe.position.x*ratio.x,safe.position.y*ratio.y,(window.x-safe.end.x)*ratio.x,(window.y-safe.end.y)*ratio.y)
	# Keep longer generated names readable inside the existing screen space.
	var title_width: float = title.get_theme_font("font").get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,96).x
	var title_size := mini(96, int(96 * size.x * 0.9 / maxf(1, title_width)))
	if title.get_theme_font_size("font_size") != title_size:
		title.add_theme_font_size_override("font_size", title_size)
	var identifier_width: float = identifier.get_theme_font("font").get_string_size(identifier.text,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
	if identifier.get_theme_font_size("font_size") != 20:
		identifier.add_theme_font_size_override("font_size",20)
	identifier.clip_text = false
	identifier.tooltip_text = identifier.text
	identifier.custom_minimum_size.x = minf(identifier_width*20.0/30.0+8,size.x*0.24)
	identifier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for panel in panels: panel.reset_size()
	panels[0].custom_minimum_size.x = 0
	panels[0].size.x = minf(panels[0].size.x,size.x-inset.x-inset.z-(0 if focused else panels[3].size.x+10))
	panels[0].position = Vector2(inset.x,inset.y)
	panels[2].position = Vector2(inset.x,size.y-panels[2].size.y-inset.w)
	panels[3].position = Vector2(size.x-panels[3].size.x-inset.z,inset.y)
	panels[4].position = size-panels[4].size-Vector2(inset.z,inset.w)
	panels[1].position = Vector2(size.x-panels[1].size.x-inset.z,panels[4].position.y-panels[1].size.y-10)
	title.position = Vector2(0,size.y*0.38)
	title.size = Vector2(size.x,124)
	subtitle.position = Vector2(0,size.y*0.38+128)
	subtitle.size = Vector2(size.x,62)
	reserved.clear()
	for panel in panels:
		if panel.visible: reserved.append(panel.get_global_rect().grow(4))
	geometry_changed.emit()

func regions() -> Array[Rect2]:
	return reserved if active else []

func prepare_introduction(name_value: String, number: int) -> void:
	cancel()
	system_name = name_value
	system_number = number
	title.text = name_value.to_upper()
	subtitle.text = "SYSTEM %02d" % number
	title.modulate.a = 0
	subtitle.modulate.a = 0
	title.show()
	subtitle.show()
	for panel in panels:
		panel.modulate.a = 0
		panel.mouse_filter = MOUSE_FILTER_IGNORE
	for panel in panels:
		for button in panel.find_children("*","BaseButton",true,false):
			blocked_buttons[button] = [button.disabled,button.focus_mode]
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP
	layout()

func introduce(duration: float) -> bool:
	var request: int = revision
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	motion.tween_property(title,"modulate:a",1.0,0.6).set_delay(duration*0.08)
	motion.tween_property(subtitle,"modulate:a",1.0,0.5).set_delay(duration*0.28)
	motion.chain().tween_interval(maxf(0.0,duration*0.78-(duration*0.28+0.5)))
	motion.chain().tween_property(title,"modulate:a",0.0,duration*0.12)
	motion.parallel().tween_property(subtitle,"modulate:a",0.0,duration*0.12)
	for i in range(panels.size()):
		motion.parallel().tween_property(panels[i],"modulate:a",1.0,duration*0.06).set_delay(i*duration*0.0125+duration*0.12)
	motion.chain().tween_callback(settled.emit)
	await settled
	if request != revision or not is_inside_tree(): return false
	title.hide()
	subtitle.hide()
	restore_input()
	mouse_filter = MOUSE_FILTER_IGNORE
	for panel in panels: panel.mouse_filter = MOUSE_FILTER_STOP
	return true

func restore_input() -> void:
	for button in blocked_buttons:
		if is_instance_valid(button):
			button.disabled = blocked_buttons[button][0]
			button.focus_mode = blocked_buttons[button][1]
	blocked_buttons.clear()

func cancel() -> void:
	restore_input()
	revision += 1
	if motion and motion.is_valid(): motion.kill()
	if is_instance_valid(title):
		title.hide()
		subtitle.hide()
	for panel in panels:
		panel.modulate.a = 1
		panel.mouse_filter = MOUSE_FILTER_STOP
	mouse_filter = MOUSE_FILTER_IGNORE
	settled.emit()

func _exit_tree() -> void:
	cancel()
	if is_instance_valid(hull_bar) and hull_bar.get_parent()==null: hull_bar.free()

# Zoom controls belong to a map generation, not to the screen. Replacement is explicit.
func attach_zoom(map: Control) -> void:
	if not active: return
	if _zoom_source != null and _zoom_source.get_ref() == map: return
	_release_zoom()
	_zoom_source = weakref(map)
	map.external_zoom_controls = true
	for button in map.zoom_controls.get_children():
		_zoom_actions.append(button)
		_borrow(button, utilities)
	queue_layout()


func _release_zoom() -> void:
	var map: Node = _zoom_source.get_ref() if _zoom_source != null else null
	if map != null: map.external_zoom_controls = false
	for button in _zoom_actions:
		if not is_instance_valid(button): continue
		var saved: Dictionary = originals[button]
		var parent: Node = saved.parent.get_ref()
		if parent != null:
			button.reparent(parent)
			parent.move_child(button, mini(saved.index, parent.get_child_count() - 1))
		else:
			button.get_parent().remove_child(button)
			button.queue_free()
		originals.erase(button)
	_zoom_actions.clear()
	_zoom_source = null


# Read-only facts from the expedition screen; no gameplay state is stored here.
func set_metagame(profile: String, pressure: int, access: String) -> void:
	defense_mode = false
	warzone_mode = false
	_sync_strategic_controls()
	metagame.text = "%s · PRESSURE %d / 12\n%s" % [profile, pressure, access]
	metagame.add_theme_color_override("font_color", Color("ff8e9b") if pressure >= 7 else (Color("e3bb6b") if pressure >= 4 else Color("9ad8e5")))
	queue_layout()

# Presentation only: use the same pressure denominator as the strategic simulation.
func set_defense_status(state: Resource) -> void:
	defense_mode = true
	warzone_mode = false
	var ratio := clampf(state.defense.pressure / maxf(1.0,state.defense.tuning.pressure_maximum),0,1)
	metagame.text = "PRESSURE %d / %d" % [int(state.defense.pressure),int(state.defense.tuning.pressure_maximum)]
	if state.defense.mothership_advancing: metagame.text += "\nMOTHERSHIP ADVANCING"
	pressure_bar.value = ratio*100
	pressure_fill.bg_color = Color("77e596") if ratio < 0.5 else (Color("ffaf58") if ratio < 0.8 else Color("ff646e"))
	pressure_bar.tooltip_text = "Pressure %.1f / %.1f" % [state.defense.pressure,state.defense.tuning.pressure_maximum]
	turret_count.text = "Turrets: %d%s" % [state.defense.turrets.size(), " · Travel +50%" if state.poi_effects.fuel > 0 else ""]
	_sync_strategic_controls()
	queue_layout()


func set_warzone_status(state: Resource) -> void:
	defense_mode = false
	warzone_mode = true
	var operation = state.warzone
	lattice_mode = operation.is_lattice()
	if lattice_mode:
		_present_lattice_status(state, operation)
	else:
		_set_legacy_warzone_text(state, operation)
	metagame.add_theme_color_override("font_color", Color("9ad8e5"))
	wait_button.text = "Wait %ds" % operation.tuning.wait_seconds
	wait_button.disabled = operation.complete or state.navigation.leg_active or not state.can_navigate()
	_sync_strategic_controls()
	queue_layout()


func _present_lattice_status(state: Resource, operation: RefCounted) -> void:
	var goal: int = operation.tuning.effort_goal
	var percent := clampi(roundi(100.0 * operation.effort / goal), 0, 100)
	war_effort_bar.max_value = goal
	war_effort_bar.value = operation.effort
	war_effort_bar.accessibility_name = "War Effort %d of %d" % [operation.effort, goal]
	metagame.text = "WAR EFFORT  %d%%" % percent
	if operation.complete:
		metagame.text = state.warzone_outcome.grade + " · FTL Ready"
	elif operation.consolidation > 0:
		metagame.text += "\nHolding %s · %d/%ds" % [operation.objective_name(operation.final_command),
			operation.consolidation, operation.tuning.consolidation_seconds]
	elif operation.final_command >= 0:
		metagame.text += "\nSecure " + operation.objective_name(operation.final_command)
	elif percent == 100:
		metagame.text += "\nSupport the offensive"
	var counts := [operation.fleet_count("allied"), operation.fleet_count("hostile"),
		0 if operation.complete else operation.engagement_count()]
	for i in warzone_counts.size():
		warzone_counts[i].text = ["A %d", "H %d", "%d"][i] % counts[i]
	var allied: int = operation.objectives.filter(func(site): return site.owner == "allied").size()
	var hostile: int = operation.objectives.filter(func(site): return site.owner == "hostile").size()
	territory_bar.max_value = maxi(1, allied + hostile)
	territory_bar.value = allied
	territory_bar.accessibility_name = "Territory · %d allied, %d hostile" % [allied, hostile]
	if _warzone_instance != operation.get_instance_id():
		_warzone_instance = operation.get_instance_id()
		_warzone_effort = operation.effort
		_warzone_event = operation.event_revision
		war_effort_gain.text = ""
		warzone_warning_text.text = ""
	if operation.effort > _warzone_effort:
		if _gain_fade != null: _gain_fade.kill()
		war_effort_gain.text = "+%d" % (operation.effort - _warzone_effort)
		war_effort_gain.modulate.a = 1.0
		_gain_fade = create_tween()
		_gain_fade.tween_property(war_effort_gain, "modulate:a", 0.0, 0.4).set_delay(1.0)
	_warzone_effort = operation.effort
	if operation.event_revision != _warzone_event:
		for event in operation.events_since(_warzone_event):
			if event.begins_with("Hostile counterattack"):
				_flash_warzone_warning("Counterattack")
			elif event.begins_with("Allied") and event.ends_with("destroyed."):
				_flash_warzone_warning("Allied fleet lost")
			elif event.contains("captured"):
				_flash_warzone_warning("Site captured" if event.begins_with("Allied") else "Site lost")
			elif event.contains("reinforcements entering the sector."):
				_flash_warzone_warning(event.get_slice(" ", 0) + " reinforcements")
			elif event.begins_with("Capture link severed"):
				_flash_warzone_warning("Capture link severed")
			elif event.contains("Severed hostile supply"):
				_flash_warzone_warning("Hostile supply cut")
		_warzone_event = operation.event_revision


func _flash_warzone_warning(message: String) -> void:
	if _warning_fade != null: _warning_fade.kill()
	warzone_warning_text.text = message
	warzone_warning.modulate.a = 1.0
	_warning_fade = create_tween()
	_warning_fade.tween_property(warzone_warning, "modulate:a", 0.0, 0.35).set_delay(2.5)
	_warning_fade.tween_callback(func():
		warzone_warning_text.text = ""
		warzone_warning.hide())


func _set_legacy_warzone_text(state: Resource, operation: RefCounted) -> void:
	metagame.text = "WARZONE · OBJECTIVES %d / %d\nFleets · Allied %d / Hostile %d · %d fights" % [
		operation.controlled(), state.Warzone.REQUIRED_OBJECTIVES,
		operation.fleet_count("allied"), operation.fleet_count("hostile"), operation.engagement_count()]
	if operation.complete:
		metagame.text += "\n" + state.warzone_outcome.grade
	elif operation.consolidation > 0:
		metagame.text += "\nHolding · %ds / %ds" % [operation.consolidation, operation.tuning.consolidation_seconds]
	else:
		var threat: String = operation.main_threat()
		metagame.text += "\n" + (threat if not threat.is_empty() else "Capture and hold two objectives")
	if not operation.events.is_empty():
		var latest: String = operation.events.back()
		metagame.text += "\n" + (latest.left(40) + "…" if latest.length() > 40 else latest)



func _sync_strategic_controls() -> void:
	for node in [pressure_bar,pressure_gap,turret_count]:
		if is_instance_valid(node): node.visible = defense_mode and mode == Mode.OVERVIEW
	var show_actions: bool = mode == Mode.OVERVIEW and (defense_mode or warzone_mode)
	panels[1].visible = show_actions
	details_button.visible = show_actions
	wait_button.visible = show_actions and warzone_mode
	lattice_button.visible = show_actions and warzone_mode and lattice_mode
	var show_lattice := show_actions and warzone_mode and lattice_mode
	for control in [war_effort_bar, warzone_summary, territory_bar]: control.visible = show_lattice
	var connection_warning := warzone_warning_text.text in ["Capture link severed", "Hostile supply cut"]
	warzone_warning.visible = show_lattice and not warzone_warning_text.text.is_empty() \
		and (lattice_button.button_pressed or not connection_warning)
