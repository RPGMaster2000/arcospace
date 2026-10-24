extends SceneTree
const Scene = preload("res://scenes/board.tscn")
const AI = preload("res://scripts/enemy_ai.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
class Probe extends Node:
	var received: Dictionary = {}
	func choose(_cards: Array, _actor: Dictionary, _target: Dictionary, context: Dictionary = {}) -> Dictionary:
		received = context.duplicate(true)
		return {"slot":-1,"discard":false} # Capture only; Board rejects this test slot without advancing a turn.
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for restart in range(2):
		var board = Scene.instantiate()
		board.setup_settings = {"modifier":0}
		board.get_node("BattleEffects").enabled = false
		board.get_node("CardMotion").settings.enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		var probe = Probe.new()
		board.add_child(probe)
		board.enemy_ai = probe
		for kind in [2,3,4,0,5]:
			board.modifier.configure(kind,123)
			var moments: Array = [0,board.modifier.next_round,board.modifier.next_round+board.modifier.ACTIVE_ROUNDS]
			for moment in moments:
				if moment > 0: board.modifier.begin_round(moment)
				if kind == 2 and moment > 0: board.modifier.ion_factor = 0.5 if moment == moments[1] else 1.0
				var expected: Dictionary = board.modifier.forecast_context()
				var rng: int = board.modifier.rng.state
				board.current_actor = "enemy"
				board._on_enemy_timeout()
				check(probe.received == expected,"Board captures current context after activation/expiry/change/restart")
				check(board.modifier.rng.state == rng,"Context handoff never consumes modifier RNG")
				board.enemy_timer.stop()
		board.queue_free()
		await process_frame
	var ai = AI.new()
	var actor: Dictionary = Ship.new().snapshot()
	var target: Dictionary = Ship.new().snapshot()
	for key in Ship.RESOURCES: actor[key] = 40
	actor.hull = 4
	actor.shields = 12
	target.hull = 40
	target.shields = 12
	ai.rng.seed = 7
	check(ai.choose([Cards.CARDS[40],Cards.CARDS[0]],actor,target,{"kind":2,"active":true,"ion_factor":2.0}) == {"slot":1,"discard":false},"Ion doubled Collapse cannot be selected over a safe card")
	check(ai.choose([Cards.CARDS[43],Cards.CARDS[0]],actor,target,{"kind":3,"active":true}) == {"slot":1,"discard":false},"Flare cannot use stored Shields to survive self-damage")
	check(ai.choose([Cards.CARDS[41]],actor,target,{"kind":4,"miss_rate":30}).discard,"Fatal direct self-damage remains unsafe even on a Nebula miss")
	ai.free()
	print("Forecast scene/safety: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
