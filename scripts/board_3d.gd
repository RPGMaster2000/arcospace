extends "res://scripts/board.gd"

# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# All card rules, input and turn handling are inherited unchanged.
func refresh_display() -> void:
	super.refresh_display()
	$BattleView/Viewport/Battlefield/PlayerShip.set_hull_strength(player_hull)
	$BattleView/Viewport/Battlefield/EnemyShip.set_hull_strength(enemy_hull)
	$BattleView/Viewport/Battlefield/PlayerShip.set_shield_strength(player_shields)
	$BattleView/Viewport/Battlefield/EnemyShip.set_shield_strength(enemy_shields)

var backdrop_scale: Vector3
var backdrop: MeshInstance3D
var battle_camera: Camera3D
var baseline_fov: float

func _ready() -> void:
	var camera: Camera3D = $BattleView/Viewport/Battlefield/Camera3D
	# Keep the existing 16:9 framing, then reveal more horizontally on wider screens.
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(camera.fov) * 0.5) / (1280.0 / 395.0)))
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
	battle_camera = camera
	baseline_fov = camera.fov
	backdrop = $BattleView/Viewport/Battlefield/MeshInstance3D
	backdrop_scale = backdrop.scale
	resized.connect(_fit_backdrop)
	_fit_backdrop()
	super._ready()

func _fit_backdrop() -> void:
	# The flat starfield must cover the extra camera view as well as the viewport.
	var height_scale: float = maxf(1.0, (size.y - 325.0) / 395.0)
	battle_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(baseline_fov) * 0.5) * height_scale))
	backdrop.scale = backdrop_scale * maxf(height_scale, size.x / 1280.0)
