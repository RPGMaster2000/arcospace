extends SceneTree
const Face = preload("res://scripts/ui/card_face_text.gd")
const Data = preload("res://scripts/cards/card_data.gd")
const Library = preload("res://scripts/cards/card_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	# These are display semantics, not a replacement resolver or new gameplay fixtures.
	var card := Data.new()
	card.family = "materials"
	card.effects = {"damage": 4, "pierce": 1.0, "steal": {"crew": 4}}
	check(
		Face.card_text(card) == "Deal 4 Hull damage.\nSteal up to 4 Crew.",
		"Full pierce is Hull damage; theft is bounded by enemy reserve"
	)
	card.effects = {
		"energy": 3,
		"conditional":
		{
			"attribute": "energy",
			"comparison": "at_most",
			"threshold": 5,
			"then": {"damage": 8},
			"else": {"damage": 2}
		}
	}
	check(
		(
			Face.card_text(card)
			== "Gain 3 Energy. Then:\nIf Energy ≤5:\nDeal 8 damage.\nElse: 2 damage."
		),
		"Base gain precedes threshold; branches never factored"
	)
	card.effects = {
		"conditional":
		{
			"target": "enemy",
			"attribute": "reactor",
			"comparison": "above",
			"compare_target": "self",
			"compare_attribute": "reactor",
			"then": {"shields": 4, "reactor": 1},
			"else": {"materials": 11}
		}
	}
	check(
		(
			Face.card_text(card)
			== "If enemy Reactor >yours:\nGain 4 Shields.\nEnergy prod. +1.\nElse: +11 Materials."
		),
		"Compact else retains positive gain, production, relative target and full resource name"
	)
	card.effects = {
		"conditional":
		{
			"target": "enemy",
			"attribute": "hull",
			"comparison": "below",
			"threshold": 0.5,
			"fraction_of": "hull_capacity",
			"then": {"damage": 19, "pierce": 1.0},
			"else": {"damage": 11, "pierce": 1.0}
		}
	}
	check(
		(
			Face.card_text(card)
			== "If enemy Hull <50% max:\nDeal 19 Hull damage.\nElse: 11 Hull damage."
		),
		"Compact damage else retains Hull bypass and both exact values"
	)
	card.effects = {"self_damage": 2, "self_damage_regular": 4}
	check(
		Face.card_text(card) == "Take 2 Hull damage.\nTake 4 damage\n(Shields first).",
		"Direct and shield-absorbed self damage remain distinct"
	)
	card.effects = {"random_gain_range_other": {"min": 2, "max": 6}}
	check(
		Face.card_text(card) == "Gain 2–6 random\nEnergy or Crew.",
		"Random resource excludes cost family and retains amount bounds"
	)
	card.effects = {"shield_collapse": {"threshold": 10, "chance": 0.5, "self_damage": 10}}
	var text := Face.card_text(card)
	check(
		(
			text.contains("If started ≥10")
			and text.contains("50% risk: take 10 damage")
			and text.contains("Shields first")
		),
		"Collapse retains original shield threshold, probability and backlash absorption"
	)
	check(
		(
			Face.condition(
				{
					"attribute": "hull",
					"threshold": 0.5,
					"fraction_of": "hull_capacity",
					"comparison": "below"
				}
			)
			== "Hull <50% max"
		),
		"Capacity-relative threshold remains explicit"
	)
	check(
		(
			Face.condition(
				{
					"attribute": "reactor",
					"target": "enemy",
					"compare_attribute": "reactor",
					"compare_target": "self",
					"comparison": "above"
				}
			)
			== "enemy Reactor >yours"
		),
		"Relative production retains both targets"
	)
	var random_before: int = Effects.combat_rng.state
	for base in Library.CARDS:
		for level in range(base.max_upgrades + 1):
			var definition: Resource = base.with_upgrade(level)
			var before := JSON.stringify(
				[
					definition.effects,
					definition.cost,
					definition.family,
					definition.upgrade_effects,
					definition.description
				]
			)
			text = Face.card_text(definition)
			check(
				not text.is_empty() and text == Face.card_text(definition),
				"Deterministic nonempty copy: " + definition.card_name
			)
			check(
				(
					JSON.stringify(
						[
							definition.effects,
							definition.cost,
							definition.family,
							definition.upgrade_effects,
							definition.description
						]
					)
					== before
				),
				"Display never mutates card definition: " + definition.card_name
			)
	check(
		Effects.combat_rng.state == random_before, "Full-library display never consumes combat RNG"
	)
	print("Card face text: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
