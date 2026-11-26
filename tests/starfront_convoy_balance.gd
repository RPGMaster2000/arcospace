extends "res://tests/defense_warfare_strategies.gd"
## Optimistic card wins keep this study focused on map-level feasibility and incentives.
const POLICIES := ["home_nearest", "home_dangerous", "convoy", "alternating", "decoys", "turrets", "nearby_poi", "economic", "ignore", "sacrifice", "early_boss"]


func _initialize() -> void:
	var rules := Rules.duplicate()
	rules.log_rolls = false
	rules.defense_tuning = Rules.defense_tuning.duplicate()
	rules.defense_tuning.convoy_enabled = "--no-convoy" not in OS.get_cmdline_user_args()
	var selection := Array(OS.get_cmdline_user_args()).filter(func(arg): return arg in POLICIES)
	for policy in POLICIES:
		if not selection.is_empty() and policy not in selection: continue
		var row := {"runs":0, "secured":0, "lost":0, "damage":0, "pressure":0.0, "reveal":0, "advance":0,
			"waves":0, "battles":0, "completion_time":0.0, "preparations":0, "salvage_from_pois":0,
			"production_from_pois":0, "hazardous_battles":0, "unresolved_legs":0}
		for stage in [3,4,5]:
			for seed_value in range(31,49):
				var run := State.new()
				run.start(seed_value % 6, rules, seed_value, {"mode":"defense","stage":stage,"rank":-1})
				play(run, policy, row)
		print("CONVOY_POLICY ", policy, " ", JSON.stringify(row))
	quit()


func target(fleet: RefCounted, player: Vector3, policy: String) -> Vector3:
	if fleet.convoy == null: return super.target(fleet, player, "dangerous" if policy == "home_dangerous" else policy)
	var score := INF
	var meeting := player
	var open_convoy: bool = fleet.convoy.traveling() and not fleet.convoy.pursuers.is_empty()
	for unit in fleet.units:
		if not fleet.available(unit): continue
		var pursuer: bool = fleet.target_kind(unit) == "convoy"
		if pursuer and policy in ["ignore", "sacrifice"]: continue
		if unit.mothership and policy == "sacrifice" and open_convoy and not fleet.mothership_advancing: continue
		var at: Vector3 = fleet.intercept_point(unit.encounter, player)
		var travel := player.distance_to(at)
		if unit.mothership:
			travel *= 0.15 if policy == "early_boss" or fleet.mothership_advancing else 1.5
		elif pursuer:
			if policy == "convoy": travel *= 0.10
			elif policy in ["home_nearest", "home_dangerous"]: travel *= 2.5
			elif policy == "alternating": travel *= 0.45 if fleet.convoy.attackers.is_empty() else 2.5
		elif policy == "home_dangerous":
			var eta: float = unit.position.distance_to(fleet.target_for(unit)) / maxf(0.001, fleet._speed(unit))
			travel = 0.35 * travel + eta - fleet.arrival_damage(unit) * 0.3
		if travel < score:
			score = travel
			meeting = at
	for index in fleet.missiles.active:
		var at: Vector3 = fleet.intercept_point(index, player)
		var travel := player.distance_to(at) * 0.65
		if travel < score:
			score = travel
			meeting = at
	return meeting
