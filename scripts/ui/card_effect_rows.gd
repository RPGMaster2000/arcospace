extends RefCounted
## Card-face effect vocabulary derived from gameplay dictionaries, never from prose.
## All cards use the same font size. Full details remain available in Inspector.
const Data = preload("res://scripts/cards/card_data.gd")
const COLORS = {
	"materials": "#ff8176", "energy": "#80d9ff", "crew": "#9ee79e",
	"hull": "#ffc4a2", "shields": "#9ed7ff", "damage": "#ff9789",
	"special": "#b8a9ff", "production": "#e9d39c"
}

static func colored(icon: String, color: String, message: String) -> String:
	return "[color=%s]%s[/color] %s" % [color, icon, message]

static func line(icon: String, color: String, message: String, treatment: String = "") -> String:
	var result: String = colored(icon, color, message)
	match treatment:
		"conditional":
			return "[bgcolor=#123a40][color=#71dfd6]┊[/color] " + result + " [color=#71dfd6]┊[/color][/bgcolor]"
		"risk":
			return "[bgcolor=#42301e][color=#efb86f]⚠[/color] " + result + "[/bgcolor]"
		"pierce":
			return "[bgcolor=#43232b][color=#ff8585]▌[/color] " + result + "[/bgcolor]"
	return result

static func resource_icon(kind: String) -> String:
	return {"materials": "■", "energy": "◆", "crew": "●", "hull": "▰", "shields": "⬡"}.get(kind, "✦")

static func describe(values: Dictionary, treatment: String = "") -> Array[String]:
	var result: Array[String] = []
	for key in values:
		var value: Variant = values[key]
		var color: String = COLORS.get(key, COLORS.special)
		match key:
			"conditional":
				var predicate: Dictionary = value.duplicate(true)
				predicate["then"] = {}
				predicate.erase("else")
				var condition: String = Data.describe_effects({"conditional": predicate}).trim_suffix(": ")
				result.append(line("◇", "#71dfd6", condition, "conditional"))
				result.append_array(describe(value.get("then", {}), "conditional"))
				if not value.get("else", {}).is_empty():
					result.append(line("◇", "#71dfd6", "Otherwise:", "conditional"))
					result.append_array(describe(value["else"], "conditional"))
			"materials", "energy", "crew", "hull", "shields":
				result.append(line(resource_icon(key), color, "%+d %s" % [int(value), key.capitalize()], treatment))
			"damage":
				var piercing: float = float(values.get("pierce", 0.0))
				result.append(line("◎" if piercing >= 1.0 else "✹", COLORS.damage,
					"%d %s" % [int(value), "direct Hull damage" if piercing >= 1.0 else "damage"],
					"pierce" if piercing >= 1.0 else treatment))
			"pierce":
				if float(value) < 1.0:
					result.append(line("◎", COLORS.damage, "%d%% bypasses Shields" % roundi(float(value) * 100), "pierce"))
			"break_shields":
				result.append(line("⬡", COLORS.shields, "Enemy −%d Shields" % int(value), treatment))
			"self_damage", "self_damage_regular":
				result.append(line("▰", COLORS.hull, Data.describe_effects({key: value}), "risk"))
			"shield_collapse":
				result.append(line("⬡", COLORS.shields, "Clear enemy Shields", treatment))
				result.append(line("⚠", "#efb86f", "If ≥%d: %d%% risk of %d self damage (Shields first)" % [
					int(value.threshold), roundi(float(value.chance) * 100), int(value.self_damage)], "risk"))
			"shield_collapse_below":
				result.append(line("⬡", COLORS.shields, Data.describe_effects({key: value}), "conditional"))
			"enemy_production":
				for kind in value:
					result.append(line("⚙", COLORS.production, "Enemy %s %+d" % [str(kind).capitalize(), int(value[kind])], treatment))
			"synthesizer", "reactor", "quarters":
				result.append(line("⚙", COLORS.get({"synthesizer":"materials","reactor":"energy","quarters":"crew"}[key], COLORS.production),
					"%+d %s production" % [int(value), key.capitalize()], treatment))
			"production_other":
				result.append(line("⚙", COLORS.production, Data.describe_effects({key: value}), treatment))
			"sabotage", "random_sabotage":
				result.append(line("⚙", "#efb86f", Data.describe_effects({key: value}), treatment))
			"steal":
				for kind in value:
					result.append(line("⇄", COLORS.get(kind, COLORS.special), "Steal ≤%d %s" % [int(value[kind]), str(kind).capitalize()], treatment))
			"drain":
				if value.size() == 3 and value.get("materials") == value.get("energy") and value.get("energy") == value.get("crew"):
					result.append(line("↓", COLORS.special, "Enemy −%d all resources" % int(value.materials), treatment))
				else:
					for kind in value:
						result.append(line("↓", COLORS.get(kind, COLORS.special), "Enemy −%d %s" % [int(value[kind]), str(kind).capitalize()], treatment))
			"swap_resource", "swap_shields":
				result.append(line("⇄", COLORS.special, Data.describe_effects({key: value}), treatment))
			"random_gain", "random_gain_other", "random_gain_range_other":
				result.append(line("✧", COLORS.special, Data.describe_effects({key: value}), treatment))
			_:
				result.append(line("✦", COLORS.special, Data.describe_effects({key: value}), treatment))
	return result

static func render(card: Resource) -> String:
	var rows: Array[String] = describe(card.effects)
	if card.play_again:
		rows.append(line("↻", "#76dfd6", "Play again"))
	return "\n".join(rows)
