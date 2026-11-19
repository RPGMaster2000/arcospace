extends RefCounted
## Persistent campaign results and deterministic support packages. No gameplay RNG.

const TIERS := ["emergency", "limited", "standard", "strong"]
const WARZONE_SYSTEM := 2


static func operation_for(campaign_mode: String, system: int) -> String:
	if campaign_mode == "defense" and system == WARZONE_SYSTEM:
		return "warzone"
	return campaign_mode


static func homeworld_outcome(state: Resource) -> Dictionary:
	return {
		"secured": state.defense.complete,
		"integrity": state.defense.integrity,
		"maximum_integrity": state.defense.tuning.base_integrity,
		"player_hull": state.hull,
		"salvage": state.salvage,
		"production_upgrades": state.production_upgrades.duplicate(),
		"card_upgrades": state.deck_snapshot().upgrades,
	}


static func homeworld_package(outcome: Dictionary, tuning: Resource) -> Dictionary:
	# Runs already beyond Homeworld in old saves have no historical integrity.
	var tier := 2
	if not outcome.is_empty():
		var fraction: float = float(outcome.integrity) / float(outcome.maximum_integrity)
		tier = 0
		for threshold in [tuning.limited_integrity, tuning.standard_integrity, tuning.strong_integrity]:
			if fraction >= threshold:
				tier += 1
	return {
		"tier": TIERS[tier],
		"fleet_strength": _package_value(tuning.allied_fleet_strength, tier, 5),
		"salvage": _package_value(tuning.starting_salvage, tier, 0),
		"shields": _package_value(tuning.arrival_shields, tier, 0),
	}


static func _package_value(values: PackedInt32Array, tier: int, minimum: int) -> int:
	return maxi(minimum, values[tier]) if tier < values.size() else minimum
