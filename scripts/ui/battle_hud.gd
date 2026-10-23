extends RefCounted

const Sound = preload("res://scripts/audio/sfx.gd")
# RESPONSIBILITY: Render combat HUD/results and fit generic 2D controls.
# DOES NOT: Advance turns, record rewards, choose encounters or modify combat state.
# EXTEND: Add display facts to Board._display_snapshot(), then update the relevant refresh method.
const Repairs = preload("res://scripts/repair_rules.gd")
const ResultPresentation = preload("res://scripts/ui/encounter_presentation.gd")
const Effects = preload("res://scripts/visual/visual_effects.gd")
var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var result_visible: bool = false
var _emp_charge: int = -1
var _emp_ready: bool = false
var _emp_fired: bool = false
var nodes: Dictionary = {}
var cards: Array[Control] = []
var card_slots: Array[NodePath] = []
var tactical: Control


func _init(board_view: Control) -> void:
	# Bind existing scene controls once. Do not retain the gameplay controller.
	for path in [
		"EnemyHullBar",
		"EnemyShip/ShieldPlaceholder",
		"EnemyTurnBanner",
		"FTLPanel/Charge",
		"FTLPanel/Progress",
		"FTLPanel/WarpButton",
		"HandRule",
		"LastActionLabel",
		"MatchResult",
		"MatchResult/Panel",
		"MatchResult/Panel/BattlesWon",
		"MatchResult/Panel/Configure",
		"MatchResult/Panel/Continue",
		"MatchResult/Panel/Details",
		"MatchResult/Panel/NextEncounter",
		"MatchResult/Panel/PlayAgain",
		"MatchResult/Panel/Repair",
		"MatchResult/Panel/RepairAmount",
		"MatchResult/Panel/RepairMinus",
		"MatchResult/Panel/RepairPlus",
		"MatchResult/Panel/Rewards",
		"MatchResult/Panel/Title",
		"ModeLabel",
		"ModeLabel/Subtitle",
		"ModeRule",
		"PlayerHullBar",
		"PlayerShip/ShieldPlaceholder",
		"SalvageLabel",
		"TurnLabel",
		"SystemsFailureDisplay"
	]:
		nodes[path] = board_view.get_node(path)
	for field in [
		"repair_preview",
		"allocation_button",
		"allocation_popup",
		"battle_effects",
		"player_hull_label",
		"player_shields_label",
		"player_materials_label",
		"player_energy_label",
		"player_crew_label",
		"player_synthesizer_label",
		"player_reactor_label",
		"player_quarters_label",
		"enemy_hull_label",
		"enemy_shields_label",
		"enemy_materials_label",
		"enemy_energy_label",
		"enemy_crew_label",
		"enemy_synthesizer_label",
		"enemy_reactor_label",
		"enemy_quarters_label"
	]:
		nodes[field] = board_view.get(field)
	card_slots.assign(board_view.card_slots)
	for path in card_slots:
		cards.append(board_view.get_node(path))
	tactical = preload("res://scripts/ui/tactical_preview.gd").new()
	tactical.name = "TacticalPreview"
	board_view.add_child(tactical)
	for side in ["player", "enemy"]:
		for attribute in preload("res://scripts/cards/card_targets.gd").ATTRIBUTES:
			tactical.indicators[side + "_" + attribute] = nodes[side + "_" + attribute + "_label"]
	tactical.bind(cards, [board_view.settings_button.popup, board_view.settings_button.menu.shade, board_view.settings_button.information.shade, nodes["allocation_popup"].shade, board_view.get_node("ModifierDisplay/Meter").details.shade])
	var reference: Node = board_view.settings_button.information
	for side in ["player", "enemy"]:
		for attribute in preload("res://scripts/cards/card_targets.gd").ATTRIBUTES:
			bind_reference(nodes[side + "_" + attribute + "_label"], reference, "resources" if attribute not in ["hull", "shields"] else "defenses")
	bind_reference(nodes["FTLPanel/Charge"], reference, "emp")
	for column in nodes["SystemsFailureDisplay"].columns.values():
		for label in column.get_children(): bind_reference(label, reference, "failure")



func refresh(data: Dictionary) -> void:
	tactical.update_context(data)
	nodes["SystemsFailureDisplay"].refresh(data.systems_failure)
	refresh_results(data)
	refresh_emp(data)
	refresh_ships_and_cards(data)


