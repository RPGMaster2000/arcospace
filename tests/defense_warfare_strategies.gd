extends SceneTree
## Map-only stress diagnostic. Contacts use the real sweep; each card battle assumes a win.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Warfare = preload("res://scripts/expedition/defense_warfare.gd")
const Result = preload("res://scripts/combat/battle_result.gd")
const STRATEGIES := ["nearest", "dangerous", "nearby_poi", "turrets", "decoys", "economic", "early_boss", "detours"]


func _initialize() -> void:
	var rules := Rules.duplicate()
	rules.system_variety = Rules.system_variety.duplicate()
	rules.defense_tuning = Rules.defense_tuning.duplicate()
	rules.defense_tuning.convoy_enabled = "--no-convoy" not in OS.get_cmdline_user_args()
	rules.system_variety.progressive_geometry = "--legacy-geography" not in OS.get_cmdline_user_args()
	rules.system_variety.extreme_weather = "--legacy-weather" not in OS.get_cmdline_user_args()
	for strategy in STRATEGIES:
		var groups := {}
		for mode in Warfare.FORMATIONS:
			groups[mode] = {"runs":0, "secured":0, "lost":0, "damage":0, "pressure":0.0, "reveal":0, "advance":0, "waves":0, "battles":0, "completion_time":0.0, "preparations":0,
				"salvage_from_pois":0, "production_from_pois":0, "hazardous_battles":0, "unresolved_legs":0}
		for stage in [3, 4, 5]:
			for seed_value in range(31, 49):
				var run := State.new()
				run.start(seed_value % 6, rules, seed_value, {"mode":"defense","stage":stage,"rank":-1})
				var row: Dictionary = groups[run.defense.military.formation]
				play(run, strategy, row)
		print("STARFRONT_STRATEGY ", strategy, " ", JSON.stringify(groups))
	quit()


