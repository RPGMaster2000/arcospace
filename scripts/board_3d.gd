extends "res://scripts/board.gd"


# RESPONSIBILITY: Connect the optional 3D presentation to the existing board.
# DOES NOT: Redefine card rules, input or turn handling; these are inherited from board.gd.
var destruction_started: bool = false
var destruction_pending: bool = false
@export var cinematic_settings: Resource = preload("res://resources/presentation/battle_cinematics.tres")
var cinematic_director: Node
const CombatForecast = preload("res://scripts/combat/combat_forecast.gd")
var _beam_choreographed := false
var _skip_destruction_camera := false
var _camera_attack: Dictionary = {}
# Presentation latches only; rewards remain committed by Board._record_result.
var victory_started := false
var victory_pending := false
var emp_presented := false
var emp_pending := false
var victory_ready := false
var victory_transition: CanvasLayer



func refresh_display() -> void:
	if (
		not winner.is_empty() and result_cause == "hull" and not escaped_by_ftl
		and (player_hull <= 0 or enemy_hull <= 0) and not destruction_started
		and not resolving_card and not battle_effects.busy
	):
		destruction_started = true
		if battle_effects.enabled:
			_destroy_ships()
		elif not _presentation_locked() and not _skip_destruction_camera:
			var victim = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
			cinematic_director.attack(null,victim,true,false)
	if (
		_victory_eligible()
		and not victory_started
		and not destruction_pending
		and not resolving_card
		and not battle_effects.busy
		and not _presentation_locked()
	):
		victory_started = true
		victory_pending = true
		_present_victory.call_deferred()
	super.refresh_display()
	if is_instance_valid(cinematic_director): cinematic_director.mask_ui()
	if not is_instance_valid(cinematic_director) or not cinematic_director.active or cinematic_director.kind != "departure":
		$BattleView/Viewport/Battlefield/PlayerShip.engine_boost = false
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
		0 if modifier.shields_disabled() or (destruction_started and enemy_hull <= 0) or (
			is_instance_valid(cinematic_director) and is_instance_valid(cinematic_director.emp_effect)
			and cinematic_director.emp_effect._disabled
		) else enemy_shields
	)


func _display_snapshot() -> Dictionary:
	var data: Dictionary = super._display_snapshot()
	data.emp_cinematic = emp_presented
	data.emp_pending = emp_pending
	var camera_busy: bool = (
		(is_instance_valid(cinematic_director) and cinematic_director.active)
		or (victory_pending and not victory_ready) or emp_pending
	)
	data.effects_busy = data.effects_busy or destruction_pending or camera_busy
	data.resolving_card = data.resolving_card or camera_busy
	data.destruction_presenting = (
		destruction_pending
		or (
			is_instance_valid(cinematic_director)
			and cinematic_director.kind == "destruction"
			and (cinematic_director.active or victory_pending)
		)
	)
	return data


func _destroy_ships() -> void:
	destruction_pending = true
	_ensure_destruction_camera()
	var animation := create_tween()
	# Only terminal destruction presentation follows the cinematic playback speed.
	if cinematic_director.active and cinematic_director.kind == "destruction":
		animation.set_speed_scale(maxf(0.1, cinematic_settings.playback_speed))
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
const PLANETARY_BATTLEFIELD = preload("res://scenes/battlefield_planetary_orbit.tscn")
const PLAYER_HULL_LIGHT_LAYER := 1 << 18
const ENEMY_HULL_LIGHT_LAYER := 1 << 19

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
			scene = PLANETARY_BATTLEFIELD
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
	# Create the curtain first so the director cancels before it exits the tree.
	victory_transition = preload("res://scripts/presentation/star_system/white_transition.gd").new()
	add_child(victory_transition)
	victory_transition.layer = 301
	victory_transition.curtain.color = Color(0,0,0,0)
	cinematic_director = preload("res://scripts/presentation/battle_cinematic_director.gd").new()
	cinematic_director.settings = cinematic_settings
	add_child(cinematic_director)
	cinematic_director.configure(self,camera,backdrop,$BattleView)
	cinematic_director.stage_changed.connect(func(stage: String):
		if stage == "emp_discharge": $FTLPanel.discharge())
	cinematic_director.started.connect(func():
		if hud != null:
			hud.set_panels_locked(true, true))
	battle_effects.weapon_presented.connect(func(_side, weapon):
		if weapon == "beam" and _beam_choreographed: cinematic_director.beam_launched())
	cinematic_director.settled.connect(func():
		if is_inside_tree() and hud != null and not cinematic_director.exiting: refresh_display())
	engine_light = get_node_or_null("BattleView/Viewport/Battlefield/PlayerShip/Body/OmniLight3D")
	if engine_light:
		engine_base_energy = engine_light.light_energy
	super._ready()
	# Modifier scenery opts into the same isolated, shadowless hull fills.
	if (
		camera.get_parent().scene_file_path in [BATTLEFIELDS[0].resource_path, PLANETARY_BATTLEFIELD.resource_path]
		or camera.get_parent().has_node("EnvironmentGeometry")
	):
		cinematic_director.player.add_visibility_light(PLAYER_HULL_LIGHT_LAYER)
		cinematic_director.enemy.add_visibility_light(ENEMY_HULL_LIGHT_LAYER)
	for pair in [["PlayerShip", player_ship_data], ["EnemyShip", enemy_ship_data]]:
		if pair[1] != null:
			$BattleView/Viewport/Battlefield.get_node(pair[0]).set_hull_color(pair[1].hull_color)
	_fit_ftl()


