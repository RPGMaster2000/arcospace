extends RefCounted
## Frozen engagement modifiers. Fractional attrition carries between volleys.

const Package = preload("res://scripts/combat/combat_preparation.gd")
const Validation = preload("res://scripts/expedition/defense_state.gd")
const RESOURCE_FACTOR := 0.2
const PRODUCTION_FACTOR := 1.5
const SHIELD_FACTOR := 1.0 / 6.0
const DISRUPTION_STRENGTH := 0.75

var records := {}


func update(sector: RefCounted) -> void:
	var participants := {}
	for fleet in sector.fleets:
		if sector.active(fleet) and fleet.engaged >= 0:
			participants[str(fleet.id)] = fleet
			participants[str(fleet.engaged)] = sector.fleet_at(fleet.engaged)
	for key in records.keys():
		if not participants.has(key): records.erase(key)
	for key in participants:
		if records.has(key): continue
		var fleet: Dictionary = participants[key]
		var package: Dictionary = sector.fleet_preparations.get(key, {})
		sector.fleet_preparations.erase(key)
		var offensive := 0.0
		for attribute in Package.RESOURCES: offensive += RESOURCE_FACTOR * int(package.get(attribute, 0))
		for attribute in Package.PRODUCTION: offensive += PRODUCTION_FACTOR * int(package.get(attribute, 0))
		var shields := SHIELD_FACTOR * int(package.get("shields", 0))
		var limit: float = minf(3.0, fleet.strength * 0.30)
		var scale := minf(1.0, limit / maxf(0.001, offensive + shields))
		records[key] = {"offense": offensive * scale, "shield": shields * scale,
			"disrupts": package.has("disrupt"), "disrupted_target": -1, "penalty": 0.0, "carry": 0.0}
	for key in participants:
		var fleet: Dictionary = participants[key]
		var target := str(fleet.engaged)
		if records[key].disrupts and records[key].disrupted_target < 0 and records.has(target):
			records[key].disrupted_target = fleet.engaged
			records[target].penalty = DISRUPTION_STRENGTH


func effective(fleet: Dictionary) -> float:
	var record: Dictionary = records.get(str(fleet.id), {})
	var base: float = fleet.strength
	return maxf(1.0, base + record.get("offense", 0.0) - record.get("penalty", 0.0))


func volley(fleet: Dictionary, ordinary: int) -> float:
	return ordinary * effective(fleet) / maxf(1.0, fleet.strength)


func receive(fleet: Dictionary, incoming: float) -> int:
	var record: Dictionary = records.get(str(fleet.id), {})
	if record.is_empty(): return roundi(incoming)
	var absorbed := minf(record.shield, incoming)
	record.shield -= absorbed
	var total: float = incoming - absorbed + record.carry
	var whole := floori(total + 0.000000001)
	record.carry = maxf(0.0, total - whole)
	return whole


func effective_defense(fleet: Dictionary) -> float:
	var record: Dictionary = records.get(str(fleet.id), {})
	return fleet.strength + record.get("shield", 0.0) - record.get("carry", 0.0)


func restore(value: Variant, fleet_count: int) -> bool:
	if not value is Dictionary or value.size() > fleet_count: return false
	for key in value:
		if not key is String or not key.is_valid_int() or str(int(key)) != key \
			or not Validation.number(int(key), 0, fleet_count - 1): return false
		var record: Variant = value[key]
		if not record is Dictionary or record.size() != 6 or not record.get("disrupts") is bool \
			or not Validation.number(record.get("disrupted_target"), -1, fleet_count - 1): return false
		for pair in [["offense", 3.0], ["shield", 3.0], ["penalty", DISRUPTION_STRENGTH], ["carry", 1.0]]:
			var number: Variant = record.get(pair[0])
			if not (number is float or number is int) or not is_finite(number) or number < 0 or number > pair[1]:
				return false
		if record.offense + record.shield > 3.000001 or record.carry >= 1.0: return false
	records = value.duplicate(true)
	for key in records: records[key].disrupted_target = int(records[key].disrupted_target)
	return true
