extends RefCounted
## Sector-local faction currency and idempotent income. No player currency is held here.

const Validation = preload("res://scripts/expedition/defense_state.gd")
const SIDES := ["allied", "hostile"]
const STARTING := 10
const MAXIMUM := 40
const CAPTURE := 3
const VICTORY := 4
const DEPOT_INCOME := 2
const MAX_PASSIVE := 4
const INCOME_INTERVAL := 20000

var wallets := {"allied": STARTING, "hostile": STARTING}
var captures := {"allied": [], "hostile": []}
var neutralized: Array[int] = []
var last_income_ms := 0


func can_spend(side: String, amount: int) -> bool:
	return wallets.has(side) and amount >= 0 and wallets[side] >= amount


func spend(side: String, amount: int) -> bool:
	if not can_spend(side, amount): return false
	wallets[side] -= amount
	return true


func _credit(side: String, amount: int) -> void:
	wallets[side] = mini(MAXIMUM, wallets[side] + amount)


func capture(side: String, site: int) -> void:
	if side not in SIDES or site in captures[side]: return
	captures[side].append(site)
	_credit(side, CAPTURE)


func combat_kill(side: String, fleet_id: int) -> void:
	if side not in SIDES or fleet_id in neutralized: return
	neutralized.append(fleet_id)
	_credit(side, VICTORY)


func pay_supply(sector: RefCounted) -> void:
	if sector.clock_ms - last_income_ms < INCOME_INTERVAL: return
	last_income_ms = sector.clock_ms
	for side in SIDES:
		var count := 0
		for index in sector.supplied[side]:
			if sector.facility(index) == "sabotage": count += 1
		_credit(side, mini(MAX_PASSIVE, DEPOT_INCOME * count))


func snapshot() -> Dictionary:
	return {"wallets": wallets.duplicate(), "captures": captures.duplicate(true),
		"neutralized": Array(neutralized), "last_income_ms": last_income_ms}


func restore(record: Variant, sites: int, fleets: int, clock_ms: int) -> bool:
	if not record is Dictionary or not record.get("wallets") is Dictionary or record.wallets.size() != 2 \
		or not record.get("captures") is Dictionary or record.captures.size() != 2 \
		or not Validation.number(record.get("last_income_ms"), 0, clock_ms):
		return false
	for side in SIDES:
		if not Validation.number(record.wallets.get(side), 0, MAXIMUM) \
			or not _valid_ids(record.captures.get(side), sites): return false
	if not _valid_ids(record.get("neutralized"), fleets): return false
	for side in SIDES:
		wallets[side] = int(record.wallets[side])
		captures[side] = record.captures[side].map(func(id): return int(id))
	neutralized.assign(record.neutralized.map(func(id): return int(id)))
	last_income_ms = int(record.last_income_ms)
	return true


static func _valid_ids(values: Variant, limit: int) -> bool:
	if not values is Array or values.size() > limit: return false
	var seen := {}
	for value in values:
		if not Validation.number(value, 0, limit - 1) or seen.has(int(value)): return false
		seen[int(value)] = true
	return true
