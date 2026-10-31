@tool
extends Button

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Display a card resource in the editor and at runtime.
# DOES NOT: Apply effects or draw cards.

signal discard_requested
const Summary = preload("res://scripts/ui/card_summary.gd")
const EffectBadge = preload("res://scripts/ui/card_effect_badge.gd")
var effect_badges: Array[Control] = []
## TUNE: Shared normal-card text and read-only inspection settings.
@export var presentation_settings: Resource = preload("res://resources/card_presentation.tres")
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var interaction_tween: Tween
var interaction_hovered: bool = false
var interaction_selected: bool = false
var inspection_enabled: bool = true
var hold_input: Node
var discard_target_height: float = 33.0

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
	interaction_tween.tween_property(art, "position:y", 67.0 - elevation, duration)
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


# Small visual aid only; card text and Inspector remain authoritative.
static func effect_cue(card: Resource) -> String:
	if card.play_again:
		return "↻"
	if card.effects.has("conditional"):
		return "◇?"
	if card.effects.has("damage") or card.effects.has("break_shields"):
		return "✦"
	if card.effects.has("shields") or card.effects.has("hull"):
		return "✚"
	if card.effects.has("sabotage") or card.effects.has("enemy_production"):
		return "↓"
	if card.effects.has("steal") or card.effects.has("drain"):
		return "⇄"
	match card.allocation_category:
		"offense": return "✦"
		"defense": return "✚"
		_: return "⚙"


func refresh_card() -> void:
	queue_redraw()
	set_process(card_data != null and card_data.tier > 1)
	if card_data == null:
		$TitleLabel.text = "Empty slot"
		$TierLabel.text = ""
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		$EffectCue.text = ""
		clear_effect_badges()
		$FullCardArt.visible = false
		tooltip_text = ""
		$DiscardButton.disabled = true
		$DiscardButton.text = "Discard"
		return
	$TitleLabel.text = card_data.card_name.trim_suffix("++").trim_suffix("+").to_upper()
	# Fit actual rendered text, not just its line count: a two-line label can
	# still exceed the header height or contain a clipped long word.
	$TitleLabel.max_lines_visible = -1
	$TitleLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for font_size in range(mini(16, presentation_settings.card_title_font_size), 7, -1):
		$TitleLabel.add_theme_font_size_override("font_size", font_size)
		var title_font: Font = $TitleLabel.get_theme_font("font")
		var longest_word: float = 0.0
		for word in $TitleLabel.text.replace("\\n", " ").split(" ", false):
			longest_word = maxf(longest_word, title_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if ($TitleLabel.get_line_count() <= 2
			and $TitleLabel.get_minimum_size().y <= 40.0
			and longest_word <= 128.0):
			break
	$TitleLabel.max_lines_visible = 2
	$TitleLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$TitleLabel.clip_text = true
	$TitleLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$TierLabel.text = (
		("T%d " % card_data.tier if card_data.tier > 1 else "")
		+ "+".repeat(card_data.upgrade_level)
	)
	$CostLabel.text = str(card_data.cost)
	$EffectCue.text = effect_cue(card_data)
	$EffectCue.tooltip_text = card_data.allocation_category.capitalize() + " · full details in Inspector"
	var artwork: Variant = card_data.get_meta("card_art") if card_data.has_meta("card_art") else null
	$FullCardArt.texture = artwork if artwork is Texture2D else null
	$FullCardArt.visible = $FullCardArt.texture != null
	$ArtPlaceholder.visible = not $FullCardArt.visible
	$DescriptionLabel.text = Summary.card_text(
		card_data, presentation_settings.description_shorthand_threshold
	)
	var description_size: int = mini(12, presentation_settings.compact_description_font_size)
	$DescriptionLabel.add_theme_font_size_override("font_size", description_size)
	# Fixed artwork and description rectangles. Overflow is an ellipsis, never borrowed art space.
	$DiscardButton.add_theme_font_size_override(
		"font_size", roundi(mini(13, presentation_settings.discard_button_font_size) / maxf(scale.y, 0.01))
	)
	$TitleLabel.offset_bottom = 53.0
	$DiscardButton.offset_top = 294.0 - discard_target_height
	$DiscardButton.offset_bottom = 294.0
	$DiscardButton.custom_minimum_size.y = discard_target_height
	$DescriptionLabel.offset_top = 204.0
	$DescriptionLabel.offset_bottom = $DiscardButton.offset_top - 5
	$DescriptionLabel.clip_text = true
	$DescriptionLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var line_height: float = $DescriptionLabel.get_theme_font("font").get_height(
		description_size
	)
	$DescriptionLabel.max_lines_visible = maxi(
		1, floori(($DescriptionLabel.offset_bottom - 204.0) / line_height)
	)
	# Exception to the length threshold: abbreviate short text only when it cannot fit.
	if $DescriptionLabel.get_line_count() > $DescriptionLabel.max_lines_visible:
		$DescriptionLabel.text = Summary.card_text(card_data, -1)
	$ArtPlaceholder.offset_top = 67.0
	$ArtPlaceholder.offset_bottom = 177.0
	$ArtPlaceholder.visible = not $FullCardArt.visible
	fit_placeholder_art()
	update_effect_badges()
	var colors = {
		"materials": Color(1, 0.55, 0.5), "energy": Color(0.5, 0.8, 1), "crew": Color(0.5, 1, 0.65)
	}
	var color: Color = colors.get(card_data.family, Color.WHITE)
	for icon in $ResourceIcon.get_children():
		icon.visible = icon.name.to_lower() == card_data.family
	$CostBadge.color = Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.96)
	var normal: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
	normal.bg_color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.16, 1)
	normal.border_color = color.lerp(Color(0.97, 0.89, 0.69), 0.5)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.border_color = Color(1, 0.96, 0.8)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	$DiscardButton.text = "Discard +%d" % int(floor(card_data.cost / 3.0))
	$DiscardButton.tooltip_text = (
		"Recover %d %s" % [int(floor(card_data.cost / 3.0)), card_data.family.capitalize()]
	)
	tooltip_text = card_data.card_name + "\n" + card_data.description
	tooltip_text += (
		"\nHold to preview · I: preview/inspect · Middle-click to inspect\nRight-click: discard (+%d %s)"
		% [int(floor(card_data.cost / 3.0)), card_data.family.capitalize()]
	)



