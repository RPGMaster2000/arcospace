extends SceneTree
# Integration smoke test: real card resolution with the optional 3D presentation.
const Scene = preload("res://scenes/board_3d.tscn")
const Library = preload("res://scripts/card_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var board = Scene.instantiate()
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	var fx = board.battle_effects
	if fx.busy:
		await fx.finished
	board.enemy_timer.wait_time = 60
	var field = board.get_node("BattleView/Viewport/Battlefield")
	var player = field.get_node("PlayerShip")
	var enemy = field.get_node("EnemyShip")
	check(player.hull_material != enemy.hull_material, "Ships need independent materials")
	board.enemy_shields = 0
	board.refresh_display()
	check(not enemy.shield.visible, "Zero shields must be invisible")
	for strength in [20, 10, 5, 1, 0]:
		enemy.set_shield_strength(strength)
		check(is_equal_approx(float(enemy.shield_material.get_shader_parameter("strength")), minf(strength / 10.0, 1.0)), "Shield opacity must follow strength below ten")
	var before: Dictionary = board._both_states()
	board.enemy_hull -= 3
	fx.play_changes(before, board._both_states(), "", "", 0, true)
	await create_timer(0.1).timeout
	check(enemy.get_node("Body/Hull").get_child_count() == 5, "Unshielded damage must spawn hull explosions")
	check(enemy.hull_material.albedo_color != enemy.base_color, "3D hull must flash on damage")
	check(player.hull_material.albedo_color == player.base_color, "Enemy damage must not tint player")
	await fx.finished
	await process_frame
	check(enemy.get_node("Body/Hull").get_child_count() == 0, "Explosions must clean up")
	check(enemy.body.position == Vector3.ZERO, "Recoil must restore position")
	check(enemy.hull_material.albedo_color == enemy.base_color, "Hull tint must restore")
	before = board._both_states()
	board.enemy_shields = 5
	fx.play_changes(before, board._both_states())
	board.refresh_display()
	await create_timer(0.06).timeout
	check(enemy.shield.visible and float(enemy.shield_material.get_shader_parameter("formation")) < 1.0, "Shield gain must restore and pulse shell")
	await fx.finished
	board.hand.cards[0] = Library.CARDS[2]
	var hull_before: int = board.player_hull
	board._on_card_pressed(0)
	check(board.resolving_card and board.current_actor == "player", "Repair must delay turn advancement")
	await board.action_finished
	check(board.player_hull > hull_before, "Original repair card must still apply")
	check(board.current_actor == "enemy" and not fx.busy, "Original turn flow must resume")
	await create_timer(0.25).timeout
	var banner = board.get_node("EnemyTurnBanner")
	var card = board.get_node(board.card_slots[0])
	check(is_equal_approx(card.modulate.r, 0.48) and is_equal_approx(banner.modulate.a, 1.0), "Enemy turn must dim hand and show banner")
	board.enemy_timer.stop()
	board.current_actor = "player"
	board.refresh_display()
	await create_timer(0.08).timeout
	check(card.modulate.r > 0.48 and card.modulate.r < 1.0, "Return to player must fade rather than snap")
	await create_timer(0.2).timeout
	check(card.modulate == Color.WHITE and is_zero_approx(banner.modulate.a), "Player turn restores hand and hides banner")
	# A hull-only repair must never start a shield animation.
	before = board._both_states()
	board.player_hull += 1
	fx.play_changes(before, board._both_states())
	await create_timer(0.1).timeout
	check(float(player.repair_material.get_shader_parameter("progress")) > 0.0, "Repair sweep must advance")
	check(float(player.shield_material.get_shader_parameter("formation")) == 1.0, "Hull repair must leave shield alone")
	await fx.finished
	check(float(player.repair_material.get_shader_parameter("progress")) == -1.0, "Repair sweep must reset")
	board.queue_free()
	await process_frame
	print("3D integration checks: %d failures" % failures)
	quit(1 if failures else 0)
