extends Control

# RESPONSIBILITY: Coordinate both hands, turns, effects and board display.
# DOES NOT: Choose AI moves, implement card effects or animate cards.

signal action_finished(side: String, discarded: bool)
signal expedition_continue
signal expedition_restart
signal expedition_exit
var expedition: Resource
var expedition_encounter: int = -1
## TUNE: Static Power Allocation weight; copied into the player hand at battle start.
@export var allocation_settings: Resource = preload("res://resources/power_allocation.tres")
var allocation_button: Button
var allocation_popup: CanvasLayer

const Ships = preload("res://scripts/ship_library.gd")
const ResultPresentation = preload("res://scripts/ui/encounter_presentation.gd")
var player_ship_data: Resource
var enemy_ship_data: Resource

const MatchRules = preload("res://scripts/match_rules.gd")
const CardEffects = preload("res://scripts/card_effects.gd")
# Assign the six editable scene card buttons in the Inspector.
@export var card_slots: Array[NodePath] = [NodePath("ShieldPlatingCard"),
	NodePath("SynthesizerUpgradeCard"), NodePath("LaserBurstCard"),
	NodePath("EnergyCellCard"), NodePath("QuartersUpgradeCard"), NodePath("TorpedoSalvoCard")]
## TUNE: Amount required in EACH of the three resources for resource victory.
@export_range(1, 1000, 1) var resource_goal: int = 100
## TUNE in Board3D Inspector: permanent capacity for each ship; excess is temporary plating.
@export_range(1, 1000, 1) var player_hull_capacity: int = 30
@export_range(1, 1000, 1) var enemy_hull_capacity: int = 30
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
var repair_spend: int = -1
var starting_player_hull: int = 0
var player_hull_damage_taken: int = 0
# Pending rewards belong only to this encounter, never permanent setup values.
var pending_resource_bonus: int = 0
var pending_shield_bonus: int = 0
## TUNE: Next-battle rewards for tactical and strategic victories.
const TACTICAL_RESOURCES: int = 5
const STRATEGIC_SHIELDS: int = 10
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
@export var player_hull: int = 30
## TUNE: Starting shields for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_shields: int = 10

## TUNE: Starting materials for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_materials: int = 16
## TUNE: Starting energy for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_energy: int = 16
## TUNE: Starting crew for the player. Edit the board node in the Inspector if it has a saved override.
@export var player_crew: int = 16

## TUNE: Starting materials gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_synthesizer: int = 2
## TUNE: Starting energy gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_reactor: int = 2
## TUNE: Starting crew gained each player turn. Edit the board node in the Inspector if it has a saved override.
@export var player_quarters: int = 2


# ENEMY
## TUNE: Starting hull for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_hull: int = 30
## TUNE: Starting shields for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_shields: int = 10

## TUNE: Starting materials for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_materials: int = 16
## TUNE: Starting energy for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_energy: int = 16
## TUNE: Starting crew for the enemy. Edit the board node in the Inspector if it has a saved override.
@export var enemy_crew: int = 16

## TUNE: Starting materials gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_synthesizer: int = 2
## TUNE: Starting energy gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_reactor: int = 2
## TUNE: Starting crew gained each enemy turn. Edit the board node in the Inspector if it has a saved override.
@export var enemy_quarters: int = 2

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

func _enter_tree() -> void:
	# Ship selection persists in setup settings. Enemy is rolled anew per board instance.
	if setup_settings.has("player_ship"):
		player_ship_data = Ships.PLAYERS[clampi(int(setup_settings.player_ship), 0, Ships.PLAYERS.size()-1)]
		var generator = RandomNumberGenerator.new()
		generator.randomize()
		enemy_ship_data = Ships.ENEMIES[generator.randi_range(0, Ships.ENEMIES.size()-1)]
		if setup_settings.has("enemy_ship"):
			enemy_ship_data = Ships.ENEMIES[clampi(int(setup_settings.enemy_ship), 0, Ships.ENEMIES.size() - 1)]
		if setup_settings.has("enemy_data"):
			enemy_ship_data = setup_settings.enemy_data

