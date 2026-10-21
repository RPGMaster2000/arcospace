extends SceneTree
const Rules = preload("res://encounters/expedition_rules.tres")
var host: Control
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for n in range(14): await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/deck-replacement-" + name + ".png")
func prepare() -> Resource:
	while host.state.player_pool().size() < host.state.deck_limit():
		host.state.pending_choice = "card"
		host.state.card_offers = host.state.random_card_offers()
		host.state.choose_card(0)
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	var incoming: Resource = host.state.card_offers[0]
	host.show_outcome()
	host._preview_card(incoming)
	host.card_inspector.confirm_button.pressed.emit()
	return incoming
func run() -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.rules = Rules.duplicate(true)
	host.rules.debug_seed = 2211
	host.rules.log_rolls = false
	root.add_child(host)
	current_scene = host
	var incoming: Resource = prepare()
	check(host.view_kind == "replacement" and host.state.pending_card == incoming, "Actual acquire confirmation opens replacement")
	var original: Array = host.state.player_pool()
	for size in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450),Vector2i(686,384)]:
		root.size = size
		host.show_system()
		await settle()
		check(host.view_kind == "replacement" and host.state.pending_card == incoming and host.incoming_portrait.card_data == incoming, "Fixed incoming survives screen reconstruction")
		check(host.title.text == "Deck Full — 36/36 Cards" and host.replace_button.disabled, "Capacity and no-selection safeguard")
		check(host.card_gallery.cards.size() == 36 and host.state.player_pool() == original, "Gallery contains owned identities without removal")
		check(host.card_gallery.scroll.get_v_scroll_bar().max_value > host.card_gallery.scroll.get_v_scroll_bar().page, "Owned gallery scrolls")
		host.card_gallery.scroll.scroll_vertical = 500
		await settle()
		check(host.card_gallery.scroll.scroll_vertical > 0, "Gallery scrolling works")
		host.card_gallery.scroll.scroll_vertical = 0
		host.card_gallery.grid.get_child(0).pressed.emit()
		check(not host.replace_button.disabled and not host.replacement_key.is_empty() and host.replacement_selection.text.contains("Upgrade 0"), "Selecting owned portrait enables explicit replacement")
		var first_key: String = host.replacement_key
		host.card_gallery.grid.get_child(1).pressed.emit()
		check(host.replacement_key != first_key and host.state.player_pool() == original, "Selection changes without mutation")
		host.incoming_portrait.pressed.emit()
		check(host.card_inspector.read_only and not host.card_inspector.confirm_button.visible, "Incoming can be inspected without acquisition reroll")
		host.card_inspector.dismiss()
		host.scroll.scroll_vertical = 0
		await settle()
		await capture("top-%d" % size.x)
		host.scroll.scroll_vertical = 10000
		await settle()
		check(host.replace_button.get_global_rect().end.y <= host.scroll.get_global_rect().end.y + 1, "Replacement action reachable at bottom")
		await capture("actions-%d" % size.x)
	var remove_key: String = host.replacement_key
	host.replace_button.pressed.emit()
	host._replace_card()
	check(host.state.pending_choice.is_empty() and host.state.player_pool().size()==36, "Replace completes once")
	for card in host.state.player_pool(): check(card.identity_key() != remove_key, "Exactly selected identity removed")
	check(host.state.acquired_draw_weights()[incoming.identity_key()] == 3.0, "Incoming is weighted acquisition")
	host._show_current_deck()
	check(host.current_deck_viewer.title.text.contains("Deck: 36 / 36") and host.current_deck_viewer.gallery.cards.size()==36, "Deck viewer reflects current capacity")
	host.current_deck_viewer.dismiss()
	var retained: Array = host.state.player_pool()
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	host.state.choose_card(0)
	host.show_outcome()
	await settle()
	host._decline_card()
	host._decline_card()
	check(host.state.pending_choice.is_empty() and host.state.player_pool()==retained, "Keep Current Deck declines without mutation")
	host.free()
	await process_frame
	print("Deck replacement UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
