extends RefCounted

const ShieldStack = preload("res://scripts/ui/holographic/shield_stack.gd")

const Holo = preload("res://scripts/ui/holographic/skin.gd")

const Sound = preload("res://scripts/audio/sfx.gd")
# RESPONSIBILITY: Render combat HUD/results and fit generic 2D controls.
# DOES NOT: Advance turns, record rewards, choose encounters or modify combat state.
# EXTEND: Add display facts to Board._display_snapshot(), then update the relevant refresh method.
const ResultPresentation = preload("res://scripts/ui/encounter_presentation.gd")
const Effects = preload("res://scripts/visual/visual_effects.gd")
const SidePanel = preload("res://scripts/ui/battle_side_panel.gd")
const ModifierPanel = preload("res://scripts/ui/battle_modifier_panel.gd")
const EnemyCardFlavor = preload("res://scripts/ui/enemy_card_flavor.gd")
var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var result_visible: bool = false
var _emp_charge: int = -1
var _emp_ready: bool = false
var _emp_fired: bool = false
var nodes: Dictionary = {}
var cards: Array[Control] = []
var card_slots: Array[NodePath] = []
var tactical: Control
var player_panel: Control
var enemy_panel: Control
var _boons: Label
var _modifier: Label
var _system: Label
var _identity: Label
var _abilities: Label
var _beam: Label
const Header = preload("res://scripts/ui/battle_header.gd")
const RESERVES := ["materials", "energy", "crew"]
const PRODUCTION := ["synthesizer", "reactor", "quarters"]
const PRODUCTION_TAGS := ["SYN", "REACT", "QTR"]
var header: Header
var _player_profile: Label
var _shield_stacks: Dictionary = {}
var _hull_frames: Dictionary = {}
var _enemy_modifier: Label


