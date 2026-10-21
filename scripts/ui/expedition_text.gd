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


static func approach_text(state: Resource, approach: Resource) -> String:
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
		lines.append("Cost: %d Salvage" % approach.salvage_cost)
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
