@tool
extends Button

signal discard_requested

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
	if card_data == null:
		$TitleLabel.text = "Empty slot"
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		tooltip_text = ""
		$DiscardButton.disabled = true
		$DiscardButton.text = "Discard"
		return
	$TitleLabel.text = card_data.card_name.to_upper()
	$CostLabel.text = str(card_data.cost)
	$DescriptionLabel.text = card_data.description
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


func set_playable(playable: bool) -> void:
	disabled = not playable
	# Keep the discard footer bright and clickable even when play is unaffordable.
	var tint: Color = Color.WHITE if playable else Color(0.48, 0.48, 0.48)
	self_modulate = tint
	for path in ["TitleLabel", "CostLabel", "DescriptionLabel", "ResourceIcon", "ArtPlaceholder", "CostRule"]:
		get_node(path).modulate = tint


func set_discardable(allowed: bool) -> void:
	$DiscardButton.disabled = not allowed
