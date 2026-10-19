extends "res://tests/card_progression_simulation.gd"
# Diagnostic only: identical seed set, base ship pools, real 2/2/2 opening.
# No modifiers, EMP escape, expedition bonuses or human decisions; not a win-rate forecast.
func run() -> void:
	print("ship,wins,losses,unresolved,average_rounds")
	for player in Ships.PLAYERS:
		var totals: Dictionary = {"wins":0,"losses":0,"unresolved":0,"rounds":0,"drawn":0,"played":0,"early":0,"burst":0}
		for enemy in Config.enemy_ships:
			for seed_value in range(1,11): simulate(player, enemy, "updated", seed_value, totals)
		var matches: int = Config.enemy_ships.size() * 10
		print("%s,%d,%d,%d,%.1f" % [player.ship_name, totals.wins, totals.losses, totals.unresolved, float(totals.rounds) / matches])
	quit()
