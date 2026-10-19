@tool
extends Resource
class_name CardData

# RESPONSIBILITY: Store Inspector-editable card data.
# DOES NOT: Change game state or manage turns.
## TUNE: Original rarity controls draw eligibility and border presentation, independently of upgrades.
@export_enum("Tier 1:1", "Tier 2:2", "Tier 3:3") var tier: int = 1
## TUNE: One primary Power Allocation purpose. Upgrades retain this identity category.
@export_enum("offense", "defense", "systems") var allocation_category: String = "systems"
## TUNE: Complete replacement effects for Upgrade I and II. Base effects/cost stay unchanged.
@export var upgrade_effects: Array[Dictionary] = []
@export_range(0, 2, 1) var max_upgrades: int = 2
@export_range(0, 2, 1) var upgrade_level: int = 0

## TUNE: Card title shown in the UI; edit each cards/*.tres resource in the Inspector.
@export var card_name: String = "":
	set(value):
		card_name = value
		emit_changed()
## TUNE: Resource type spent to play this card.
@export_enum("materials", "energy", "crew") var family: String = "materials":
	set(value):
		family = value
		emit_changed()
## TUNE: Resource amount needed to play the card.
@export var cost: int = 0:
	set(value):
		cost = value
		emit_changed()
## TUNE: Displayed explanation only; update effects separately to change gameplay.
@export_multiline var description: String = "":
	set(value):
		description = value
		emit_changed()
## TUNE: Gameplay amounts. conditional = {target, attribute, comparison, threshold, then, else}.
## Compare live stats with compare_target/compare_attribute, or use fraction_of: hull_capacity.
## swap_resource exchanges a non-cost reserve; enemy_production applies signed changes, minimum 1.
@export var effects: Dictionary = {}:
	set(value):
		effects = value
		emit_changed()
## TUNE: Set true to grant another action, without extra income or FTL charge.
@export var play_again: bool = false:
	set(value):
		play_again = value
		emit_changed()


# Return a separate player definition with a stable identity; upgrade entries replace, rather than add to, base effects.
func with_upgrade(level: int) -> Resource:
	var result: Resource = duplicate(false)
	result.set_meta("card_identity", identity_key())
	result.set_meta("inspection_base", get_meta("inspection_base", self))
	result.upgrade_level = clampi(level, 0, mini(2, mini(max_upgrades, upgrade_effects.size())))
	if result.upgrade_level > 0:
		result.effects = upgrade_effects[result.upgrade_level - 1].duplicate(true)
		result.card_name = (
			card_name.trim_suffix("++").trim_suffix("+") + "+".repeat(result.upgrade_level)
		)
		result.description = describe_effects(result.effects)
		if play_again:
			result.description += "; play again"
	return result


## Descriptions derive from the same effect data used by combat, including nested effects.
static func describe_effects(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in values:
		var value = values[key]
		match key:
			"conditional":
				var subject: String = "Own" if value.get("target", "self") == "self" else "Enemy"
				var symbols: Dictionary = {
					"below": "<", "at_most": "≤", "equal": "=", "at_least": "≥", "above": ">"
				}
				var threshold: String = str(value.get("threshold", 0))
				if value.has("compare_attribute"):
					threshold = (
						("own " if value.get("compare_target", "self") == "self" else "enemy ")
						+ str(value.compare_attribute).capitalize()
					)
				elif value.has("fraction_of"):
					threshold = "%d%% max" % roundi(float(value.threshold) * 100)
				var text: String = (
					"If %s %s %s%s: %s"
					% [
						subject,
						str(value.get("attribute", "hull")).capitalize(),
						symbols.get(value.get("comparison", "at_most"), "?"),
						threshold,
						describe_effects(value.get("then", {}))
					]
				)
				if not value.get("else", {}).is_empty():
					text += "; else " + describe_effects(value["else"])
				parts.append(text)
			"swap_resource":
				parts.append("Swap %s reserves" % str(value).capitalize())
			"enemy_production":
				for attribute in value:
					parts.append(
						(
							"Enemy %s %+d (min 1)"
							% [str(attribute).capitalize(), int(value[attribute])]
						)
					)
			"damage":
				parts.append(
					("%d Hull damage" if values.get("pierce", 0.0) == 1.0 else "%d damage") % value
				)
			"pierce":
				if float(value) != 1.0:
					parts.append("%d%% bypasses Shields" % roundi(float(value) * 100))
			"break_shields":
				parts.append("Enemy -%d Shields" % value)
			"swap_shields":
				parts.append("Swap Shields with enemy")
			"sabotage":
				parts.append("Enemy all prod -%d (min 1)" % int(value))
			"steal", "drain":
				if (
					key == "drain"
					and value.size() == 3
					and value.get("materials") == value.get("energy")
					and value.get("energy") == value.get("crew")
				):
					parts.append("Enemy -%d all resources" % value.materials)
					continue
				for resource in value:
					parts.append(
						(
							("Steal ≤%d %s" if key == "steal" else "Enemy -%d %s")
							% [value[resource], resource.capitalize()]
						)
					)
			"production_other":
				var production: String = value.type
				var resource: String = {
					"synthesizer": "Materials", "reactor": "Energy", "quarters": "Crew"
				}[production]
				parts.append(
					(
						"+%d %s, +%d %s"
						% [value.production, production.capitalize(), value.resource, resource]
					)
				)
			"random_gain":
				parts.append("+%d random resource" % value)
			"random_gain_other":
				parts.append("+%d random other resource" % value)
			"random_gain_range_other":
				parts.append("+%d–%d random other resource" % [value.min, value.max])
			"shield_collapse":
				parts.append(
					(
						"Clear enemy Shld; ≥%d: %d%% risk %d Shield-first self dmg"
						% [value.threshold, roundi(float(value.chance) * 100), value.self_damage]
					)
				)
			"shield_collapse_below":
				parts.append("Remove enemy Shields if below %d" % value)
			"self_damage":
				parts.append("Take %d direct Hull dmg" % value)
			"self_damage_regular":
				parts.append("Take %d regular dmg" % value)
			_:
				parts.append("%+d %s" % [int(value), str(key).capitalize()])
	return "; ".join(parts)


func identity_key() -> String:
	return str(
		get_meta("card_identity", resource_path if not resource_path.is_empty() else card_name)
	)