func _init(board_view: Control) -> void:
	# Bind existing scene controls once. Do not retain the gameplay controller.
	for path in [
		"EnemyHullBar",
		"EnemyShip/ShieldPlaceholder",
		"EnemyTurnBanner",
		"FTLPanel",
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
		"MatchResult/Panel/Rewards",
		"MatchResult/Panel/Title",
		"ModeLabel",
		"ModeLabel/Subtitle",
		"ModeRule",
		"PlayerHullBar",
		"PlayerShip/ShieldPlaceholder",
		"TurnLabel",
		"SystemsFailureDisplay"
	]:
		nodes[path] = board_view.get_node(path)
	for field in [
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
	_style_telemetry(board_view)
	card_slots.assign(board_view.card_slots)
	for path in card_slots:
		cards.append(board_view.get_node(path))
	tactical = preload("res://scripts/ui/tactical_preview.gd").new()
	tactical.name = "TacticalPreview"
	board_view.add_child(tactical)
	for side in ["player", "enemy"]:
		for attribute in preload("res://scripts/cards/card_targets.gd").ATTRIBUTES:
			tactical.indicators[side + "_" + attribute] = nodes[side + "_" + attribute + "_label"]
	tactical.extra_targets = {
		"player_hull": [nodes["PlayerHullBar"]], "enemy_hull": [nodes["EnemyHullBar"]],
		"player_shields": [nodes["PlayerShip/ShieldPlaceholder"]],
		"enemy_shields": [nodes["EnemyShip/ShieldPlaceholder"]]
	}
	tactical.bind(cards, [board_view.settings_button.popup, board_view.settings_button.menu.shade, board_view.settings_button.information.shade, nodes["allocation_popup"].shade])
	var reference: Node = board_view.settings_button.information
	for side in ["player", "enemy"]:
		for attribute in preload("res://scripts/cards/card_targets.gd").ATTRIBUTES:
			if attribute in ["hull", "shields"]:
				bind_reference(nodes[side + "_" + attribute + "_label"], reference, "defenses")
	bind_reference(nodes["FTLPanel"], reference, "emp")
	for column in nodes["SystemsFailureDisplay"].columns.values():
		for label in column.get_children(): bind_reference(label, reference, "failure")

	player_panel = SidePanel.new(true)
	enemy_panel = SidePanel.new(false)
	for panel in [player_panel, enemy_panel]:
		board_view.add_child(panel)
	player_panel.handle.pressed.connect(_toggle_panel.bind(player_panel, enemy_panel))
	enemy_panel.handle.pressed.connect(_toggle_panel.bind(enemy_panel, player_panel))
	header = Header.new(board_view, _toggle_panel.bind(player_panel, enemy_panel))
	_player_profile = player_panel.add_section("SHIP PROFILE")
	var player_ship: Resource = board_view.player_ship_data
	if player_ship != null:
		_player_profile.text = player_ship.summary
		if player_ship.signature_card != null:
			var signature: Resource = player_ship.signature_card
			_player_profile.text = "%s · %s\n%s" % [signature.card_name, signature.description, player_ship.summary]
	_player_profile.get_parent().visible = not _player_profile.text.is_empty()
	_boons = player_panel.add_section("ACTIVE BOONS")
	_system = player_panel.add_section("STAR SYSTEM")
	_modifier = player_panel.add_section("BATTLE MODIFIER")
	_identity = enemy_panel.add_section("COMBAT PROFILE")
	_abilities = enemy_panel.add_section("SPECIAL ABILITIES")
	_beam = enemy_panel.add_section("CHARGED BEAM")
	_enemy_modifier = enemy_panel.add_section("ENVIRONMENT")
	_abilities.get_parent().hide()
	describe_enemy(board_view.enemy_ship_data)



func _style_telemetry(board_view: Control) -> void:
	var skin := Holo.DEFAULT
	for side in ["player", "enemy"]:
		var prefix: String = side.capitalize()
		nodes[prefix + "HullBar"].animate_changes = true
		for kind in ["hull", "shields"]:
			var label: Label = nodes[side + "_" + kind + "_label"]
			var tint := Holo.family(kind)
			var style := Holo.frame("status", tint)
			Holo.plate(label, style)
			if kind == "hull": _hull_frames[side] = style
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			var ink_margins := StyleBoxEmpty.new()
			ink_margins.content_margin_top = skin.related_gap
			label.add_theme_stylebox_override("normal", ink_margins)
			if kind == "shields":
				var stack := ShieldStack.new(label)
				label.add_child(stack, false, Node.INTERNAL_MODE_FRONT)
				stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				stack.offset_bottom = 1 - skin.compact_padding
				stack.offset_top = stack.offset_bottom - 12
				stack.offset_left = skin.compact_padding
				stack.offset_right = -skin.compact_padding
				_shield_stacks[side] = stack
		for i in range(RESERVES.size()):
			var key: String = RESERVES[i]
			var widget: Control = board_view.get_node("%sResource%d" % [prefix, i + 1])
			var tint := Holo.family(key)
			for item in ["Shape", "Outline", "BadgeOutline"]:
				widget.get_node(item).hide()
			var badge: ColorRect = widget.get_node("ProductionBadge")
			badge.color = Color.TRANSPARENT
			var background := Holo.family_surface(key)
			var panel := Holo.frame("status." + key, tint)
			panel.bg_color = background
			panel.depth_color = background.darkened(0.27)
			Holo.plate(widget, panel)
			var production := Holo.frame("status." + PRODUCTION[i], tint)
			production.bg_color = background.lightened(0.06)
			production.depth_color = background
			production.border_color = Color(tint, 0.38)
			production.details = 0
			production.cut = 3
			production.set_content_margin_all(0)
			Holo.plate(badge, production)
			widget.get_node(PRODUCTION[i]).add_theme_font_size_override("font_size", 11)
			widget.get_node(key).add_theme_font_size_override("font_size", 22)
			widget.get_node(key).add_theme_color_override("font_color", skin.text)
			var family := Label.new()
			family.name = "FamilyLabel"
			family.text = key.to_upper()
			family.mouse_filter = Control.MOUSE_FILTER_IGNORE
			family.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			family.add_theme_font_size_override("font_size", 11)
			family.add_theme_color_override("font_color", tint)
			widget.add_child(family)
	nodes["ModeRule"].hide()
	nodes["HandRule"].default_color = Color(skin.edge, 0.58)


func add_overdrive(button: MenuButton) -> void:
	player_panel.content.add_child(button)
	player_panel.content.move_child(button, 0)
	player_panel.closing.connect(button.get_popup().hide)


func _toggle_panel(panel: Control, other: Control) -> void:
	tactical.dismiss(true)
	other.set_open(false, true)
	panel.set_open(not panel.open)


func close_panels(immediate: bool = false) -> void:
	player_panel.set_open(false, immediate)
	enemy_panel.set_open(false, immediate)


func set_panels_locked(locked: bool, immediate: bool = false) -> void:
	if locked:
		close_panels(immediate)
	header.player_info.disabled = locked
	player_panel.handle.disabled = locked
	enemy_panel.handle.disabled = locked


func fit_side_panels(view: Control) -> void:
	for side in ["Player", "Enemy"]:
		var panel: Control = player_panel if side == "Player" else enemy_panel
		panel.fit(
			view.get_node(side + "Resource1").get_rect(),
			view.get_node(side + "Resource3").get_rect(),
			cards[0].position.y,
			view.size.x,
			nodes["FTLPanel"].get_rect() if side == "Player" else Rect2()
		)


func describe_enemy(profile: Resource) -> void:
	if profile == null:
		_identity.text = "Unknown vessel"
		return
	_identity.text = "\n".join(PackedStringArray([profile.ship_name, profile.subtitle, profile.summary])).strip_edges()
	var traits := PackedStringArray()
	if profile.signature_card != null:
		var card: Resource = profile.signature_card
		traits.append("%s · %s" % [EnemyCardFlavor.title(card, profile), card.description])
	for card in profile.starting_cards:
		if card != profile.signature_card and card.resource_path.begins_with("res://cards/enemy/"):
			traits.append("%s · %s" % [EnemyCardFlavor.title(card, profile), card.description])
	_abilities.text = "\n".join(traits)
	_abilities.get_parent().visible = not traits.is_empty()


func refresh_panels(data: Dictionary) -> void:
	var immediate: bool = data.presentation_locked or not data.winner.is_empty()
	set_panels_locked(immediate or data.resolving_card or data.effects_busy, immediate)
	var boons: PackedStringArray = data.active_boons
	_boons.text = "No active boons" if boons.is_empty() else "\n".join(boons)
	_modifier.text = data.modifier
	_modifier.get_parent().get_child(0).modulate = data.modifier_tint
	_system.text = data.system_overview
	_beam.text = data.enemy_beam
	_beam.get_parent().visible = not _beam.text.is_empty()
	_enemy_modifier.text = data.enemy_modifier
	_enemy_modifier.get_parent().visible = not _enemy_modifier.text.is_empty()


static func modifier_status(modifier: Node, round_number: int) -> String:
	var status := ModifierPanel.compact_status(modifier, round_number)
	var separator := status.find(" · ")
	return status if separator == -1 else status.substr(separator + 3)


func refresh(data: Dictionary) -> void:
	refresh_panels(data)
	tactical.update_context(data)
	nodes["SystemsFailureDisplay"].refresh(data.systems_failure)
	refresh_results(data)
	refresh_emp(data)
	refresh_ships_and_cards(data)


func refresh_results(data: Dictionary) -> void:
	header.update(data)
	nodes["MatchResult/Panel/BattlesWon"].visible = data.winner in ["enemy", "draw"]
	nodes["MatchResult/Panel/BattlesWon"].text = "%d BATTLES WON" % data.battles_won
	nodes["MatchResult/Panel/Rewards"].visible = data.winner == "player"
	nodes["allocation_button"].visible = data.winner.is_empty() or data.get("destruction_presenting",false)
	nodes["allocation_button"].disabled = not data.winner.is_empty()
	if nodes["allocation_button"].disabled: nodes["allocation_popup"].dismiss()
	if not data.winner.is_empty():
		nodes["allocation_popup"].dismiss()
	nodes["MatchResult"].visible = (
		not data.winner.is_empty() and data.result_recorded and not data.resolving_card and (not data.effects_busy or nodes["MatchResult"].started)
	)
	nodes["MatchResult/Panel/Title"].text = (
		"SYSTEM SECURED" if data.system_secured else ("MOTHERSHIP DESTROYED" if data.get("mothership_destroyed", false) else "VESSEL DISABLED")
		if data.escaped_by_ftl
		else (
			"DRAW"
			if data.winner == "draw"
			else (("SYSTEM SECURED" if data.system_secured else ("MOTHERSHIP DESTROYED" if data.get("mothership_destroyed", false) else "VICTORY")) if data.winner == "player" else "DEFEAT")
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
		nodes["MatchResult"].play.call_deferred()
	elif not visible_now and result_visible:
		Effects.reset(heading)
		Effects.reset(nodes["MatchResult/Panel"])
	result_visible = visible_now
	var method: String = (
		"EMP Pulse"
		if data.escaped_by_ftl
		else (
			"Enemy ship destroyed"
			if data.enemy.hull <= 0 and data.winner == "player" and data.result_cause != "systems_failure"
			else (
				"Systems Failure"
				if data.result_cause == "systems_failure"
				else ("Both ships destroyed" if data.winner == "draw" else "Defeat")
			)
		)
	)
	if data.system_secured:
		method = "Mothership neutralized" if data.defense_recovery else "Mothership neutralized · " + method
	elif data.defense_recovery:
		method = "Enemy disabled"
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
			"Upgrade Cards" if data.pending_choice == "upgrade" and data.upgrades_available > 0 else ("Choose Reward" if data.pending_choice == "battle_reward" else "Star System")
		)

	nodes["MatchResult"].set_summary(data)


func refresh_emp(data: Dictionary) -> void:
	var scope: Node = nodes["FTLPanel/WarpButton"]
	var ready_now: bool = data.emp.can_warp and data.winner.is_empty()
	if data.escaped_by_ftl and not _emp_fired:
		if not data.get("emp_cinematic", false): Sound.play(&"emp_fire", scope)
		_emp_fired = true
	elif ready_now and not _emp_ready:
		Sound.play(&"emp_ready", scope)
	elif _emp_charge >= 0 and data.emp.charge > _emp_charge and data.emp.disabled_turns == 0 and data.winner.is_empty():
		Sound.play(&"emp_charge", scope)
	_emp_charge = data.emp.charge
	_emp_ready = ready_now
	nodes["FTLPanel"].present(data)

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
	for side in ["player", "enemy"]:
		var ship: Dictionary = data[side]
		var hull_bar: Control = nodes[side.capitalize() + "HullBar"]
		var hull_label: Label = nodes[side + "_hull_label"]
		hull_label.text = "Hull %d/%d" % [ship.hull, ship.hull_capacity]
		hull_bar.update_hull(ship.hull, ship.hull_capacity)
		var hull_tint: Color = hull_bar.plating_color if ship.hull > ship.hull_capacity else hull_bar.condition_color()
		hull_label.add_theme_color_override("font_color", hull_tint)
		var hull_frame: Holo.Frame = _hull_frames[side]
		var border := Color(hull_tint, hull_frame.border_color.a)
		if hull_frame.border_color != border: hull_frame.border_color = border
		_shield_stacks[side].update_shields(ship.shields, data.shields_disabled)
		for i in RESERVES.size():
			var reserve: String = RESERVES[i]
			var production: String = PRODUCTION[i]
			nodes["battle_effects"].set_number(nodes[side + "_" + reserve + "_label"], ship[reserve])
			var label: Label = nodes[side + "_" + production + "_label"]
			label.text = "%s %+d" % [PRODUCTION_TAGS[i], ship[production]]
			label.tooltip_text = "%s %+d per turn" % [production.capitalize(), ship[production]]
			label.accessibility_name = label.tooltip_text
	for slot in range(cards.size()):
		var button = cards[slot]
		var shown: Dictionary = data.cards[slot]
		button.card_data = shown.preview
		button.set_ion_glow(shown.ion_glow, shown.get("storm_color",Color(0.15,0.55,1.0)))
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


func fit_combat_controls(bounds: Rect2) -> void:
	if is_instance_valid(tactical): tactical.dismiss(true)
	var gap: float = 10.0
	var card_scale: float = minf(1.0, (bounds.size.x - 32 - gap * 5) / (198 * 6))
	var hand_width: float = 198 * card_scale * 6 + gap * 5
	for index in range(cards.size()):
		var card: Control = cards[index]
		card.scale = Vector2.ONE * card_scale
		card.position = Vector2(
			bounds.get_center().x - hand_width / 2 + index * (198 * card_scale + gap),
			bounds.end.y - 12 - 294 * card_scale
		)
		card.discard_target_height = card.presentation_settings.discard_button_height / card_scale
		card.get_node("DiscardButton").add_theme_font_size_override(
			"font_size", roundi(card.presentation_settings.discard_button_font_size / card_scale)
		)
		if card.card_data != null:
			card.refresh_card()
	var hand_top: float = bounds.end.y - 12 - 294 * card_scale
	nodes["HandRule"].position.y = hand_top - 8 - 359
	nodes["LastActionLabel"].position = Vector2(bounds.position.x + 16, hand_top - 32)
	nodes["LastActionLabel"].size.x = bounds.size.x - 160


static func bind_reference(control: Control, overlay: Node, section: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.tooltip_text += "\nTap for GAME REFERENCE"
	control.gui_input.connect(func(event):
		var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
		if pressed:
			control.accept_event()
			overlay.show_reference(section))
