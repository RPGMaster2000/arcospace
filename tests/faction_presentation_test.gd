extends SceneTree
const Catalog = preload("res://scripts/expedition/faction_catalog.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for profile in Catalog.DEFAULTS:
		var host = load("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.play_system_intro = false
		host.rules = host.rules.duplicate(true)
		host.rules.game_mode = "defense"
		host.rules.factions.assign([profile])
		host.rules.debug_seed = 4242
		host.rules.log_rolls = false
		root.add_child(host)
		for size in [Vector2i(960, 540), Vector2i(1280, 573)]:
			root.size = size
			for frame in range(8):
				await process_frame
			var hud = host.screen.overview_hud
			check(
				(
					hud.faction_label.is_visible_in_tree()
					and hud.faction_label.text == profile.display_name
				),
				"Actual overview displays controlling faction"
			)
			check(
				hud.faction_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Label does not intercept map input"
			)
			check(
				hud.panels[0].get_global_rect().end.x < hud.panels[3].get_global_rect().position.x,
				"Faction fits beside existing controls"
			)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/factions")
				root.get_texture().get_image().save_webp(
					(
						"res://.godot/testlogs/factions/%s-%s-%d.webp"
						% [RenderingServer.get_current_rendering_method(), profile.id, size.x]
					)
				)
		host.free()
		await process_frame
	print("Faction presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
