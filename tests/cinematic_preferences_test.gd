extends SceneTree
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if "--preference-probe" in OS.get_cmdline_user_args():
		check(Preferences.skip_cinematics(), "Preference survives a new application process")
		quit(1 if failures else 0)
		return
	Preferences.set_skip_cinematics(false)
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	menu._unhandled_input(key)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "First event never double-advances")
	key.echo = true
	menu._unhandled_input(key)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "Held-key repeats ignored")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.pressed = true
	menu._unhandled_input(emulated)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "Synthetic mouse cannot duplicate a touch")
	var settings = menu.settings_button.menu
	settings.present()
	settings.cinematics_toggle.button_pressed = true
	check(Preferences.skip_cinematics() and menu.showcase.skip_cinematics, "Setting persists and updates presentation")
	root.get_node("Music").set_enabled(false)
	root.get_node("Music").set_enabled(true)
	check(Preferences.skip_cinematics(), "Changing music preserves cinematic setting")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/cinematic_preferences_test.gd", "--", "--preference-probe"], output, true)
	check(code == 0, "Fresh-process preference validation: " + str(output))
	key.echo = false
	menu._unhandled_input(key)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "Settings input does not advance menu")
	settings.dismiss()
	menu.queue_free()
	await process_frame
	menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY and menu.showcase.logo.modulate.a == 1.0, "Re-entry skips fades and retains Press to Play")
	menu._unhandled_input(key)
	await menu.showcase.selection_ready
	check(menu.get_node("Selection").visible, "Short camera transition unlocks selection")
	menu.queue_free()
	Preferences.set_skip_cinematics(false)
	await process_frame
	print("Cinematic preferences: %d failures" % failures)
	quit(1 if failures else 0)
