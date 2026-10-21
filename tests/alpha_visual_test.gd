extends SceneTree
const Settings = preload("res://resources/visual/alpha_visual_settings.tres")
const Ships = preload("res://scripts/ships/ship_library.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/alpha-" + name + ".png")


func run() -> void:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	for frame in range(12):
		await process_frame
	var card = board.get_node(board.card_slots[0])
	var base_scale: Vector2 = card.scale
	var base_position: Vector2 = card.position
	card.mouse_entered.emit()
	await create_timer(Settings.card_hover_duration + 0.05).timeout
	check(
		card.get_node("ArtPlaceholder").scale.is_equal_approx(
			Vector2.ONE * Settings.card_hover_scale
		),
		"Hover zoom uses shared configuration"
	)
	card.button_down.emit()
	await create_timer(Settings.card_selected_duration + 0.05).timeout
	check(
		card.get_node("ArtPlaceholder").scale.is_equal_approx(
			Vector2.ONE * Settings.card_selected_scale
		),
		"Pressed selection is stronger"
	)
	check(
		card.scale == base_scale and card.position == base_position,
		"Feedback preserves card layout/input transform"
	)
	await capture("card-selected")
	card.mouse_exited.emit()
	await create_timer(Settings.card_hover_duration + 0.05).timeout
	check(
		card.get_node("ArtPlaceholder").scale.is_equal_approx(Vector2.ONE),
		"Interrupted selection resets smoothly"
	)
	var ship = board.get_node("BattleView/Viewport/Battlefield/PlayerShip")
	var canvas_before: Transform2D = root.canvas_transform
	var before: Dictionary = board._both_states()
	var after: Dictionary = before.duplicate(true)
	after.player.shields -= 2
	board.battle_effects.enabled = true
	board.battle_effects.play_changes(before, after, "", "", 0, true)
	await create_timer(0.05).timeout
	check(root.canvas_transform != canvas_before, "Shield damage produces a small screen shake")
	await board.battle_effects.finished
	check(root.canvas_transform == canvas_before, "Shield screen shake restores the viewport")
	board.battle_effects.enabled = false
	var origin: Vector3 = ship.body.position
	var tween = ship.create_tween()
	ship.animate_hit(tween, false, 0.25)
	await create_timer(0.08).timeout
	check(ship.body.position.is_equal_approx(origin), "Shield-only impact has no hull recoil")
	await tween.finished
	for shield_hit in [false, true]:
		tween = ship.create_tween()
		ship.animate_hit(tween, true, 0.35)
		if shield_hit:
			ship.animate_shield(ship.create_tween(), 0.35)
		await create_timer(0.07).timeout
		check(
			ship.hull_material.albedo_color != ship.base_color,
			"Hull flash appears for hull/combined damage"
		)
		await capture("combined-hit" if shield_hit else "hull-hit")
		await tween.finished
		await process_frame
		check(
			(
				ship.body.position.is_equal_approx(origin)
				and ship.hull_material.albedo_color == ship.base_color
			),
			"Hit restores hull transform/color"
		)
		check(
			is_zero_approx(float(ship.shield_material.get_shader_parameter("hit"))),
			"Ripple resets after impact"
		)
	board.winner = "player"
	board.enemy_hull = 0
	board.refresh_display()
	var reveal: Tween = board.get_node("MatchResult/Panel/Title").get_meta("visual_reveal")
	board.refresh_display()
	check(
		board.get_node("MatchResult/Panel/Title").get_meta("visual_reveal") == reveal,
		"Repeated HUD refresh does not restart heading animation"
	)
	await create_timer(Settings.result_heading_duration + 0.1).timeout
	await capture("victory")
	board.free()
	await process_frame
	var loss = load("res://scenes/board_3d.tscn").instantiate()
	loss.get_node("BattleEffects").enabled = false
	root.add_child(loss)
	loss.enemy_timer.stop()
	loss.player_hull = 0
	loss.winner = "enemy"
	loss.refresh_display()
	await create_timer(Settings.result_heading_duration + 0.1).timeout
	check(
		(
			loss.get_node("MatchResult/Panel/Title").get_theme_color("font_color")
			== Settings.defeat_accent_color
		),
		"Defeat has its own configured accent"
	)
	check(
		(
			loss.get_node("MatchResult/Panel/Configure").visible
			and not loss.get_node("MatchResult/Panel/Continue").visible
		),
		"Defeat preserves existing navigation"
	)
	await capture("defeat")
	loss.free()
	await process_frame
	var previous: StandardMaterial3D
	for profile in Ships.PLAYERS:
		var model = profile.model_scene.instantiate()
		root.add_child(model)
		check(model.engine_materials.size() > 0, profile.ship_name + ": engine geometry discovered")
		var material: StandardMaterial3D = model.engine_materials[0]
		check(material != previous, profile.ship_name + ": independently editable engine material")
		previous = material
		await process_frame
		check(
			material.emission == model.engine_colors[0],
			profile.ship_name + ": authored engine color preserved"
		)
		model.engine_boost = true
		await create_timer(Settings.engine_ftl_transition_duration + 0.05).timeout
		check(
			is_equal_approx(model.engine_multiplier, Settings.engine_ftl_multiplier),
			profile.ship_name + ": escape boost reaches configured multiplier"
		)
		model.engine_boost = false
		await create_timer(Settings.engine_ftl_transition_duration + 0.05).timeout
		check(is_equal_approx(model.engine_multiplier, 1.0), profile.ship_name + ": boost resets")
		model.free()
	var flash = preload("res://scripts/ui/outcome_flash.gd").new()
	root.add_child(flash)
	flash.play(true)
	check(
		flash.duration == Settings.poi_reveal_duration and flash.active,
		"POI pulse uses configured duration"
	)
	flash.free()
	await process_frame
	check(true, "Closing an active POI pulse releases its waiter without errors")
	print("Alpha visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
