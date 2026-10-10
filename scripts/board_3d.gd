extends "res://scripts/board.gd"

# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# All card rules, input and turn handling are inherited unchanged.
func refresh_display() -> void:
	super.refresh_display()
	$BattleView/Viewport/Battlefield/PlayerShip.set_hull_strength(player_hull)
	$BattleView/Viewport/Battlefield/EnemyShip.set_hull_strength(enemy_hull)
	$BattleView/Viewport/Battlefield/PlayerShip.set_shield_strength(player_shields)
	$BattleView/Viewport/Battlefield/EnemyShip.set_shield_strength(enemy_shields)
