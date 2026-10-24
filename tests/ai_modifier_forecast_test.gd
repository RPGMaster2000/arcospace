extends SceneTree
const AI = preload("res://scripts/enemy_ai.gd")
const Cases = preload("res://tests/ai_forecast_cases.gd")
const Forecast = preload("res://scripts/combat/combat_forecast.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Rules = preload("res://scripts/match_rules.gd")
const BASELINE = "res://tests/ai_forecast_baseline.json"
const REPORT = "res://docs/refactoring/ai_forecast_decisions.json"
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func gates(item: Dictionary) -> Dictionary:
	var old_win: Array = []
	var old_safe: Array = []
	var new_win: Array = []
	var new_safe: Array = []
	for slot in range(item.cards.size()):
		var card: Resource = item.cards[slot]
		if item.actor[card.family] < card.cost: continue
		var a: Dictionary = item.actor.duplicate(true)
		var b: Dictionary = item.enemy.duplicate(true)
		Effects.play(card,a,b,null,true)
		var wins: bool = a.hull > 0 and Rules.wins(a,b)
		var safe: bool = a.hull > 0
		if wins: old_win.append(slot)
		if safe: old_safe.append(slot)
		var kind: int = item.context.get("kind",0)
		var relevant: bool = (kind == 2 and item.context.get("active",false) and card.family == "energy") or (kind == 3 and item.context.get("active",false)) or (kind == 4 and item.context.get("miss_rate",30) > 0 and Modifier.is_combat(card.effects))
		if relevant:
			var f: Dictionary = Forecast.predict(card,item.actor,item.enemy,item.context)
			check(f.complete,"Comparison uses complete forecasts")
			wins = f.guaranteed_win
			safe = not f.possible_self_destruction
		if wins: new_win.append(slot)
		if safe: new_safe.append(slot)
	return {"old_winning":old_win,"new_winning":new_win,"old_safe":old_safe,"new_safe":new_safe}
func _initialize() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var cases: Array = Cases.cases()
	var changes: Array = []
	var decisions: int = 0
	var random_only: int = 0
	var unmodified: int = 0
	for index in range(cases.size()):
		var item: Dictionary = cases[index]
		var old: Dictionary = baseline.records[index]
		old.move.slot = int(old.move.slot)
		check(Cases.fingerprint(item) == old.inputs,"Baseline inputs preserved")
		var ai = AI.new()
		ai.rng.seed = item.seed
		ai.tactical_weights = item.weights
		Effects.combat_rng.seed = item.seed ^ 127
		var legacy_move: Dictionary = ai.choose(item.cards,item.actor,item.enemy)
		check(legacy_move == old.move and str(ai.rng.state) == old.rng,"Explicit-seed legacy call matches captured decision")
		ai.rng.seed = item.seed
		var before: Array = [item.actor.duplicate(true),item.enemy.duplicate(true),item.context.duplicate(),Effects.combat_rng.state]
		var move: Dictionary = ai.choose(item.cards,item.actor,item.enemy,item.context)
		var state: String = str(ai.rng.state)
		check(before == [item.actor,item.enemy,item.context,Effects.combat_rng.state],"Decision never mutates source/RNG/context")
		var classification: Dictionary = gates(item)
		var unchanged: bool = move == old.move and state == old.rng
		var context: Dictionary = item.context
		var ordinary: bool = context.get("kind",0) in [0,1,5] or (context.get("kind",0) == 2 and not context.get("active",false))
		if ordinary:
			unmodified += 1
			check(unchanged,"Unmodified/inactive/independent-event compatibility")
		if not unchanged:
			check(not ordinary,"Only active modified battles may differ")
			check(classification.old_winning != classification.new_winning or classification.old_safe != classification.new_safe,"Every delta attributable to corrected gate information")
			decisions += int(move != old.move)
			random_only += int(move == old.move)
			var names: Array = []
			for card in item.cards: names.append(card.card_name)
			changes.append({"id":item.id,"cards":names,"actor":item.actor,"target":item.enemy,"context":context,"ai_seed":item.seed,"combat_seed":item.seed ^ 127,"weights":item.weights,"old":old.move,"new":move,"old_rng":old.rng,"new_rng":state,"gates":classification,"intentional":true})
		ai.rng.seed = item.seed
		check(move == ai.choose(item.cards,item.actor,item.enemy,item.context) and state == str(ai.rng.state),"Repeated decision deterministic")
		ai.free()
	var report: Dictionary = {"baseline":"9ec97c6f3d8aca31422839830eb4e5577f358c29","cases":cases.size(),"unchanged_context_cases":unmodified,"changed_decisions":decisions,"same_decision_rng_deltas":random_only,"changes":changes}
	if "--record-comparison" in OS.get_cmdline_user_args():
		FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	else:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
		check(JSON.parse_string(JSON.stringify(report)) == expected,"Every intended decision/RNG delta matches reviewed report")
	print("Modifier AI: %d cases, %d ordinary/inactive/no-op cases identical; %d changed decisions, %d RNG-only deltas; %d checks, %d failures" % [cases.size(),unmodified,decisions,random_only,checks,failures])
	quit(1 if failures else 0)
