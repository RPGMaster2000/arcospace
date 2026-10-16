extends RefCounted
# Presentation-only effect comparison. Values always come from CardData dictionaries.
const Data = preload("res://scripts/card_data.gd")
const GREEN = "91e6ad"

static func improved(value: Variant, before: Variant, lower_is_better: bool = false) -> bool:
	if before == null: return true
	if value is int or value is float:
		return float(value) < float(before) if lower_is_better else float(value) > float(before)
	return value != before

static func segment(text: String, value: Variant, before: Variant, lower: bool = false) -> String:
	return "[color=" + GREEN + "]" + text + "[/color]" if improved(value, before, lower) else text

static func comparison(card: Resource, base: Resource) -> String:
	var lines: PackedStringArray = []
	for key in card.effects:
		var value = card.effects[key]
		var before = base.effects.get(key)
		match key:
			"production_other":
				var old: Dictionary = before if before is Dictionary else {}
				lines.append(segment("+%d %s" % [value.production, str(value.type).capitalize()], value.production, old.get("production")))
				var resource: String = {"synthesizer":"Materials", "reactor":"Energy", "quarters":"Crew"}[value.type]
				lines.append(segment("+%d %s" % [value.resource, resource], value.resource, old.get("resource")))
			"steal", "drain":
				var old: Dictionary = before if before is Dictionary else {}
				for resource in value:
					lines.append(segment(("Steal ≤%d %s" if key == "steal" else "Enemy −%d %s") % [value[resource], str(resource).capitalize()], value[resource], old.get(resource)))
			"shield_collapse":
				var old: Dictionary = before if before is Dictionary else {}
				lines.append("Clear enemy Shields")
				lines.append(segment("At ≥%d Shields" % value.threshold, value.threshold, old.get("threshold")))
				lines.append(segment("%d%% risk" % roundi(float(value.chance) * 100), value.chance, old.get("chance"), true) + " · " + segment("%d self dmg (Shld first)" % value.self_damage, value.self_damage, old.get("self_damage"), true))
			"random_gain_range_other":
				var old: Dictionary = before if before is Dictionary else {}
				lines.append("+" + segment(str(value.min), value.min, old.get("min")) + "–" + segment(str(value.max), value.max, old.get("max")) + " random other resource")
			_:
				lines.append(segment(Data.describe_effects({key:value}), value, before, key in ["self_damage", "self_damage_regular"]))
	if card.play_again: lines.append("Play again")
	return "\n".join(lines)