func _apply_ship(side: String, data: Resource) -> void:
	if data == null:
		return
	set(side + "_hull_capacity", data.hull_capacity)
	set(side + "_hull", data.hull_capacity)
	set(side + "_shields", data.shields)
	for key in MatchRules.RESOURCES + MatchRules.PRODUCTION:
		set(side + "_" + key, data.get(key))

# Initialize ship stats and expedition overrides before dealing hands and starting turn income.
func _ready() -> void:
	get_node("/root/Music").play_battle()
	repair_preview = preload("res://scripts/ui/repair_preview.gd").new()
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
	ftl.charge_target = player_ship_data.ftl_turns if player_ship_data != null else maxi(1, int(setup_settings.get("ftl_turns", ftl.FULL_CHARGE)))
	ftl.failure_multiplier = 1.0 - player_ship_data.ftl_resistance if player_ship_data != null else 1.0
	if player_ship_data != null and hand.card_pool.is_empty() and not player_ship_data.starting_cards.is_empty():
		hand.card_pool.assign(player_ship_data.starting_cards)
	if enemy_ship_data != null:
		enemy_hand.family_weights = enemy_ship_data.card_family_weights
		enemy_hand.effect_weights = enemy_ship_data.card_effect_weights
		enemy_ai.tactical_weights = enemy_ship_data.tactical_weights
		enemy_ai.tactical_variation = enemy_ship_data.tactical_variation
		enemy_ai.hull_capacity = enemy_ship_data.hull_capacity
	if expedition != null:
		expedition.begin_battle(self, expedition_encounter)
		starting_player_hull = player_hull
	modifier.configure(int(setup_settings.get("modifier", 0)))
	for active_hand in [hand, enemy_hand]:
		active_hand.drop_multiplier = modifier.TEMPORAL_DROP_MULTIPLIER if modifier.kind == 5 else 1.0
	_setup_allocation()
	$MatchResult/Panel/Configure.pressed.connect(_return_to_setup)
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


