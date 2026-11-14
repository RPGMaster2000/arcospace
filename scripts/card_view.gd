@tool
extends Button

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Display a card resource in the editor and at runtime.
# DOES NOT: Apply effects or draw cards.

signal discard_requested
const Summary = preload("res://scripts/ui/card_face_text.gd")
const Icons = preload("res://scripts/ui/card_effect_rows.gd")
const ART_TOP := 68.0
const BODY_TOP := 112.0
const INK := Color("edf4fa")
var family_tint := Color.WHITE
var footer_visual_height := 28.0
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
	if Engine.is_editor_hint() or not is_node_ready():
		return
	if selected and not interaction_selected and card_data != null and not disabled:
		Sound.play(&"card_select", self)
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
	interaction_tween = create_tween().set_parallel(true)
	interaction_tween.set_trans(visual_settings.interaction_transition).set_ease(
		visual_settings.interaction_ease
	)
	var duration: float = (
		visual_settings.card_selected_duration if selected else visual_settings.card_hover_duration
	)
	interaction_tween.tween_property(art, "scale", Vector2.ONE * zoom, duration)
	interaction_tween.tween_property(art, "position:y", ART_TOP - elevation, duration)
	queue_redraw()


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


# Two-line shaped header: the first line reserves the cost corner; the second
# uses the full width BELOW the cost. Every title keeps the same 18px type.
func title_text(name: String) -> String:
	var title := name.trim_suffix("++").trim_suffix("+")
	var font: Font = $TitleLabel.get_theme_font("font")
	var first := ""
	var words := title.split(" ")
	while not words.is_empty():
		var candidate: String = first + (" " if not first.is_empty() else "") + words[0]
		if (
			(
				(
					font
					. get_string_size(
						candidate,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						presentation_settings.card_title_font_size
					)
					. x
				)
				> 126
			)
			and not first.is_empty()
		):
			break
		first = candidate
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
	$DescriptionLabel.offset_top = BODY_TOP
	$DescriptionLabel.offset_bottom = $DiscardButton.offset_top - 6
	$DescriptionLabel.clip_text = false
	$DescriptionLabel.max_lines_visible = -1
	$DescriptionLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	$TitleLabel.clip_text = false
	$TitleLabel.max_lines_visible = 2
	$TitleLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for art in [$ArtPlaceholder, $FullCardArt]:
		art.position = Vector2(12, ART_TOP)
		art.size = Vector2(174, 36)
	fit_placeholder_art()
	if card_data == null:
		$TitleLabel.text = "Empty slot"
		$TierLabel.text = ""
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		$FullCardArt.hide()
		tooltip_text = ""
		$DiscardButton.disabled = true
		$DiscardButton.text = "↻"
		return
	$TitleLabel.text = title_text(card_data.card_name)
	$TierLabel.text = (
		("T%d " % card_data.tier if card_data.tier > 1 else "")
		+ "+".repeat(card_data.upgrade_level)
	)
	$CostLabel.text = str(card_data.cost)
	$DescriptionLabel.text = Summary.card_text(card_data)
	var artwork: Variant = (
		card_data.get_meta("card_art") if card_data.has_meta("card_art") else null
	)
	$FullCardArt.texture = artwork if artwork is Texture2D else null
	$FullCardArt.visible = $FullCardArt.texture != null
	$ArtPlaceholder.visible = not $FullCardArt.visible
	family_tint = (
		{"materials": Color("f39489"), "energy": Color("80cfe9"), "crew": Color("a0d9ac")}
		. get(card_data.family, Color.WHITE)
	)
	for icon in $ResourceIcon.get_children():
		icon.visible = icon.name.to_lower() == card_data.family
		icon.color = family_tint
	var normal: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
	normal.bg_color = Color("101b27")
	normal.border_color = family_tint.darkened(0.40)
	normal.set_border_width_all(1)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("152330")
	hover.border_color = family_tint
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	$CostRule.default_color = Color(family_tint, 0.28)
	$ArtPlaceholder/Accent.default_color = Color(family_tint, 0.6)
	for node in [$TitleLabel, $CostLabel, $DescriptionLabel]:
		node.add_theme_color_override("font_color", INK)
	$DiscardButton.text = (
		"↻ +%d %s" % [floori(card_data.cost / 3.0), Icons.resource_icon(card_data.family)]
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
	footer.content_margin_top = maxf(0, discard_target_height - footer_visual_height)
	footer.content_margin_bottom = 0
	$DiscardButton.add_theme_stylebox_override("normal", footer)
	$DiscardButton.add_theme_stylebox_override("disabled", footer)
	var highlighted: StyleBoxFlat = footer.duplicate()
	highlighted.bg_color = Color(0.12, 0.20, 0.26, 0.5)
	$DiscardButton.add_theme_stylebox_override("hover", highlighted)
	$DiscardButton.add_theme_stylebox_override("pressed", highlighted)
	$DiscardButton.add_theme_color_override("font_color", family_tint)
	$DiscardButton.add_theme_color_override("font_disabled_color", family_tint.darkened(0.25))
	tooltip_text = (
		card_data.card_name
		+ "\n"
		+ preload("res://scripts/cards/card_data.gd").describe_effects(card_data.effects)
	)
	tooltip_text += "\nHold / I / middle-click: inspect · Right-click: discard"


func set_playable(playable: bool, affordable: int = -1) -> void:
	disabled = not playable
	if affordable < 0:
		affordable = int(playable)
	# Unaffordable changes cost/art emphasis, never the readability of the rules.
	self_modulate = Color.WHITE
	for path in ["TitleLabel", "TierLabel", "DescriptionLabel", "ResourceIcon", "CostRule"]:
		get_node(path).modulate = Color.WHITE
	$CostLabel.modulate = Color.WHITE if affordable != 0 else Color("ffc483")
	$ArtPlaceholder.modulate = Color.WHITE if affordable != 0 else Color(0.72, 0.72, 0.72)
	$FullCardArt.modulate = $ArtPlaceholder.modulate


func fit_placeholder_art() -> void:
	# Existing primitive art uses a 174×74 design surface; scale its children to fit.
	$ArtPlaceholder.clip_contents = true
	var height: float = maxf(0, $ArtPlaceholder.offset_bottom - $ArtPlaceholder.offset_top)
	for child in $ArtPlaceholder.get_children():
		child.scale.y = height / 74.0


func set_discardable(allowed: bool) -> void:
	$DiscardButton.disabled = not allowed


func set_ion_glow(active: bool, tint: Color = Color(0.15, 0.55, 1.0)) -> void:
	# TUNE: Shared storm outline; the default blue preserves the Ion caller contract.
	for style in ["normal", "disabled", "hover", "pressed"]:
		var box: StyleBoxFlat = get_theme_stylebox(style).duplicate()
		box.shadow_color = Color(tint, 0.55 if active else 0.0)
		box.shadow_size = 9 if active else 0
		add_theme_stylebox_override(style, box)



func _draw() -> void:
	# Slim visible footer; the existing full-width Button retains its larger hitbox.
	draw_rect(Rect2(7, 294 - footer_visual_height, 184, footer_visual_height), Color("0b121c"))
	draw_line(
		Vector2(12, 294 - footer_visual_height),
		Vector2(186, 294 - footer_visual_height),
		Color(family_tint, 0.25),
		1.0
	)
	if interaction_hovered or interaction_selected:
		draw_rect(
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			visual_settings.card_selection_color,
			false,
			2.0 if interaction_selected else 1.0
		)
