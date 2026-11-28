extends Control
## Accepted outcomes are shown with detached, input-transparent card portraits.
const Deck = preload("res://scripts/ui/battle_deck_visual.gd")
const Portrait = preload("res://scripts/ui/card_portrait.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Accent = preload("res://scripts/ui/battle_signal.gd")
const SECONDS := 0.35

var animation: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(clear)


func clear() -> void:
	if animation: animation.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func play(kind: String, entries: Array, incoming: Resource = null) -> void:
	clear()
	if entries.is_empty() or Motion.duration(SECONDS) == 0.0: return
	animation = create_tween().set_parallel()
	if kind in ["card", "card_batch", "purchase"]:
		var center := Vector2(size.x * 0.5, size.y * 0.43)
		var deck := Deck.new()
		add_child(deck)
		deck.position = center - deck.size * 0.5
		deck.premium = Motion.Preferences.ui_motion() == 2
		animation.tween_property(deck, "assembly", 1.0, 0.10)
		animation.tween_property(deck, "assembly", 0.0, 0.13).set_delay(0.22)
		for entry in entries:
			var portrait := _copy(entry.card, entry.rect)
			animation.tween_property(portrait, "position", center - deck.size * 0.5, 0.25)
			animation.tween_property(portrait, "scale", Vector2.ONE * 0.28 / portrait.card_scale, 0.25)
			animation.tween_property(portrait, "modulate:a", 0.0, 0.14).set_delay(0.12)
	else:
		var entry: Dictionary = entries[0]
		var portrait := _copy(entry.card, entry.rect)
		var wash := Holo.DEFAULT.hostile if kind in ["replace", "trim"] else Holo.DEFAULT.reward
		Accent.sweep(portrait.rendering, wash, 0.25)
		animation.tween_property(portrait, "modulate:a", 0.0, 0.17).set_delay(0.16 if kind == "upgrade" else 0.0)
		if kind == "replace" and incoming != null:
			var received := _copy(incoming, entry.rect)
			received.modulate.a = 0.0
			animation.tween_property(received, "modulate:a", 1.0, 0.12).set_delay(0.10)
			animation.tween_property(received, "modulate:a", 0.0, 0.13).set_delay(0.22)
	animation.chain().tween_callback(clear)


func _copy(card: Resource, region: Rect2) -> Portrait:
	var portrait := Portrait.new()
	portrait.card_data = card
	portrait.inspection_enabled = false
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.focus_mode = Control.FOCUS_NONE
	portrait.card_scale = region.size.x / 198.0
	add_child(portrait)
	portrait.position = region.position
	return portrait
