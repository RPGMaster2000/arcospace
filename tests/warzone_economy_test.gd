extends SceneTree

const Sector = preload("res://scripts/expedition/warzone_sector.gd")
const Discovery = preload("res://scripts/expedition/warzone_discoveries.gd")
const Stations = preload("res://scripts/expedition/warzone_stations.gd")
const Tuning = preload("res://scripts/expedition/warzone_tuning.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var op := Sector.new()
	op.setup_sector(Tuning.new(), 8, 1.0, 19, 2)
	var cash := op.economy
	check(cash.spend("allied", 7) and not cash.spend("allied", 4)
		and cash.wallets == {"allied": 3, "hostile": 10}, "Faction spending is independent and cannot overdraw")
	cash.capture("allied", 1)
	cash.capture("allied", 1)
	cash.capture("hostile", 1)
	cash.combat_kill("hostile", 0)
	cash.combat_kill("hostile", 0)
	check(cash.wallets == {"allied": 6, "hostile": 17}, "Repeat captures and neutralizations cannot pay twice")
	op.supplied.hostile = [op.site("depot"), op.site("west_hub"), op.site("east_hub")].filter(func(id): return id >= 0)
	op.clock_ms = 19999
	cash.pay_supply(op)
	check(cash.wallets.hostile == 17, "Supply income does not pay before twenty seconds")
	op.clock_ms = 20000
	cash.pay_supply(op)
	cash.pay_supply(op)
	var income := mini(4, 2 * op.supplied.hostile.size())
	check(cash.wallets.hostile == 17 + income, "Supplied logistics award at most four per interval")
	cash.wallets.hostile = 39
	cash.combat_kill("hostile", 1)
	check(cash.wallets.hostile == 40, "Wallet cannot exceed forty")
	var saved := op.snapshot()
	var restored := Sector.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved)), op.tuning)
		and restored.economy.snapshot() == cash.snapshot(), "Economy and ledgers survive JSON restoration")
	saved.lattice.erase("economy")
	check(Sector.new().restore(saved, op.tuning), "Older sectors remain loadable")
	check_stations(op)
	check_discoveries()
	print("Warzone economy: %d failures" % failures)
	quit(int(failures > 0))


func check_stations(op: RefCounted) -> void:
	var site: int = op.root("allied")
	var prepared := {}
	var quotes := Stations.quotes(op, site, "allied", 12, prepared, 0)
	check(quotes.size() == 3 and quotes[1].enabled, "A supplied command offers a choice of production")
	if quotes.size() != 3: return
	Stations.apply(op, site, quotes[1], prepared)
	check(prepared == {"reactor": 1} and Stations.cooldown(op, site) == 30 and op.facility_cooldowns.is_empty(),
		"Production is limited to one and uses independent station recharge")
	op.clock_ms += 30000
	check(not Stations.quotes(op, site, "allied", 99, prepared, 0)[0].enabled,
		"A different production family cannot bypass the cap")
	op.objectives[site].contested = true
	check(not Stations.quotes(op, site, "allied", 99, {}, 0)[0].enabled,
		"Contested sites cannot sell preparations")
	check(not Stations.quotes(op, site, "hostile", 99, {}, 0)[0].enabled,
		"Hostiles cannot purchase at allied facilities")


func check_discoveries() -> void:
	var route: Array[Vector3] = [Vector3.ZERO, Vector3(10, 0, 0)]
	check(Discovery.detour(Vector3(5, 0, 3), route, 10.0) == 0
		and Discovery.detour(Vector3(5, 0, 11), route, 10.0) == 1
		and Discovery.detour(Vector3(5, 0, 25), route, 10.0) == 2,
		"Geometric insertion distinguishes all three detours")
	var approach: Resource = Discovery.POIS[1].approaches.filter(func(option): return Discovery.risky(option)).front()
	check(Discovery.payout(2, true, approach, true) == 38
		and Discovery.payout(2, true, approach, false) == 28, "Only success earns stackable risk and hazard bonuses")
