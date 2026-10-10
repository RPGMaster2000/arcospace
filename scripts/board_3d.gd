extends "res://scripts/board.gd"

# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# All card rules, input and turn handling are inherited unchanged.
func refresh_display() -> void:
	super.refresh_display()
	$BattleView/Viewport/Battlefield/PlayerShip/Shield.visible = player_shields > 0
	$BattleView/Viewport/Battlefield/EnemyShip/Shield.visible = enemy_shields > 0
