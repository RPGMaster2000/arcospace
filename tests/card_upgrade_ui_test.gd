extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var view = load("res://scenes/card.tscn").instantiate()
	root.add_child(view)
	var modifier = preload("res://scripts/combat_modifier.gd").new()
	modifier.kind = 2
	modifier.active = true
	for card in Cards.CARDS:
		for level in [1, 2]:
			for factor in [0.0, 0.5, 2.0]:
				modifier.ion_factor = factor
				var enhanced: Resource = card.with_upgrade(level)
				view.card_data = enhanced if factor == 0 else modifier.preview(enhanced)
				await process_frame
				var label: RichTextLabel = view.get_node("DescriptionLabel")
				var title: Label = view.get_node("TitleLabel")
				if title.position.y + title.get_minimum_size().y > view.get_node("ArtPlaceholder").position.y + 1:
					failures += 1
					push_error("Upgraded title overlaps art: " + view.card_data.card_name)
				var limit: float = view.get_node("DiscardButton").position.y - label.position.y
				if label.get_minimum_size().y > limit:
					failures += 1
					push_error("Upgraded description overlaps discard: %s Ion %.1f, minimum %.1f, space %.1f" % [view.card_data.card_name,factor,label.get_minimum_size().y,limit])
	modifier.free()
	view.queue_free()
	print("Upgrade UI checks: %d failures" % failures)
	quit(1 if failures else 0)
