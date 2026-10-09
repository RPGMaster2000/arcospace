@tool
extends Button

# HUVUDANSVAR: Visa en kortresurs i scenen och under körning.
# GÖR INTE: Utföra effekter eller dra kort.
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
	refresh_card()


func refresh_card() -> void:
	if card_data == null:
		$TitleLabel.text = "Empty slot"
		$CostLabel.text = ""
		$DescriptionLabel.text = ""
		tooltip_text = ""
		return
	$TitleLabel.text = card_data.card_name
	$CostLabel.text = "%d %s" % [card_data.cost, card_data.family.capitalize()]
	$DescriptionLabel.text = card_data.description
	var colors = {"materials": Color(1, 0.55, 0.5), "energy": Color(0.5, 0.8, 1), "crew": Color(0.5, 1, 0.65)}
	$CostLabel.add_theme_color_override("font_color", colors.get(card_data.family, Color.WHITE))
	tooltip_text = card_data.card_name + "\n" + card_data.description


func set_playable(playable: bool) -> void:
	disabled = not playable
	modulate = Color.WHITE if playable else Color(0.55, 0.55, 0.55)
