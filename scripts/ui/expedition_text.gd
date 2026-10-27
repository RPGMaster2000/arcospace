extends RefCounted
# RESPONSIBILITY: Presentation only: format encounter descriptions without changing expedition state.


static func compact_text(value: String) -> String:
	return (
		value
		. replace(" next battle", "")
		. replace("Next battle: ", "")
		. replace("permanent Hull", "Hull")
		. replace("starting resource of choice", "resource of choice")
		. replace("for expedition", "(expedition)")
	)


static func compact_outcome(state: Resource, outcome: Resource) -> String:
	return compact_text(state.describe_outcome(outcome))


static func highlight_outcome(value: String) -> String:
	var expression = RegEx.new()
	expression.compile(r"[+-]\d+[^·\n]*|\d+(?:\.\d+)?%")
	var result = ""
	var offset = 0
	for matched in expression.search_all(value):
		result += value.substr(offset, matched.get_start() - offset)
		var part: String = matched.get_string()
		if part.ends_with("%"):
			result += "[b]" + part + "[/b]"
		else:
			# Offline turns are a penalty despite their positive counter.
			var color = (
				"f49b97"
				if part.begins_with("-") or part.to_lower().contains("offline")
				else "9ce3b2"
			)
			result += "[b][color=" + color + "]" + part + "[/color][/b]"
		offset = matched.get_end()
	return result + value.substr(offset)


static func approach_text(state: Resource, approach: Resource, contextual: bool = false) -> String:
	var lines: Array[String] = []
	if not approach.requirement.is_empty():
		lines.append(
			(
				"%s ≥%d (ship: %d)"
				% [
					state.LABELS[approach.requirement],
					approach.minimum_production,
					state.production(approach.requirement)
				]
			)
		)
	if approach.salvage_cost > 0:
		lines.append("Cost: %d Salvage" % approach.salvage_cost + (" · Available: %d" % state.salvage if contextual else ""))
	lines.append(
		(
			"%s%% — %s"
			% [
				String.num(approach.success_chance * 100, 2).trim_suffix(".0"),
				compact_outcome(state, approach.success)
			]
		)
	)
	if approach.success_chance < 1:
		lines.append(
			(
				"%s%% — %s"
				% [
					String.num((1.0 - approach.success_chance) * 100, 2).trim_suffix(".0"),
					compact_outcome(state, approach.failure)
				]
			)
		)
	if contextual:
		var keys: Dictionary = {}
		var show_hull := false
		for outcome in [approach.success,approach.failure]:
			if outcome == null: continue
			show_hull = show_hull or outcome.hull != 0
			for key in outcome.next_battle:
				if key in state.RESOURCES or key == "shields": keys[key] = true
		var balances: Array[String] = []
		if show_hull: lines.append("Current Hull: %d/%d" % [state.hull,state.ship().hull_capacity])
		for key in keys: balances.append("%s %d" % [state.LABELS[key],state.starting_value(state.ship(),key)])
		if not balances.is_empty(): lines.append("Next-battle start: " + " · ".join(balances))
	var reason: String = state.locked_reason(approach)
	if not reason.is_empty():
		lines.append(
			(
				"LOCKED"
				if reason.begins_with(
					"Requires " + state.LABELS.get(approach.requirement, "missing")
				)
				else "LOCKED — " + reason
			)
		)
	return "\n".join(lines)


# Reuse the existing HUD symbols; keep every signed amount and mechanical qualifier.
static func effect_indicators(value: String) -> String:
	var presentation = preload("res://scripts/ui/encounter_presentation.gd")
	for pair in [["Materials","materials"],["Energy","energy"],["Crew","crew"],["Shields","shields"],["Hull","hull"]]:
		value = value.replace(pair[0],presentation.icon(pair[1],presentation.UI_FONT))
	return value.replace("EMP Pulse charge","EMP charge").replace("EMP Pulse offline","EMP offline").replace("No starting modifiers","No modifiers").replace("minimum 1","min 1")


static func requirement_text(requirement: RefCounted, labels: Dictionary) -> String:
	var contract = preload("res://scripts/expedition/approach_requirement.gd")
	match requirement.kind:
		contract.Kind.PRODUCTION:
			return "%s %d required (%d)" % [labels[requirement.attribute], requirement.required, requirement.current]
		contract.Kind.SALVAGE:
			return "Salvage %d required (%d)" % [requirement.required, requirement.current]
		contract.Kind.FULL_HULL:
			return "Hull already full"
	return ""
