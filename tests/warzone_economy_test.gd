extends SceneTree

const Sector = preload("res://scripts/expedition/warzone_sector.gd")
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
	print("Warzone economy: %d failures" % failures)
	quit(int(failures > 0))