func refresh_results(data: Dictionary) -> void:
	nodes["ModeLabel"].text = data.enemy_name
	nodes["ModeLabel/Subtitle"].text = data.enemy_subtitle
	nodes["ModeLabel"].add_theme_font_size_override(
		"font_size", nodes["TurnLabel"].get_theme_font_size("font_size")
	)
	nodes["ModeLabel/Subtitle"].add_theme_font_size_override(
		"font_size", nodes["SalvageLabel"].get_theme_font_size("font_size")
	)
	nodes["SalvageLabel"].text = "Salvage %d" % data.salvage
	nodes["MatchResult/Panel/BattlesWon"].visible = data.winner in ["enemy", "draw"]
	nodes["MatchResult/Panel/BattlesWon"].text = "%d BATTLES WON" % data.battles_won
	nodes["MatchResult/Panel/Rewards"].visible = data.winner == "player"
	var repair_limit: int = data.repair_limit
	for path in ["Repair", "RepairMinus", "RepairPlus", "RepairAmount"]:
		nodes["MatchResult/Panel/" + path].visible = data.winner == "player"
	nodes["MatchResult/Panel/Repair"].disabled = (
		data.repair_spend <= 0 or data.resolving_card or data.effects_busy
	)
	nodes["MatchResult/Panel/RepairMinus"].disabled = (
		data.repair_spend <= 0 or data.resolving_card or data.effects_busy
	)
	nodes["MatchResult/Panel/RepairPlus"].disabled = (
		data.repair_spend >= repair_limit or data.resolving_card or data.effects_busy
	)
	var repair_amount: int = maxi(0, data.repair_spend)
	nodes["repair_preview"].visible = data.winner == "player"
	nodes["repair_preview"].show_repair(
		data.player.hull,
		data.player.hull_capacity,
		data.salvage,
		repair_amount,
		data.repair_unit_cost
	)
	nodes["MatchResult/Panel/RepairAmount"].text = "+%d Hull" % repair_amount
	nodes["MatchResult/Panel/Repair"].text = (
		"Confirm · %d Salvage" % Repairs.quantity_cost(repair_amount, data.repair_unit_cost)
	)
	if repair_limit == 0:
		nodes["MatchResult/Panel/Repair"].text = (
			"Hull full" if data.player.hull >= data.player.hull_capacity else "Need 2 Salvage"
		)
	nodes["allocation_button"].visible = data.winner.is_empty()
	if not data.winner.is_empty():
		nodes["allocation_popup"].dismiss()
	nodes["MatchResult"].visible = (
		not data.winner.is_empty() and not data.resolving_card and not data.effects_busy
	)
	nodes["MatchResult/Panel/Title"].text = (
		"EMP PULSE SUCCESS"
		if data.escaped_by_ftl
		else (
			"DRAW"
			if data.winner == "draw"
			else ("YOU WIN" if data.winner == "player" else "YOU LOSE")
		)
	)
	var visible_now: bool = nodes["MatchResult"].visible
	var heading: Label = nodes["MatchResult/Panel/Title"]
	heading.add_theme_color_override(
		"font_color",
		(
			visual_settings.victory_accent_color
			if data.winner == "player"
			else visual_settings.defeat_accent_color
		)
	)
	if visible_now and not result_visible:
		if data.result_cause == "systems_failure":
			Sound.play(&"systems_failure_defeat", nodes["MatchResult"])
		elif data.winner == "player" and not data.escaped_by_ftl:
			Sound.play(&"result_reveal", nodes["MatchResult"])
		Effects.reveal(
			heading,
			visual_settings,
			visual_settings.result_heading_duration,
			visual_settings.result_heading_start_scale
		)
		Effects.reveal(nodes["MatchResult/Panel"], visual_settings)
	elif not visible_now and result_visible:
		Effects.reset(heading)
		Effects.reset(nodes["MatchResult/Panel"])
	result_visible = visible_now
	var method: String = (
		"EMP Pulse"
		if data.escaped_by_ftl
		else (
			"Enemy ship destroyed"
			if data.enemy.hull <= 0 and data.winner == "player"
			else (
				"Systems Failure"
				if data.result_cause == "systems_failure"
				else ("Both ships destroyed" if data.winner == "draw" else "Defeat")
			)
		)
	)
	nodes["MatchResult/Panel/Details"].text = (
		"%s · Turn %d\n❤️ %d → %d · Damage taken: %d"
		% [
			method,
			data.turn_number,
			data.starting_player_hull,
			data.result_hull if data.result_recorded else data.player.hull,
			data.player_hull_damage_taken
		]
	)
	nodes["MatchResult/Panel/Rewards"].text = data.rewards_text
	nodes["MatchResult/Panel/Rewards"].visible = not (
		nodes["MatchResult/Panel/Rewards"].text.is_empty()
	)
	nodes["MatchResult/Panel/PlayAgain"].hide()
	nodes["MatchResult/Panel/Configure"].text = "Main Menu"
	nodes["MatchResult/Panel/Configure"].visible = data.winner != "player"
	var can_continue: bool = data.winner == "player" and data.player.hull > 0
	nodes["MatchResult/Panel/Continue"].visible = can_continue
	nodes["MatchResult/Panel/NextEncounter"].visible = can_continue and not data.in_expedition
	if can_continue and not data.in_expedition:
		nodes["MatchResult/Panel/NextEncounter"].text = (
			"Encounter %d · %s" % [data.encounter_number + 1, data.next_modifier_name]
		)
	if data.in_expedition:
		nodes["MatchResult/Panel/Continue"].text = (
			"Upgrade Cards" if data.pending_choice == "upgrade" else "Star System"
		)


