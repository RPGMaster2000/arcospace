extends SceneTree

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var card = load("res://scenes/card.tscn").instantiate()
	root.add_child(card)
	await process_frame
	var sample = load("res://scripts/cards/card_data.gd").new()
	sample.card_name = "Test Attack"
	sample.family = "energy"
	sample.cost = 6
	sample.effects = {"damage": 9}
	sample.description = "Deal 9 damage."
	sample.allocation_category = "offense"
	card.card_data = sample
	await process_frame
	check(card.get_node("EffectCue").text == "✦", "Attack icon cue reflects card effect")
	check(card.get_node("DescriptionLabel").text.contains("9"), "Written effect remains visible")
	check(not card.get_node("FullCardArt").visible, "Placeholder art remains when no artwork assigned")
	var artwork = GradientTexture2D.new()
	artwork.width = 64
	artwork.height = 96
	sample.set_meta("card_art", artwork)
	card.refresh_card()
	check(card.get_node("FullCardArt").visible, "Optional full-card art shows when supplied")
	check(not card.get_node("ArtPlaceholder").visible, "Placeholder hides when art is supplied")
	card.queue_free()
	await process_frame
	print("Card icon cue: %d failures" % failures)
	quit(1 if failures else 0)
