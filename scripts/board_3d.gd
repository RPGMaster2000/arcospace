extends "res://scripts/board.gd"

# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# DOES NOT: Redefine card rules, input or turn handling; these are inherited from board.gd.
func refresh_display() -> void:
	super.refresh_display()
	$BattleView/Viewport/Battlefield/PlayerShip.set_hull_strength(mini(player_hull, player_hull_capacity))
	$BattleView/Viewport/Battlefield/EnemyShip.set_hull_strength(mini(enemy_hull, enemy_hull_capacity))
	$BattleView/Viewport/Battlefield/PlayerShip.set_shield_strength(0 if modifier.shields_disabled() else player_shields)
	$BattleView/Viewport/Battlefield/EnemyShip.set_shield_strength(0 if modifier.shields_disabled() else enemy_shields)

# EDIT: Each scene is an independent battlefield layout for this setup selection.
# Keep Camera3D, MeshInstance3D, PlayerShip and EnemyShip node names for board wiring.
const BATTLEFIELDS = [
	preload("res://scenes/battlefield_3d.tscn"),
	preload("res://scenes/battlefield_asteroid_belt.tscn"),
	preload("res://scenes/battlefield_ion_storm.tscn"),
	preload("res://scenes/battlefield_solar_flare.tscn"),
	preload("res://scenes/battlefield_nebula.tscn"),
	preload("res://scenes/battlefield_temporal_rift.tscn")
]

## TUNE: Optional normal-only presentation override; leave empty for Deep Space.
## Drag battlefield_planetary_orbit.tscn here to use that normal variant. No RNG or modifier changes.
@export var normal_battlefield: PackedScene

# Install the selected battlefield/model before child _ready callbacks cache presentation nodes.
func _enter_tree() -> void:
	super._enter_tree()
	# Replace before child _ready callbacks cache the ships for visual effects.
	var selection: int = clampi(int(setup_settings.get("modifier", 0)), 0, BATTLEFIELDS.size() - 1)

	var viewport = $BattleView/Viewport
	var previous = viewport.get_node("Battlefield")
	viewport.remove_child(previous)
	previous.free()
	var scene: PackedScene = normal_battlefield if selection == 0 and normal_battlefield != null else BATTLEFIELDS[selection]
	var battlefield = scene.instantiate()
	battlefield.name = "Battlefield"
	for pair in [["PlayerShip", player_ship_data], ["EnemyShip", enemy_ship_data]]:
		var data = pair[1]
		if data != null and data.model_scene != null:
			var old = battlefield.get_node(pair[0])
			var location = old.transform
			battlefield.remove_child(old)
			old.free()
			var model = data.model_scene.instantiate()
			model.name = pair[0]
			model.transform = location
			battlefield.add_child(model)
	viewport.add_child(battlefield)

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
	engine_light = get_node_or_null("BattleView/Viewport/Battlefield/PlayerShip/Body/OmniLight3D")
	if engine_light:
		engine_base_energy = engine_light.light_energy
	super._ready()
	for pair in [["PlayerShip", player_ship_data], ["EnemyShip", enemy_ship_data]]:
		if pair[1] != null:
			$BattleView/Viewport/Battlefield.get_node(pair[0]).set_hull_color(pair[1].hull_color)
	_fit_ftl()

func _fit_backdrop() -> void:
	# The flat starfield must cover the extra camera view as well as the viewport.
	var height_scale: float = maxf(1.0, (size.y - 325.0) / 395.0)
	battle_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(baseline_fov) * 0.5) * height_scale))
	backdrop.scale = backdrop_scale * maxf(height_scale, size.x / 1280.0)
	_fit_ftl()

## TUNE: Fine placement offset from the mirrored FTL position, in UI pixels.
@export var ftl_position_offset: Vector2 = Vector2(-40, 5)

## TUNE: Engine light factors relative to its scene-authored brightness.
@export var engine_offline_factor: float = 0.3
@export var engine_ready_factor: float = 1.4
@export var engine_pulse_depth: float = 0.10
@export var engine_pulse_speed: float = 2.0
var engine_light: OmniLight3D
var engine_base_energy: float = 0.0
var engine_phase: float = 0.0

func _process(delta: float) -> void:
	if not engine_light:
		return
	engine_phase += delta * engine_pulse_speed
	var factor: float = engine_offline_factor if ftl.disabled_turns > 0 else 1.0
	if ftl.can_warp():
		factor = engine_ready_factor * (1.0 + engine_pulse_depth * sin(engine_phase))
	engine_light.light_energy = engine_base_energy * factor

func _fit_ftl() -> void:
	if not battle_camera:
		return
	var container: Control = $BattleView
	var viewport: SubViewport = $BattleView/Viewport
	var ship: Node3D = $BattleView/Viewport/Battlefield/PlayerShip
	var ship_center: Vector2 = container.position + battle_camera.unproject_position(ship.global_position) * container.size / Vector2(viewport.size)
	var hull_center: float = $PlayerHullLabel.position.y + $PlayerHullLabel.size.y * 0.5
	# Mirror Hull status vertically about the ship, and center FTL horizontally on it.
	$FTLPanel.position = Vector2(ship_center.x - $FTLPanel.size.x * 0.5, ship_center.y * 2.0 - hull_center - $FTLPanel.size.y * 0.5) + ftl_position_offset
	$FTLPanel.position.x = clampf($FTLPanel.position.x, 16, size.x - $FTLPanel.size.x - 16)
	_fit_jump_button()
	_fit_allocation_button()

## TUNE: Ship-relative offset as fractions of the battle presentation height, not engine coordinates.
@export var allocation_presentation_offset: Vector2 = Vector2(-0.56, 0.02)

func _fit_allocation_button() -> void:
	if not is_instance_valid(allocation_button) or not battle_camera: return
	var area: Control = $BattleView
	var viewport: SubViewport = $BattleView/Viewport
	var player: Node3D = $BattleView/Viewport/Battlefield/PlayerShip
	var center: Vector2 = area.position + battle_camera.unproject_position(player.global_position) * area.size / Vector2(viewport.size)
	var location: Vector2 = center + allocation_presentation_offset * area.size.y - allocation_button.size * 0.5
	# Keep the resource column, top HUD, Hull/Shields and hand accessible.
	location.x = clampf(location.x, 136, size.x - allocation_button.size.x - 16)
	location.y = clampf(location.y, 80, minf($PlayerHullLabel.position.y - allocation_button.size.y - 12, size.y - 340))
	allocation_button.position = location
