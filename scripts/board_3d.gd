extends "res://scripts/board.gd"


# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# DOES NOT: Redefine card rules, input or turn handling; these are inherited from board.gd.
var destruction_started: bool = false
var destruction_pending: bool = false
@export var cinematic_settings: Resource = preload("res://resources/presentation/battle_cinematics.tres")
var cinematic_director: Node
var _beam_side := ""
var _camera_attack: Dictionary = {}



func refresh_display() -> void:
	if (
		not winner.is_empty() and result_cause == "hull" and not escaped_by_ftl
		and (player_hull <= 0 or enemy_hull <= 0) and not destruction_started
		and not resolving_card and not battle_effects.busy
	):
		destruction_started = true
		if battle_effects.enabled:
			_destroy_ships()
		elif not _presentation_locked():
			var victim = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
			cinematic_director.attack(null,victim,true,false)
	super.refresh_display()
	if is_instance_valid(cinematic_director): cinematic_director.mask_ui()
	$BattleView/Viewport/Battlefield/PlayerShip.engine_boost = escaped_by_ftl
	$BattleView/Viewport/Battlefield/PlayerShip.set_hull_strength(
		mini(player_hull, player_hull_capacity)
	)
	$BattleView/Viewport/Battlefield/EnemyShip.set_hull_strength(
		mini(enemy_hull, enemy_hull_capacity)
	)
	$BattleView/Viewport/Battlefield/PlayerShip.set_shield_strength(
		0 if modifier.shields_disabled() or (destruction_started and player_hull <= 0) else player_shields
	)
	$BattleView/Viewport/Battlefield/EnemyShip.set_shield_strength(
		0 if modifier.shields_disabled() or (destruction_started and enemy_hull <= 0) else enemy_shields
	)


func _display_snapshot() -> Dictionary:
	var data: Dictionary = super._display_snapshot()
	data.effects_busy = data.effects_busy or destruction_pending or _presentation_locked()
	data.resolving_card = data.resolving_card or _presentation_locked()
	return data


func _destroy_ships() -> void:
	destruction_pending = true
	_ensure_destruction_camera()
	var animation := create_tween()
	for pair in [["PlayerShip", player_hull], ["EnemyShip", enemy_hull]]:
		if pair[1] <= 0:
			$BattleView/Viewport/Battlefield.get_node(pair[0]).animate_destruction(animation)
	await animation.finished
	destruction_pending = false
	if is_instance_valid(cinematic_director): cinematic_director.release_destruction()
	refresh_display()


# EDIT: Each scene is an independent battlefield layout for this setup selection.
# Keep Camera3D, MeshInstance3D, PlayerShip and EnemyShip node names for board wiring.
const BATTLEFIELDS = [
	preload("res://scenes/battlefield_3d.tscn"),
	preload("res://scenes/battlefield_asteroid_belt.tscn"),
	preload("res://scenes/battlefield_ion_storm.tscn"),
	preload("res://scenes/battlefield_solar_flare.tscn"),
	preload("res://scenes/battlefield_nebula.tscn"),
	preload("res://scenes/battlefield_temporal_rift.tscn"),
	preload("res://scenes/battlefield_metal_storm.tscn"),
	preload("res://scenes/battlefield_psionic_storm.tscn")
]

## TUNE: Optional normal-only override; empty randomizes Deep Space / Planetary Orbit.
## Drag battlefield_planetary_orbit.tscn here to use that normal variant. No gameplay RNG or modifier changes.
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
	var scene: PackedScene = (
		normal_battlefield
		if selection == 0 and normal_battlefield != null
		else BATTLEFIELDS[selection]
	)
	if selection == 0 and normal_battlefield == null:
		var visual_rng := RandomNumberGenerator.new()
		visual_rng.randomize()
		if visual_rng.randi_range(0, 1) == 1:
			scene = preload("res://scenes/battlefield_planetary_orbit.tscn")
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
			# Arena instances supply pose; the model supplies its authored size.
			# Strip fallback scaling so it is not multiplied into a custom model.
			location.basis = location.basis.orthonormalized()
			model.transform = location * model.transform
			battlefield.add_child(model)
	viewport.add_child(battlefield)
	$BattleView.set_environment(selection)


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
	cinematic_director = preload("res://scripts/presentation/battle_cinematic_director.gd").new()
	cinematic_director.settings = cinematic_settings
	add_child(cinematic_director)
	cinematic_director.configure(self,camera,backdrop,$BattleView)
	battle_effects.weapon_presented.connect(func(side, weapon):
		if weapon == "beam": _beam_side = side)
	cinematic_director.settled.connect(func():
		if is_inside_tree() and hud != null and not cinematic_director.exiting: refresh_display())
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
	var fitted_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(baseline_fov) * 0.5) * height_scale))
	var fitted_scale := backdrop_scale * maxf(height_scale, size.x / 1280.0)
	if is_instance_valid(cinematic_director) and cinematic_director.active:
		cinematic_director.default_fov = fitted_fov
		cinematic_director.default_backdrop_scale = fitted_scale
	else:
		battle_camera.fov = fitted_fov
		backdrop.scale = fitted_scale
	_fit_ftl()


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
	# Shared HUD placement follows the Hull bar, independently of camera/idle motion.
	_fit_allocation_button()
	_fit_jump_button()

func _begin_battle_presentation() -> void:
	await cinematic_director.introduction()
	if is_inside_tree() and not is_queued_for_deletion() and not checkpoint_exit and not cinematic_director.exiting:
		_begin_turn("player")

func _presentation_locked() -> bool:
	return is_instance_valid(cinematic_director) and cinematic_director.active

func _card_resolution_presented(side: String, damage: int, discard: bool) -> void:
	_camera_attack = {"actor":side,"damage":damage,"beam":not discard and _beam_side == side,"presented":false}
	_beam_side = ""
	_try_attack_camera()

func _committed_damage_presented() -> void:
	_try_attack_camera()

func _try_attack_camera() -> void:
	if not is_instance_valid(cinematic_director) or cinematic_director.exiting: return
	if _camera_attack.is_empty() or _camera_attack.presented or not damage_timeline.pending.is_empty(): return
	var destroyed: bool = not winner.is_empty() and result_cause == "hull" and not escaped_by_ftl
	if not destroyed and (not _camera_attack.beam or _camera_attack.damage < cinematic_settings.heavy_beam_threshold): return
	_camera_attack.presented = true
	var actor: Node3D = $BattleView/Viewport/Battlefield.get_node("PlayerShip" if _camera_attack.actor == "player" else "EnemyShip")
	var victim: Node3D = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if _camera_attack.actor == "player" else "PlayerShip")
	if destroyed: victim = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
	cinematic_director.attack(actor,victim,destroyed,destroyed and battle_effects.enabled)

func _ensure_destruction_camera() -> void:
	if not is_instance_valid(cinematic_director) or cinematic_director.exiting or cinematic_director.active: return
	var victim: Node3D = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
	cinematic_director.attack(null,victim,true,true)

func _wait_action_presentation() -> void:
	while _presentation_locked() and cinematic_director.kind != "destruction":
		await cinematic_director.settled
	_camera_attack = {}

func play_victory_departure(transition: CanvasLayer) -> bool:
	return await cinematic_director.departure(transition)
