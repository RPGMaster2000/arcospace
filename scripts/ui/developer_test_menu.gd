extends CanvasLayer

signal launch_requested(configuration: Dictionary)

const Variation = preload("res://scripts/expedition/system_variation.gd")
const Warfare = preload("res://scripts/expedition/defense_warfare.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Launch = preload("res://scripts/expedition/developer_launch.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")

static var last_configuration := {"mode": "warzone", "stage": 1, "rank": -1}
var ship_name: String
var mode: OptionButton
var stage: OptionButton
var difficulty: OptionButton
var formation: OptionButton
var faction: OptionButton
var environment: OptionButton
var system_size: OptionButton
var home_region: OptionButton
var binary: OptionButton
var expedition_seed: LineEdit
var setup_rows: VBoxContainer
var geography_rows: VBoxContainer
var geography_button: Button
var launch_button: Button
var back_button: Button
var _previous_focus: Control
var _was_paused := false
var _was_back_quit := true
var _open := false


func _ready() -> void:
	layer = 221
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 430
	panel.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Developer Testing"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	var summary := Label.new()
	summary.text = "Unsaved session · Selected ship: %s" % ship_name
	column.add_child(summary)
	setup_rows = VBoxContainer.new()
	column.add_child(setup_rows)
	geography_rows = VBoxContainer.new()
	column.add_child(geography_rows)
	geography_rows.hide()
	mode = _selector(setup_rows, "Game Mode", Launch.MODE_LABELS, Launch.MODES.find(last_configuration.mode))
	var stages: Array = []
	for number in range(1, Launch.MAX_STAGE + 1):
		stages.append("System %d" % number)
	stage = _selector(setup_rows, "Expedition Stage", stages, int(last_configuration.stage) - 1)
	difficulty = _selector(setup_rows, "Enemy Difficulty", ["Automatic", "Tier 1", "Tier 2", "Tier 3"],
		int(last_configuration.rank) + 1)
	var formation_ids: Array = [""] + Warfare.FORMATIONS
	formation = _selector(setup_rows, "Formation", ["Automatic"] + Warfare.NAMES,
		formation_ids.find(last_configuration.get("formation", "")))
	var faction_ids: Array = Factions.DEFAULTS.map(func(profile): return profile.id)
	faction = _selector(setup_rows, "Enemy Faction", ["Automatic"] + Factions.DEFAULTS.map(func(profile): return profile.display_name),
		faction_ids.find(last_configuration.get("faction", "")) + 1)
	mode.item_selected.connect(func(_index): _update_scenario_selectors())
	stage.item_selected.connect(func(_index): _update_scenario_selectors())
	var environment_labels := Variation.ARCHETYPES.map(func(key): return key.replace("_", " ").capitalize())
	environment = _selector(geography_rows, "Environment", ["Automatic"] + environment_labels,
		Variation.ARCHETYPES.find(last_configuration.get("environment", "")) + 1)
	system_size = _selector(geography_rows, "System Size", ["Automatic"] + Variation.SIZE_CLASSES,
		Variation.SIZE_CLASSES.find(last_configuration.get("size_class", "")) + 1)
	home_region = _selector(geography_rows, "Homeworld Region", ["Automatic"] + Variation.HOME_REGIONS,
		Variation.HOME_REGIONS.find(last_configuration.get("home_region", "")) + 1)
	binary = _selector(geography_rows, "Stellar Configuration", ["Automatic", "Single", "Binary"],
		int(last_configuration.get("binary", -1)) + 1)
	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Expedition Seed"
	seed_label.custom_minimum_size.x = 150
	seed_row.add_child(seed_label)
	expedition_seed = LineEdit.new()
	expedition_seed.accessibility_name = seed_label.text
	expedition_seed.placeholder_text = "Random"
	expedition_seed.text = last_configuration.get("seed", "")
	expedition_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_seed.custom_minimum_size.y = 36
	expedition_seed.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_row.add_child(expedition_seed)
	geography_rows.add_child(seed_row)
	for selector in [environment, system_size, home_region, binary]:
		selector.custom_minimum_size.y = 36
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	back_button = _action(actions, "Back", close)
	geography_button = _action(actions, "Environment & Seed", _toggle_geography)
	_update_scenario_selectors()
	launch_button = _action(actions, "Launch Test", _launch_selected, true)
	# Keep keyboard focus inside the modal, including when wrapping past the buttons.
	mode.focus_previous = mode.get_path_to(launch_button)
	launch_button.focus_next = launch_button.get_path_to(mode)

	_previous_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	_was_back_quit = get_tree().quit_on_go_back
	get_tree().paused = true
	get_tree().quit_on_go_back = false
	_open = true
	mode.grab_focus()


func _selector(column: VBoxContainer, caption: String, choices: Array, selected: int) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var selector := OptionButton.new()
	selector.accessibility_name = caption
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.y = 48
	for choice in choices:
		selector.add_item(choice)
	selector.get_popup().add_theme_constant_override("v_separation", 12)
	selector.select(selected)
	Presentation.action(selector)
	row.add_child(selector)
	return selector


func _action(row: HBoxContainer, caption: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Presentation.action(button, primary)
	row.add_child(button)
	button.pressed.connect(action)
	return button


func _update_scenario_selectors() -> void:
	var defense: bool = Launch.MODES[mode.selected] == "defense"
	for selector in [environment, system_size, home_region, binary]:
		selector.get_parent().visible = defense and stage.selected >= 2
	geography_button.text = "Environment & Seed" if defense and stage.selected >= 2 else "Seed"
	faction.get_parent().visible = defense
	formation.get_parent().visible = defense and stage.selected >= 2
	for index in Warfare.FORMATIONS.size():
		formation.set_item_disabled(index + 1, not Warfare.available_formation(Warfare.FORMATIONS[index], stage.selected + 1))
	if formation.is_item_disabled(formation.selected): formation.select(0)
	if formation.get_parent().visible:
		for selector in [mode, stage, difficulty, formation, faction]:
			selector.custom_minimum_size.y = 40
	else:
		for selector in [mode, stage, difficulty, formation, faction]:
			selector.custom_minimum_size.y = 48


func _toggle_geography() -> void:
	geography_rows.visible = not geography_rows.visible
	setup_rows.visible = not geography_rows.visible
	if geography_rows.visible:
		geography_button.text = "Scenario Options"
	else:
		_update_scenario_selectors()
		mode.grab_focus()


func _launch_selected() -> void:
	if not _open:
		return
	var seed_text := expedition_seed.text.strip_edges()
	if not seed_text.is_empty() and (not seed_text.is_valid_int() or int(seed_text) == 0):
		if not geography_rows.visible: _toggle_geography()
		expedition_seed.placeholder_text = "Enter a nonzero integer"
		expedition_seed.clear()
		expedition_seed.grab_focus()
		return
	var overrides := {"seed":seed_text, "binary":binary.selected - 1}
	if environment.selected > 0: overrides.environment = Variation.ARCHETYPES[environment.selected - 1]
	if system_size.selected > 0: overrides.size_class = Variation.SIZE_CLASSES[system_size.selected - 1]
	if home_region.selected > 0: overrides.home_region = Variation.HOME_REGIONS[home_region.selected - 1]
	last_configuration = Launch.configuration(Launch.MODES[mode.selected], stage.selected + 1, difficulty.selected - 1,
		Warfare.FORMATIONS[formation.selected - 1] if formation.selected > 0 else "",
		Factions.DEFAULTS[faction.selected - 1].id if faction.selected > 0 else "", overrides)
	close()
	launch_requested.emit(last_configuration.duplicate())


func close() -> void:
	if not _open:
		return
	_restore_input()
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	queue_free()


func _restore_input() -> void:
	if _open:
		_open = false
		get_tree().paused = _was_paused
		get_tree().quit_on_go_back = _was_back_quit


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open:
		for selector in [mode, stage, difficulty, formation, faction, environment, system_size, home_region, binary]:
			if selector.get_popup().visible:
				selector.get_popup().hide()
				return
		close()


func _exit_tree() -> void:
	_restore_input()
