extends SceneTree
const Feedback = preload("res://scripts/presentation/star_system/map_feedback.gd")
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var canvas := Control.new()
	canvas.size = Vector2(1280,720)
	root.add_child(canvas)
	var camera := Camera3D.new()
	root.add_child(camera)
	var ship := Node3D.new()
	ship.position = Vector3(3,0,-20)
	root.add_child(ship)
	var world := Node3D.new()
	root.add_child(world)
	var feedback := Feedback.new()
	feedback.canvas = canvas
	feedback.camera = camera
	feedback.ship = ship
	world.add_child(feedback)
	feedback._process(0.2)
	check(feedback.position == ship.position, "Locator follows actual ship position")
	var phase: float = feedback.locator_phase
	feedback._process(0.2)
	check(feedback.locator_phase != phase and feedback.identification.visible, "Stationary player locator pulses")
	feedback.update_direction(Vector2(1400,300))
	check(feedback.direction_arrow.visible and feedback.direction_arrow.position.x <= 1252, "Offscreen player receives safe edge indicator")
	feedback.update_direction(Vector2(1270,300))
	check(feedback.direction_arrow.visible, "Viewport boundary hysteresis avoids flicker")
	feedback.update_direction(Vector2(640,360))
	check(not feedback.direction_arrow.visible, "Visible ship hides offscreen arrow")
	feedback.suppressed = true
	feedback.update_direction(Vector2(-100,300))
	check(not feedback.direction_arrow.visible, "Scripted cinematic suppresses player arrow")
	feedback.suppressed = false
	for dimensions in [Vector2(960,540),Vector2(1920,1080),Vector2(1024,600)]:
		canvas.size = dimensions
		feedback.update_direction(Vector2(-100,300))
		check(feedback.direction_arrow.position.x >= feedback.arrow_margin.x and feedback.direction_arrow.position.y <= dimensions.y-feedback.arrow_margin.w, "Resized arrow clears existing action/status areas")
	check(feedback.direction_arrow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Locator never captures mouse or touch input")
	feedback.free()
	check(not is_instance_valid(feedback), "Locator cleanup completes")
	world.free()
	canvas.free()
	ship.free()
	camera.free()
	print("Weekend player locator: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