func refresh_emp(data: Dictionary) -> void:
	var scope: Node = nodes["FTLPanel/WarpButton"]
	var ready_now: bool = data.emp.can_warp and data.winner.is_empty()
	if data.escaped_by_ftl and not _emp_fired:
		Sound.play(&"emp_fire", scope)
		_emp_fired = true
	elif ready_now and not _emp_ready:
		Sound.play(&"emp_ready", scope)
	elif _emp_charge >= 0 and data.emp.charge > _emp_charge and data.emp.disabled_turns == 0 and data.winner.is_empty():
		Sound.play(&"emp_charge", scope)
	_emp_charge = data.emp.charge
	_emp_ready = ready_now
	var ftl_status: String = "EMP Pulse %d / %d" % [data.emp.charge, data.emp.charge_target]
	if data.emp.disabled_turns > 0:
		ftl_status += " · Offline (%d turns)" % data.emp.disabled_turns
	elif data.emp.can_warp:
		ftl_status += " · Ready"
	nodes["FTLPanel/Charge"].text = ftl_status
	nodes["FTLPanel/Charge"].tooltip_text = ftl_status
	nodes["FTLPanel/Charge"].text = ftl_status.replace("EMP Pulse ", "EMP ").replace(
		" · Offline (", " · Off ("
	)
	nodes["FTLPanel/Progress"].max_value = data.emp.charge_target
	nodes["FTLPanel/Progress"].value = data.emp.charge
	var charged: bool = data.emp.charge >= data.emp.charge_target and data.winner.is_empty()
	nodes["FTLPanel/Charge"].visible = not charged
	nodes["FTLPanel/Progress"].visible = not charged
	nodes["FTLPanel/WarpButton"].visible = charged
	update_jump_style(data.emp.disabled_turns)
	nodes["FTLPanel/WarpButton"].disabled = (
		not data.emp.can_warp
		or data.current_actor != "player"
		or data.resolving_card
		or data.effects_busy
		or not data.winner.is_empty()
	)


func refresh_ships_and_cards(data: Dictionary) -> void:
	nodes["EnemyTurnBanner"].show_enemy_turn(
		data.current_actor == "enemy" and data.winner.is_empty(), card_slots
	)
	nodes["PlayerShip/ShieldPlaceholder"].visible = (
		data.player.shields > 0 and not data.shields_disabled
	)
	nodes["EnemyShip/ShieldPlaceholder"].visible = (
		data.enemy.shields > 0 and not data.shields_disabled
	)
	var player_can_act: bool = (
		data.winner.is_empty() and data.current_actor == "player" and not data.resolving_card
	)
	if data.winner.is_empty():
		nodes["TurnLabel"].text = (
			"Turn %d · %s"
			% [data.turn_number, "You" if data.current_actor == "player" else "Enemy"]
		)
	else:
		nodes["TurnLabel"].text = (
			"DRAW"
			if data.winner == "draw"
			else ("YOU WIN" if data.winner == "player" else "ENEMY WINS")
		)
	nodes["player_hull_label"].text = "Hull %d/%d" % [data.player.hull, data.player.hull_capacity]
	nodes["player_hull_label"].add_theme_color_override(
		"font_color",
		(
			nodes["PlayerHullBar"].plating_color
			if data.player.hull > data.player.hull_capacity
			else Color(0.82, 0.84, 0.87)
		)
	)
	nodes["PlayerHullBar"].update_hull(data.player.hull, data.player.hull_capacity)
	nodes["player_shields_label"].text = (
		"Shields OFF" if data.shields_disabled else "Shields %d" % data.player.shields
	)
	nodes["enemy_hull_label"].text = "Hull %d/%d" % [data.enemy.hull, data.enemy.hull_capacity]
	nodes["enemy_hull_label"].add_theme_color_override(
		"font_color",
		(
			nodes["EnemyHullBar"].plating_color
			if data.enemy.hull > data.enemy.hull_capacity
			else Color(0.82, 0.84, 0.87)
		)
	)
	nodes["EnemyHullBar"].update_hull(data.enemy.hull, data.enemy.hull_capacity)
	nodes["enemy_shields_label"].text = (
		"Shields OFF" if data.shields_disabled else "Shields %d" % data.enemy.shields
	)
	nodes["battle_effects"].set_number(nodes["player_materials_label"], data.player.materials)
	nodes["player_synthesizer_label"].text = str(data.player.synthesizer)

	nodes["battle_effects"].set_number(nodes["player_energy_label"], data.player.energy)
	nodes["player_reactor_label"].text = str(data.player.reactor)
	nodes["battle_effects"].set_number(nodes["player_crew_label"], data.player.crew)
	nodes["player_quarters_label"].text = str(data.player.quarters)
	nodes["battle_effects"].set_number(nodes["enemy_materials_label"], data.enemy.materials)
	nodes["enemy_synthesizer_label"].text = str(data.enemy.synthesizer)
	nodes["battle_effects"].set_number(nodes["enemy_energy_label"], data.enemy.energy)
	nodes["enemy_reactor_label"].text = str(data.enemy.reactor)
	nodes["battle_effects"].set_number(nodes["enemy_crew_label"], data.enemy.crew)
	nodes["enemy_quarters_label"].text = str(data.enemy.quarters)
	for slot in range(cards.size()):
		var button = cards[slot]
		var shown: Dictionary = data.cards[slot]
		button.card_data = shown.preview
		button.set_ion_glow(shown.ion_glow)
		button.set_playable(
			shown.present and player_can_act and shown.affordable, int(shown.affordable)
		)
		button.set_discardable(shown.present and player_can_act)


