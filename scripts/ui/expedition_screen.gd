extends Control
# RESPONSIBILITY: Own exploration screen controls; emits user intent without accessing expedition state.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Tile = preload("res://scripts/ui/encounter_tile.gd")
const Text = preload("res://scripts/ui/expedition_text.gd")
const Effects = preload("res://scripts/visual/visual_effects.gd")
var kind: String = ""
var view_revision: int = 0
var grid: GridContainer
var selected_approach: int = -1
var approach_buttons: Array[Button] = []
var mission_header: Label
const Header = preload("res://scenes/poi_header.tscn")
const TouchScroll = preload("res://scripts/ui/encounter_scroll.gd")

signal deck_requested
signal main_menu_requested
signal hull_requested
signal return_requested
signal cancel_requested
signal confirm_requested
signal jump_requested

const EdgeHUD = preload("res://scripts/ui/star_system_hud.gd")
var overview_hud: Control
var focus_layout_size := Vector2(-1,-1)
var _focus_safe_insets := Vector4(-1,-1,-1,-1)
var _layout_queued := false
var compact_focus := false
var focus_transition := false
var focus_motion: Tween
var focus_backing: Panel
var returning_from_focus := false
var body: HBoxContainer
var sidebar: VBoxContainer
var model_space: Control
var map_layer: Control

var hull_pulse_period: float = 1.45
var hull_pulse_scale: float = 1.03
var hull_pulse_intensity: float = 0.22
var ui: MarginContainer
var title: Label
var heading_row: HBoxContainer
var deck_button: Button
var legend: Button
var settings_button: Button
var resource_bar: HFlowContainer
var header: PanelContainer
var return_button: Button
var scroll: ScrollContainer
var view: VBoxContainer
var more_hint: Control
var footer: HBoxContainer
var confirmation: CanvasLayer
var approach_note: Label
var confirm_button: Button
var jump_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	resized.connect(_request_layout)
	body.item_rect_changed.connect(_request_layout)
	sidebar.item_rect_changed.connect(_request_layout)
	view.resized.connect(_request_layout)
	view.minimum_size_changed.connect(_request_layout)
	_request_layout()


