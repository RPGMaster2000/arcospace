extends RefCounted
## Compact duration ledger owned by ExpeditionState. No clocks, RNG or scene nodes.
## Callers supply completed battles, committed strategic seconds and actual distance.
const CATEGORIES = ["synthesizer", "reactor", "quarters"]
var production: Dictionary = {}
var mothership: String = ""
var pause: float = 0.0
var reduction: float = 0.0
var fuel: float = 0.0

func snapshot() -> Dictionary:
	return {"production":production.duplicate(true), "mothership":mothership,
		"pause":pause,"reduction":reduction,"fuel":fuel}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	if not value.get("production") is Dictionary or value.production.size() > 3: return false
	if value.get("mothership") not in ["", "penetration", "damage"]: return false
	var limits := {"pause":15.0,"reduction":30.0,"fuel":30.0}
	for key in limits:
		if not number(value.get(key), 0, limits[key]): return false
	for category in value.production:
		var item: Variant = value.production[category]
		if category not in CATEGORIES or not item is Dictionary or item.size() != 2: return false
		if not integer(item.get("amount"), 1, 2) or not integer(item.get("battles"), 1, 3): return false
	production = value.production.duplicate(true)
	for item in production.values():
		item.amount = int(item.amount)
		item.battles = int(item.battles)
	mothership = value.mothership
	pause = float(value.pause)
	reduction = float(value.reduction)
	fuel = float(value.fuel)
	return true

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value, minimum, maximum) and value == floor(float(value))

func grant_production(category: String, amount: int, battles: int) -> void:
	assert(category in CATEGORIES and amount >= 1 and amount <= 2 and battles >= 1 and battles <= 3)
	var existing: Dictionary = production.get(category, {"amount":0,"battles":0})
	# One bounded entry per category. Retain stronger magnitude and longer duration.
	production[category] = {"amount":maxi(amount, existing.amount),"battles":maxi(battles, existing.battles)}

func bonus(category: String) -> int:
	return int(production.get(category, {}).get("amount", 0))

func completed_battle() -> void:
	for category in production.keys():
		production[category].battles -= 1
		if production[category].battles <= 0: production.erase(category)

func leave_system() -> void:
	mothership = ""
	pause = 0.0
	reduction = 0.0

func pressure_multiplier() -> float:
	if pause > 0.0: return 0.0
	return 0.5 if reduction > 0.0 else 1.0

func next_boundary() -> float:
	var result := INF
	for remaining in [pause, reduction]:
		if remaining > 0.0: result = minf(result, remaining)
	return result

func advance_seconds(seconds: float) -> void:
	assert(is_finite(seconds) and seconds >= 0.0)
	pause = maxf(0.0, pause - seconds)
	reduction = maxf(0.0, reduction - seconds)

func consume_distance(distance: float) -> void:
	assert(is_finite(distance) and distance >= 0.0)
	fuel = maxf(0.0, fuel - distance)

func summary() -> String:
	var parts: Array[String] = []
	for category in CATEGORIES:
		if production.has(category):
			parts.append("+%d %s production · %d battles" % [production[category].amount,category,production[category].battles])
	if mothership == "penetration": parts.append("Mothership: player card damage bypasses Shields")
	if mothership == "damage": parts.append("Mothership: +50% player card damage")
	if pause > 0: parts.append("Pressure paused · %.1f strategic seconds" % pause)
	if reduction > 0: parts.append("Half Pressure rate · %.1f strategic seconds" % reduction)
	if fuel > 0: parts.append("Travel speed +50%% · %.1f distance" % fuel)
	return "\n".join(parts)