func fit_board_lines(
	board_size: Vector2, mode_rule_origin: Vector2, hand_rule_origin: Vector2
) -> void:
	nodes["ModeRule"].position = mode_rule_origin + Vector2(board_size.x - 1280.0, 0)
	nodes["HandRule"].position = hand_rule_origin + Vector2(0, board_size.y - 720.0)
	var points: PackedVector2Array = nodes["HandRule"].points
	points[points.size() - 1].x = board_size.x - 24.0
	nodes["HandRule"].points = points


func fit_combat_controls(board_size: Vector2) -> void:
	if is_instance_valid(tactical): tactical.dismiss(true)
	var gap: float = 10.0
	var card_scale: float = minf(1.0, (board_size.x - 32 - gap * 5) / (198 * 6))
	var hand_width: float = 198 * card_scale * 6 + gap * 5
	for index in range(cards.size()):
		var card: Control = cards[index]
		card.scale = Vector2.ONE * card_scale
		card.position = Vector2(
			(board_size.x - hand_width) / 2 + index * (198 * card_scale + gap),
			board_size.y - 12 - 294 * card_scale
		)
		card.discard_target_height = card.presentation_settings.discard_button_height / card_scale
		card.get_node("DiscardButton").add_theme_font_size_override(
			"font_size", roundi(card.presentation_settings.discard_button_font_size / card_scale)
		)
		if card.card_data != null:
			card.refresh_card()
	var hand_top: float = board_size.y - 12 - 294 * card_scale
	nodes["HandRule"].position.y = hand_top - 8 - 359
	nodes["LastActionLabel"].position = Vector2(16, hand_top - 32)
	nodes["LastActionLabel"].size.x = board_size.x - 160


static func fit_jump_button(button: Button, progress_width: float) -> void:
	button.size = Vector2(progress_width, 27)
	button.position = Vector2.ZERO


func update_jump_style(disabled_turns: int) -> void:
	var offline: bool = disabled_turns > 0
	var button: Button = nodes["FTLPanel/WarpButton"]
	button.text = "EMP offline" if offline else "EMP Pulse"
	button.tooltip_text = (
		"Offline: %d turns remaining." % disabled_turns if offline else "Escape by EMP Pulse."
	)
	if button.has_meta("offline_style") and button.get_meta("offline_style") == offline:
		return
	button.set_meta("offline_style", offline)
	ResultPresentation.action(button)
	button.add_theme_font_size_override("font_size", 13)
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var compact_box: StyleBox = button.get_theme_stylebox(key).duplicate()
		compact_box.content_margin_top = 2
		compact_box.content_margin_bottom = 2
		button.add_theme_stylebox_override(key, compact_box)
	if offline:
		for key in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = button.get_theme_stylebox(key).duplicate()
			box.bg_color = Color("702b35")
			box.border_color = Color("ef7e88")
			button.add_theme_stylebox_override(key, box)
		button.add_theme_color_override("font_disabled_color", Color("ffd3d7"))


static func bind_reference(control: Control, overlay: Node, section: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.tooltip_text += "\nTap for GAME REFERENCE"
	control.gui_input.connect(func(event):
		var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
		if pressed:
			control.accept_event()
			overlay.show_reference(section))
