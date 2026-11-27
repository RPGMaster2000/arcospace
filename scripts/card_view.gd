@tool
extends Button

const HoloMotion = preload("res://scripts/ui/holographic/motion.gd")
const SignalAccent = preload("res://scripts/ui/battle_signal.gd")
const TITLE_PRICE_CLEARANCE := 120.0
const Holo = preload("res://scripts/ui/holographic/skin.gd")

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Display a card resource in the editor and at runtime.
# DOES NOT: Apply effects or draw cards.

signal discard_requested
const Motifs = preload("res://scripts/ui/card_motifs.gd")
const Summary = preload("res://scripts/ui/card_face_text.gd")
const ThemeStyle = preload("res://scripts/ui/card_theme.gd")
const ART_TOP := 68.0
const BODY_TOP := 131.0
const INK := Color("edf4fa")
const TIER_THREE_INK := Color("f4d58a")
var family_tint := Color.WHITE
# Optional title for a read-only enemy reveal; never stored on CardData.
var display_title := ""
var footer_visual_height := 28.0
var preview_selected := false
var affordable := true
var _affordability_ink := 1.0:
	set(value):
		_affordability_ink = value
		if not is_node_ready(): return
		for state in ["normal", "disabled", "hover", "pressed"]:
			var box := get_theme_stylebox(state) as Holo.Frame
			if box != null:
				ThemeStyle.shade_affordability(box, presentation_settings.card_base_color, family_tint, value,
					interaction_selected or preview_selected or interaction_hovered or state in ["hover", "pressed"])
var storm_active := false
var storm_color := Color(0.15, 0.55, 1.0)
var theme_stamp := ""
var _rarity_identity := ""
var _rarity_plate: Panel
var _sweep := 0.0:
	set(value):
		_sweep = value
		queue_redraw()
## TUNE: Shared normal-card text and read-only inspection settings.
@export var presentation_settings: Resource = preload("res://resources/card_presentation.tres")
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var interaction_tween: Tween
var interaction_hovered: bool = false
var interaction_selected: bool = false
var inspection_enabled: bool = true
var hold_input: Node
var discard_target_height: float = 44.0

@export var card_data: Resource:
	set(value):
		if card_data != null and card_data.changed.is_connected(refresh_card):
			card_data.changed.disconnect(refresh_card)
		if card_data != value and is_instance_valid(hold_input):
			hold_input.cancel()
		card_data = value
		if card_data != null:
			card_data.changed.connect(refresh_card)
		if is_node_ready():
			refresh_card()


func _ready() -> void:
	$DiscardButton.pressed.connect(_on_discard_pressed)
	# The whole hand fades on turn changes; avoid an instant disabled-text jump.
	$DiscardButton.add_theme_color_override(
		"font_disabled_color", $DiscardButton.get_theme_color("font_color")
	)
	refresh_card()
	if not Engine.is_editor_hint():
		mouse_entered.connect(func(): set_interaction_emphasis(true, false))
		mouse_exited.connect(func(): set_interaction_emphasis(false, false))
		focus_entered.connect(func(): set_interaction_emphasis(true, false))
		focus_exited.connect(func(): set_interaction_emphasis(false, false))
		button_down.connect(func(): set_interaction_emphasis(true, true))
		button_up.connect(func(): set_interaction_emphasis(is_hovered(), false))
	if not Engine.is_editor_hint() and inspection_enabled:
		hold_input = preload("res://scripts/ui/card_hold.gd").new()
		add_child(hold_input)
		hold_input.bind_card(self, self, presentation_settings, $DiscardButton)


func set_interaction_emphasis(hovered: bool, selected: bool) -> void:
	if Engine.is_editor_hint() or not is_node_ready() or not is_inside_tree():
		return
	if selected and not interaction_selected and card_data != null and not disabled:
		Sound.play(&"card_select", self)
	if selected and not interaction_selected and card_data != null and card_data.tier == 3:
		_play_rarity_sweep()
	interaction_hovered = hovered and card_data != null
	interaction_selected = selected and card_data != null
	if interaction_tween != null and interaction_tween.is_valid():
		interaction_tween.kill()
	var art: Control = $ArtPlaceholder
	art.pivot_offset = art.size * 0.5
	var zoom: float = (
		visual_settings.card_selected_scale
		if interaction_selected
		else (visual_settings.card_hover_scale if interaction_hovered else 1.0)
	)
	var elevation: float = visual_settings.card_hover_elevation if interaction_hovered else 0.0
	var duration := HoloMotion.duration(
		visual_settings.card_selected_duration if selected else visual_settings.card_hover_duration)
	if duration == 0.0:
		art.scale = Vector2.ONE
		art.position.y = ART_TOP
	else:
		interaction_tween = create_tween().set_parallel(true)
		interaction_tween.set_trans(Holo.DEFAULT.transition).set_ease(Holo.DEFAULT.easing)
		interaction_tween.tween_property(art, "scale", Vector2.ONE * zoom, duration)
		interaction_tween.tween_property(art, "position:y", ART_TOP - elevation, duration)
	apply_card_theme()


