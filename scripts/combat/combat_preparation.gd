extends RefCounted
## Bounded, detached next-engagement packages shared by map and card combat.

const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const RESOURCES = Ship.RESOURCES
const PRODUCTION = Ship.PRODUCTION
const SHIELDS_MAX := 12
const RESOURCE_MAX := 10
const DISRUPTION := 4


static func benefit(package: Dictionary, attribute: String, amount: int) -> int:
	if attribute == "shields" or attribute in RESOURCES:
		return mini(amount, (SHIELDS_MAX if attribute == "shields" else RESOURCE_MAX) - int(package.get(attribute, 0)))
	if attribute in PRODUCTION:
		return 0 if PRODUCTION.any(func(key): return package.has(key)) else 1
	if attribute.begins_with("disrupt.") and attribute.get_slice(".", 1) in RESOURCES:
		return 0 if package.has("disrupt") else DISRUPTION
	return 0


static func add(package: Dictionary, attribute: String, amount: int) -> void:
	if attribute.begins_with("disrupt."):
		package.disrupt = attribute.get_slice(".", 1)
	else:
		package[attribute] = int(package.get(attribute, 0)) + amount


static func apply(ship: RefCounted, own: Dictionary, opposing: Dictionary) -> void:
	for key in RESOURCES + PRODUCTION + ["shields"]:
		var disruption := DISRUPTION if key == opposing.get("disrupt", "") else 0
		ship.set(key, maxi(0, int(ship.get(key)) + int(own.get(key, 0)) - disruption))


static func summary(package: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in RESOURCES + PRODUCTION + ["shields"]:
		if package.has(key): parts.append("+%d %s" % [package[key], key.capitalize()])
	if package.has("disrupt"):
		parts.append("−%d opposing %s" % [DISRUPTION, str(package.disrupt).capitalize()])
	return " · ".join(parts)


static func valid(package: Variant) -> bool:
	if not package is Dictionary: return false
	var production := 0
	for key in package:
		if key == "disrupt":
			if package[key] not in RESOURCES: return false
			continue
		if key not in RESOURCES + PRODUCTION + ["shields"]: return false
		var value: Variant = package[key]
		if not (value is int or value is float) or not is_finite(value) or value != floorf(value): return false
		var maximum := SHIELDS_MAX if key == "shields" else (1 if key in PRODUCTION else RESOURCE_MAX)
		if value < 1 or value > maximum: return false
		if key in PRODUCTION: production += int(value)
	return production <= 1
