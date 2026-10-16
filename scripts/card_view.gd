@tool
extends Button

signal discard_requested
var discard_target_height: float = 48.0

# RESPONSIBILITY: Display a card resource in the editor and at runtime.
# DOES NOT: Apply effects or draw cards.
@export var card_data: Resource:
	set(value):
		if card_data != null and card_data.changed.is_connected(refresh_card):
			card_data.changed.disconnect(refresh_card)
		card_data = value
		if card_data != null:
			card_data.changed.connect(refresh_card)
		if is_node_ready():
			refresh_card()

func _ready() -> void:
	$DiscardButton.pressed.connect(_on_discard_pressed)
	# The whole hand fades on turn changes; avoid an instant disabled-text jump.
	$DiscardButton.add_theme_color_override("font_disabled_color", $DiscardButton.get_theme_color("font_color"))
	refresh_card()


func _on_discard_pressed() -> void:
	if not Engine.is_editor_hint():
		discard_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or card_data == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		discard_requested.emit()


func refresh_card() -> void:
	queue_redraw()
	set_process(card_data != null and card_data.tier > 1)
	if card_data == null:
		$TitleLabel.text = "Empty slot"
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		tooltip_text = ""
		$DiscardButton.disabled = true
		$DiscardButton.text = "Discard"
		return
	$TitleLabel.text = card_data.card_name.to_upper() + (" · T%d" % card_data.tier if card_data.tier > 1 else "")
	$CostLabel.text = str(card_data.cost)
	$DescriptionLabel.text = card_data.description
	# Enhanced effects may need a fourth line. Borrow only decorative art space;
	# keep the existing readable font, card size and discard hit target.
	$DiscardButton.offset_top = 294.0 - discard_target_height
	$DiscardButton.offset_bottom = 294.0
	$DiscardButton.custom_minimum_size.y = discard_target_height
	$DescriptionLabel.offset_bottom = $DiscardButton.offset_top - 6
	$DescriptionLabel.offset_top = 188.0
	$ArtPlaceholder.offset_top = 109.0
	$ArtPlaceholder.offset_bottom = 183.0
	$ArtPlaceholder.visible = true
	var required: float = $DescriptionLabel.get_minimum_size().y
	var extra: float = maxf(0, required - ($DescriptionLabel.offset_bottom - 188.0))
	$DescriptionLabel.offset_top -= extra
	$ArtPlaceholder.offset_bottom = $DescriptionLabel.offset_top - 5
	$ArtPlaceholder.offset_top = maxf(109.0, $TitleLabel.position.y + $TitleLabel.get_minimum_size().y + 2.0)
	$ArtPlaceholder.visible = $ArtPlaceholder.offset_top < $ArtPlaceholder.offset_bottom
	fit_placeholder_art()
	var colors = {"materials": Color(1, 0.55, 0.5), "energy": Color(0.5, 0.8, 1), "crew": Color(0.5, 1, 0.65)}
	var color: Color = colors.get(card_data.family, Color.WHITE)
	for icon in $ResourceIcon.get_children():
		icon.visible = icon.name.to_lower() == card_data.family
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
	$DiscardButton.tooltip_text = "Recover %d %s" % [int(floor(card_data.cost / 3.0)), card_data.family.capitalize()]
	tooltip_text = card_data.card_name + "\n" + card_data.description
	tooltip_text += "\nRight-click: discard (+%d %s)" % [int(floor(card_data.cost / 3.0)), card_data.family.capitalize()]


func set_playable(playable: bool, affordable: int = -1) -> void:
	disabled = not playable
	if affordable < 0:
		affordable = int(playable)
	# Keep the discard footer bright and clickable even when play is unaffordable.
	var tint: Color = Color.WHITE if affordable != 0 else Color(0.48, 0.48, 0.48)
	self_modulate = tint
	for path in ["TitleLabel", "CostLabel", "DescriptionLabel", "ResourceIcon", "ArtPlaceholder", "CostRule"]:
		get_node(path).modulate = tint

func fit_placeholder_art() -> void:
	# Existing primitive art uses a 174×74 design surface; scale its children to fit.
	$ArtPlaceholder.clip_contents = true
	var height: float = maxf(0, $ArtPlaceholder.offset_bottom - $ArtPlaceholder.offset_top)
	for child in $ArtPlaceholder.get_children():
		child.scale.y = height / 74.0


func set_discardable(allowed: bool) -> void:
	$DiscardButton.disabled = not allowed

func set_ion_glow(active: bool) -> void:
	# TUNE: Shadow size and alpha control the subtle blue outline during ion storms.
	for style in ["normal", "disabled", "hover", "pressed"]:
		var box: StyleBoxFlat = get_theme_stylebox(style).duplicate()
		box.shadow_color = Color(0.15, 0.55, 1.0, 0.55 if active else 0.0)
		box.shadow_size = 9 if active else 0
		add_theme_stylebox_override(style, box)

var border_time: float = 0.0
func _process(delta: float) -> void:
	border_time += delta
	queue_redraw()

func _draw() -> void:
	if card_data == null or card_data.tier < 2:
		return
	# TUNE: Jagged edge depth (pixels), tooth spacing and subtle pulse strength.
	var depth: float = 2.0
	var spacing: float = 12.0
	var pulse: float = 0.28 + 0.10 * sin(border_time * 2.0)
	var color = Color(0.65, 0.8, 1.0, pulse)
	var points = PackedVector2Array()
	var corners = [Vector2(3, 3), Vector2(size.x-3, 3), size-Vector2(3,3), Vector2(3,size.y-3), Vector2(3,3)]
	for edge in range(4):
		var start: Vector2 = corners[edge]
		var end: Vector2 = corners[edge+1]
		var steps: int = maxi(2, int(start.distance_to(end) / spacing))
		var inward: Vector2 = (end-start).normalized().orthogonal()
		for step in range(steps):
			points.append(start.lerp(end, float(step)/steps) + inward * (depth if step % 2 else 0.0))
	points.append(points[0])
	for width in [8.0, 4.0, 1.5]:
		draw_polyline(points, Color(color, pulse * (0.3 if width > 2 else 1.0)), width, true)