func _fit_backdrop() -> void:
	# The flat starfield must cover the extra camera view as well as the viewport.
	var height_scale: float = maxf(1.0, (size.y - 325.0) / 395.0)
	var fitted_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(baseline_fov) * 0.5) * height_scale))
	var fitted_scale := backdrop_scale
	if not backdrop.get_meta("infinite_panorama", false):
		fitted_scale *= maxf(height_scale, size.x / 1280.0)
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
	# Shared HUD placement is independent of camera and idle motion.
	_fit_allocation_button()

func _begin_battle_presentation() -> void:
	await cinematic_director.introduction(
		enemy_ship_data.ship_name if enemy_ship_data != null else "Enemy Ship",
		enemy_ship_data.subtitle if enemy_ship_data != null else "Unknown Vessel"
	)
	if is_inside_tree() and not is_queued_for_deletion() and not checkpoint_exit and not cinematic_director.exiting:
		_begin_turn("player")

func _begin_emp_presentation() -> void:
	if not is_instance_valid(cinematic_director) or not cinematic_director.allowed(): return
	emp_presented = true
	# The director cancels any old presentation before acquiring the camera.
	# Keep the committed result masked through that handoff as well.
	emp_pending = true
	await cinematic_director.emp_victory(ftl.rng.seed)
	emp_pending = false
	if is_inside_tree() and not is_queued_for_deletion() and not checkpoint_exit and not cinematic_director.exiting:
		refresh_display()


func _presentation_locked() -> bool:
	return victory_pending or emp_pending or (is_instance_valid(cinematic_director) and cinematic_director.active)

func _prepare_beam_presentation(side: String, card: Resource) -> float:
	if not cinematic_director.allowed(): return 0.0
	var other := "enemy" if side == "player" else "player"
	var forecast := CombatForecast.predict(card, ship_snapshot(side), ship_snapshot(other), modifier.forecast_context())
	var cinematic: bool = forecast.outcomes.any(func(outcome):
		var damage: int = outcome.damage.get("direct_damage", 0)
		return damage >= cinematic_settings.heavy_beam_threshold or (damage > 0 and outcome.target.hull <= 0))
	if not cinematic: return 0.0
	_beam_choreographed = true
	var actor: Node3D = cinematic_director.player if side == "player" else cinematic_director.enemy
	var victim: Node3D = cinematic_director.enemy if side == "player" else cinematic_director.player
	await cinematic_director.beam_charge(actor, victim)
	return cinematic_settings.duration(cinematic_settings.beam_turn_seconds) if cinematic_director.active and not cinematic_director.skipped else 0.0

func _beam_reached_target() -> void:
	if _beam_choreographed: cinematic_director.beam_impact()

func _card_resolution_presented(side: String, _damage: int, _discard: bool) -> void:
	_camera_attack = {"actor": side, "presented": false}
	_try_attack_camera()

func _committed_damage_presented() -> void:
	_try_attack_camera()

func _try_attack_camera() -> void:
	if not is_instance_valid(cinematic_director) or cinematic_director.exiting: return
	if _camera_attack.is_empty() or _camera_attack.presented or not damage_timeline.pending.is_empty(): return
	var destroyed: bool = not winner.is_empty() and result_cause == "hull" and not escaped_by_ftl
	if not destroyed: return
	_camera_attack.presented = true
	if _beam_choreographed:
		_skip_destruction_camera = true
		if battle_effects.enabled: cinematic_director.finish_beam(true)
		return
	var actor: Node3D = $BattleView/Viewport/Battlefield.get_node("PlayerShip" if _camera_attack.actor == "player" else "EnemyShip")
	var victim: Node3D = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if _camera_attack.actor == "player" else "PlayerShip")
	if destroyed: victim = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
	cinematic_director.attack(actor,victim,destroyed,destroyed and battle_effects.enabled)

func _ensure_destruction_camera() -> void:
	if _skip_destruction_camera or not is_instance_valid(cinematic_director) or cinematic_director.exiting or cinematic_director.active: return
	var victim: Node3D = $BattleView/Viewport/Battlefield.get_node("EnemyShip" if enemy_hull <= 0 else "PlayerShip")
	cinematic_director.attack(null,victim,true,true)

func _wait_action_presentation() -> void:
	if _beam_choreographed:
		if cinematic_director.active and cinematic_director.kind == "heavy_beam":
			await cinematic_director.finish_beam(false)
		_beam_choreographed = false
	while _presentation_locked() and cinematic_director.kind != "destruction":
		await cinematic_director.settled
	_camera_attack = {}

func play_victory_departure(transition: CanvasLayer) -> bool:
	return await cinematic_director.departure(transition)


func _victory_eligible() -> bool:
	return (
		is_instance_valid(cinematic_director)
		and cinematic_director.enabled()
		and result_recorded
		and winner == "player"
		and player_hull > 0
		and not escaped_by_ftl
	)


func _present_victory() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or checkpoint_exit:
		return
	await cinematic_director.departure(victory_transition)
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or checkpoint_exit
		or not is_instance_valid(cinematic_director)
		or cinematic_director.exiting
	):
		return
	# The outcome is already authoritative. Prepare the existing result screen
	# under black, then reveal its own animation without another scene fade.
	$BattleView/Viewport/Battlefield/PlayerShip.hide()
	$BattleView/Viewport/Battlefield/EnemyShip.hide()
	victory_ready = true
	refresh_display()
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion() or checkpoint_exit:
		return
	victory_transition.cancel()
	victory_pending = false
	refresh_display()
