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
	var before: Dictionary = board._both_states()
	board.enemy_hull -= 3
	fx.play_changes(before, board._both_states(), "", "", 0, true)
	await create_timer(0.1).timeout
	check(enemy.hull_material.albedo_color != enemy.base_color, "3D hull must flash on damage")
	check(player.hull_material.albedo_color == player.base_color, "Enemy damage must not tint player")
	await fx.finished
	check(enemy.body.position == Vector3.ZERO, "Recoil must restore position")
	check(enemy.hull_material.albedo_color == enemy.base_color, "Hull tint must restore")
	before = board._both_states()
	board.enemy_shields = 5
	fx.play_changes(before, board._both_states())
	board.refresh_display()
	await create_timer(0.06).timeout
	check(enemy.shield.visible and enemy.shield_material.albedo_color.a > 0.18, "Shield gain must restore and pulse shell")
	await fx.finished
	board.hand.cards[0] = Library.CARDS[2]
	var hull_before: int = board.player_hull
	board._on_card_pressed(0)
	check(board.resolving_card and board.current_actor == "player", "Repair must delay turn advancement")
	await board.action_finished
	check(board.player_hull > hull_before, "Original repair card must still apply")
	check(board.current_actor == "enemy" and not fx.busy, "Original turn flow must resume")
	board.queue_free()
	await process_frame
	print("3D integration checks: %d failures" % failures)
	quit(1 if failures else 0)
