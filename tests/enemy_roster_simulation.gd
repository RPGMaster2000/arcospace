extends "res://tests/card_progression_simulation.gd"
# Diagnostic: real resolver/draws/AI, base players, no modifiers or escape, 40-round bound.
func run() -> void:
	print("player,enemy,wins,losses,unresolved,average_rounds")
	for player in Ships.PLAYERS:
		for enemy in Ships.ENEMIES:
			var totals: Dictionary = {"wins":0,"losses":0,"unresolved":0,"rounds":0,"drawn":0,"played":0,"early":0,"burst":0}
			for seed_value in range(1, 11): simulate(player, enemy, "updated", seed_value, totals)
			print("%s,%s,%d,%d,%d,%.1f" % [player.ship_name,enemy.ship_name,totals.wins,totals.losses,totals.unresolved,totals.rounds / 10.0])
	quit()