func clear_effect_badges() -> void:
	for badge in effect_badges:
		if is_instance_valid(badge):
			badge.queue_free()
	effect_badges.clear()


func update_effect_badges() -> void:
	clear_effect_badges()
	if card_data == null:
		return
	var effects: Dictionary = card_data.effects
	var conditional_effects: Dictionary = {}
	if effects.get("conditional") is Dictionary:
		conditional_effects = effects["conditional"].get("then", {})
	var entries: Array[Dictionary] = []
	for kind in ["materials", "crew", "energy"]:
		var amount: int = int(effects.get(kind, 0))
		var extra: int = int(conditional_effects.get(kind, 0))
		if amount != 0:
			entries.append({"kind": kind, "amount": amount, "conditional": false})
		if extra != 0:
			entries.append({"kind": kind, "amount": extra, "conditional": true})
	# Keep the full written effect for non-resource cards; icon badges supplement it.
	var width: float = minf(55.0, 174.0 / maxf(1.0, float(entries.size())))
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var badge: Control = EffectBadge.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(13.0 + index * width, 181.0)
		badge.size = Vector2(width - 4.0, 21.0)
		add_child(badge)
		badge.configure(entry.kind, entry.amount, entry.conditional)
		effect_badges.append(badge)

func set_playable(playable: bool, affordable: int = -1) -> void:
	disabled = not playable
	if affordable < 0:
		affordable = int(playable)
	# Keep the discard footer bright and clickable even when play is unaffordable.
	var tint: Color = Color.WHITE if affordable != 0 else Color(0.48, 0.48, 0.48)
	self_modulate = tint
	for path in [
		"TitleLabel",
		"CostLabel",
		"TierLabel",
		"DescriptionLabel",
		"ResourceIcon",
		"ArtPlaceholder",
		"CostRule",
		"EffectCue",
	]:
		get_node(path).modulate = tint


func fit_placeholder_art() -> void:
	# Existing primitive art uses a 174×74 design surface; scale its children to fit.
	$ArtPlaceholder.clip_contents = true
	var height: float = maxf(0, $ArtPlaceholder.offset_bottom - $ArtPlaceholder.offset_top)
	for child in $ArtPlaceholder.get_children():
		child.scale.y = height / 74.0


func set_discardable(allowed: bool) -> void:
	$DiscardButton.disabled = not allowed


func set_ion_glow(active: bool, tint: Color = Color(0.15,0.55,1.0)) -> void:
	# TUNE: Shared storm outline; the default blue preserves the Ion caller contract.
	for style in ["normal", "disabled", "hover", "pressed"]:
		var box: StyleBoxFlat = get_theme_stylebox(style).duplicate()
		box.shadow_color = Color(tint, 0.55 if active else 0.0)
		box.shadow_size = 9 if active else 0
		add_theme_stylebox_override(style, box)


var border_time: float = 0.0


func _process(delta: float) -> void:
	border_time += delta
	queue_redraw()


func _draw() -> void:
	if interaction_hovered or interaction_selected:
		var tint: Color = visual_settings.card_selection_color
		draw_rect(
			Rect2(Vector2(3, 3), size - Vector2(6, 6)),
			Color(tint, visual_settings.card_glow_intensity),
			false,
			6.0
		)
		draw_rect(
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			tint,
			false,
			2.0 if interaction_selected else 1.0
		)
	if card_data == null or card_data.tier < 2:
		return
	# TUNE: Jagged edge depth (pixels), tooth spacing and subtle pulse strength.
	var depth: float = 2.0
	var spacing: float = 12.0
	var pulse: float = 0.28 + 0.10 * sin(border_time * 2.0)
	var color = Color(0.65, 0.8, 1.0, pulse)
	var points = PackedVector2Array()
	var corners = [
		Vector2(3, 3),
		Vector2(size.x - 3, 3),
		size - Vector2(3, 3),
		Vector2(3, size.y - 3),
		Vector2(3, 3)
	]
	for edge in range(4):
		var start: Vector2 = corners[edge]
		var end: Vector2 = corners[edge + 1]
		var steps: int = maxi(2, int(start.distance_to(end) / spacing))
		var inward: Vector2 = (end - start).normalized().orthogonal()
		for step in range(steps):
			points.append(
				start.lerp(end, float(step) / steps) + inward * (depth if step % 2 else 0.0)
			)
	points.append(points[0])
	for width in [8.0, 4.0, 1.5]:
		draw_polyline(points, Color(color, pulse * (0.3 if width > 2 else 1.0)), width, true)
