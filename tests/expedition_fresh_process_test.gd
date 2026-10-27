extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for mode in ["write", "enter", "resume", "ended"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/expedition_save_process.gd", "--", mode], output, true)
		var log: String = "\n".join(output)
		# Preserve successful preceding phases too, so a rare later failure is reproducible.
		print("Fresh-process phase %s, exit %d:\n%s" % [mode, code, log])
		if (mode != "enter" and code != 0) or (mode == "enter" and "Checkpoint ready for forced termination" not in log) or "SCRIPT ERROR" in log or "ERROR:" in log:
			push_error("Fresh-process failure: " + mode + "\n" + log)
			quit(1)
			return
	print("Fresh-process persistence: write, forced termination, resume, reward and permadeath passed")
	quit()
