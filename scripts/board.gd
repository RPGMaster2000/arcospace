extends Control

# RESPONSIBILITY: Coordinate both hands, turns, effects and board display.
# DOES NOT: Choose AI moves, implement card effects or render HUD controls.

# EXTEND: _resolve_card commits state; BattleEffects owns VFX, BattleHUD owns UI, MatchRules owns wins.
signal action_finished(side: String, discarded: bool)
signal expedition_continue
signal expedition_restart
signal expedition_exit
const BattleResult = preload("res://scripts/combat/battle_result.gd")
const BattleSetup = preload("res://scripts/combat/battle_setup.gd")
const BattleAdapter = preload("res://scripts/combat/battle_adapter.gd")
var battle_setup: BattleSetup
var expedition: Resource
var expedition_encounter: int = -1
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
var current_actor: String = "player"
var turn_number: int = 1
var winner: String = ""
var escaped_by_ftl: bool = false
# A continuation carries only hull; setup resources/production and shields reset normally.
var continuation_hull: int = -1
var encounter_number: int = 1
var next_modifier: int = -1
var salvage: int = 0
var battles_won: int = 0
var result_recorded: bool = false
# Leaving an unfinished battle preserves its entry checkpoint, including during VFX cleanup.
var checkpoint_exit: bool = false
# Presentation-only latch: reward recording can precede the visible result.
var result_music_started: bool = false
var earned_tactical: bool = false
var earned_strategic: bool = false
var result_hull: int = 0
## TUNE: Salvage per destroyed enemy; repair rates live in RepairRules.
const DESTRUCTION_SALVAGE: int = 10
const Repairs = preload("res://scripts/repair_rules.gd")
const RESULT_SALVAGE_PER_HULL: int = Repairs.RESULT_SALVAGE_PER_HULL
var repair_preview: VBoxContainer
# Legacy name; the selector now counts Hull points, not Salvage units.
var _repair_selection: int = -1
var repair_spend: int:
	get:
		if winner == "player":
			var limit: int = _repair_spend_limit()
			return limit if _repair_selection < 0 else clampi(_repair_selection, 0, limit)
		return _repair_selection
	set(value): _repair_selection = value
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
	settings_button.z_index = 110  # Keep settings accessible above the result screen's shade.
	add_child(settings_button)
	settings_button.main_menu_requested.connect(_return_to_setup)
	repair_preview = preload("res://scripts/ui/repair_preview.gd").new()
	repair_preview.name = "RepairPreview"
	repair_preview.position = Vector2(30, 270)
	repair_preview.size = Vector2(680, 70)
	$MatchResult/Panel.add_child(repair_preview)
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
	$MatchResult/Panel/RepairMinus.pressed.connect(_adjust_repair_spend.bind(-1))
	$MatchResult/Panel/RepairPlus.pressed.connect(_adjust_repair_spend.bind(1))
	$MatchResult/Panel/Repair.pressed.connect(_repair_with_salvage)
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
	if battle_setup != null and battle_setup.battle_seed >= 0:
		hand.rng.seed = battle_setup.battle_seed ^ 101
		enemy_hand.rng.seed = battle_setup.battle_seed ^ 103
		enemy_ai.rng.seed = battle_setup.battle_seed ^ 107
		ftl.rng.seed = battle_setup.battle_seed ^ 109
	for active_hand in [hand, enemy_hand]:
		active_hand.drop_multiplier = (
			modifier.TEMPORAL_DROP_MULTIPLIER if modifier.kind == 5 else 1.0
		)
	_setup_allocation()
	$MatchResult/Panel/Configure.pressed.connect(_return_to_setup)
	damage_timeline = PendingHullDamage.new()
	add_child(damage_timeline)
	var failure_display = preload("res://scripts/ui/systems_failure_display.gd").new()
	failure_display.name = "SystemsFailureDisplay"
	add_child(failure_display)
	hud = BattleHUD.new(self)
	mode_rule_origin = $ModeRule.position
	hand_rule_origin = $HandRule.position
	resized.connect(_fit_board_lines)
	_fit_board_lines()
	$FTLPanel/WarpButton.pressed.connect(_warp_out)
	$FTLPanel/WarpButton.flat = false
	$FTLPanel/WarpButton.add_theme_font_size_override("font_size", 18)
	preload("res://scripts/ui/encounter_presentation.gd").action($FTLPanel/WarpButton)
	for active_hand in [hand, enemy_hand]:
		active_hand.current_round = turn_number
	hand.deal_player_opening()
	enemy_hand.deal(card_slots.size())
	for slot in range(card_slots.size()):
		var button: Button = get_node(card_slots[slot])
		button.pressed.connect(_on_card_pressed.bind(slot))
		button.discard_requested.connect(_discard_card.bind(slot))
	# TUNE in the scene: EnemyThinkTimer > Wait Time sets the AI pause in seconds.
	enemy_timer.timeout.connect(_on_enemy_timeout)
	_begin_turn("player")


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
	if _check_winner():
		refresh_display()
		return
	var before: Dictionary = _both_states()
	var asteroid_event: bool = false
	var asteroid_hit_player: bool = false
	if side == "player":
		var event_due: bool = (
			modifier.kind in [1, 2, 3]
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
				_apply_hull_report(report, "player", true)
			else:
				battle_effects.play_changes(before, _both_states(), "", "", 0, true, true)
				_arm_pending_damage(pending, report, "player")
				refresh_display()
				await damage_timeline.damage_applied
				if damage_timeline.closing or is_queued_for_deletion():
					return
				# The staged impacts were already scheduled; subsequent income has its own delta.
				before = _both_states()
			asteroid_event = true
		$ModifierDisplay.announce(announcement)
		if event_due:
			var player_hit: bool = asteroid_event and asteroid_hit_player
			$ModifierDisplay.impact(modifier.kind, player_hit)
		if not _check_winner():
			var was_offline: bool = ftl.disabled_turns > 0
			ftl.begin_player_turn()
			if was_offline and ftl.disabled_turns == 0:
				$ModifierDisplay.ftl_online(ftl.can_warp())
	var state: Dictionary = ship_snapshot(side)
	if winner.is_empty():
		Execution.begin_turn(state)
		apply_ship_snapshot(side, state)
	battle_effects.play_changes(before, _both_states(), "", "", 0, asteroid_event)
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


# Guard legality and lock input while CardMotion invokes _resolve_card at its animation cue.
# After all presentation finishes, either retain the extra action or advance the actor/round.
func _act(side: String, slot: int, discard: bool) -> bool:
	if (
		resolving_card
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
	if not Execution.can_play(card, discard, ship_snapshot(side)):
		return false
	resolving_card = true
	enemy_timer.stop()
	refresh_display()
	var ion_card: bool = (
		not discard and modifier.kind == 2 and modifier.active and card.family == "energy"
	)
	if ion_card:
		await $ModifierDisplay.warning(2, true, modifier.ion_text())
		if is_queued_for_deletion():
			return false
	var source: Control = get_node(card_slots[slot]) if side == "player" else null
	var motion = $CardMotion
	await motion.animate_action(
		modifier.preview(card), source, side, discard, _resolve_card.bind(side, slot, discard, card)
	)
	if ion_card:
		await $ModifierDisplay.hold_result()
	if motion.cancelling or not is_inside_tree() or is_queued_for_deletion():
		return false
	if not damage_timeline.pending.is_empty():
		await damage_timeline.damage_applied
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or is_queued_for_deletion():
		return false
	resolving_card = false
	if _check_winner():
		refresh_display()
	elif extra_action_requested:
		# Another action in the same turn: no additional production income.
		refresh_display()
		if side == "enemy":
			enemy_timer.start()
	else:
		await _finish_turn(side)
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
	_announce_failure(Execution.end_turn(_both_states(), systems_failure, side, systems_failure_turns))
	if _check_winner():
		refresh_display()
		return
	var next: Dictionary = Execution.next_turn(side, turn_number)
	turn_number = next.round
	await _begin_turn(next.side)


# Determine once, stage shield-break Hull loss, replace the slot, then present deltas.
# CombatModifier.play delegates cost/effects to CardEffects; discard uses its own refund path.
func _resolve_card(side: String, slot: int, discard: bool, card: Resource) -> void:
	damage_timeline.finish_now()
	if not winner.is_empty():
		return
	var before: Dictionary = _both_states()
	var active_hand = hand if side == "player" else enemy_hand
	var other: String = "enemy" if side == "player" else "player"
	var actor: Dictionary = ship_snapshot(side)
	var target: Dictionary = ship_snapshot(other)
	var resolution = Execution.resolve(card, discard, actor, target, modifier)
	if resolution == null:
		return
	$ModifierDisplay.announce(resolution.announcement)
	if not discard and modifier.kind == 2 and modifier.active and card.family == "energy":
		$ModifierDisplay.impact(2)
	var report: Dictionary = resolution.hull_damage
	var determined: Dictionary = {side: actor, other: target}
	var pending: Array[Dictionary] = _stage_overflow(before, determined, report, side)
	apply_ship_snapshot(side, actor)
	apply_ship_snapshot(other, target)
	_sync_systems_failure()
	if pending.is_empty():
		_apply_hull_report(report, side, true)
	active_hand.replace_card(slot)
	extra_action_requested = resolution.extra_action
	var who: String = "You" if side == "player" else "Enemy"
	var action: String = "discarded" if discard else "played"
	$LastActionLabel.text = "%s %s %s" % [who, action, card.card_name]
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
	if not pending.is_empty():
		_arm_pending_damage(pending, report, side)
	_check_winner()
	refresh_display()


# EnemyAI returns a slot/discard decision; _act still enforces the same real action rules.
func _on_enemy_timeout() -> void:
	if resolving_card or current_actor != "enemy" or not winner.is_empty():
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


func _arm_pending_damage(events: Array[Dictionary], report: Dictionary, side: String) -> void:
	var settings: Resource = battle_effects.visual_settings.shield_shatter
	damage_timeline.arm(
		events,
		settings.shatter_burst_start,
		settings.shatter_total_duration,
		_apply_pending_hull.bind(report, side),
		battle_effects.shatter_updates,
		func():
			return (
				not battle_effects.enabled
				or battle_effects.cancelling
				or not settings.shatter_enabled
			)
	)


func _apply_hull_report(report: Dictionary, side: String, visuals: bool) -> void:
	var key: String = "actor" if side == "player" else "target"
	var amount: int = int(report.get(key, 0))
	player_hull_damage_taken += amount
	var before: int = int(report.get(key + "_before", player_hull))
	var permanent: int = permanent_damage(before, before - amount, player_hull_capacity)
	if visuals:
		_damage_ftl(permanent)
	else:
		ftl.take_hull_damage(permanent)


func _apply_pending_hull(
	events: Array[Dictionary], visuals: bool, report: Dictionary, side: String
) -> void:
	visuals = visuals and is_instance_valid(battle_effects) and not battle_effects.cancelling
	var before: Dictionary = _both_states()
	for event in events:
		set(event.side + "_hull", maxi(0, int(get(event.side + "_hull")) - event.amount))
	_apply_hull_report(report, side, visuals)
	if visuals and battle_effects.enabled and not battle_effects.cancelling:
		battle_effects.play_changes(before, _both_states())
	_check_winner()
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
		or resolving_card
		or not damage_timeline.pending.is_empty()
		or battle_effects.busy
		or not winner.is_empty()
	):
		return
	if _check_winner() or not ftl.can_warp():
		refresh_display()
		return
	winner = "player"
	escaped_by_ftl = true
	_record_result()
	enemy_timer.stop()
	$LastActionLabel.text = "EMP Pulse complete — escaped!"
	refresh_display()
	$MatchResult/Panel/Title.text = "EMP PULSE SUCCESS"


func _damage_ftl(amount: int) -> void:
	if ftl.take_hull_damage(amount):
		$ModifierDisplay.ftl_offline()


func _continue_encounter() -> void:
	damage_timeline.finish_now(false)
	if winner != "player" or player_hull <= 0 or resolving_card or battle_effects.busy:
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
	$ModifierDisplay.refresh(modifier, turn_number)
	hud.refresh(_display_snapshot())
	if $MatchResult.visible and not result_music_started:
		result_music_started = true
		# Start music only when the result is revealed, after combat presentation.
		get_node("/root/Music").play_result(winner == "player", enemy_ship_data.enemy_rank if enemy_ship_data != null else 0)


func _display_snapshot() -> Dictionary:
	var shown_cards: Array[Dictionary] = []
	for card in hand.cards:
		shown_cards.append(
			{
				"preview": modifier.preview(card),
				"present": card != null,
				"affordable": card != null and get("player_" + card.family) >= card.cost,
				"ion_glow":
				card != null and card.family == "energy" and modifier.kind == 2 and modifier.active
			}
		)
	return {
		"player": ship_snapshot("player"),
		"enemy": ship_snapshot("enemy"),
		"enemy_name": enemy_ship_data.ship_name if enemy_ship_data != null else "Enemy Ship",
		"enemy_subtitle": enemy_ship_data.subtitle if enemy_ship_data != null else "Unknown Vessel",
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
		"repair_limit": _repair_spend_limit(),
		"repair_unit_cost": RESULT_SALVAGE_PER_HULL,
		"rewards_text": victory_description(),
		"in_expedition": expedition != null,
		"pending_choice": expedition.pending_choice if expedition != null else "",
		"next_modifier_name": modifier.NAMES[next_modifier] if next_modifier >= 0 else "",
		"salvage": salvage,
		"winner": winner,
		"result_cause": result_cause,
		"systems_failure": systems_failure.snapshot(_both_states()),
		"battles_won": battles_won,
		"repair_spend": repair_spend,
		"resolving_card": resolving_card or not damage_timeline.pending.is_empty(),
		"current_actor": current_actor,
		"turn_number": turn_number,
		"escaped_by_ftl": escaped_by_ftl,
		"starting_player_hull": starting_player_hull,
		"result_hull": result_hull,
		"result_recorded": result_recorded,
		"player_hull_damage_taken": player_hull_damage_taken,
		"encounter_number": encounter_number,
	}


# Control nodes use editor-visible anchors; these decorative lines are Node2Ds.
func _fit_board_lines() -> void:
	hud.fit_board_lines(size, mode_rule_origin, hand_rule_origin)
	_fit_combat_controls()


func _fit_combat_controls() -> void:
	hud.fit_combat_controls(size)
	_fit_allocation_button()
	_fit_jump_button()


func _fit_allocation_button() -> void:
	if not is_instance_valid(allocation_button):
		return
	preload("res://scripts/ui/battle_layout.gd").fit(self, settings_button, allocation_button)


func _setup_allocation() -> void:
	hand.configure_player_allocation(allocation_settings.matching_draw_weight)
	allocation_popup = preload("res://scripts/ui/power_allocation_popup.gd").new()
	add_child(allocation_popup)
	allocation_button = Button.new()
	allocation_button.name = "PowerAllocation"
	allocation_button.custom_minimum_size = preload("res://scripts/ui/battle_layout.gd").BUTTON_SIZE
	allocation_button.add_theme_font_override("font", ResultPresentation.UI_FONT)
	allocation_button.add_theme_font_size_override("font_size", 22)
	ResultPresentation.action(allocation_button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = allocation_button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		allocation_button.add_theme_stylebox_override(state, box)
	add_child(allocation_button)
	allocation_popup.mode_selected.connect(_select_allocation)
	allocation_button.pressed.connect(
		func(): allocation_popup.present(hand.allocation_mode, hand._allocation_multiplier)
	)
	_select_allocation("balanced")


func _select_allocation(mode: String) -> void:
	if is_instance_valid(damage_timeline) and not damage_timeline.pending.is_empty():
		return
	if not hand.select_allocation(mode):
		return
	var index: int = allocation_popup.MODES.find(mode)
	allocation_button.text = allocation_popup.ICONS[index]
	allocation_button.tooltip_text = "Power Allocation · " + allocation_popup.NAMES[index]


func _fit_jump_button() -> void:
	# Board3D positions this control before the base Board has initialized its HUD.
	BattleHUD.fit_jump_button($FTLPanel/WarpButton, $FTLPanel/Progress.size.x)


func _update_jump_style() -> void:
	hud.update_jump_style(ftl.disabled_turns)


#endregion

#region Results and repairs


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
		return ""
	var lines: PackedStringArray = []
	var bonuses: PackedStringArray = []
	if expedition != null:
		var result: BattleResult = battle_result()
		lines.append(
			(
				"🪨 +%d Salvage · 🚀 FTL %d/%d"
				% [
					expedition.victory_salvage(result),
					expedition.ftl_charge,
					expedition.required_ftl_charge
				]
			)
		)
		var upgrades: int = expedition.battle_upgrade_count(result)
		if upgrades > 0:
			lines[0] += " · Upgrade %d cards" % upgrades
		var elite_bonus: int = expedition.elite_resource_reward(result)
		if elite_bonus > 0:
			bonuses.append("Elite: " + _resource_reward_text(elite_bonus))
	elif not escaped_by_ftl:
		lines.append("🪨 +%d Salvage" % DESTRUCTION_SALVAGE)
	if tactical_victory():
		bonuses.append("Tactical: " + _resource_reward_text(TACTICAL_RESOURCES))
	if strategic_victory():
		bonuses.append("Strategic: 🛡️ +%d" % STRATEGIC_SHIELDS)
	if not bonuses.is_empty():
		if expedition != null:
			bonuses[0] = "Next battle · " + bonuses[0]
		else:
			lines.append("Next battle")
		lines.append_array(bonuses)
	return "\n".join(lines)


func _resource_reward_text(amount: int) -> String:
	return "🛠️ +%d · ⚡ +%d · 👥 +%d" % [amount, amount, amount]


func _record_result() -> void:
	if winner.is_empty() or result_recorded or checkpoint_exit:
		return
	# Freeze combat rewards before post-battle salvage repair changes hull.
	earned_tactical = tactical_victory()
	earned_strategic = strategic_victory()
	result_hull = player_hull
	result_recorded = true
	if winner == "player":
		battles_won += 1
		if expedition != null:
			salvage += expedition.victory_salvage(battle_result())
		elif not escaped_by_ftl:
			salvage += DESTRUCTION_SALVAGE
	if expedition != null:
		expedition.record_battle(battle_result())
	if winner == "player" and player_hull > 0 and expedition == null and next_modifier < 0:
		next_modifier = randi_range(1, modifier.NAMES.size() - 1)


func battle_result() -> BattleResult:
	return BattleAdapter.result(self)


func _sync_expedition_hand() -> void:
	BattleAdapter.sync_hand(hand, expedition.player_pool(), expedition.acquired_draw_weights(), expedition.upgraded_cards)


func _repair_spend_limit() -> int:
	return Repairs.max_spend(player_hull, player_hull_capacity, salvage)


func _adjust_repair_spend(change: int) -> void:
	if winner != "player" or resolving_card or battle_effects.busy:
		return
	repair_spend = clampi(maxi(0, repair_spend) + change, 0, _repair_spend_limit())
	refresh_display()


func _repair_with_salvage() -> void:
	if winner != "player" or repair_spend <= 0 or resolving_card or battle_effects.busy:
		return
	_record_result()
	var spent: int = mini(repair_spend, _repair_spend_limit())
	player_hull += spent
	salvage -= Repairs.quantity_cost(spent, RESULT_SALVAGE_PER_HULL)
	if expedition != null:
		expedition.sync_battle(battle_result())
	repair_spend = _repair_spend_limit()
	refresh_display()

#endregion
