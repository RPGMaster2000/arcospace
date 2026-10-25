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
	title = _label("", 30)
	heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	column.add_child(heading_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)
	deck_button = Button.new()
	deck_button.text = "Deck"
	deck_button.custom_minimum_size = Vector2(90, 48)
	Presentation.action(deck_button)
	deck_button.pressed.connect(deck_requested.emit)
	heading_row.add_child(deck_button)
	legend = Button.new()
	legend.text = "GAME REFERENCE"
	legend.custom_minimum_size = Vector2(100, 48)
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
	jump_button.custom_minimum_size.y = 48
	jump_button.add_theme_font_size_override("font_size", 21)
	jump_button.add_theme_font_override("font", Presentation.UI_FONT)
	Presentation.action(jump_button)
	jump_button.pressed.connect(jump_requested.emit)
	column.add_child(jump_button)


func _label(text: String, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func mount_map(map: Control) -> void:
	map_layer = map
	add_child(map)
	move_child(map, 1)

func map_layout(enabled: bool, focused: bool) -> void:
	# Keep bright celestial bodies from washing out the existing PoI header.
	header.get_node("TextBacking").color.a = 0.92 if enabled and focused else 0.36
	model_space.visible = enabled
	sidebar.visible = not enabled or focused
	if enabled:
		model_space.size_flags_stretch_ratio = 0.48 if focused else 1.0

func _process(_delta: float) -> void:
	if ui.visible and kind == "system" and is_instance_valid(grid):
		# Fit six tiles plus the separate service button in the existing scroll area.
		var available_height: float = scroll.size.y - 14
		for child in view.get_children():
			if child != grid:
				available_height -= child.size.y + view.get_theme_constant("separation")
		for tile in grid.get_children():
			tile.minimum_height = maxf(100, available_height / 2)
	if is_instance_valid(map_layer) and is_instance_valid(body):
		map_layer.position = body.global_position - global_position
		map_layer.size = body.size


func add_action(
	text: String, callback: Callable, disabled: bool = false, height: float = 64
) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 22)
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
	title.text = "System Encounters — " + state.system_name
	resource_bar.exploration(state)
	jump_button.text = (
		"%s FTL Drive %d/%d · %s"
		% [
			icon.call("travel"),
			state.ftl_charge,
			state.required_ftl_charge,
			(
				"Jump to Next System"
				if state.ftl_charge >= state.required_ftl_charge
				else "Requires %d more charge" % (state.required_ftl_charge - state.ftl_charge)
			)
		]
	)
	if state.mandatory_boss_pending():
		jump_button.text = (
			"%s FTL Drive %d/%d · Resolve Boss first"
			% [icon.call("travel"), state.ftl_charge, state.required_ftl_charge]
		)
		jump_button.tooltip_text = "Defeat the mandatory Boss or escape by EMP Pulse before leaving this system."
	else:
		jump_button.tooltip_text = "FTL resets to zero when entering the next system."
	jump_button.disabled = not state.can_jump()
	jump_button.visible = state.hull > 0
	return_button.disabled = false


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
	if split_map and model_space.visible:
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
	return is_inside_tree() and scroll.allows_activation()


func hide_for_battle() -> void:
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
	view_revision += 1
	cancel_suspense()


func _exit_tree() -> void:
	cancel_pending()
