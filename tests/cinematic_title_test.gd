extends SceneTree
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main_menu_3d.tscn").instantiate()
	root.add_child(scene)
	check(scene.background_fade_duration == 2.0 and scene.logo_fade_duration == 2.0, "Two-second fade defaults")
	check(scene.phase == scene.Phase.INTRO_BACKGROUND and scene.curtain.color.a == 1.0, "Begins black")
	scene.advance()
	check(scene.phase == scene.Phase.PRESS_TO_PLAY and scene.logo.modulate.a == 1.0 and scene.prompt.visible, "Early press finishes intro only")
	scene.camera_transition_duration = 0.02
	scene.advance()
	scene.advance()
	check(scene.phase == scene.Phase.CAMERA_TRANSITION, "Repeated input cannot overlap transition")
	await create_timer(0.6).timeout
	check(scene.phase == scene.Phase.SHIP_SELECTION and scene.camera.transform.is_equal_approx(scene.selection_anchor.transform), "Authored camera destination reached")
	scene.queue_free()
	await process_frame
	print("Cinematic title: %d failures" % failures)
	quit(1 if failures else 0)