func play(run: Resource, policy: String, row: Dictionary) -> void:
	var fleet: RefCounted = run.defense
	var spent := 0.0
	var report_id := 0
	var prepared := false
	row.runs += 1
	if policy == "turrets":
		run.salvage += 2 * fleet.tuning.turret_salvage_cost
		for id in ["flank_a", "flank_b", "home"]:
			run.deploy_turret(id)
	if policy == "decoys": run.decoys = 2
	var player: Vector3 = fleet.start
	for step in 160:
		if fleet.complete or fleet.failed() or spent > 210.0: break
		if policy == "decoys" and fleet.decoy.is_empty() and run.decoys > 0:
			for angle in 12:
				var at := player + Vector3(5, 0, 0).rotated(Vector3.UP, TAU * angle / 12.0)
				if not fleet.decoy_targets(at, fleet.tuning.decoy_attraction_radius).is_empty() and run.deploy_decoy(at):
					break
		var destination := player
		var poi := -1
		if policy in ["nearby_poi", "economic"] and not prepared:
			for index in Warfare.preparation_sites(run, fleet.anchors.keys()):
				if index >= 0 and fleet.anchors[index].distance_to(player) < 21.0:
					poi = index
					break
		if poi >= 0:
			destination = fleet.anchors[poi]
		elif policy == "detours" and spent < 24.0:
			var edge := State.SystemLayout.bounds(run.layout_expansion).end.x - 3.0
			destination = Vector3(edge if player.x < 0.0 else -edge, 0, edge if player.z < 0.0 else -edge)
		else:
			destination = target(fleet, player, policy)
		var travel: float = player.distance_to(destination) * fleet.tuning.seconds_per_distance
		var event: Dictionary = run._advance_strategy(maxf(1.0, travel), player, destination, false, false)
		spent += event.elapsed
		player = event.position
		run.navigation.checkpoint_position(State.Defense.wire(player))
		if event.contact >= 0:
			row.hazardous_battles += int(run.preview_modifier(event.contact) != 0)
			row["coupled_battles"] = row.get("coupled_battles", 0) + int(run.battle_environment(event.contact).has("temporal_anomaly"))
			run.active_battle = event.contact
			var result := Result.new()
			var punitive: bool = fleet.unit_for(event.contact).get("punitive", false)
			report_id += 1
			result.result_id = report_id
			result.encounter_index = event.contact
			result.system_number = run.system_number
			result.winner = "player"
			result.player_hull = run.hull
			result.salvage = run.salvage
			result.battles_won = run.battles_won + 1
			if run.record_battle(result):
				row.battles += 1
				if run.pending_choice == "battle_reward" and run.card_offers.any(func(card): return card.tier == 3):
					row["elite_drafts"] = row.get("elite_drafts", 0) + 1
				if punitive:
					row["punitive_battles"] = row.get("punitive_battles", 0) + 1
					row["punitive_salvage"] = row.get("punitive_salvage", 0) + int(result.salvage_rewards.get("standard", 0)) + int(result.salvage_rewards.get("victory", 0))
					row["punitive_drafts"] = row.get("punitive_drafts", 0) + int(run.pending_choice == "battle_reward" and run.card_offers.any(func(card): return card.tier == 3))
				spent += fleet.tuning.battle_seconds
				run.active_battle = -1
				if run.pending_choice == "battle_reward": run.choose_battle_reward(false)
				while run.pending_choice == "upgrade":
					run.choose_upgrade(run.upgrade_candidates().front().identity_key())
		elif event.missile_contact >= 0:
			run.resolve_missile(event.missile_contact, "direct")
			spent += fleet.tuning.missile_intercept_seconds
		elif poi >= 0:
			var options: Array = run.poi_approaches(poi)
			var choice := 0
			if policy == "economic":
				for index in options.size():
					var reward: Dictionary = options[index].get_meta("strategic_reward", {})
					if not run.approach_requirement(options[index]).is_locked() and (reward.has("production") or reward.has("next_battle")):
						choice = index
						break
			var salvage: int = run.salvage
			var production: float = run.production_upgrades.values().reduce(func(sum, increment): return sum + increment, 0)
			if run.resolve_approach(poi, choice):
				spent += float(options[choice].get_meta("strategic_seconds", 0))
				row.preparations += 1
				row.salvage_from_pois += maxi(0, run.salvage - salvage)
				row.production_from_pois += run.production_upgrades.values().reduce(func(sum, increment): return sum + increment, 0) - production
			prepared = true
		elif destination != player:
			row.unresolved_legs += 1
		if fleet.revealed and not fleet.mothership_destroyed() and not row.has("current_reveal"):
			row.current_reveal = spent
		if fleet.mothership_advancing and not row.has("current_advance"):
			row.current_advance = spent
	row.reveal += float(row.get("current_reveal", 0.0))
	row.advance += float(row.get("current_advance", 0.0))
	row.erase("current_reveal")
	row.erase("current_advance")
	row.secured += int(fleet.complete)
	row.lost += int(fleet.failed())
	row.damage += fleet.tuning.base_integrity - fleet.integrity
	if fleet.complete: row.completion_time += spent
	row.pressure += fleet.pressure
	row.waves += fleet.reinforcements_spawned
	if fleet.convoy != null:
		var convoy: RefCounted = fleet.convoy
		row["evacuated"] = row.get("evacuated", 0) + int(convoy.activity == "extracted")
		row["convoy_losses"] = row.get("convoy_losses", 0) + int(convoy.activity == "destroyed")
		row["convoy_damage"] = row.get("convoy_damage", 0) + convoy.maximum_integrity - convoy.integrity
		row["evacuation_salvage"] = row.get("evacuation_salvage", 0) + (convoy.reward if convoy.reward_claimed else 0)
		row["total_salvage"] = row.get("total_salvage", 0) + run.salvage


func target(fleet: RefCounted, player: Vector3, policy: String) -> Vector3:
	var best := INF
	var meeting := player
	for unit in fleet.units:
		if not fleet.available(unit): continue
		var position: Vector3 = fleet.intercept_point(unit.encounter, player)
		var cost := player.distance_to(position)
		if unit.mothership:
			if policy == "early_boss" or fleet.mothership_advancing:
				cost *= 0.25
			else:
				cost *= 1.4
		elif policy == "dangerous":
			var eta: float = unit.position.distance_to(fleet.target_for(unit)) / fleet._speed(unit)
			cost = 0.35 * cost + eta - fleet.arrival_damage(unit) * 0.3
		if cost < best:
			best = cost
			meeting = position
	for missile in fleet.missiles.active:
		var position: Vector3 = fleet.intercept_point(missile, player)
		var cost := player.distance_to(position) * 0.65
		if cost < best:
			best = cost
			meeting = position
	return meeting
