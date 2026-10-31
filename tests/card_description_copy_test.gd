extends SceneTree

const Library = preload("res://scripts/cards/card_library.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Library.CARDS.size() == 80, "All registered cards included in copy audit")
	for card in Library.CARDS:
		check(not card.description.strip_edges().is_empty(), "%s has readable base copy" % card.card_name)
		check(not card.description.contains("\n"), "%s keeps one concise description" % card.card_name)
		if card.upgrade_effects.size() > 0:
			var upgraded: Resource = card.with_upgrade(1)
			check(not upgraded.description.strip_edges().is_empty(),
				"%s upgrade text generated from upgraded effects" % card.card_name)
	for index in range(74, 80):
		var signature: Resource = Library.CARDS[index]
		check(signature.description.contains("+") or signature.description.contains("damage"),
			"%s signature states its mechanical values" % signature.card_name)
	print("Card descriptions: %d cards audited, %d failures" % [Library.CARDS.size(), failures])
	quit(1 if failures > 0 else 0)
