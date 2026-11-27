extends Control

# Combat renderers share the frozen entry configuration; no independent phenomenon roll.
var battle_environment: Dictionary:
	get: return battle_setup.environment if battle_setup != null else {}

# RESPONSIBILITY: Coordinate both hands, turns, effects and board display.
# DOES NOT: Choose AI moves, implement card effects or render HUD controls.

# EXTEND: _resolve_card commits state; BattleEffects owns VFX, BattleHUD owns UI, MatchRules owns wins.
signal action_finished(side: String, discarded: bool)
signal expedition_continue
signal expedition_restart
signal expedition_exit
signal developer_one_hit_kill_changed(enabled: bool)
const BattleResult = preload("res://scripts/combat/battle_result.gd")
const BattleSetup = preload("res://scripts/combat/battle_setup.gd")
const BattleEnvironment = preload("res://scripts/expedition/battle_environment.gd")
const BattleAdapter = preload("res://scripts/combat/battle_adapter.gd")
var battle_setup: BattleSetup
var expedition: Resource
var expedition_encounter: int = -1
var developer_one_hit_kill := false
## TUNE: Static Power Allocation weight; copied into the player hand at battle start.
@export var allocation_settings: Resource = preload("res://resources/power_allocation.tres")
var settings_button: Button
var allocation_button: Button
var allocation_popup: CanvasLayer

const PendingHullDamage = preload("res://scripts/combat/pending_hull_damage.gd")
var damage_timeline: PendingHullDamage
const BattleHUD = preload("res://scripts/ui/battle_hud.gd")
var hud: BattleHUD

const Ships = preload("res://scripts/ships/ship_library.gd")
const ResultPresentation = preload("res://scripts/ui/encounter_presentation.gd")
var player_ship_data: Resource
var enemy_ship_data: Resource

const ShipCombatState = preload("res://scripts/combat/ship_combat_state.gd")
var _player_state = ShipCombatState.new()
var _enemy_state = ShipCombatState.new()

