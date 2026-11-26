extends RefCounted

const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
const HoloMotion = preload("res://scripts/ui/holographic/motion.gd")

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
var _shield_meters: Dictionary = {}
var _enemy_modifier: Label


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
	bind_reference(nodes["FTLPanel/Charge"], reference, "emp")
	for column in nodes["SystemsFailureDisplay"].columns.values():
		for label in column.get_children(): bind_reference(label, reference, "failure")

	player_panel = SidePanel.new(true)
	enemy_panel = SidePanel.new(false)
	for panel in [player_panel, enemy_panel]:
		board_view.add_child(panel)
	player_panel.handle.pressed.connect(_toggle_panel.bind(player_panel, enemy_panel))
	enemy_panel.handle.pressed.connect(_toggle_panel.bind(enemy_panel, player_panel))
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
	for side in ["player", "enemy"]:
		var prefix: String = side.capitalize()
		nodes[prefix + "HullBar"].animate_changes = true
		for kind in ["hull", "shields"]:
			var label: Label = nodes[side + "_" + kind + "_label"]
			var tint := Holo.family(kind)
			var style := Holo.frame("status", tint)
			style.cut = 5
			Holo.plate(label, style, Vector2(4, -2))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if kind == "shields":
				var bar := ProgressBar.new()
				bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bar.show_percentage = false
				bar.tooltip_text = "Shields relative to the highest value this battle"
				label.add_child(bar, false, Node.INTERNAL_MODE_FRONT)
				bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				bar.offset_bottom = -3.0
				bar.offset_top = -7.0
				bar.offset_left = 4.0
				bar.offset_right = -4.0
				Meter.attach(bar, tint)
				_shield_meters[side] = bar
		for i in range(3):
			var key: String = ["materials", "energy", "crew"][i]
			var widget: Control = board_view.get_node("%sResource%d" % [prefix, i + 1])
			var tint := Holo.family(key)
			var badge: ColorRect = widget.get_node("ProductionBadge")
			for item in ["Shape", "Outline", "BadgeOutline"]:
				widget.get_node(item).hide()
			badge.color = Color.TRANSPARENT
			Holo.plate(badge, Holo.frame("compact", tint))
			Holo.plate(widget.get_node(key), Holo.frame("status", tint), Vector2(1, 7))
			widget.get_node(key).add_theme_color_override("font_color", Holo.DEFAULT.text)
			var nameplate := Label.new()
			nameplate.text = ["MAT", "ENG", "CREW"][i]
			nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nameplate.add_theme_font_size_override("font_size", 9)
			nameplate.add_theme_color_override("font_color", tint)
			nameplate.position = Vector2(0, 6)
			nameplate.size.x = widget.get_node(key).size.x
			widget.add_child(nameplate)
			widget.get_node(["synthesizer", "reactor", "quarters"][i]).add_theme_color_override("font_color", tint)
	var turn: Label = nodes["TurnLabel"]
	Holo.plate(turn, Holo.frame("compact", Holo.DEFAULT.edge), Vector2(5, 1))
	for rule in ["ModeRule", "HandRule"]:
		nodes[rule].default_color = Color(Holo.DEFAULT.edge, 0.58)
	var charge: ProgressBar = nodes["FTLPanel/Progress"]
	Meter.attach(charge, Holo.DEFAULT.energy)

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
	player_panel.handle.disabled = locked
	enemy_panel.handle.disabled = locked


func fit_side_panels(view: Control) -> void:
	for side in ["Player", "Enemy"]:
		var panel: Control = player_panel if side == "Player" else enemy_panel
		panel.fit(
			view.get_node(side + "Resource1").get_rect(),
			view.get_node(side + "Resource3").get_rect(),
			cards[0].position.y,
			view.size.x
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
	nodes["allocation_button"].visible = data.winner.is_empty() or data.get("destruction_presenting",false)
	nodes["allocation_button"].disabled = not data.winner.is_empty()
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
	var charged: bool = data.emp.charge >= data.emp.charge_target and (data.winner.is_empty() or data.get("destruction_presenting",false))
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
	if data.get("emp_pending", false):
		nodes["TurnLabel"].text = "EMP PULSE"
	elif data.winner.is_empty():
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
	for side in _shield_meters:
		var meter: ProgressBar = _shield_meters[side]
		var shield: int = data[side].shields
		meter.max_value = maxf(meter.get_meta("peak", 1), shield)
		meter.set_meta("peak", meter.max_value)
		meter.value = 0 if data.shields_disabled else shield
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
			var box: Holo.Frame = button.get_theme_stylebox(key).duplicate()
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