func _read_state(side: String) -> Dictionary:
	var state: Dictionary = {}
	for key in ["hull", "hull_capacity", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters"]:
		state[key] = get(side + "_" + key)
	return state


func _write_state(side: String, state: Dictionary) -> void:
	for key in state:
		set(side + "_" + key, state[key])


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
	if side == "player":
		var event_due: bool = modifier.kind in [1, 2, 3] and not modifier.active and turn_number >= modifier.next_round
		if event_due:
			resolving_card = true
			refresh_display()
			await $ModifierDisplay.warning(modifier.kind)
			if is_queued_for_deletion():
				return
		var announcement: String = modifier.begin_round(turn_number)
		if modifier.kind == 1 and not announcement.is_empty():
			var player: Dictionary = _read_state("player")
			var enemy: Dictionary = _read_state("enemy")
			announcement = modifier.asteroid_strike(player, enemy)
			_write_state("player", player)
			_write_state("enemy", enemy)
			player_hull_damage_taken += maxi(0, int(before.player.hull) - player_hull)
			_damage_ftl(permanent_damage(int(before.player.hull), player_hull, player_hull_capacity))
			asteroid_event = true
		$ModifierDisplay.announce(announcement)
		if event_due:
			var player_hit: bool = asteroid_event and (player_hull < int(before.player.hull) or player_shields < int(before.player.shields))
			$ModifierDisplay.impact(modifier.kind, player_hit)
		if not _check_winner():
			var was_offline: bool = ftl.disabled_turns > 0
			ftl.begin_player_turn()
			if was_offline and ftl.disabled_turns == 0:
				$ModifierDisplay.ftl_online(ftl.can_warp())
	var state: Dictionary = _read_state(side)
	if winner.is_empty():
		MatchRules.income(state)
		_write_state(side, state)
	battle_effects.play_changes(before, _both_states(), "", "", 0, asteroid_event)
	resolving_card = battle_effects.busy or resolving_card
	_check_winner()
	refresh_display()
	if asteroid_event or (side == "player" and modifier.active):
		await $ModifierDisplay.hold_result()
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
	if resolving_card or current_actor != side or not winner.is_empty():
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
	if not discard and get(side + "_" + card.family) < card.cost:
		return false
	resolving_card = true
	enemy_timer.stop()
	refresh_display()
	var ion_card: bool = not discard and modifier.kind == 2 and modifier.active and card.family == "energy"
	if ion_card:
		await $ModifierDisplay.warning(2, true, modifier.ion_text())
		if is_queued_for_deletion():
			return false
	var source: Control = get_node(card_slots[slot]) if side == "player" else null
	var motion = $CardMotion
	await motion.animate_action(modifier.preview(card), source, side, discard,
		_resolve_card.bind(side, slot, discard, card))
	if ion_card:
		await $ModifierDisplay.hold_result()
	if motion.cancelling or not is_inside_tree() or is_queued_for_deletion():
		return false
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
		if side == "enemy":
			turn_number += 1
		await _begin_turn("enemy" if side == "player" else "player")
	action_finished.emit(side, discard)
	return true


# Commit dictionary results, replace the used slot, then present deltas and evaluate victory.
# CombatModifier.play delegates cost/effects to CardEffects; discard uses its own refund path.
func _resolve_card(side: String, slot: int, discard: bool, card: Resource) -> void:
	var before: Dictionary = _both_states()
	var active_hand = hand if side == "player" else enemy_hand
	var other: String = "enemy" if side == "player" else "player"
	var actor: Dictionary = _read_state(side)
	var target: Dictionary = _read_state(other)
	if discard:
		actor[card.family] += int(floor(card.cost / 3.0))
	else:
		$ModifierDisplay.announce(modifier.play(card, actor, target))
		if modifier.kind == 2 and modifier.active and card.family == "energy":
			$ModifierDisplay.impact(2)
	_write_state(side, actor)
	_write_state(other, target)
	if not discard:
		player_hull_damage_taken += int(modifier.last_hull_damage.actor if side == "player" else modifier.last_hull_damage.target)
	if not discard:
		var key: String = "actor" if side == "player" else "target"
		var report: Dictionary = modifier.last_hull_damage
		var attack_before: int = int(report.get(key + "_before", player_hull))
		_damage_ftl(permanent_damage(attack_before, attack_before - int(report.get(key, 0)), player_hull_capacity))
	active_hand.replace_card(slot)
	extra_action_requested = not discard and card.play_again
	var who: String = "You" if side == "player" else "Enemy"
	var action: String = "discarded" if discard else "played"
	$LastActionLabel.text = "%s %s %s" % [who, action, card.card_name]
	if discard:
		$LastActionLabel.text += " (+%d %s)" % [int(floor(card.cost / 3.0)), card.family.capitalize()]
	elif extra_action_requested:
		$LastActionLabel.text += " — play again"
	battle_effects.play_changes(before, _both_states(), side,
		card.family, 0 if discard else card.cost,
		not discard and (card.effects.get("damage", 0) > 0 or card.effects.get("break_shields", 0) > 0 or card.effects.has("shield_collapse_below") or card.effects.has("shield_collapse")))
	_check_winner()
	refresh_display()


func _both_states() -> Dictionary:
	return {"player": _read_state("player"), "enemy": _read_state("enemy")}


# EnemyAI returns a slot/discard decision; _act still enforces the same real action rules.
func _on_enemy_timeout() -> void:
	if resolving_card or current_actor != "enemy" or not winner.is_empty():
		return
	var move: Dictionary = enemy_ai.choose(enemy_hand.cards, _read_state("enemy"),
		_read_state("player"), resource_goal)
	if move.is_empty():
		# A deliberately undersized custom pool may leave the AI with no cards.
		$LastActionLabel.text = "Enemy has no cards — passes"
		turn_number += 1
		_begin_turn("player")
		return
	_act("enemy", move.slot, move.discard)


# Latch the first terminal result and stop AI timing; reward recording happens in refresh_display.
func _check_winner() -> bool:
	if not winner.is_empty():
		return true
	var player: Dictionary = _read_state("player")
	var enemy: Dictionary = _read_state("enemy")
	if player.hull <= 0 and enemy.hull <= 0:
		winner = "draw"
	elif MatchRules.wins(player, enemy, resource_goal):
		winner = "player"
	elif MatchRules.wins(enemy, player, resource_goal):
		winner = "enemy"
	if not winner.is_empty():
		enemy_timer.stop()
	return not winner.is_empty()


func _restart_match() -> void:
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
	if current_actor != "player" or resolving_card or battle_effects.busy or not winner.is_empty():
		return
	if _check_winner() or not ftl.can_warp():
		refresh_display()
		return
	winner = "player"
	escaped_by_ftl = true
	enemy_timer.stop()
	$LastActionLabel.text = "EMP Pulse complete — escaped!"
	refresh_display()
	$MatchResult/Panel/Title.text = "EMP PULSE SUCCESS"

# Refresh controls from authoritative state; _record_result also commits a finished battle once.
# Layout helpers below override scene offsets on resize, so inspect them before moving scene controls.
func refresh_display() -> void:
	$ModeLabel.text = enemy_ship_data.ship_name if enemy_ship_data != null else "Enemy Ship"
	$ModeLabel/Subtitle.text = enemy_ship_data.subtitle if enemy_ship_data != null else "Unknown Vessel"
	$ModeLabel.add_theme_font_size_override("font_size", $TurnLabel.get_theme_font_size("font_size"))
	$ModeLabel/Subtitle.add_theme_font_size_override("font_size", $SalvageLabel.get_theme_font_size("font_size"))
	_record_result()
	$SalvageLabel.text = "Salvage %d" % salvage
	$MatchResult/Panel/BattlesWon.visible = winner in ["enemy", "draw"]
	$MatchResult/Panel/BattlesWon.text = "%d BATTLES WON" % battles_won
	$MatchResult/Panel/Rewards.visible = winner == "player"
	var repair_limit: int = _repair_spend_limit()
	if winner == "player":
		repair_spend = repair_limit if repair_spend < 0 else clampi(repair_spend, 0, repair_limit)
	for path in ["Repair", "RepairMinus", "RepairPlus", "RepairAmount"]:
		get_node("MatchResult/Panel/" + path).visible = winner == "player"
	$MatchResult/Panel/Repair.disabled = repair_spend <= 0 or resolving_card or battle_effects.busy
	$MatchResult/Panel/RepairMinus.disabled = repair_spend <= 0 or resolving_card or battle_effects.busy
	$MatchResult/Panel/RepairPlus.disabled = repair_spend >= repair_limit or resolving_card or battle_effects.busy
	var repair_amount: int = maxi(0, repair_spend)
	repair_preview.visible = winner == "player"
	repair_preview.show_repair(player_hull, player_hull_capacity, salvage, repair_amount, RESULT_SALVAGE_PER_HULL)
	$MatchResult/Panel/RepairAmount.text = "+%d Hull" % repair_amount
	$MatchResult/Panel/Repair.text = "Confirm · %d Salvage" % Repairs.quantity_cost(repair_amount, RESULT_SALVAGE_PER_HULL)
	if repair_limit == 0:
		$MatchResult/Panel/Repair.text = "Hull full" if player_hull >= player_hull_capacity else "Need 2 Salvage"
	$ModifierDisplay.refresh(modifier, turn_number)
	var ftl_status: String = "EMP Pulse %d / %d" % [ftl.charge, ftl.charge_target]
	if ftl.disabled_turns > 0:
		ftl_status += " · Offline (%d turns)" % ftl.disabled_turns
	elif ftl.can_warp():
		ftl_status += " · Ready"
	$FTLPanel/Charge.text = ftl_status
	$FTLPanel/Charge.tooltip_text = ftl_status
	$FTLPanel/Charge.text = ftl_status.replace("EMP Pulse ", "EMP ").replace(" · Offline (", " · Off (")
	$FTLPanel/Progress.max_value = ftl.charge_target
	$FTLPanel/Progress.value = ftl.charge
	var charged: bool = ftl.charge >= ftl.charge_target and winner.is_empty()
	$FTLPanel/Charge.visible = not charged
	$FTLPanel/Progress.visible = not charged
	$FTLPanel/WarpButton.visible = charged
	_update_jump_style()
	$FTLPanel/WarpButton.disabled = not ftl.can_warp() or current_actor != "player" or resolving_card or battle_effects.busy or not winner.is_empty()
	allocation_button.visible = winner.is_empty()
	if not winner.is_empty(): allocation_popup.dismiss()
	$MatchResult.visible = not winner.is_empty() and not resolving_card and not battle_effects.busy
	if $MatchResult.visible and not result_music_started:
		result_music_started = true
		# Start the intro at the reveal, after combat presentation; EMP escape is also a win.
		get_node("/root/Music").play_result(winner == "player")
	$MatchResult/Panel/Title.text = "EMP PULSE SUCCESS" if escaped_by_ftl else ("DRAW" if winner == "draw" else ("YOU WIN" if winner == "player" else "YOU LOSE"))
	var method: String = "EMP Pulse" if escaped_by_ftl else ("Enemy ship destroyed" if enemy_hull <= 0 and winner == "player" else ("Resource victory" if winner == "player" else ("Both ships destroyed" if winner == "draw" else "Defeat")))
	$MatchResult/Panel/Details.text = "%s · Turn %d\n❤️ %d → %d · Damage taken: %d" % [method, turn_number, starting_player_hull, result_hull if result_recorded else player_hull, player_hull_damage_taken]
	$MatchResult/Panel/Rewards.text = victory_description()
	$MatchResult/Panel/Rewards.visible = not $MatchResult/Panel/Rewards.text.is_empty()
	$MatchResult/Panel/PlayAgain.hide()
	$MatchResult/Panel/Configure.text = "Select Ship"
	var can_continue: bool = winner == "player" and player_hull > 0
	$MatchResult/Panel/Continue.visible = can_continue
	$MatchResult/Panel/NextEncounter.visible = can_continue and expedition == null
	if can_continue and expedition == null:
		if next_modifier < 0:
			# TUNE: Draw equally from active modifiers, including Temporal Rift; excludes None.
			next_modifier = randi_range(1, modifier.NAMES.size() - 1)
		$MatchResult/Panel/NextEncounter.text = "Encounter %d · %s" % [encounter_number + 1, modifier.NAMES[next_modifier]]
	if expedition != null:
		$MatchResult/Panel/Continue.text = "Upgrade Cards" if expedition.pending_choice == "upgrade" else "Star System"
	$EnemyTurnBanner.show_enemy_turn(current_actor == "enemy" and winner.is_empty(), card_slots)
	$PlayerShip/ShieldPlaceholder.visible = player_shields > 0 and not modifier.shields_disabled()
	$EnemyShip/ShieldPlaceholder.visible = enemy_shields > 0 and not modifier.shields_disabled()
	var player_can_act: bool = winner.is_empty() and current_actor == "player" and not resolving_card
	if winner.is_empty():
		$TurnLabel.text = "Turn %d · %s" % [turn_number, "You" if current_actor == "player" else "Enemy"]
	else:
		$TurnLabel.text = "DRAW" if winner == "draw" else ("YOU WIN" if winner == "player" else "ENEMY WINS")
	player_hull_label.text = "Hull %d/%d" % [player_hull, player_hull_capacity]
	player_hull_label.add_theme_color_override("font_color", $PlayerHullBar.plating_color if player_hull > player_hull_capacity else Color(0.82, 0.84, 0.87))
	$PlayerHullBar.update_hull(player_hull, player_hull_capacity)
	player_shields_label.text = "Shields OFF" if modifier.shields_disabled() else "Shields %d" % player_shields
	enemy_hull_label.text = "Hull %d/%d" % [enemy_hull, enemy_hull_capacity]
	enemy_hull_label.add_theme_color_override("font_color", $EnemyHullBar.plating_color if enemy_hull > enemy_hull_capacity else Color(0.82, 0.84, 0.87))
	$EnemyHullBar.update_hull(enemy_hull, enemy_hull_capacity)
	enemy_shields_label.text = "Shields OFF" if modifier.shields_disabled() else "Shields %d" % enemy_shields
	battle_effects.set_number(player_materials_label, player_materials)
	player_synthesizer_label.text = str(player_synthesizer)

	battle_effects.set_number(player_energy_label, player_energy)
	player_reactor_label.text = str(player_reactor)
	battle_effects.set_number(player_crew_label, player_crew)
	player_quarters_label.text = str(player_quarters)
	battle_effects.set_number(enemy_materials_label, enemy_materials)
	enemy_synthesizer_label.text = str(enemy_synthesizer)
	battle_effects.set_number(enemy_energy_label, enemy_energy)
	enemy_reactor_label.text = str(enemy_reactor)
	battle_effects.set_number(enemy_crew_label, enemy_crew)
	enemy_quarters_label.text = str(enemy_quarters)
	for slot in range(card_slots.size()):
		var button = get_node(card_slots[slot])
		var card: Resource = hand.cards[slot]
		button.card_data = modifier.preview(card)
		button.set_ion_glow(card != null and card.family == "energy" and modifier.kind == 2 and modifier.active)
		var playable: bool = card != null and player_can_act
		if playable:
			playable = get("player_" + card.family) >= card.cost
		button.set_playable(playable, int(card != null and get("player_" + card.family) >= card.cost))
		button.set_discardable(card != null and player_can_act)

# Control nodes use editor-visible anchors; these decorative lines are Node2Ds.
func _fit_board_lines() -> void:
	$ModeRule.position = mode_rule_origin + Vector2(size.x - 1280.0, 0)
	$HandRule.position = hand_rule_origin + Vector2(0, size.y - 720.0)
	var points: PackedVector2Array = $HandRule.points
	points[points.size() - 1].x = size.x - 24.0
	$HandRule.points = points
	_fit_combat_controls()

func _fit_combat_controls() -> void:
	var gap: float = 10.0
	var card_scale: float = minf(1.0, (size.x - 32 - gap * 5) / (198 * 6))
	var hand_width: float = 198 * card_scale * 6 + gap * 5
	for index in range(card_slots.size()):
		var card: Control = get_node(card_slots[index])
		card.scale = Vector2.ONE * card_scale
		card.position = Vector2((size.x - hand_width) / 2 + index * (198 * card_scale + gap), size.y - 12 - 294 * card_scale)
		card.discard_target_height = 48.0 / card_scale
		card.get_node("DiscardButton").add_theme_font_size_override("font_size", roundi(18 / card_scale))
		if card.card_data != null: card.refresh_card()
	var hand_top: float = size.y - 12 - 294 * card_scale
	$HandRule.position.y = hand_top - 8 - 359
	$LastActionLabel.position = Vector2(16, hand_top - 32)
	$LastActionLabel.size.x = size.x - 160
	_fit_allocation_button()
	_fit_jump_button()

func _fit_allocation_button() -> void:
	if not is_instance_valid(allocation_button): return
	# 2D fallback uses the ship presentation center; 3D boards override this projection.
	allocation_button.position = $PlayerShip.position + Vector2(-150, 0) - allocation_button.size * 0.5

func _setup_allocation() -> void:
	hand.configure_player_allocation(allocation_settings.matching_draw_weight)
	allocation_popup = preload("res://scripts/ui/power_allocation_popup.gd").new()
	add_child(allocation_popup)
	allocation_button = Button.new()
	allocation_button.name = "PowerAllocation"
	allocation_button.custom_minimum_size = Vector2(64, 48)
	allocation_button.add_theme_font_override("font", ResultPresentation.UI_FONT)
	allocation_button.add_theme_font_size_override("font_size", 26)
	ResultPresentation.action(allocation_button)
	add_child(allocation_button)
	allocation_popup.mode_selected.connect(_select_allocation)
	allocation_button.pressed.connect(func(): allocation_popup.present(hand.allocation_mode, hand._allocation_multiplier))
	_select_allocation("balanced")

func _select_allocation(mode: String) -> void:
	if not hand.select_allocation(mode): return
	var index: int = allocation_popup.MODES.find(mode)
	allocation_button.text = allocation_popup.ICONS[index]
	allocation_button.tooltip_text = "Power Allocation · " + allocation_popup.NAMES[index]

func _fit_jump_button() -> void:
	var button: Button = $FTLPanel/WarpButton
	button.size = Vector2($FTLPanel/Progress.size.x, 48)
	button.position = Vector2(0, -10)

func _update_jump_style() -> void:
	var button: Button = $FTLPanel/WarpButton
	var offline: bool = ftl.disabled_turns > 0
	button.text = "EMP offline" if offline else "EMP Pulse"
	button.tooltip_text = "Offline: %d turns remaining." % ftl.disabled_turns if offline else "Escape by EMP Pulse."
	if button.has_meta("offline_style") and button.get_meta("offline_style") == offline: return
	button.set_meta("offline_style", offline)
	ResultPresentation.action(button)
	if offline:
		for key in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = button.get_theme_stylebox(key).duplicate()
			box.bg_color = Color("702b35")
			box.border_color = Color("ef7e88")
			button.add_theme_stylebox_override(key, box)
		button.add_theme_color_override("font_disabled_color", Color("ffd3d7"))

func _damage_ftl(amount: int) -> void:
	if ftl.take_hull_damage(amount):
		$ModifierDisplay.ftl_offline()

func _continue_encounter() -> void:
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
	if winner != "player": return ""
	var lines: PackedStringArray = []
	var bonuses: PackedStringArray = []
	if expedition != null:
		lines.append("🪨 +%d Salvage · 🚀 FTL %d/%d" % [expedition.victory_salvage(self), expedition.ftl_charge, expedition.required_ftl_charge])
		var upgrades: int = expedition.battle_upgrade_count(self)
		if upgrades > 0: lines[0] += " · Upgrade %d cards" % upgrades
		var elite_bonus: int = expedition.elite_resource_reward(self)
		if elite_bonus > 0: bonuses.append("Elite: " + _resource_reward_text(elite_bonus))
	elif enemy_hull <= 0 and not escaped_by_ftl:
		lines.append("🪨 +%d Salvage" % DESTRUCTION_SALVAGE)
	if tactical_victory(): bonuses.append("Tactical: " + _resource_reward_text(TACTICAL_RESOURCES))
	if strategic_victory(): bonuses.append("Strategic: 🛡️ +%d" % STRATEGIC_SHIELDS)
	if not bonuses.is_empty():
		if expedition != null: bonuses[0] = "Next battle · " + bonuses[0]
		else: lines.append("Next battle")
		lines.append_array(bonuses)
	return "\n".join(lines)

func _resource_reward_text(amount: int) -> String:
	return "🛠️ +%d · ⚡ +%d · 👥 +%d" % [amount, amount, amount]

func _record_result() -> void:
	if winner.is_empty() or result_recorded:
		return
	# Freeze combat rewards before post-battle salvage repair changes hull.
	earned_tactical = tactical_victory()
	earned_strategic = strategic_victory()
	result_hull = player_hull
	result_recorded = true
	if winner == "player":
		battles_won += 1
		if expedition != null:
			salvage += expedition.victory_salvage(self)
		elif enemy_hull <= 0 and not escaped_by_ftl:
			salvage += DESTRUCTION_SALVAGE
	if expedition != null:
		expedition.record_battle(self)

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
		expedition.sync_battle(self)
	repair_spend = -1
	refresh_display()

static func permanent_damage(before: int, after: int, capacity: int) -> int:
	return maxi(0, mini(before, capacity) - mini(after, capacity))
