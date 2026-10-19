extends RefCounted

# RESPONSIBILITY: Derive compact card summaries from effect data without changing gameplay values.
# Presentation only: short summaries derive from the same dictionaries as full descriptions.
const Data = preload("res://scripts/cards/card_data.gd")


static func describe(values: Dictionary) -> String:
	var basic: Dictionary = values.duplicate(true)
	basic.erase("conditional")
	var text: String = compact(Data.describe_effects(basic))
	var c: Dictionary = values.get("conditional", {})
	if c.is_empty():
		return text
	var yes: Dictionary = c.get("then", {}).duplicate(true)
	var no: Dictionary = c.get("else", {}).duplicate(true)
	# Factor common branch values for concise repair/finisher summaries, without changing timing.
	var shared: Dictionary = {}
	for key in no.keys():
		if not yes.has(key):
			continue
		if yes[key] == no[key]:
			shared[key] = no[key]
		elif yes[key] is int and no[key] is int and yes[key] >= no[key] and no[key] > 0:
			shared[key] = no[key]
	for key in shared:
		if yes[key] == shared[key]:
			yes.erase(key)
		else:
			yes[key] -= shared[key]
		no.erase(key)
	if not shared.is_empty():
		text = join(text, compact(Data.describe_effects(shared)))
	var predicate: Dictionary = c.duplicate(true)
	predicate["then"] = {}
	predicate.erase("else")
	var condition: String = (
		compact(Data.describe_effects({"conditional": predicate}))
		. trim_suffix(": ")
		. trim_prefix("If ")
	)
	var branch: String = compact(Data.describe_effects(yes))
	var context: Dictionary = basic.duplicate(true)
	context.merge(shared, true)
	if no.is_empty() and yes.size() == 1 and context.has(yes.keys()[0]) and yes.values()[0] is int:
		branch = "%+d" % int(yes.values()[0])
	elif no.is_empty() and shared.has("damage") and yes.has("break_shields"):
		branch = "Break %d Shld first" % int(yes.break_shields)
	if no.is_empty():
		branch += " if " + condition
	else:
		branch = "If " + condition + ": " + branch + "; else " + compact(Data.describe_effects(no))
	return join(text, branch)


static func join(a: String, b: String) -> String:
	return a + "; " + b if not a.is_empty() and not b.is_empty() else a + b


static func compact(text: String) -> String:
	var replacements: Dictionary = {
		"Materials": "Mat",
		"Shields": "Shld",
		"Enemy ": "foe ",
		"Own ": "",
		"own Reactor": "yours",
		"Synthesizer": "Synth",
		"Quarters": "Qtrs",
		" (min 1)": "",
		" max": "",
		" damage": " dmg",
		"regular dmg": "Shield-first dmg",
		"random other resource": "random other",
		"corresponding resource": "matching reserve"
	}
	for key in replacements:
		text = text.replace(key, replacements[key])
	var shield_damage = RegEx.new()
	shield_damage.compile("foe -(\\d+) Shld")
	return shield_damage.sub(text, "$1 Shield dmg", true)


static func card_text(card: Resource) -> String:
	return describe(card.effects) + ("; play again" if card.play_again else "")
