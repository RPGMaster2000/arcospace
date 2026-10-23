extends CanvasLayer

# RESPONSIBILITY: Present audio/settings controls and pause gameplay while open.
# DOES NOT: Reset an expedition; the owning screen handles main_menu_requested.
signal cinematics_changed(enabled: bool)
signal main_menu_requested
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var is_main_menu: bool = false
var save_quit_action: Callable
var battle_restart_notice: bool = false
var _quit_after_save: bool = false
var shade: ColorRect
var panel: PanelContainer
var close_button: Button
var music_volume: HSlider
var sfx_volume: HSlider
var music_toggle: CheckButton
var cinematics_toggle: CheckButton
var main_menu_button: Button
var quit_button: Button
# Future settings belong here; the body already scrolls on compact displays.
var extra_settings: VBoxContainer
var _margin: MarginContainer
var _previous_focus: Control
var _was_paused: bool = false
var _owns_pause: bool = false
var _music: Node
var _sfx: Node


func _ready() -> void:
	layer = 220
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = get_node("/root/Music")
	_sfx = get_node("/root/Sfx")
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	shade.add_child(panel)
	_margin = MarginContainer.new()
	panel.add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = _button("Close")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(close_button)
	close_button.pressed.connect(dismiss)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var audio := Label.new()
	audio.text = "Audio"
	audio.add_theme_font_size_override("font_size", 22)
	body.add_child(audio)
	music_toggle = CheckButton.new()
	music_toggle.text = "Music"
	music_toggle.custom_minimum_size.y = 52
	music_toggle.add_theme_font_size_override("font_size", 22)
	body.add_child(music_toggle)
	extra_settings = VBoxContainer.new()
	extra_settings.add_theme_constant_override("separation", 14)
	body.add_child(extra_settings)
	music_volume = _volume_slider("Music Volume", _music.volume, _music.set_volume)
	sfx_volume = _volume_slider("Sound Effects Volume (0 = mute)", _sfx.volume, _sfx.set_volume)
	cinematics_toggle = CheckButton.new()
	cinematics_toggle.text = "Skip Cinematics"
	cinematics_toggle.custom_minimum_size.y = 52
	cinematics_toggle.add_theme_font_size_override("font_size", 22)
	cinematics_toggle.set_pressed_no_signal(Preferences.skip_cinematics())
	extra_settings.add_child(cinematics_toggle)
	cinematics_toggle.toggled.connect(func(enabled: bool):
		if Preferences.set_skip_cinematics(enabled) == OK:
			cinematics_changed.emit(enabled)
		else:
			cinematics_toggle.set_pressed_no_signal(not enabled)
			var notice := AcceptDialog.new()
			notice.dialog_text = "Could not save the cinematic preference."
			notice.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(notice)
			notice.confirmed.connect(notice.queue_free)
			notice.popup_centered(Vector2i(460, 160)))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	main_menu_button = _button("Main Menu")
	main_menu_button.disabled = is_main_menu
	main_menu_button.tooltip_text = "Already in the main menu" if is_main_menu else "Return to ship selection"
	actions.add_child(main_menu_button)
	main_menu_button.pressed.connect(_request_main_menu)
	quit_button = _button("Quit Game")
	quit_button.disabled = OS.has_feature("web")
	if quit_button.disabled:
		quit_button.tooltip_text = "Close the browser tab to quit."
	actions.add_child(quit_button)
	quit_button.pressed.connect(_request_quit)
	music_toggle.toggled.connect(_music.set_enabled)
	_music.enabled_changed.connect(_sync_music)
	_sync_music(_music.enabled)
	shade.resized.connect(_fit)
	_fit()
	shade.hide()


func _volume_slider(caption: String, value: float, change: Callable) -> HSlider:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 20)
	extra_settings.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 40)
	slider.tooltip_text = caption
	slider.value_changed.connect(change)
	extra_settings.add_child(slider)
	return slider


func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(100, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 21)
	Presentation.action(button)
	return button


func _fit() -> void:
	# TUNE: 860 x 600 is the roomy desktop panel; 24-pixel outer margins fit small screens.
	panel.size = Vector2(minf(860, shade.size.x - 48), minf(600, shade.size.y - 48))
	panel.position = (shade.size - panel.size) * 0.5
	for edge in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + edge, 12 if shade.size.y < 480 else 24)


func present() -> void:
	if shade.visible:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	_owns_pause = true
	get_tree().paused = true
	_sync_music(_music.enabled)
	cinematics_toggle.set_pressed_no_signal(Preferences.skip_cinematics())
	music_volume.set_value_no_signal(_music.volume)
	sfx_volume.set_value_no_signal(_sfx.volume)
	shade.show()
	_fit()
	close_button.grab_focus()


func dismiss() -> void:
	shade.hide()
	_restore_pause()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


func _restore_pause() -> void:
	if _owns_pause:
		get_tree().paused = _was_paused
		_owns_pause = false


func _exit_tree() -> void:
	_restore_pause()


func _sync_music(enabled: bool) -> void:
	music_toggle.set_pressed_no_signal(enabled)


func configure_save_quit(action: Callable, in_battle: bool = false) -> void:
	save_quit_action = action
	battle_restart_notice = in_battle
	main_menu_button.text = "Save & Quit"
	main_menu_button.tooltip_text = "Return to the main menu after saving expedition progress"
	close_button.text = "Resume"


func _request_main_menu() -> void:
	if save_quit_action.is_valid():
		if battle_restart_notice:
			var notice := ConfirmationDialog.new()
			notice.dialog_text = "Your current battle will restart when you continue."
			notice.ok_button_text = "Save & Quit"
			notice.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(notice)
			notice.confirmed.connect(func(): _run_save_quit(); notice.queue_free())
			notice.canceled.connect(func(): _quit_after_save = false; notice.queue_free())
			notice.popup_centered(Vector2i(460, 160))
		else:
			_run_save_quit()
		return
	if main_menu_button.disabled:
		return
	dismiss()
	main_menu_requested.emit()


func _run_save_quit() -> void:
	var quit_after: bool = _quit_after_save
	_quit_after_save = false
	if save_quit_action.call() and quit_after:
		get_tree().quit()


func _request_quit() -> void:
	if save_quit_action.is_valid():
		_quit_after_save = true
		_request_main_menu()
	else:
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if not shade.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		var controls: Array[Control] = [close_button, music_toggle]
		for control in extra_settings.find_children("*", "Control", true, false):
			if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
				if not control is BaseButton or not control.disabled:
					controls.append(control)
		if not main_menu_button.disabled:
			controls.append(main_menu_button)
		if not quit_button.disabled:
			controls.append(quit_button)
		var current: int = controls.find(get_viewport().gui_get_focus_owner())
		controls[posmod(current + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()