func _on_discard_pressed() -> void:
	if not Engine.is_editor_hint():
		discard_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or card_data == null:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		accept_event()
		discard_requested.emit()


# The first line clears the price. Condense an exceptional long opening word
# horizontally so the title can wrap on a word boundary at the same height.
func title_text(name: String) -> String:
	var title := name.trim_suffix("++").trim_suffix("+")
	var font: Font = $TitleLabel.get_theme_font("font")
	var font_size: int = presentation_settings.card_title_font_size
	var words := title.split(" ")
	var opening := font.get_string_size(words[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := minf(1.0, TITLE_PRICE_CLEARANCE / maxf(opening, 1.0))
	$TitleLabel.scale = Vector2(width, 1.0)
	var first := ""
	while not words.is_empty():
		var next: String = first + (" " if not first.is_empty() else "") + words[0]
		if not first.is_empty() and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * width > TITLE_PRICE_CLEARANCE:
			break
		first = next
		words.remove_at(0)
	return first + ("\n" + " ".join(words) if not words.is_empty() else "")


func refresh_card() -> void:
	queue_redraw()
	set_process(false)  # No continuous rarity animation across the whole hand.
	$TitleLabel.add_theme_font_size_override(
		"font_size", presentation_settings.card_title_font_size
	)
	$DescriptionLabel.add_theme_font_size_override(
		"font_size", presentation_settings.compact_description_font_size
	)
	$DiscardButton.add_theme_font_size_override(
		"font_size", presentation_settings.discard_button_font_size
	)
	$DiscardButton.offset_top = 294.0 - discard_target_height
	$DiscardButton.offset_bottom = 294.0
	$DiscardButton.custom_minimum_size.y = discard_target_height
	# Recover text space by compressing the illustration before the touch
	# footer grows. Keep body typography and the full discard hit target.
	var art_reduction := clampf(discard_target_height - 45.0, 0.0, 35.0)
	$DescriptionLabel.offset_top = BODY_TOP - art_reduction
	$DescriptionLabel.offset_bottom = $DiscardButton.offset_top - Holo.DEFAULT.compact_padding
	$DescriptionLabel.clip_text = false
	$DescriptionLabel.max_lines_visible = -1
	$DescriptionLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	$TitleLabel.clip_text = false
	$TitleLabel.max_lines_visible = 2
	$TitleLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for art in [$ArtPlaceholder, $FullCardArt]:
		art.position = Vector2(12, ART_TOP)
		art.size = Vector2(174, 56 - art_reduction)
	fit_placeholder_art()
	$TierLabel.position.y = ART_TOP + 56 - art_reduction - 19.0
	if card_data == null:
		_rarity_identity = ""
		if is_instance_valid(_rarity_plate): _rarity_plate.hide()
		if not Engine.is_editor_hint(): HoloMotion.stop(self, &"rarity")
		_sweep = 0.0
		$TitleLabel.text = "Empty slot"
		$TierLabel.text = ""
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		$FullCardArt.hide()
		$ArtPlaceholder/EffectMotif.hide()
		$ArtPlaceholder/Ship.show()
		$ArtPlaceholder/Accent.show()
		tooltip_text = ""
		$DiscardButton.disabled = true
		$DiscardButton.text = "Discard"
		return
	$TitleLabel.text = title_text(display_title if not display_title.is_empty() else card_data.card_name)
	$TierLabel.text = (
		("T%d " % card_data.tier if card_data.tier > 1 else "")
		+ "+".repeat(card_data.upgrade_level)
	)
	var rarity_id := "%s/%d" % [card_data.identity_key(), card_data.upgrade_level]
	if rarity_id != _rarity_identity:
		_rarity_identity = rarity_id
		if not Engine.is_editor_hint(): HoloMotion.stop(self, &"rarity")
		_sweep = 0.0
		if card_data.tier == 3: _play_rarity_sweep()
	var rarity_tint := TIER_THREE_INK if card_data.tier == 3 else Holo.DEFAULT.rarity_two
	$TierLabel.add_theme_color_override("font_color", rarity_tint)
	if card_data.tier > 1:
		if not is_instance_valid(_rarity_plate) or _rarity_plate.get_meta("tier", 0) != card_data.tier:
			var badge := Holo.frame("status", rarity_tint)
			badge.details = 0
			badge.cut = 3.0
			if not is_instance_valid(_rarity_plate):
				_rarity_plate = Holo.plate($TierLabel, badge, Vector2(3, -2))
			else:
				_rarity_plate.add_theme_stylebox_override("panel", badge)
			_rarity_plate.set_meta("tier", card_data.tier)
		_rarity_plate.show()
	elif is_instance_valid(_rarity_plate):
		_rarity_plate.hide()
	$CostLabel.text = str(card_data.cost)
	$DescriptionLabel.text = Summary.card_text(card_data)
	var artwork: Variant = (
		card_data.get_meta("card_art") if card_data.has_meta("card_art") else null
	)
	$FullCardArt.texture = artwork if artwork is Texture2D else null
	$FullCardArt.visible = $FullCardArt.texture != null
	$ArtPlaceholder.visible = not $FullCardArt.visible
	family_tint = presentation_settings.family_color(card_data.family)
	var motif: Texture2D = Motifs.texture_for(card_data)
	$ArtPlaceholder/EffectMotif.texture = motif
	$ArtPlaceholder/EffectMotif.visible = motif != null and not $FullCardArt.visible
	$ArtPlaceholder/EffectMotif.modulate = family_tint
	$ArtPlaceholder/Ship.visible = motif == null
	$ArtPlaceholder/Accent.visible = motif == null
	for icon in $ResourceIcon.get_children():
		icon.visible = icon.name.to_lower() == card_data.family
		icon.color = family_tint
	$ThemeWash.texture = ThemeStyle.wash(family_tint)
	$ArtPlaceholder/Backdrop.color = Color("060d15").lerp(family_tint, 0.045)
	$ArtPlaceholder/Accent.default_color = Color(family_tint, 0.6)
	$CostRule.default_color = Color(family_tint, 0.9)
	$CostLabel.add_theme_color_override("font_color", family_tint if affordable else Holo.DEFAULT.warning)
	for node in [$TitleLabel, $DescriptionLabel]:
		node.add_theme_color_override("font_color", INK)
	apply_card_theme()
	$DiscardButton.text = (
		"Discard +%d %s" % [floori(card_data.cost / 3.0), card_data.family.capitalize()]
	)
	$DiscardButton.tooltip_text = (
		"Discard · Recover %d %s" % [floori(card_data.cost / 3.0), card_data.family.capitalize()]
	)
	var footer: StyleBoxFlat = $DiscardButton.get_theme_stylebox("normal").duplicate()
	footer_visual_height = maxf(
		28,
		(
			$DiscardButton.get_theme_font("font").get_height(
				presentation_settings.discard_button_font_size
			)
			+ 6
		)
	)
	footer.bg_color = Color.TRANSPARENT
	footer.set_border_width_all(0)
	footer.expand_margin_bottom = -3  # Paint inside the frame; retain the full input rect.
	footer.content_margin_top = maxf(0, discard_target_height - footer_visual_height)
	footer.content_margin_bottom = Holo.DEFAULT.related_gap
	$DiscardButton.add_theme_stylebox_override("normal", footer)
	$DiscardButton.add_theme_stylebox_override("disabled", footer)
	var highlighted: StyleBoxFlat = footer.duplicate()
	highlighted.bg_color = Color(0.12, 0.20, 0.26, 0.5)
	$DiscardButton.add_theme_stylebox_override("hover", highlighted)
	$DiscardButton.add_theme_stylebox_override("pressed", highlighted)
	var footer_focus: StyleBoxFlat = footer.duplicate()
	footer_focus.border_color = Color(family_tint, 0.6)
	footer_focus.set_border_width_all(1)
	$DiscardButton.add_theme_stylebox_override("focus", footer_focus)
	$DiscardButton.add_theme_color_override("font_color", family_tint)
	$DiscardButton.add_theme_color_override("font_disabled_color", family_tint.darkened(0.25))
	tooltip_text = (
		(display_title if not display_title.is_empty() else card_data.card_name)
		+ "\n"
		+ preload("res://scripts/cards/card_data.gd").describe_effects(card_data.effects)
	)
	tooltip_text += "\nHold / I / middle-click: inspect · Right-click: discard"


func set_playable(playable: bool, can_afford: int = -1, feedback: bool = false) -> void:
	disabled = not playable
	var previous := affordable
	affordable = bool(int(playable) if can_afford < 0 else can_afford)
	# Dim the surface and ink moderately; preserve readable rules and discard.
	self_modulate = Color.WHITE
	for path in ["TitleLabel", "TierLabel", "DescriptionLabel"]:
		get_node(path).modulate = Color.WHITE if affordable else Color(0.87, 0.89, 0.93)
	for path in ["CostLabel", "ResourceIcon", "CostRule"]:
		get_node(path).modulate = Color.WHITE if affordable else Color(0.71, 0.72, 0.74)
	$CostLabel.add_theme_color_override("font_color", family_tint if affordable else Holo.DEFAULT.warning)
	var seconds := HoloMotion.duration(Holo.DEFAULT.selection_seconds)
	var wash := Color.WHITE if affordable else Color(1, 1, 1, 0.35)
	var art := Color.WHITE if affordable else Color(0.42, 0.42, 0.42)
	if feedback and previous != affordable and seconds > 0.0:
		var tween := HoloMotion.start(self, &"affordability").set_parallel()
		tween.tween_property(self, "_affordability_ink", float(affordable), seconds)
		tween.tween_property($ThemeWash, "modulate", wash, seconds)
		for surface in [$ArtPlaceholder, $FullCardArt]:
			tween.tween_property(surface, "modulate", art, seconds)
		if affordable:
			SignalAccent.sweep($CostLabel, family_tint, 0.24)
	elif not feedback or not has_meta(&"holo_affordability"):
		HoloMotion.stop(self, &"affordability")
		$ThemeWash.modulate = wash
		$ArtPlaceholder.modulate = art
		$FullCardArt.modulate = art
		_affordability_ink = float(affordable)
	apply_card_theme()


func pulse_draw() -> void:
	if card_data == null: return
	var ink: Color = Holo.DEFAULT.rarity_three if card_data.tier == 3 else (
		Holo.DEFAULT.rarity_two if card_data.tier == 2 else family_tint)
	SignalAccent.sweep(self, ink,
		HoloMotion.duration(0.23, card_data.tier > 1))
	if card_data.tier == 3: _play_rarity_sweep()


func fit_placeholder_art() -> void:
	# Retain main's original primitive placeholder on its 174×74 design surface.
	$ArtPlaceholder.clip_contents = true
	for child in $ArtPlaceholder.get_children():
		if child == $ArtPlaceholder/EffectMotif:
			continue
		child.scale = Vector2($ArtPlaceholder.size.x / 174.0, $ArtPlaceholder.size.y / 74.0)


func set_preview_selected(active: bool) -> void:
	# The existing tactical preview owns raising, z-order and restoration.
	preview_selected = active
	if not active:
		set_interaction_emphasis(is_hovered(), false)
	apply_card_theme()


func apply_card_theme() -> void:
	if not is_node_ready():
		return
	var selected := interaction_selected or preview_selected
	var stamp := str(
		[
			family_tint,
			presentation_settings.card_base_color,
			selected,
			interaction_hovered,
			affordable,
			storm_active,
			storm_color,
			card_data.tier if card_data != null else 1
		]
	)
	if stamp == theme_stamp:
		return
	theme_stamp = stamp
	for state in ["normal", "disabled", "hover", "pressed"]:
		var box := ThemeStyle.box(
			presentation_settings.card_base_color,
			family_tint,
			selected or state == "pressed",
			interaction_hovered or state == "hover",
			affordable,
			storm_active,
			storm_color,
			card_data.tier if card_data != null else 1
		)
		ThemeStyle.shade_affordability(box, presentation_settings.card_base_color, family_tint, _affordability_ink,
			selected or interaction_hovered or state in ["hover", "pressed"])
		add_theme_stylebox_override(state, box)
	# Keep native keyboard focus visible without a second, unrelated blue border.
	var focus := Holo.frame("focus", family_tint)
	focus.cut = 8.0
	focus.set_content_margin_all(0)
	add_theme_stylebox_override("focus", focus)
	queue_redraw()


func set_discardable(allowed: bool) -> void:
	$DiscardButton.disabled = not allowed


func set_ion_glow(active: bool, tint: Color = Color(0.15, 0.55, 1.0)) -> void:
	# Preserve the existing storm cue; active selection keeps its family-colored glow.
	storm_active = active
	storm_color = tint
	apply_card_theme()


func _play_rarity_sweep() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or not is_visible_in_tree(): return
	var seconds := HoloMotion.duration(Holo.DEFAULT.meter_seconds, true)
	if seconds <= 0.0: return
	_sweep = 0.001
	HoloMotion.start(self, &"rarity").tween_property(self, "_sweep", 1.0, seconds)


func _draw() -> void:
	if _sweep > 0.0 and _sweep < 1.0 and card_data != null and card_data.tier == 3:
		var point := lerpf(14, 143, _sweep)
		draw_line(Vector2(point, 4), Vector2(point + 34, 4),
			Color(TIER_THREE_INK, sin(_sweep * PI) * (0.8 if affordable else 0.42)), 2.0, true)
	# Slim visible footer; the existing full-width Button retains its larger hitbox.
	draw_rect(Rect2(7, 294 - footer_visual_height, 184, footer_visual_height - 3), Color("0b121c"))
	draw_line(
		Vector2(12, 294 - footer_visual_height),
		Vector2(186, 294 - footer_visual_height),
		Color(family_tint, 0.25),
		1.0
	)
