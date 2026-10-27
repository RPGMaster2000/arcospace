extends SceneTree
const Pressure = preload("res://scripts/expedition/system_pressure.gd")
const Progression = preload("res://resources/expedition_progression.tres")
const Base = preload("res://ships/enemy/marauder.tres")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var original_hull: int = Base.hull_capacity
	var original_shields: int = Base.shields
	for system in [1, 4, 10]:
		var progressed: Resource = Progression.scaled_enemy(Base, system)
		for pressure in [0, 3, 4, 6, 7, 9, 10, 20]:
			var expected: float = 1.2 if pressure >= 10 else (1.1 if pressure >= 7 else 1.0)
			var enemy: Resource = Pressure.scaled_enemy(progressed, pressure)
			check(enemy.hull_capacity == ceili(progressed.hull_capacity * expected), "Pressure scales progressed Hull once")
			check(enemy.shields == ceili(progressed.shields * expected), "Pressure scales progressed Shields once")
			check(enemy.energy == progressed.energy and enemy.reactor == progressed.reactor, "Other enemy statistics unchanged")
			check(enemy != progressed, "Battle gets detached starting profile")
			check(Pressure.description(pressure).is_empty() == (pressure < 7), "Briefing modifier describes actual tier")
	check(Base.hull_capacity == original_hull and Base.shields == original_shields, "Shared ship resource remains unchanged")
	print("System pressure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
