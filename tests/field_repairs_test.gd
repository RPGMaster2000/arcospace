extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Outcome = preload("res://scripts/expedition/encounter_outcome.gd")
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(ship_index: int) -> Resource:
	var state = State.new()
	state.start(ship_index, Rules, 777)
	state.service = {"kind":"service","poi":Rules.trading_outpost,"completed":false,"title":"Trading Outpost"}
	return state
func run() -> void:
	for ship_index in range(preload("res://scripts/ships/ship_library.gd").PLAYERS.size()):
		var state = fresh(ship_index)
		var cap: int = state.ship().hull_capacity
		state.hull = cap - 9
		state.salvage = 11
		check(state.field_repair_limit() == 0 and not state.field_repair(1,state.service_revision), "Closed system view refuses field repair")
		state.field_repairs_open = true
		check(state.field_repair_limit() == 5, "Field quantity uses floor(Salvage / 2)")
		var revision: int = state.service_revision
		for amount in [-1,0,6]: check(not state.field_repair(amount,revision), "Reject invalid field quantity")
		check(state.salvage == 11 and state.hull == cap - 9, "Rejected field repair never spends")
		check(state.field_repair(4,revision) and state.salvage == 3 and state.hull == cap - 5, "Four Hull costs eight Salvage")
		check(not state.field_repair(1,revision) and state.salvage == 3, "Duplicate field confirmation refused")
		state.active_battle = 0
		check(not state.field_repair(1,state.service_revision), "No field repairs in combat")
		state.active_battle = -1
		state.pending_choice = "resource"
		check(not state.field_repair(1,state.service_revision), "No repairs during pending choices")
		state.pending_choice = ""
		state.salvage = 100
		check(state.field_repair(5,state.service_revision) and state.hull == cap, "Field repair reaches capacity")
		check(not state.field_repair(1,state.service_revision), "Field repair cannot create plating")
		state.salvage = 1
		state.hull -= 1
		check(not state.field_repair(1,state.service_revision), "One Salvage cannot buy a field point")
		# Same service slot changes state/rate without another action or resource.
		check(state.station_hull_title() == "Repair Hull", "Damaged station title")
		check(state.purchase_service(0,state.service_revision,1) and state.salvage == 0 and state.hull == cap, "Station Hull repair remains 1:1")
		check(state.station_hull_title() == "Install Ablative Plating" and state.station_hull_unit_cost() == 2, "At full Hull the same service switches to plating")
		state.salvage = 11
		revision = state.service_revision
		check(state.station_repair_limit() == 5 and not state.purchase_service(0,revision,6), "Plating affordability")
		check(state.purchase_service(0,revision,5) and state.salvage == 1 and state.hull == cap+5, "Five plating costs ten")
		check(not state.purchase_service(0,revision,1), "Station plating confirmation consumed once")
		state.salvage = 100
		check(state.station_repair_limit() == 5 and not state.purchase_service(0,state.service_revision,6), "Existing plating reduces remaining limit")
		check(state.purchase_service(0,state.service_revision,5) and state.hull == cap+10, "Purchases stop at ten plating")
		check(state.station_hull_title() == "Ablative Plating Full" and not state.purchase_service(0,state.service_revision,1), "Full plating disables the service")
		var neutral = Outcome.new()
		state._apply_outcome(neutral)
		check(state.hull == cap+10, "Noncombat neutral outcome retains plating")
		var repair = Outcome.new()
		repair.hull = 8
		state._apply_outcome(repair)
		check(state.hull == cap+10, "PoI repairs neither erase nor add plating")
		var damage = Outcome.new()
		damage.hull = -3
		state._apply_outcome(damage)
		check(state.hull == cap+7, "Agreed rule: PoI damage reduces combined Hull")
		# Actual Board initialization and all surviving result paths retain the original cap-on-sync.
		for result in ["destruction","systems","escape"]:
			state = fresh(ship_index)
			state.hull = cap+6
			state.salvage = 20
			var board = preload("res://scenes/board_3d.tscn").instantiate()
			board.setup_settings = {"player_ship":ship_index,"enemy_ship":0,"modifier":0}
			board.expedition = state
			board.get_node("BattleEffects").enabled = false
			board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
			board.get_node("CardMotion").settings.enabled = false
			root.add_child(board)
			check(board.player_hull == cap+6, "Station plating reaches battle without clamping")
			var actor: Dictionary = board.ship_snapshot("enemy")
			actor.energy = 999
			var target: Dictionary = board.ship_snapshot("player")
			target.shields = 0
			var hit = preload("res://cards/12_laser_burst.tres")
			Effects.play(hit,actor,target)
			check(target.hull == cap-3, "Laser Burst consumes six plating then its three-damage follow-up reaches Hull")
			# Leave some plating to verify that the result, not combat damage, discards it.
			board.player_hull = cap+4
			if result == "destruction": board.enemy_hull = 0
			elif result == "systems":
				board.enemy_quarters = 0
				board.enemy_reactor = 0
				board._sync_systems_failure()
				board.systems_failure.remaining.enemy = 0
			else:
				board.ftl.charge = board.ftl.charge_target
				board._warp_out()
			board._check_winner()
			board.refresh_display()
			check(board.winner == "player" and state.hull == cap, "Result discards plating: " + result)
			state.sync_battle(board.battle_result())
			check(state.hull == cap, "Returning after repairs also caps carried Hull")
			board.queue_free()
			await process_frame
	print("Field repairs and plating: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