func _build_ui() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("0e1a28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	ui = MarginContainer.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		ui.add_theme_constant_override("margin_" + edge, 24)
	add_child(ui)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	ui.add_child(column)
	title = _label("", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	column.add_child(heading_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)
	deck_button = Button.new()
	deck_button.text = "Deck"
	deck_button.custom_minimum_size = Vector2(64, 44)
	Presentation.action(deck_button)
	deck_button.pressed.connect(deck_requested.emit)
	heading_row.add_child(deck_button)
	legend = Button.new()
	legend.text = "Reference"
	legend.tooltip_text = "Game Reference"
	legend.custom_minimum_size = Vector2(100, 44)
	Presentation.action(legend)
	heading_row.add_child(legend)
	settings_button = preload("res://scripts/ui/settings_button.gd").new()
	heading_row.add_child(settings_button)
	settings_button.main_menu_requested.connect(main_menu_requested.emit)
	resource_bar = preload("res://scripts/ui/resource_bar.gd").new()
	resource_bar.pulse_period = hull_pulse_period
	resource_bar.pulse_scale = hull_pulse_scale
	resource_bar.pulse_intensity = hull_pulse_intensity
	column.add_child(resource_bar)
	resource_bar.hull_requested.connect(hull_requested.emit)
	legend.pressed.connect(func(): resource_bar.overlay.show_legend())
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	model_space = Control.new()
	model_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	model_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_space.size_flags_stretch_ratio = 0.48
	body.add_child(model_space)
	model_space.hide()
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = 0.52
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(sidebar)
	header = Header.instantiate()
	sidebar.add_child(header)
	header.return_requested.connect(return_requested.emit)
	return_button = header.return_button
	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	view = VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 10)
	scroll.add_child(view)
	more_hint = preload("res://scripts/ui/scroll_edge_fade.gd").new()
	more_hint.scroll = scroll
	more_hint.hide()
	add_child(more_hint)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	confirmation = preload("res://scripts/ui/approach_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(cancel_requested.emit)
	confirmation.column.add_child(footer)
	confirmation.column.move_child(footer, 1)
	var shared = _label("", 20)
	approach_note = shared
	shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(shared)
	confirm_button = confirmation.initiate
	confirm_button.pressed.connect(confirm_requested.emit)
	jump_button = Button.new()
	jump_button.custom_minimum_size = Vector2(210,44)
	jump_button.add_theme_font_size_override("font_size", 18)
	jump_button.add_theme_font_override("font", Presentation.UI_FONT)
	Presentation.action(jump_button)
	jump_button.pressed.connect(jump_requested.emit)
	# Reserve the compact slot while other views hide its action, keeping the HUD stable.
	var jump_slot := Control.new()
	jump_slot.custom_minimum_size = Vector2(230,50)
	jump_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_row.add_child(jump_slot)
	heading_row.move_child(jump_slot,1)
	jump_slot.add_child(jump_button)
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	jump_button.clip_text = true
	overview_hud = EdgeHUD.new()
	add_child(overview_hud)
	var utility_actions: Array[Button] = [deck_button, legend, settings_button]
	overview_hud.bind_controls(resource_bar, jump_button, utility_actions)
	overview_hud.geometry_changed.connect(_request_layout)
	focus_backing = Panel.new()
	focus_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := Presentation.style(Presentation.COLORS.special)
	backing.bg_color = Color(0.035,0.075,0.12,0.88)
	backing.set_border_width_all(0)
	focus_backing.add_theme_stylebox_override("panel",backing)
	add_child(focus_backing)
	move_child(focus_backing,1)
	focus_backing.hide()


func set_system_name(value: String) -> void:
	title.text = value
	overview_hud.system_name = value
	overview_hud.refresh()

func _label(text: String, font_size: int = 20) -> Label:
	if compact_focus: font_size = mini(font_size,24)
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func mount_map(map: Control) -> void:
	map_layer = map
	map.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(map)
	move_child(map, 1)
	_sync_map_rect()
	_request_layout()

func map_layout(enabled: bool, focused: bool) -> void:
	_set_compact_focus(enabled and focused)
	overview_hud.set_mode(EdgeHUD.Mode.FOCUS if enabled and focused else (EdgeHUD.Mode.OVERVIEW if enabled and kind == "system" else EdgeHUD.Mode.HIDDEN))
	ui.visible = not (enabled and not focused and kind == "system")
	# Keep bright celestial bodies from washing out the existing PoI header.
	header.get_node("TextBacking").color.a = 0.0
	model_space.visible = enabled
	sidebar.visible = not enabled or focused
	if enabled:
		model_space.size_flags_stretch_ratio = (0.5 if kind in ["preview","chasedown"] else 0.60) if focused else 1.0
		sidebar.size_flags_stretch_ratio = (0.5 if kind in ["preview","chasedown"] else 0.40) if focused else 0.52
	if returning_from_focus and enabled and not focused:
		_fade_focus(overview_hud)
	returning_from_focus = false
	_sync_map_rect()

# Static geometry changes are coalesced; animated map/VFX nodes keep their own processing.
func _request_layout() -> void:
	if _layout_queued or not is_inside_tree(): return
	_layout_queued = true
	_apply_geometry.call_deferred()


func _apply_geometry() -> void:
	_layout_queued = false
	if not is_inside_tree(): return
	if ui.visible and kind == "system" and is_instance_valid(grid):
		# Fit six tiles plus the separate service button in the existing scroll area.
		var available_height: float = scroll.size.y - 14
		for child in view.get_children():
			if child != grid:
				available_height -= child.size.y + view.get_theme_constant("separation")
		for tile in grid.get_children():
			tile.minimum_height = maxf(100, available_height / 2)
	if compact_focus:
		_fit_focus()
		focus_backing.position = sidebar.global_position-global_position-Vector2(10,8)
		focus_backing.size = sidebar.size+Vector2(20,16)
	_sync_map_rect()

func _sync_map_rect() -> void:
	if is_instance_valid(map_layer) and is_instance_valid(body):
		map_layer.position = Vector2.ZERO if overview_hud.active or compact_focus else body.global_position-global_position
		map_layer.size = size if overview_hud.active or compact_focus else body.size
		if overview_hud.active:
			map_layer.hud_regions = overview_hud.regions().duplicate()
			if compact_focus: map_layer.hud_regions.append(return_button.get_global_rect())
		else: map_layer.hud_regions.clear()


func add_action(
	text: String, callback: Callable, disabled: bool = false, height: float = 64
) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = minf(height,52) if compact_focus else height
	button.add_theme_font_size_override("font_size", 20 if compact_focus else 22)
	button.disabled = disabled
	Presentation.action(button)
	var revision: int = view_revision
	button.pressed.connect(
		func():
			if revision == view_revision and button.is_inside_tree() and allows_activation():
				callback.call()
	)
	view.add_child(button)
	return button


func add_grid(columns: int) -> GridContainer:
	var result = GridContainer.new()
	result.columns = columns
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("h_separation", 10)
	result.add_theme_constant_override("v_separation", 10)
	view.add_child(result)
	grid = result
	return result


func add_tile(
	parent: Node,
	heading: String,
	details: String,
	color: Color,
	callback: Callable,
	disabled: bool = false,
	centered: bool = false
) -> Button:
	var button = Tile.new()
	button.configure(heading, details, color, centered)
	if compact_focus: button.set_compact(true)
	button.disabled = disabled
	button.refresh_style()
	var revision: int = view_revision
	button.pressed.connect(
		func():
			if revision == view_revision and button.is_inside_tree() and allows_activation() and not button.disabled:
				callback.call()
	)
	parent.add_child(button)
	return button


# Query-only State input: the controller has already established field-repair eligibility.
func reset_view(kind: String, state: Resource, map_enabled: bool, icon: Callable) -> void:
	var combat_entry = sidebar.get_node_or_null("CombatEntry")
	if combat_entry != null:
		sidebar.remove_child(combat_entry)
		combat_entry.queue_free()
	returning_from_focus = compact_focus and kind == "system"
	_set_compact_focus(false)
	if not (map_enabled and kind in ["system","poi","preview","chasedown","outcome"]): overview_hud.set_mode(EdgeHUD.Mode.HIDDEN)
	resource_bar.edge_compact = map_enabled and kind in ["system","poi","preview","chasedown","outcome"]
	view.alignment = BoxContainer.ALIGNMENT_END if kind == "poi" else BoxContainer.ALIGNMENT_BEGIN
	resource_bar.overlay.dismiss()
	confirmation.dismiss()
	self.kind = kind
	mission_header = null
	view_revision += 1
	resource_bar.field_repairs_enabled = state.field_repairs_open
	selected_approach = -1
	approach_buttons = []
	grid = null
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
		if kind == "system" and map_enabled
		else ScrollContainer.SCROLL_MODE_AUTO
	)
	scroll.scroll_vertical = 0
	ui.show()
	header.visible = kind == "poi"
	return_button.visible = kind == "poi"
	footer.hide()
	confirm_button.disabled = true
	heading_row.show()
	title.visible = true
	title.text = state.system_name
	resource_bar.exploration(state)
	if overview_hud.active: overview_hud.refresh()
	overview_hud.system_number = state.system_number
	overview_hud.hull_bar.max_value = state.ship().hull_capacity
	overview_hud.hull_bar.value = state.hull
	if state.is_defense():
		var threats: int = 0
		for unit in state.defense.units:
			if state.defense.available(unit): threats += 1
		overview_hud.metagame.text = "HOME %d/%d · %d THREATS\n%s" % [state.defense.integrity, state.rules.defense_tuning.base_integrity, threats, state.ftl_status()]
	else:
		overview_hud.set_metagame(state.profile_name(), state.pressure, state.ftl_status())
	jump_button.text = ("FTL READY" if state.can_jump() else "FTL LOCKED") if state.is_defense() else state.ftl_status().replace("FTL OBJECTIVE AVAILABLE", "FTL OBJECTIVE\nAVAILABLE")
	if state.mandatory_boss_pending():
		jump_button.tooltip_text = "Defeat the mandatory Boss or escape by EMP Pulse before leaving this system."
	else:
		jump_button.tooltip_text = "Jump to the next system. FTL Access resets on arrival." if state.can_jump() else "Complete an FTL objective to acquire access."
	jump_button.modulate = Color("a3f3e5") if state.can_jump() else Color.WHITE
	jump_button.disabled = not state.can_jump()
	jump_button.visible = kind == "system" and state.hull > 0
	return_button.disabled = false
	return_button.tooltip_text = "Return to system overview"


func select_approach(slot: int, selected_title: String) -> void:
	selected_approach = slot
	footer.hide()
	for index in range(approach_buttons.size()):
		var button = approach_buttons[index]
		button.selected = index == slot or (slot == -2 and index == approach_buttons.size() - 1)
		button.refresh_style()
	confirm_button.disabled = false
	confirmation.present(selected_title)


func cancel_approach() -> void:
	confirmation.dismiss()
	selected_approach = -1
	confirm_button.disabled = true
	for button in approach_buttons:
		button.selected = false
		button.refresh_style()


func present_result(state: Resource, visual_settings: Resource, split_map: bool) -> void:
	if state.last_poi_success >= 0:
		mission_header = _label(
			"Mission Successful" if state.last_poi_success == 1 else "Mission Compromised", 32
		)
		mission_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_header.add_theme_color_override(
			"font_color",
			(
				Color(visual_settings.poi_success_color, 1.0)
				if state.last_poi_success == 1
				else Color(visual_settings.poi_failure_color, 1.0)
			)
		)
		view.add_child(mission_header)
		Effects.reveal(mission_header, visual_settings)
	var result = PanelContainer.new()
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var available_width: float = get_viewport().get_visible_rect().size.x - 48.0
	if compact_focus:
		available_width = (minf(size.x,1440)-32)*0.40
	elif split_map and model_space.visible:
		available_width *= 0.52
	result.custom_minimum_size.x = minf(900, available_width - 32)
	result.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	var picking_card: bool = state.pending_choice in ["card", "upgrade"]
	result.add_child(
		_label(
			(
				(
					"Acquire one card"
					if state.pending_choice == "card"
					else (
						"Upgrade different cards · %d remaining" % maxi(1, state.upgrades_remaining)
					)
				)
				if picking_card
				else Text.compact_text(state.last_outcome)
			),
			26 if picking_card else 22
		)
	)
	result.tooltip_text = state.last_outcome if picking_card else ""
	view.add_child(result)
	var reward_text: Label = result.get_child(0)
	reward_text.add_theme_color_override(
		"font_color",
		Color.WHITE.lerp(visual_settings.card_selection_color, visual_settings.reward_text_emphasis)
	)
	Effects.reveal(reward_text, visual_settings)


func allows_activation() -> bool:
	return is_inside_tree() and not focus_transition and scroll.allows_activation()


func hide_for_battle() -> void:
	_set_compact_focus(false)
	overview_hud.set_mode(EdgeHUD.Mode.HIDDEN)
	resource_bar.set_heartbeat(false)
	resource_bar.overlay.dismiss()
	ui.hide()
	kind = "battle"


# Presentation-only suspense. Cancellation wakes the controller without revealing a result.
signal suspense_finished
var suspense_motion: Tween
var suspense_revision: int = 0

func result_suspense(duration: float) -> bool:
	cancel_suspense()
	var revision: int = suspense_revision
	return_button.disabled = true
	for button in approach_buttons:
		button.disabled = true
	suspense_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	suspense_motion.tween_interval(duration)
	suspense_motion.tween_callback(suspense_finished.emit)
	await suspense_finished
	if revision != suspense_revision or not is_inside_tree():
		return false
	return_button.disabled = false
	return true

func cancel_suspense() -> void:
	suspense_revision += 1
	if suspense_motion and suspense_motion.is_valid():
		suspense_motion.kill()
	suspense_finished.emit()

func cancel_pending() -> void:
	_cancel_focus_motion()
	overview_hud.cancel()
	view_revision += 1
	cancel_suspense()


func _exit_tree() -> void:
	cancel_pending()

# Focus borrows the existing Back control; all gameplay/choice ownership stays outside.
func _set_compact_focus(enabled: bool) -> void:
	if compact_focus == enabled: return
	_cancel_focus_motion()
	compact_focus = enabled
	focus_backing.visible = enabled
	header.compact = enabled
	header._fit()
	heading_row.visible = not enabled
	if enabled:
		return_button.reparent(self)
		return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		return_button.position = Vector2(16,74)
		return_button.size = Vector2(104,52)
		return_button.text = "Back"
		return_button.show()
		return_button.z_index = 80
		view.alignment = BoxContainer.ALIGNMENT_BEGIN
		view.add_theme_constant_override("separation",4)
		_fit_focus()
		_fade_focus(sidebar)
	else:
		focus_layout_size = Vector2(-1,-1)
		return_button.reparent(header.get_node("Overlay"))
		return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		return_button.offset_left = -172
		return_button.offset_top = 12
		return_button.offset_right = -12
		return_button.offset_bottom = 68
		return_button.text = "Return"
		return_button.z_index = 0
		view.add_theme_constant_override("separation",10)
		for edge in ["left","right","top","bottom"]: ui.add_theme_constant_override("margin_"+edge,24)

func _fit_focus() -> void:
	var safe := preload("res://scripts/ui/battle_layout.gd").safe_insets(self)
	if focus_layout_size == size and _focus_safe_insets == safe: return
	focus_layout_size = size
	_focus_safe_insets = safe
	var edge: int = roundi(maxf(16,(size.x-1440)*0.5+16))
	ui.add_theme_constant_override("margin_left",edge+roundi(safe.x))
	ui.add_theme_constant_override("margin_right",edge+roundi(safe.z))
	ui.add_theme_constant_override("margin_top",76+roundi(safe.y))
	ui.add_theme_constant_override("margin_bottom",16+roundi(safe.w))
	return_button.position = Vector2(16+safe.x,74+safe.y)

func _fade_focus(target: Control) -> void:
	focus_transition = true
	target.modulate.a = 0
	focus_motion = create_tween()
	focus_motion.tween_property(target,"modulate:a",1.0,0.24)
	if target == sidebar:
		focus_backing.modulate.a = 0
		focus_motion.parallel().tween_property(focus_backing,"modulate:a",1.0,0.24)
	focus_motion.tween_callback(func(): focus_transition = false)

func _cancel_focus_motion() -> void:
	if focus_motion and focus_motion.is_valid(): focus_motion.kill()
	focus_transition = false
	if is_instance_valid(sidebar): sidebar.modulate.a = 1
	if is_instance_valid(focus_backing): focus_backing.modulate.a = 1
	if is_instance_valid(overview_hud): overview_hud.modulate.a = 1

func _input(_event: InputEvent) -> void:
	if focus_transition: get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		overview_hud.queue_layout()
		_request_layout()
