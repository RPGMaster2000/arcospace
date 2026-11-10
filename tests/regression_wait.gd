extends RefCounted
## Test-only readiness fences and aggregate timings. Never changes scene settings.
static var totals: Dictionary = {}

static func record(phase: String, started: int, frames: int = 0) -> void:
	var row: Dictionary = totals.get(phase,{"phase":phase,"seconds":0.0,"calls":0,"frames":0})
	row.seconds += (Time.get_ticks_usec()-started)/1000000.0
	row.calls += 1
	row.frames += frames
	totals[phase] = row

static func report() -> void:
	for phase in totals:
		print("REGRESSION_METRIC "+JSON.stringify(totals[phase]))

static func layout(tree: SceneTree, controls: Array, ready: Callable = Callable(), timeout: float = 8.0) -> bool:
	var started := Time.get_ticks_usec()
	var previous: Array = []
	var stable := 0
	var frames := 0
	while (Time.get_ticks_usec()-started)/1000000.0 < timeout:
		await tree.process_frame
		frames += 1
		var current: Array = []
		for control in controls:
			if not is_instance_valid(control):
				record("layout_wait",started,frames)
				return false
			current.append(control.get_global_rect())
		stable = stable+1 if current == previous and (not ready.is_valid() or ready.call()) else 0
		previous = current
		if stable >= 2:
			record("layout_wait",started,frames)
			return true
	record("layout_wait",started,frames)
	return false

static func rendered(tree: SceneTree) -> void:
	var started := Time.get_ticks_usec()
	await tree.process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await tree.process_frame
	record("render_fence",started,1)

static func capture(tree: SceneTree, path: String) -> Error:
	await rendered(tree)
	var started := Time.get_ticks_usec()
	var result := tree.root.get_texture().get_image().save_png(path)
	record("screenshot_readback_encode",started)
	return result