const MatchRules = preload("res://scripts/match_rules.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
# Assign the six editable scene card buttons in the Inspector.
@export var card_slots: Array[NodePath] = [
	NodePath("ShieldPlatingCard"),
	NodePath("SynthesizerUpgradeCard"),
	NodePath("LaserBurstCard"),
	NodePath("EnergyCellCard"),
	NodePath("QuartersUpgradeCard"),
	NodePath("TorpedoSalvoCard")
]
## TUNE: Full affected-ship turns available to recover production after activation.
@export_range(1, 20, 1) var systems_failure_turns: int = 3
const SystemsFailure = preload("res://scripts/combat/systems_failure.gd")
var systems_failure = SystemsFailure.new()
var result_cause: String = ""
## TUNE in Board3D Inspector: permanent capacity for each ship; excess is temporary plating.
@export_range(1, 1000, 1) var player_hull_capacity: int = 30:
	get: return _player_state.hull_capacity
	set(value): _player_state.hull_capacity = value
@export_range(1, 1000, 1) var enemy_hull_capacity: int = 30:
	get: return _enemy_state.hull_capacity
	set(value): _enemy_state.hull_capacity = value
const ProgressionActions = preload("res://scripts/combat/progression_actions.gd")
var progression_actions := ProgressionActions.new()
const ProgressionCheckpoint = preload("res://scripts/combat/progression_checkpoint.gd")
var resume_combat: Dictionary = {}
var settled_combat: Dictionary = {}
var overdrive_triggered := false
var overdrive_button: MenuButton
var overdrive_choices: Array[Dictionary] = []
var beam_notice: Label
var current_actor: String = "player"
var turn_number: int = 1
var last_turret_round: int = 0
var winner: String = ""
var escaped_by_ftl: bool = false
# A continuation carries only hull; setup resources/production and shields reset normally.
var continuation_hull: int = -1
var encounter_number: int = 1
var next_modifier: int = -1
var salvage: int = 0
var salvage_rewards: Dictionary = {}
var strategic_summary := ""
var battles_won: int = 0
var result_recorded: bool = false
var result_salvage_gained: int = 0
# Leaving an unfinished battle preserves its entry checkpoint, including during VFX cleanup.
var checkpoint_exit: bool = false
# Presentation-only latch: reward recording can precede the visible result.
var result_music_started: bool = false
var earned_tactical: bool = false
var earned_strategic: bool = false
var result_hull: int = 0
## TUNE: Salvage per destroyed enemy.
const DESTRUCTION_SALVAGE: int = 10
var starting_player_hull: int = 0
var player_hull_damage_taken: int = 0
# Pending rewards belong only to this encounter, never permanent setup values.
var pending_resource_bonus: int = 0
var pending_shield_bonus: int = 0
## TUNE: Next-battle rewards for tactical and strategic victories.
const TACTICAL_RESOURCES: int = preload("res://scripts/combat/battle_result.gd").TACTICAL_RESOURCES
const STRATEGIC_SHIELDS: int = preload("res://scripts/combat/battle_result.gd").STRATEGIC_SHIELDS
# Settings are assigned before adding the board to the scene tree.
var setup_settings: Dictionary = {}
@onready var modifier = $CombatModifier
var extra_action_requested: bool = false
# Card replacement is delayed until its owner begins the next turn.
var pending_card_draws: Dictionary = {"player": [], "enemy": []}
const InterfaceMotion = preload("res://scripts/ui/battle_interface_motion.gd")
var interface_motion: InterfaceMotion
var resolving_card: bool = false
@onready var ftl = $FTLDrive
@onready var hand = $CardHand
@onready var enemy_hand = $EnemyHand
@onready var enemy_ai = $EnemyAI
@onready var battle_effects = $BattleEffects
@onready var enemy_timer: Timer = $EnemyThinkTimer

#PLAYER
## TUNE: Starting hull for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_hull: int = 30:
	get: return _player_state.hull
	set(value): _player_state.hull = value
## TUNE: Starting shields for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_shields: int = 10:
	get: return _player_state.shields
	set(value): _player_state.shields = value

## TUNE: Starting materials for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_materials: int = 16:
	get: return _player_state.materials
	set(value): _player_state.materials = value
## TUNE: Starting energy for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_energy: int = 16:
	get: return _player_state.energy
	set(value): _player_state.energy = value
## TUNE: Starting crew for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_crew: int = 16:
	get: return _player_state.crew
	set(value): _player_state.crew = value

## TUNE: Starting materials gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_synthesizer: int = 2:
	get: return _player_state.synthesizer
	set(value): _player_state.synthesizer = value
## TUNE: Starting energy gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_reactor: int = 2:
	get: return _player_state.reactor
	set(value): _player_state.reactor = value
## TUNE: Starting crew gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_quarters: int = 2:
	get: return _player_state.quarters
	set(value): _player_state.quarters = value

# ENEMY
## TUNE: Starting hull for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_hull: int = 30:
	get: return _enemy_state.hull
	set(value): _enemy_state.hull = value
## TUNE: Starting shields for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_shields: int = 10:
	get: return _enemy_state.shields
	set(value): _enemy_state.shields = value

## TUNE: Starting materials for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_materials: int = 16:
	get: return _enemy_state.materials
	set(value): _enemy_state.materials = value
## TUNE: Starting energy for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_energy: int = 16:
	get: return _enemy_state.energy
	set(value): _enemy_state.energy = value
## TUNE: Starting crew for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_crew: int = 16:
	get: return _enemy_state.crew
	set(value): _enemy_state.crew = value

## TUNE: Starting materials gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_synthesizer: int = 2:
	get: return _enemy_state.synthesizer
	set(value): _enemy_state.synthesizer = value
## TUNE: Starting energy gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_reactor: int = 2:
	get: return _enemy_state.reactor
	set(value): _enemy_state.reactor = value
## TUNE: Starting crew gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_quarters: int = 2:
	get: return _enemy_state.quarters
	set(value): _enemy_state.quarters = value

@onready var player_hull_label: Label = $PlayerHullLabel
@onready var player_shields_label: Label = $PlayerShieldsLabel
@onready var enemy_hull_label: Label = $EnemyHullLabel
@onready var enemy_shields_label: Label = $EnemyShieldsLabel

@onready var player_materials_label = $PlayerResource1/materials
@onready var player_synthesizer_label = $PlayerResource1/synthesizer

@onready var player_energy_label: Label = $PlayerResource2/energy
@onready var player_reactor_label: Label = $PlayerResource2/reactor
@onready var player_crew_label: Label = $PlayerResource3/crew
@onready var player_quarters_label: Label = $PlayerResource3/quarters
@onready var enemy_materials_label: Label = $EnemyResource1/materials
@onready var enemy_synthesizer_label: Label = $EnemyResource1/synthesizer
@onready var enemy_energy_label: Label = $EnemyResource2/energy
@onready var enemy_reactor_label: Label = $EnemyResource2/reactor
@onready var enemy_crew_label: Label = $EnemyResource3/crew
@onready var enemy_quarters_label: Label = $EnemyResource3/quarters

var mode_rule_origin: Vector2
var hand_rule_origin: Vector2

#region Initialization


func _enter_tree() -> void:
	# Ship selection persists in setup settings. Enemy is rolled anew per board instance.
	if setup_settings.has("player_ship"):
		player_ship_data = Ships.PLAYERS[clampi(
			int(setup_settings.player_ship), 0, Ships.PLAYERS.size() - 1
		)]
		if setup_settings.has("player_data"):
			player_ship_data = setup_settings.player_data
		var generator = RandomNumberGenerator.new()
		generator.randomize()
		enemy_ship_data = Ships.ENEMIES[generator.randi_range(0, Ships.ENEMIES.size() - 1)]
		if setup_settings.has("enemy_ship"):
			enemy_ship_data = Ships.ENEMIES[clampi(
				int(setup_settings.enemy_ship), 0, Ships.ENEMIES.size() - 1
			)]
		if setup_settings.has("enemy_data"):
			enemy_ship_data = setup_settings.enemy_data


func _apply_ship(side: String, data: Resource) -> void:
	if data == null:
		return
	(_player_state if side == "player" else _enemy_state).configure_profile(data)


# Initialize ship stats and expedition overrides before dealing hands and starting turn income.
func _ready() -> void:
	get_node("/root/Music").play_battle()
	settings_button = preload("res://scripts/ui/battle_menu.gd").new()
	if expedition != null and not expedition.developer_test.is_empty():
		settings_button.developer_one_hit_kill_available = true
		settings_button.developer_one_hit_kill_enabled = developer_one_hit_kill
		settings_button.developer_one_hit_kill_changed.connect(func(enabled: bool):
			developer_one_hit_kill = enabled
			developer_one_hit_kill_changed.emit(enabled))
	settings_button.z_index = 110  # Keep settings accessible above the result screen's shade.
	add_child(settings_button)
	settings_button.main_menu_requested.connect(_return_to_setup)
	$MatchResult/Panel/Details.add_theme_font_override("font", ResultPresentation.UI_FONT)
	$MatchResult/Panel/Rewards.add_theme_font_override("font", ResultPresentation.UI_FONT)
	_apply_ship("player", player_ship_data)
	_apply_ship("enemy", enemy_ship_data)
	for side in ["player", "enemy"]:
		for key in MatchRules.RESOURCES + MatchRules.PRODUCTION:
			var setting: String = side + "_" + key
			if setup_settings.has(setting):
				set(setting, int(setup_settings[setting]))
	if continuation_hull >= 0:
		player_hull = mini(continuation_hull, player_hull_capacity)
	starting_player_hull = player_hull
	for key in MatchRules.RESOURCES:
		set("player_" + key, get("player_" + key) + pending_resource_bonus)
	player_shields += pending_shield_bonus
	$MatchResult/Panel/Continue.pressed.connect(_continue_encounter)
	ftl.charge_target = (
		player_ship_data.ftl_turns
		if player_ship_data != null
		else maxi(1, int(setup_settings.get("ftl_turns", ftl.FULL_CHARGE)))
	)
	ftl.failure_multiplier = (
		1.0 - player_ship_data.ftl_resistance if player_ship_data != null else 1.0
	)
	if (
		player_ship_data != null
		and hand.card_pool.is_empty()
		and not player_ship_data.starting_cards.is_empty()
	):
		hand.card_pool.assign(player_ship_data.starting_cards)
	if player_ship_data != null:
		hand.signature_card = player_ship_data.signature_card
	if enemy_ship_data != null:
		if not enemy_ship_data.starting_cards.is_empty():
			enemy_hand.card_pool.assign(enemy_ship_data.starting_cards)
		enemy_hand.family_weights = enemy_ship_data.card_family_weights
		enemy_hand.effect_weights = enemy_ship_data.card_effect_weights
		enemy_ai.tactical_weights = enemy_ship_data.tactical_weights
		enemy_ai.tactical_variation = enemy_ship_data.tactical_variation
		enemy_ai.hull_capacity = enemy_ship_data.hull_capacity
	if expedition != null:
		if battle_setup == null:
			battle_setup = expedition.prepare_battle(expedition_encounter, enemy_ship_data)
		BattleAdapter.apply_setup(self, battle_setup)
		expedition.deck_changed.connect(_sync_expedition_hand)
		starting_player_hull = player_hull
	modifier.configure(int(setup_settings.get("modifier", 0)), battle_setup.battle_seed if battle_setup != null else -1)
	if expedition != null and expedition.system_number < 3:
		enemy_hand.tier_three_chance = 0.0
	if battle_setup != null and battle_setup.battle_seed >= 0:
		hand.rng.seed = battle_setup.battle_seed ^ 101
		enemy_hand.rng.seed = battle_setup.battle_seed ^ 103
		enemy_ai.rng.seed = battle_setup.battle_seed ^ 107
		ftl.rng.seed = battle_setup.battle_seed ^ 109
	for active_hand in [hand, enemy_hand]:
		active_hand.drop_multiplier = (
			modifier.TEMPORAL_DROP_MULTIPLIER if modifier.kind == 5 or BattleEnvironment.temporal_draw(battle_environment) else 1.0
		)
	_setup_allocation()
	$MatchResult/Panel/Configure.pressed.connect(_return_to_setup)
	damage_timeline = PendingHullDamage.new()
	add_child(damage_timeline)
	var failure_display = preload("res://scripts/ui/systems_failure_display.gd").new()
	failure_display.name = "SystemsFailureDisplay"
	add_child(failure_display)
	hud = BattleHUD.new(self)
	interface_motion = InterfaceMotion.new()
	interface_motion.name = "BattleInterfaceMotion"
	add_child(interface_motion)
	interface_motion.configure(hud)
	interface_motion.boot_finished.connect(_settle_hud_boot)
	interface_motion.skip_requested.connect(interface_motion.finish_boot)
	mode_rule_origin = $ModeRule.position
	hand_rule_origin = $HandRule.position
	resized.connect(_fit_board_lines)
	_fit_board_lines()
	$FTLPanel/WarpButton.pressed.connect(_warp_out)
	for active_hand in [hand, enemy_hand]:
		active_hand.current_round = turn_number
	if resume_combat.is_empty():
		hand.deal_player_opening()
		enemy_hand.deal(card_slots.size())
	for slot in range(card_slots.size()):
		var button: Button = get_node(card_slots[slot])
		button.pressed.connect(_on_card_pressed.bind(slot))
		button.discard_requested.connect(_discard_card.bind(slot))
	# TUNE in the scene: EnemyThinkTimer > Wait Time sets the AI pause in seconds.
	enemy_timer.timeout.connect(_on_enemy_timeout)
	if expedition != null:
		progression_actions.rng.seed = battle_setup.battle_seed ^ 0x42524159
		_setup_progression_actions()
	if not resume_combat.is_empty():
		ProgressionCheckpoint.restore(self, resume_combat)
		settled_combat = resume_combat.duplicate(true)
		overdrive_triggered = true
		if progression_actions.beam == ProgressionActions.Beam.CHARGING:
			_show_beam_notice("BEAM CHARGING · 25 damage next enemy turn")
		elif progression_actions.beam == ProgressionActions.Beam.DISRUPTED:
			_show_beam_notice("BEAM DISRUPTED · Enemy will skip its next turn")
		refresh_display()
	else:
		_begin_battle_presentation()


# The first authoritative turn still starts after the entrance presentation.
func _begin_battle_presentation() -> void:
	_start_hud_boot()
	if interface_motion.booting:
		await interface_motion.boot_finished
	if is_inside_tree() and not is_queued_for_deletion() and not checkpoint_exit:
		_begin_turn("player")


func _start_hud_boot() -> void:
	if interface_motion.boot_started or not InterfaceMotion.allowed(): return
	refresh_display()
	interface_motion.begin(hud, _display_snapshot(), $CardMotion.settings.enabled)
	hud.set_panels_locked(true, true)
	hud.tactical.dismiss(true)
	allocation_button.disabled = true


func _settle_hud_boot() -> void:
	if is_queued_for_deletion(): return
	hud.finish_boot()
	allocation_button.disabled = false
	refresh_display()


func _presentation_locked() -> bool:
	return is_instance_valid(interface_motion) and interface_motion.booting

func _card_resolution_presented(_side: String, _damage: int, _discard: bool) -> void:
	pass

func _committed_damage_presented() -> void:
	pass

func _prepare_beam_presentation(_side: String, _card: Resource) -> float:
	return 0.0

func _beam_reached_target() -> void:
	pass

func _wait_action_presentation() -> void:
	pass

#endregion

#region Battle state


func ship_snapshot(side: String) -> Dictionary:
	return (_player_state if side == "player" else _enemy_state).snapshot()


func apply_ship_snapshot(side: String, state: Dictionary) -> void:
	(_player_state if side == "player" else _enemy_state).apply_snapshot(state)


func _both_states() -> Dictionary:
	return {"player": ship_snapshot("player"), "enemy": ship_snapshot("enemy")}


static func permanent_damage(before: int, after: int, capacity: int) -> int:
	return maxi(0, mini(before, capacity) - mini(after, capacity))


#endregion

#region Turns and cards


func _on_card_pressed(slot: int) -> void:
	_act("player", slot, false)


func _discard_card(slot: int) -> void:
	_act("player", slot, true)


# Apply round events and player escape charging, then income; wait for presentation before AI input.
func _begin_turn(side: String) -> void:
	for active_hand in [hand, enemy_hand]:
		active_hand.current_round = turn_number
	current_actor = side
	extra_action_requested = false
	if side == "player":
		progression_actions.overdrive_used = false
	elif progression_actions.beam == ProgressionActions.Beam.DISRUPTED:
		progression_actions.beam = ProgressionActions.Beam.SPENT
		_show_beam_notice("BEAM DISRUPTED · Enemy turn skipped")
		await _finish_turn("enemy")
		return
	if _check_winner():
		refresh_display()
		return
	var before: Dictionary = _both_states()
	var asteroid_event: bool = false
	var asteroid_hit_player: bool = false
	var turret_event: bool = false
	if side == "player":
		var event_due: bool = (
			(modifier.kind in [1, 3] or modifier.STORMS.has(modifier.kind))
			and not modifier.active
			and turn_number >= modifier.next_round
		)
		if event_due:
			resolving_card = true
			refresh_display()
			await $ModifierDisplay.warning(modifier.kind)
			if is_queued_for_deletion():
				return
		var announcement: String = modifier.begin_round(turn_number)
		if modifier.kind == 1 and not announcement.is_empty():
			var player: Dictionary = ship_snapshot("player")
			var enemy: Dictionary = ship_snapshot("enemy")
			announcement = modifier.asteroid_strike(player, enemy)
			var report: Dictionary = {
				"actor": maxi(0, before.player.hull - player.hull),
				"target": maxi(0, before.enemy.hull - enemy.hull),
				"actor_before": before.player.hull
			}
			asteroid_hit_player = (
				player.hull < before.player.hull or player.shields < before.player.shields
			)
			var pending: Array[Dictionary] = _stage_overflow(
				before, {"player": player, "enemy": enemy}, report, "player"
			)
			apply_ship_snapshot("player", player)
			apply_ship_snapshot("enemy", enemy)
			if pending.is_empty():
				_apply_hull_report(report, "player", true, false)
			else:
				battle_effects.play_changes(before, _both_states(), "", "", 0, true, true)
				_arm_pending_damage(pending, report, "player", false)
				refresh_display()
				await damage_timeline.damage_applied
				if damage_timeline.closing or is_queued_for_deletion():
					return
				# The staged impacts were already scheduled; subsequent income has its own delta.
				before = _both_states()
			asteroid_event = true
		$ModifierDisplay.announce(announcement, modifier.storm_color(modifier.kind) if modifier.kind in [6,7] else Color.WHITE)
		if event_due:
			var player_hit: bool = asteroid_event and asteroid_hit_player
			$ModifierDisplay.impact(modifier.kind, player_hit)
		var round_ended: bool = _check_winner()
		if not round_ended:
			turret_event = _fire_turret_support()
			if turret_event: round_ended = _check_winner()
		if not round_ended:
			var was_offline: bool = ftl.disabled_turns > 0
			ftl.begin_player_turn()
			if was_offline and ftl.disabled_turns == 0:
				$ModifierDisplay.ftl_online(ftl.can_warp())
	var state: Dictionary = ship_snapshot(side)
	if winner.is_empty():
		var before_income := state.duplicate()
		Execution.begin_turn(state)
		apply_ship_snapshot(side, state)
		hud.production_pulse(side, before_income, state)
	battle_effects.play_changes(before, _both_states(), "", "", 0, asteroid_event or turret_event)
	resolving_card = battle_effects.busy or resolving_card
	_check_winner()
	refresh_display()
	if asteroid_event or (side == "player" and modifier.active):
		await $ModifierDisplay.hold_result()
	if not damage_timeline.pending.is_empty():
		await damage_timeline.damage_applied
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or is_queued_for_deletion():
		return
	resolving_card = false
	refresh_display()
	if winner.is_empty() and side == "enemy":
		enemy_timer.start()
	elif winner.is_empty():
		_checkpoint_prototype_turn()


# Round 3 opens after two completed rounds. Latch before effects to prevent re-entry.
func _fire_turret_support() -> bool:
	var support: Dictionary = battle_environment.get("friendly_support", {})
	if support.is_empty() or turn_number <= last_turret_round or turn_number <= 1:
		return false
	if (turn_number - 1) % int(support.interval) != 0:
		return false
	last_turret_round = turn_number
	var enemy: Dictionary = ship_snapshot("enemy")
	modifier.shielded_hit(enemy, int(support.damage))
	apply_ship_snapshot("enemy", enemy)
	var allied: bool = support.get("source") == "allied_fleet"
	var title := "ALLIED FLEET SUPPORT" if allied else "FRIENDLY TURRET SUPPORT"
	$ModifierDisplay.announce("%s · %d DAMAGE" % [title, support.damage], Color("7dc6ff") if allied else Color("64d7ad"))
	return true


# Guard legality and lock input while CardMotion invokes _resolve_card at its animation cue.
# After all presentation finishes, either retain the extra action or advance the actor/round.
func _can_play_card(card: Resource, discard: bool, side: String) -> bool:
	return Execution.can_play(card, discard, ship_snapshot(side)) and (
		discard or not modifier.shields_disabled() or not card.effects.has("shield_sacrifice"))


func _act(side: String, slot: int, discard: bool) -> bool:
	if (
		resolving_card
		or _presentation_locked()
		or not damage_timeline.pending.is_empty()
		or current_actor != side
		or not winner.is_empty()
	):
		return false
	if _check_winner():
		refresh_display()
		return false
	var active_hand = hand if side == "player" else enemy_hand
	if slot < 0 or slot >= active_hand.cards.size():
		return false
	var card: Resource = active_hand.cards[slot]
	if card == null:
		return false
	if not _can_play_card(card, discard, side):
		return false
	resolving_card = true
	if side == "player":
		interface_motion.complete_slot(slot)
		hud.header.clear_extra_action()
	enemy_timer.stop()
	refresh_display()
	var storm_card: bool = (
		not discard and modifier.affects_card(card)
	)
	if storm_card:
		await $ModifierDisplay.warning(modifier.kind, true, modifier.storm_text())
		if is_queued_for_deletion():
			return false
	var source: Control = get_node(card_slots[slot]) if side == "player" else null
	var motion = $CardMotion
	await motion.animate_action(
		modifier.preview(card), source, side, discard,
		_resolve_after_activation.bind(side, slot, discard, card)
	)
	if storm_card:
		await $ModifierDisplay.hold_result()
	if motion.cancelling or not is_inside_tree() or is_queued_for_deletion():
		return false
	if not damage_timeline.pending.is_empty():
		await damage_timeline.damage_applied
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or is_queued_for_deletion():
		return false
	await _wait_action_presentation()
	if checkpoint_exit or is_queued_for_deletion(): return false
	battle_effects.end_card_presentation()
	resolving_card = false
	if _check_winner():
		refresh_display()
	elif extra_action_requested:
		# Clear outgoing visuals before refilling; no change to turn timing.
		var extra_hand = hand if side == "player" else enemy_hand
		for pending_slot in pending_card_draws[side]:
			extra_hand.replace_card(pending_slot)
			if side == "player": _present_replacement(pending_slot)
		pending_card_draws[side].clear()
		refresh_display()
		if side == "player": hud.header.show_extra_action()
		if side == "enemy":
			enemy_timer.start()
	else:
		await _finish_turn(side)
	if not resolving_card and current_actor == "player": _checkpoint_prototype_turn()
	action_finished.emit(side, discard)
	return true


func _sync_systems_failure() -> void:
	var notices: PackedStringArray = systems_failure.sync(
		_both_states(), current_actor, systems_failure_turns
	)
	_announce_failure(notices)


func _announce_failure(notices: PackedStringArray) -> void:
	var display = get_node_or_null("ModifierDisplay")
	if (
		not notices.is_empty()
		and is_instance_valid(display)
		and display.is_inside_tree()
		and not is_queued_for_deletion()
	):
		display.announce(" · ".join(notices))


func _ai_state(side: String) -> Dictionary:
	var state: Dictionary = ship_snapshot(side)
	state.systems_failure_remaining = systems_failure.remaining[side]
	return state


func _finish_turn(side: String) -> void:
	hud.close_panels()
	_announce_failure(Execution.end_turn(_both_states(), systems_failure, side, systems_failure_turns))
	if _check_winner():
		refresh_display()
		return
	var next: Dictionary = Execution.next_turn(side, turn_number)
	turn_number = next.round
	# At the turn transition, refill the outgoing actor\'s emptied slots.
	# Player visuals must disappear before the visible hand refills.
	# Enemy visuals may persist into the player's turn: their hand is hidden.
	var outgoing_hand = hand if side == "player" else enemy_hand
	outgoing_hand.current_round = turn_number
	for pending_slot in pending_card_draws[side]:
		outgoing_hand.replace_card(pending_slot)
		if side == "player": _present_replacement(pending_slot)
	pending_card_draws[side].clear()
	await _begin_turn(next.side)


# Resolve only at weapon contact. No gameplay calculations or stat commits
# occur while the card is charging or while the beam travels.
static func _may_fire_beam(effects: Dictionary) -> bool:
	if int(effects.get("damage", 0)) > 0: return true
	var conditional: Dictionary = effects.get("conditional", {})
	if not conditional.is_empty():
		return _may_fire_beam(conditional.get("then", {})) or _may_fire_beam(conditional.get("else", {}))
	return false


func _resolve_after_activation(side: String, slot: int, discard: bool, card: Resource) -> void:
	var shot: bool = (
		not discard and battle_effects.enabled
		and battle_effects.Preferences.battle_vfx()
		and _may_fire_beam(card.effects)
	)
	if shot:
		var minimum_travel: float = await _prepare_beam_presentation(side, card)
		if checkpoint_exit or is_queued_for_deletion() or battle_effects.cancelling: return
		await battle_effects.fire_before_impact(side, minimum_travel)
		if checkpoint_exit or is_queued_for_deletion() or battle_effects.cancelling: return
		_beam_reached_target()
	_resolve_card(side, slot, discard, card, false, shot)


# Determine once, stage shield-break Hull loss, replace the slot, then present deltas.
# CombatModifier.play delegates cost/effects to CardEffects; discard uses its own refund path.
func _resolve_card(side: String, slot: int, discard: bool, card: Resource, card_visible: bool = false, beam_fired: bool = false) -> bool:
	damage_timeline.finish_now()
	if not winner.is_empty():
		return false
	var before: Dictionary = _both_states()
	var active_hand = hand if side == "player" else enemy_hand
	var other: String = "enemy" if side == "player" else "player"
	var actor: Dictionary = ship_snapshot(side)
	var target: Dictionary = ship_snapshot(other)
	var developer_lethal_hit: bool = side == "player" and developer_one_hit_kill \
		and expedition != null and not expedition.developer_test.is_empty()
	var advantage: String = battle_environment.get("mothership_advantage", "") if side == "player" else ""
	var resolution = Execution.resolve(card, discard, actor, target, modifier, null, advantage, developer_lethal_hit)
	if resolution == null:
		return false
	$ModifierDisplay.announce(resolution.announcement, modifier.storm_color(modifier.kind) if modifier.kind in [6,7] else Color.WHITE)
	if not discard and modifier.affects_card(card):
		$ModifierDisplay.impact(modifier.kind)
	var delay_visuals: bool = card_visible and resolution.direct_damage > 0 and battle_effects.enabled and battle_effects.Preferences.battle_vfx()
	if delay_visuals: battle_effects.defer_card_presentation()
	var report: Dictionary = resolution.hull_damage
	var determined: Dictionary = {side: actor, other: target}
	var pending: Array[Dictionary] = _stage_overflow(before, determined, report, side)
	apply_ship_snapshot(side, actor)
	apply_ship_snapshot(other, target)
	_sync_systems_failure()
	if pending.is_empty():
		_apply_hull_report(report, side, true)
	active_hand.cards[slot] = null
	pending_card_draws[side].append(slot)
	extra_action_requested = resolution.extra_action
	var who: String = "You" if side == "player" else "Enemy"
	var action: String = "discarded" if discard else "played"
	var shown_name: String = card.card_name
	if side == "enemy":
		shown_name = preload("res://scripts/ui/enemy_card_flavor.gd").title(card, enemy_ship_data)
	$LastActionLabel.text = "%s %s %s" % [who, action, shown_name]
	if discard:
		$LastActionLabel.text += (
			" (+%d %s)" % [int(floor(card.cost / 3.0)), card.family.capitalize()]
		)
	elif extra_action_requested:
		$LastActionLabel.text += " — play again"
	battle_effects.play_changes(
		before,
		_both_states(),
		side,
		card.family,
		0 if discard else card.cost,
		(
			not discard
			and (
				card.effects.get("damage", 0) > 0
				or card.effects.get("break_shields", 0) > 0
				or card.effects.has("shield_collapse_below")
				or card.effects.has("shield_collapse")
			)
		),
		not pending.is_empty()
	)
	# Resolved provenance excludes misses, discards, self-hits and modifier-only damage.
	if resolution.direct_damage > 0 and not beam_fired and battle_effects.Preferences.battle_vfx():
		battle_effects.play_direct_damage(side)
	if not pending.is_empty():
		_arm_pending_damage(pending, report, side)
	_check_winner()
	_card_resolution_presented(side, resolution.direct_damage, discard)
	refresh_display()

	return delay_visuals


# EnemyAI returns a slot/discard decision; _act still enforces the same real action rules.
func _on_enemy_timeout() -> void:
	if resolving_card or current_actor != "enemy" or not winner.is_empty():
		return
	if progression_actions.beam == ProgressionActions.Beam.CHARGING:
		await _fire_charged_beam()
		return
	if (_enemy_can_charge_beam() and turn_number >= 2
		and progression_actions.beam == ProgressionActions.Beam.READY):
		progression_actions.beam = ProgressionActions.Beam.CHARGING
		progression_actions.charge_hull = enemy_hull
		_show_beam_notice("BEAM CHARGING · 25 damage next enemy turn")
		await _finish_turn("enemy")
		return
	var move: Dictionary = enemy_ai.choose(
		enemy_hand.cards, _ai_state("enemy"), _ai_state("player"), modifier.forecast_context()
	)
	if move.is_empty():
		# A deliberately undersized custom pool may leave the AI with no cards.
		$LastActionLabel.text = "Enemy has no cards — passes"
		_finish_turn("enemy")
		return
	_act("enemy", move.slot, move.discard)


func _enemy_can_charge_beam() -> bool:
	return (expedition != null and expedition.battles_won >= 4 and expedition.system_number > 1
		and expedition.battles_won % 2 == 0)


func _setup_progression_actions() -> void:
	overdrive_button = MenuButton.new()
	overdrive_button.name = "ResourceOverdrive"
	overdrive_button.text = "Resource Overdrive"
	overdrive_button.custom_minimum_size.y = 48
	ResultPresentation.action(overdrive_button)
	hud.add_overdrive(overdrive_button)
	var menu := overdrive_button.get_popup()
	for action in ProgressionActions.OVERDRIVE.size():
		var option: Dictionary = ProgressionActions.OVERDRIVE[action]
		for payment in option.payments:
			var effect := "+%d Shields" % option.shields if option.shields > 0 else "%d damage" % option.damage
			overdrive_choices.append({"action": action, "payment": payment})
			menu.add_item("%s · %s · %d %s" % [option.title, effect, option.cost, payment.capitalize()])
	menu.id_pressed.connect(func(index: int):
		var choice: Dictionary = overdrive_choices[index]
		activate_overdrive(choice.action, choice.payment))
	beam_notice = Label.new()
	beam_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	beam_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beam_notice.offset_left = -225
	beam_notice.offset_right = 225
	beam_notice.offset_top = 20
	beam_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam_notice.add_theme_color_override("font_color", Color("ffcd82"))
	add_child(beam_notice)


func _show_beam_notice(value: String) -> void:
	if is_instance_valid(beam_notice):
		beam_notice.text = value


func _update_overdrive() -> void:
	if not is_instance_valid(overdrive_button): return
	var locked := not _overdrive_available()
	var menu := overdrive_button.get_popup()
	var available := false
	for index in menu.item_count:
		var choice: Dictionary = overdrive_choices[index]
		var option: Dictionary = ProgressionActions.OVERDRIVE[choice.action]
		var enabled: bool = (not locked and not (option.shields > 0 and modifier.shields_disabled())
			and int(get("player_" + choice.payment)) >= option.cost)
		menu.set_item_disabled(index, not enabled)
		available = available or enabled
	overdrive_button.visible = winner.is_empty() and not _presentation_locked()
	overdrive_button.disabled = not available
	overdrive_button.tooltip_text = "Once per player turn · 30 Materials, Energy or Crew"


func _overdrive_available() -> bool:
	return (expedition != null and current_actor == "player" and winner.is_empty()
		and not progression_actions.overdrive_used and not resolving_card and not _presentation_locked()
		and not battle_effects.busy and damage_timeline.pending.is_empty())


func activate_overdrive(action: int, payment: String) -> bool:
	if not _overdrive_available() or (action == 0 and modifier.shields_disabled()):
		return false
	var before := _both_states()
	var player: Dictionary = before.player.duplicate()
	var enemy: Dictionary = before.enemy.duplicate()
	if not ProgressionActions.overdrive(action, payment, player, enemy):
		return false
	progression_actions.overdrive_used = true
	overdrive_triggered = true
	resolving_card = true
	if modifier.shields_disabled() and action == 1:
		var unshielded: Dictionary = before.enemy.duplicate()
		unshielded.shields = 0
		ProgressionActions.Modifier.shielded_hit(unshielded, ProgressionActions.OVERDRIVE[action].damage)
		enemy.hull = unshielded.hull
		enemy.shields = before.enemy.shields
	apply_ship_snapshot("player", player)
	apply_ship_snapshot("enemy", enemy)
	_interrupt_charged_beam(before.enemy.hull - enemy.hull)
	_checkpoint_prototype_turn()
	battle_effects.play_changes(before, _both_states(), "player", payment, ProgressionActions.OVERDRIVE[action].cost)
	_check_winner()
	refresh_display()
	_complete_overdrive_turn()
	return true


func _complete_overdrive_turn() -> void:
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or checkpoint_exit or is_queued_for_deletion():
		return
	resolving_card = false
	if not _check_winner():
		await _finish_turn("player")
	else:
		refresh_display()


func _checkpoint_prototype_turn() -> void:
	if (expedition != null and current_actor == "player" and winner.is_empty()
		and player_hull > 0 and enemy_hull > 0
		and (overdrive_triggered or progression_actions.beam != ProgressionActions.Beam.READY)):
		settled_combat = ProgressionCheckpoint.capture(self)


func _interrupt_charged_beam(amount: int) -> void:
	if enemy_hull > 0 and progression_actions.interrupt(amount):
		_show_beam_notice("BEAM DISRUPTED · Enemy will skip its next turn")


func _fire_charged_beam() -> void:
	resolving_card = true
	progression_actions.beam = ProgressionActions.Beam.SPENT
	_show_beam_notice("CHARGED BEAM · Firing")
	refresh_display()
	var travel := 0.0
	if battle_effects.enabled and battle_effects.Preferences.battle_vfx():
		var shot := preload("res://scripts/cards/card_data.gd").new()
		shot.family = "energy"
		shot.effects = {"damage": ProgressionActions.BEAM_DAMAGE}
		travel = await _prepare_beam_presentation("enemy", shot)
		if checkpoint_exit or is_queued_for_deletion() or battle_effects.cancelling: return
	await battle_effects.fire_before_impact("enemy", travel)
	if checkpoint_exit or is_queued_for_deletion() or battle_effects.cancelling: return
	_beam_reached_target()
	var before := _both_states()
	var player: Dictionary = before.player.duplicate()
	var shields: int = player.shields
	if modifier.shields_disabled(): player.shields = 0
	ProgressionActions.Modifier.shielded_hit(player, ProgressionActions.BEAM_DAMAGE)
	if modifier.shields_disabled(): player.shields = shields
	apply_ship_snapshot("player", player)
	_apply_hull_report({"target": before.player.hull - player.hull, "target_before": before.player.hull}, "enemy", true)
	battle_effects.play_changes(before, _both_states(), "enemy", "", 0, true)
	_check_winner()
	_card_resolution_presented("enemy", ProgressionActions.BEAM_DAMAGE, false)
	refresh_display()
	if battle_effects.busy: await battle_effects.finished
	await _wait_action_presentation()
	if checkpoint_exit or is_queued_for_deletion() or battle_effects.cancelling: return
	resolving_card = false
	_show_beam_notice("")
	await _finish_turn("enemy")


func _stage_overflow(
	before: Dictionary, determined: Dictionary, report: Dictionary, actor_side: String
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if (
		not battle_effects.enabled
		or not battle_effects.visual_settings.shield_shatter.shatter_enabled
		or modifier.shields_disabled()
	):
		return events
	for side in ["player", "enemy"]:
		var previous: Dictionary = before[side]
		var result: Dictionary = determined[side]
		var key: String = "actor" if side == actor_side else "target"
		if previous.shields > 0 and result.shields == 0:
			# Use the existing capped damage report, including mixed pierce/self-damage.
			var amount: int = maxi(0, int(report.get(key, 0)))
			if amount > 0:
				result.hull += amount
				events.append({"side": side, "amount": amount})
	return events


func _arm_pending_damage(events: Array[Dictionary], report: Dictionary, side: String, can_interrupt: bool = true) -> void:
	var settings: Resource = battle_effects.visual_settings.shield_shatter
	damage_timeline.arm(
		events,
		settings.shatter_burst_start,
		settings.shatter_total_duration,
		_apply_pending_hull.bind(report, side, can_interrupt),
		battle_effects.shatter_updates,
		func():
			return (
				not battle_effects.enabled
				or battle_effects.cancelling
				or not settings.shatter_enabled
			)
	)


func _apply_hull_report(report: Dictionary, side: String, visuals: bool, can_interrupt: bool = true) -> void:
	var key: String = "actor" if side == "player" else "target"
	var amount: int = int(report.get(key, 0))
	if can_interrupt and side == "player": _interrupt_charged_beam(int(report.get("target", 0)))
	player_hull_damage_taken += amount
	var before: int = int(report.get(key + "_before", player_hull))
	var permanent: int = permanent_damage(before, before - amount, player_hull_capacity)
	if visuals:
		_damage_ftl(permanent)
	else:
		ftl.take_hull_damage(permanent)


func _apply_pending_hull(
	events: Array[Dictionary], visuals: bool, report: Dictionary, side: String, can_interrupt: bool
) -> void:
	visuals = visuals and is_instance_valid(battle_effects) and not battle_effects.cancelling
	var before: Dictionary = _both_states()
	for event in events:
		set(event.side + "_hull", maxi(0, int(get(event.side + "_hull")) - event.amount))
	_apply_hull_report(report, side, visuals, can_interrupt)
	if visuals and battle_effects.enabled and not battle_effects.cancelling:
		battle_effects.play_changes(before, _both_states())
	_check_winner()
	_committed_damage_presented()
	if visuals and not is_queued_for_deletion():
		refresh_display()
	elif not winner.is_empty():
		_record_result()


#endregion

#region Match control


# Latch the terminal transition and rewards once, after all required impact cues.
func _check_winner() -> bool:
	if not winner.is_empty():
		return true
	_sync_systems_failure()
	if is_instance_valid(damage_timeline) and not damage_timeline.pending.is_empty():
		return false
	var result: String = Execution.outcome(_both_states(), systems_failure)
	if not result.is_empty():
		winner = "player" if result.begins_with("win") else ("enemy" if result.begins_with("loss") else "draw")
		result_cause = "hull" if result.ends_with("hull") else "systems_failure"
	if not winner.is_empty():
		enemy_timer.stop()
		_record_result()
	return not winner.is_empty()


func _restart_match() -> void:
	damage_timeline.finish_now(false)
	if expedition != null:
		expedition_restart.emit()
		return
	# Reload the scene that is actually being played (2D or 3D).
	var fresh: Node = load(scene_file_path).instantiate()
	fresh.setup_settings = setup_settings.duplicate(true)
	get_parent().add_child(fresh)
	if get_tree().current_scene == self:
		get_tree().current_scene = fresh
	queue_free()


func _return_to_setup() -> void:
	damage_timeline.finish_now(false)
	if expedition != null:
		expedition_exit.emit()
		return
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	setup.initial_settings = setup_settings.duplicate(true)
	get_parent().add_child(setup)
	get_tree().current_scene = setup
	queue_free()


# Resolve combat escape as a player win, without generating a new star system here.
func _warp_out() -> void:
	if (
		current_actor != "player"
		or _presentation_locked()
		or resolving_card
		or not damage_timeline.pending.is_empty()
		or battle_effects.busy
		or not winner.is_empty()
	):
		return
	if _check_winner() or not ftl.can_warp():
		refresh_display()
		return
	hud.close_panels(true)
	winner = "player"
	escaped_by_ftl = true
	_record_result()
	enemy_timer.stop()
	$LastActionLabel.text = battle_setup.emp_victory_message if battle_setup != null and not battle_setup.emp_victory_message.is_empty() else "EMP Pulse complete — escaped!"
	_begin_emp_presentation()
	refresh_display()


func _begin_emp_presentation() -> void:
	hud.emp_interference()


func _damage_ftl(amount: int) -> void:
	if ftl.take_hull_damage(amount):
		$ModifierDisplay.ftl_offline()


func _continue_encounter() -> void:
	damage_timeline.finish_now(false)
	if winner != "player" or player_hull <= 0 or resolving_card or battle_effects.busy or _presentation_locked():
		return
	$MatchResult/Panel/Continue.disabled = true
	if expedition != null:
		expedition_continue.emit()
		return
	var fresh = load(scene_file_path).instantiate()
	fresh.setup_settings = setup_settings.duplicate(true)
	fresh.setup_settings.modifier = next_modifier
	fresh.player_hull_capacity = player_hull_capacity
	fresh.enemy_hull_capacity = enemy_hull_capacity
	fresh.continuation_hull = mini(player_hull, player_hull_capacity)
	fresh.encounter_number = encounter_number + 1
	fresh.salvage = salvage
	fresh.battles_won = battles_won
	fresh.pending_resource_bonus = TACTICAL_RESOURCES if tactical_victory() else 0
	fresh.pending_shield_bonus = STRATEGIC_SHIELDS if strategic_victory() else 0
	get_parent().add_child(fresh)
	get_tree().current_scene = fresh
	queue_free()


#endregion

#region Display and allocation


# Render detached state; combat transitions and rewards are committed by their owners.
# Layout helpers below override scene offsets on resize, so inspect them before moving scene controls.
func refresh_display() -> void:
	_update_overdrive()
	hud.refresh(_display_snapshot())
	for slot in range(card_slots.size()):
		var view: Control = get_node(card_slots[slot])
		view.visible = not interface_motion.flights.has(slot)
		view.self_modulate.a = 0.0 if hand.cards[slot] == null else 1.0
	if $MatchResult.visible and not result_music_started:
		result_music_started = true
		# Start music only when the result is revealed, after combat presentation.
		get_node("/root/Music").play_result(winner == "player", enemy_ship_data.enemy_rank if enemy_ship_data != null else 0)


func _present_replacement(slot: int) -> void:
	var motion = $CardMotion
	if winner.is_empty() and motion.settings.enabled and interface_motion.replacement(slot, _shown_card(hand.cards[slot])):
		motion.fade_played_player()


func _shown_card(card: Resource) -> Dictionary:
	return {
		"preview": modifier.preview(card),
		"identity": card,
		"present": card != null,
		"affordable": _can_play_card(card, false, "player"),
		"ion_glow": modifier.affects_card(card),
		"storm_color": modifier.storm_color(modifier.kind, true)
	}


func _display_snapshot() -> Dictionary:
	var shown_cards: Array[Dictionary] = []
	for card in hand.cards:
		shown_cards.append(_shown_card(card))
	var modifier_name: String = modifier.NAMES[modifier.kind].capitalize()
	var modifier_status: String = BattleHUD.modifier_status(modifier, turn_number)
	var modifier_details: String = modifier_name + "\n"
	if not modifier_status.is_empty():
		modifier_details += modifier_status + "\n"
	modifier_details += modifier.description(modifier.kind)
	if battle_environment.has("temporal_anomaly"):
		modifier_details += "\nTemporal Rift · Tier 2 draw chance ×2 for both ships."
	return {
		"player": ship_snapshot("player"),
		"enemy": ship_snapshot("enemy"),
		"player_name": player_ship_data.ship_name if player_ship_data != null else "Player Ship",
		"player_subtitle": (player_ship_data.signature_card.card_name if player_ship_data.signature_card != null
			else player_ship_data.subtitle) if player_ship_data != null else "",
		"enemy_name": enemy_ship_data.ship_name if enemy_ship_data != null else "Enemy Ship",
		"enemy_subtitle": enemy_ship_data.subtitle if enemy_ship_data != null else "Unknown Vessel",
		"active_boons": PackedStringArray(),
		"modifier": modifier_details,
		"modifier_tint": modifier.storm_color(modifier.kind) if modifier.kind in [6, 7] else Color.WHITE,
		"system_overview": _battle_system_overview(),
		"enemy_beam": _enemy_beam_overview(),
		"enemy_modifier": "" if modifier.kind == 0 else modifier_details,
		"presentation_locked": _presentation_locked(),
		"emp":
		{
			"charge": ftl.charge,
			"charge_target": ftl.charge_target,
			"disabled_turns": ftl.disabled_turns,
			"can_warp": ftl.can_warp()
		},
		"cards": shown_cards,
		"effects_busy": battle_effects.busy,
		"shields_disabled": modifier.shields_disabled(),
		"nebula_miss_rate": modifier.miss_rate if modifier.kind == 4 else 0,
		"rewards_text": victory_description(),
		"strategic_summary": strategic_summary,
		"salvage_earned": result_salvage_gained,
		"upgrades_available": mini(expedition.upgrades_remaining,expedition.upgrade_candidates().size()) if expedition != null and expedition.pending_choice == "upgrade" else 0,
		"defense_recovery": salvage_rewards.has("recovery"),
		"system_secured": salvage_rewards.has("secured"),
		"mothership_destroyed": (expedition != null and expedition.is_defense()
			and expedition.defense != null and winner == "player"
			and expedition.defense.unit_for(expedition.active_battle).get("mothership", false)),
		"in_expedition": expedition != null,
		"pending_choice": expedition.pending_choice if expedition != null else "",
		"next_modifier_name": modifier.NAMES[next_modifier] if next_modifier >= 0 else "",
		"salvage": salvage,
		"winner": winner,
		"result_cause": result_cause,
		"systems_failure": systems_failure.snapshot(_both_states()),
		"battles_won": battles_won,
		"resolving_card": resolving_card or interface_motion.booting or not damage_timeline.pending.is_empty(),
		"current_actor": current_actor,
		"turn_number": turn_number,
		"escaped_by_ftl": escaped_by_ftl,
		"starting_player_hull": starting_player_hull,
		"result_hull": result_hull,
		"result_recorded": result_recorded,
		"player_hull_damage_taken": player_hull_damage_taken,
		"encounter_number": encounter_number,
	}


func _battle_system_overview() -> String:
	if expedition == null:
		return "Standalone battle"
	if expedition.is_warzone():
		var operation = expedition.warzone
		var progress: String = "War Effort %d / %d" % [operation.effort, operation.tuning.effort_goal] if operation.is_lattice() 			else "Objectives %d / %d" % [operation.controlled(), expedition.Warzone.REQUIRED_OBJECTIVES]
		var lines := PackedStringArray(["Warzone · " + progress,
			"Hostile fleets %d" % expedition.warzone.fleet_count("hostile")])
		var packages: Dictionary = battle_environment.get("preparations", {})
		for side in ["player", "enemy"]:
			var preparation := preload("res://scripts/combat/combat_preparation.gd").summary(packages.get(side, {}))
			if not preparation.is_empty():
				lines.append("%s preparation · %s" % [side.capitalize(), preparation])
		var allied: Dictionary = battle_environment.get("friendly_support", {})
		if allied.get("source") == "allied_fleet":
			var next_round: int = turn_number + posmod(1 - turn_number, allied.interval)
			if next_round <= maxi(1, last_turret_round): next_round += allied.interval
			lines.append("Allied strength %d · %d damage on round %d" % [allied.strength, allied.damage, next_round])
			lines.append("Direct combat rewards ×0.5")
		return "\n".join(lines)
	var lines := PackedStringArray([expedition.system_name])
	if expedition.is_defense() and expedition.defense != null:
		var defense = expedition.defense
		var contacts := 0
		for unit in defense.units:
			if defense.available(unit):
				contacts += 1
		lines.append("Pressure %d / %d · Hostile ships %d" % [int(defense.pressure), int(defense.tuning.pressure_maximum), contacts])
	else:
		var remaining := 0
		for encounter in expedition.encounters:
			if encounter.kind == "battle" and not encounter.completed:
				remaining += 1
		lines.append("Pressure %d · Hostile encounters %d" % [expedition.pressure, remaining])
	var support: Dictionary = battle_environment.get("friendly_support", {})
	if not support.is_empty():
		lines.append("Turret support · %d damage every %d rounds" % [support.damage, support.interval])
	return "\n".join(lines).strip_edges()


func _enemy_beam_overview() -> String:
	match progression_actions.beam:
		ProgressionActions.Beam.CHARGING:
			return "%d damage next enemy turn. Hull damage can disrupt the charge." % ProgressionActions.BEAM_DAMAGE
		ProgressionActions.Beam.DISRUPTED:
			return "Charge disrupted. The enemy will skip its next turn."
		ProgressionActions.Beam.SPENT:
			return "The enemy has used its charge attempt."
	return ("Can charge a %d-damage beam. Hull damage can disrupt the charge." % ProgressionActions.BEAM_DAMAGE
		if _enemy_can_charge_beam() else "")


# Control nodes use editor-visible anchors; these decorative lines are Node2Ds.
func _fit_board_lines() -> void:
	hud.fit_board_lines(size, mode_rule_origin, hand_rule_origin)
	_fit_combat_controls()


func _fit_combat_controls() -> void:
	hud.fit_combat_controls(_battle_bounds())
	_fit_allocation_button()


func _fit_allocation_button() -> void:
	if not is_instance_valid(allocation_button):
		return
	var bounds := _battle_bounds()
	preload("res://scripts/ui/battle_layout.gd").fit(self, settings_button, allocation_button, bounds)
	allocation_popup.fit()
	hud.fit_side_panels(self)
	if is_instance_valid(interface_motion): interface_motion.fit_deck(bounds)


func _battle_bounds() -> Rect2:
	var layout := preload("res://scripts/ui/battle_layout.gd")
	return layout.safe_bounds(size, layout.safe_insets(self))


func _defense_flank_offset() -> float:
	return absf($EnemyShip.position.x - $PlayerShip.position.x) * 0.5


func _setup_allocation() -> void:
	hand.configure_player_allocation(allocation_settings.matching_draw_weight)
	allocation_popup = preload("res://scripts/ui/power_allocation_popup.gd").new()
	add_child(allocation_popup)
	allocation_button = Button.new()
	allocation_button.name = "PowerAllocation"
	allocation_button.custom_minimum_size = preload("res://scripts/ui/battle_layout.gd").BUTTON_SIZE
	var skin := preload("res://scripts/ui/holographic/skin.gd")
	allocation_button.toggle_mode = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var frame := skin.frame("focus" if state == "focus" else "status.allocation", skin.DEFAULT.friendly,
			"pressed" if state == "hover_pressed" else state)
		frame.set_content_margin_all(skin.DEFAULT.compact_padding)
		allocation_button.add_theme_stylebox_override(state, frame)
	add_child(allocation_button)
	allocation_popup.bind_anchor(allocation_button)
	allocation_popup.mode_selected.connect(_select_allocation)
	allocation_button.pressed.connect(func():
		hud.close_panels()
		allocation_popup.toggle(hand.allocation_mode, hand._allocation_multiplier))
	_select_allocation("balanced")


func _select_allocation(mode: String) -> void:
	if is_instance_valid(damage_timeline) and not damage_timeline.pending.is_empty():
		return
	if not hand.select_allocation(mode):
		return
	if hud != null:
		hud.close_panels()
	allocation_popup.set_mode(mode)


#endregion

#region Results


func tactical_victory() -> bool:
	if result_recorded:
		return earned_tactical
	return winner == "player" and player_hull > starting_player_hull


func strategic_victory() -> bool:
	if result_recorded:
		return earned_strategic
	var player_total: int = player_synthesizer + player_reactor + player_quarters
	var enemy_total: int = enemy_synthesizer + enemy_reactor + enemy_quarters
	return winner == "player" and player_total > enemy_total


func victory_description() -> String:
	if winner != "player":
		return strategic_summary
	var lines: PackedStringArray = []
	var bonuses: PackedStringArray = []
	var result := battle_result()
	if expedition != null:
		if expedition.is_defense():
			if salvage_rewards.has("standard"):
				lines.append("Standard reward · +%d Salvage" % salvage_rewards.standard)
			if salvage_rewards.has("victory"):
				lines.append("Defense victory bonus · +%d Salvage" % salvage_rewards.victory)
			if salvage_rewards.has("recovery"):
				lines.append("Allied EMP recovery · +%d Salvage" % salvage_rewards.recovery)
			if salvage_rewards.has("secured"):
				lines.append("System secured · +%d Salvage" % salvage_rewards.secured)
			if salvage_rewards.has("extraction"):
				lines.append("Mining extraction · +%d Salvage" % salvage_rewards.extraction)
			if salvage_rewards.has("evacuation"):
				lines.append("Civilian evacuation · +%d Salvage" % salvage_rewards.evacuation)
		else:
			lines.append("🪨 +%d Salvage" % expedition.victory_salvage(result))
			if salvage_rewards.has("operation"):
				lines.append("Warzone secured · +%d Salvage" % salvage_rewards.operation)
		var upgrades: int = expedition.battle_upgrade_count(result)
		if upgrades > 0 and not lines.is_empty():
			lines[0] += " · Upgrade %d cards" % upgrades
		var elite_bonus: int = expedition.elite_resource_reward(result)
		if elite_bonus > 0:
			bonuses.append("Elite: " + _resource_reward_text(elite_bonus))
	elif not escaped_by_ftl:
		lines.append("🪨 +%d Salvage" % DESTRUCTION_SALVAGE)
	if tactical_victory():
		bonuses.append("Tactical: " + _resource_reward_text(result.tactical_resources))
	if strategic_victory():
		bonuses.append("Strategic: 🛡️ +%d" % result.strategic_shields)
	if not bonuses.is_empty():
		if expedition != null:
			bonuses[0] = "Next battle · " + bonuses[0]
		else:
			lines.append("Next battle")
		lines.append_array(bonuses)
	if expedition != null and expedition.is_defense() and expedition.defense != null:
		if expedition.defense.mothership_destroyed() and not expedition.defense.complete and expedition.defense.unit_for(expedition.active_battle).get("mothership", false):
			lines.append("Destroy the remaining forces to liberate the system.")
	if not strategic_summary.is_empty():
		lines.append(strategic_summary)
	return "\n".join(lines)


func _resource_reward_text(amount: int) -> String:
	return "🛠️ +%d · ⚡ +%d · 👥 +%d" % [amount, amount, amount]


func _record_result() -> void:
	if winner.is_empty() or result_recorded or checkpoint_exit:
		return
	var salvage_before: int = salvage
	# Freeze combat rewards at the authoritative result boundary.
	earned_tactical = tactical_victory()
	earned_strategic = strategic_victory()
	result_hull = player_hull
	result_recorded = true
	if winner == "player":
		battles_won += 1
		if expedition != null and not expedition.is_defense():
			salvage += expedition.victory_salvage(battle_result())
		elif expedition == null and not escaped_by_ftl:
			salvage += DESTRUCTION_SALVAGE
	if expedition != null:
		var result := battle_result()
		if expedition.record_battle(result):
			salvage = result.salvage
			salvage_rewards = result.salvage_rewards
			strategic_summary = result.strategic_summary
	result_salvage_gained = maxi(0,salvage-salvage_before)
	if winner == "player" and player_hull > 0 and expedition == null and next_modifier < 0:
		next_modifier = randi_range(1, modifier.NAMES.size() - 1)


func battle_result() -> BattleResult:
	return BattleAdapter.result(self)


func _sync_expedition_hand() -> void:
	BattleAdapter.sync_hand(hand, expedition.player_pool(), expedition.acquired_draw_weights(), expedition.upgraded_cards)


#endregion
