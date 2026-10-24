extends SceneTree
# Development/CI entry point; not called by gameplay or exports.
const Contract = preload("res://scripts/cards/card_effect_contract.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
func _initialize() -> void:
	var errors: Array[String] = Contract.library(Cards.CARDS)
	for diagnostic in errors: printerr(diagnostic)
	print("Card library validation: %d cards, %d errors" % [Cards.CARDS.size(), errors.size()])
	quit(0 if errors.is_empty() else 1)
