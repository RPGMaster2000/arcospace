extends Control
# Shared edge HUD layout and introduction typography. Reuses the screen's actual controls.
signal settled
signal geometry_changed

enum Mode { HIDDEN, OVERVIEW, FOCUS }
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
	economy.add_child(identifier)
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
	metagame.text = "%s · PRESSURE %d / 12\n%s" % [profile, pressure, access]
	metagame.add_theme_color_override("font_color", Color("ff8e9b") if pressure >= 7 else (Color("e3bb6b") if pressure >= 4 else Color("9ad8e5")))
	queue_layout()
