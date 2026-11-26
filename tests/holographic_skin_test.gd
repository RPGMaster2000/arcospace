extends SceneTree

const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var failures := 0
var checks := 0
var activations := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error(description)


func frames() -> void:
	for i in 5: await process_frame


func mouse_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func run() -> void:
	var original := Preferences.ui_motion()
	Preferences.set_ui_motion(1)
	var scene := preload("res://scenes/tools/holographic_showcase.tscn").instantiate()
	root.size = Vector2i(940, 530)
	root.add_child(scene)
	await frames()
	check(scene.is_visible_in_tree() and scene._section.get_child_count() == 6, "Independent showcase renders all panel variants")
	var replacement := Holo.DEFAULT.duplicate(true) as Holo.Settings
	var image := Image.create_empty(96, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color("82dcf7"))
	var texture := ImageTexture.create_from_image(image)
	replacement.frames["panel"] = texture
	replacement.frames["button.pressed"] = texture
	replacement.slice_margins = Vector4(8, 10, 11, 9)
	var frame := Holo.frame("panel", Color.TRANSPARENT, "", replacement)
	check(frame.frame_texture != null and frame.frame_texture.texture == texture, "Panel uses assigned artwork")
	check(frame.frame_texture.get_texture_margin(SIDE_RIGHT) == 11 and frame.get_margin(SIDE_LEFT) == 16,
		"Nine-slice cuts and content margins are independent")
	check(Holo.frame("panel").frame_texture == null, "Default Resource retains procedural drawing")

	var button := Button.new()
	button.text = "Intercept"
	button.position = Vector2(25, 38)
	button.size = Vector2(150, 50)
	root.add_child(button)
	Holo.action(button, Color.TRANSPARENT, false, replacement)
	Motion.bind_button(button)
	Motion.bind_button(button)
	button.pressed.connect(func(): activations += 1)
	check(button.get_theme_stylebox("pressed").frame_texture.texture == texture and
		button.get_theme_stylebox("normal").frame_texture == null, "Missing button states use procedural fallback")
	var flare: Panel = button.get_node("HolographicResponse")
	await frames()
	await mouse_click(button.get_global_rect().get_center())
	check(activations == 1 and flare.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Decorative overlay leaves native mouse input available")
	button.button_down.emit()
	var press: Tween = flare.get_meta("holo_response")
	button.button_up.emit()
	check(not press.is_running() and flare.get_meta("holo_response") != press, "Release replaces the interrupted press tween")
	button.hide()
	check(not flare.has_meta("holo_response") and flare.self_modulate.a == 0.0, "Hidden button cancels and clears feedback")

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.position = Vector2(25, 130)
	bar.size = Vector2(180, 10)
	var meter := Meter.attach(bar, Holo.DEFAULT.shield)
	root.add_child(bar)
	bar.value = 40
	var first: Tween = meter.get_meta("holo_meter")
	bar.value = 40
	check(meter.get_meta("holo_meter") == first, "A repeated gauge value keeps its existing tween")
	bar.value = 78
	check(bar.value == 78 and not first.is_running(), "A new gauge target replaces presentation independently of exact status")
	var latest: Tween = meter.get_meta("holo_meter")
	latest.custom_step(1.0)
	check(is_equal_approx(meter.display_ratio, bar.ratio), "Animated gauge lands exactly on the latest value")
	Preferences.set_ui_motion(0)
	bar.value = 26
	Motion.reveal(scene)
	check(is_equal_approx(meter.display_ratio, 0.26) and not meter.has_meta("holo_meter"), "Minimal snaps gauges and removes pending motion")
	check(scene.modulate.a == 1.0 and not scene.has_meta("holo_panel"), "Minimal leaves modal contents immediately available")
	Preferences.set_ui_motion(2)
	check(Motion.duration(0.2, true) > Motion.duration(0.2), "Cinematic strengthens decorative motion only")

	var state := State.new()
	state.start(0, Rules, 42)
	var saved := Save.encode(state)
	var overlay := preload("res://scripts/ui/info_overlay.gd").new()
	root.add_child(overlay)
	overlay.show_text("Systems ready")
	var opening: Tween = overlay.panel.get_meta("holo_panel")
	overlay.dismiss()
	check(not opening.is_running() and not overlay.shade.visible, "Dialog closes immediately during its opening")
	overlay.show_text("Systems ready")
	check(overlay.shade.visible and overlay.panel.has_meta("holo_panel"), "Dialog reopens with independent feedback")
	check(Save.encode(state) == saved, "Motion and asset selection do not affect expedition state or RNG")
	overlay.free()
	bar.free()
	button.free()
	scene.free()
	Preferences.set_ui_motion(original)
	await process_frame
	print("Holographic skin: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
