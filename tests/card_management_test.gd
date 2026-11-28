extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const LANDSCAPE := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(686, 384)]
var checks: int = 0
var failures: int = 0
var host: Control
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func settle() -> void:
	for n in range(16): await process_frame
func capture(label: String) -> void:
	var directory := OS.get_environment("ARCOSPACE_ARCHIVE_CAPTURES")
	if DisplayServer.get_name() == "headless" or directory.is_empty(): return
	if not label in ["archive", "acquire-1280", "upgrade-1280", "replace-1280", "rare", "outpost", "compact-insets"]: return
	await create_timer(0.44).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	var frame := root.get_texture().get_image()
	if frame.get_width() > 1150:
		frame.resize(1150, roundi(frame.get_height() * 1150.0 / frame.get_width()), Image.INTERPOLATE_LANCZOS)
	frame.save_webp(directory.path_join(label + ".webp"), false, 0.81)
func layout_checks(label: String) -> void:
	var modal = host.card_management
	for dimensions in LANDSCAPE:
		root.size = dimensions
		await settle()
		var bounds: Rect2 = root.get_visible_rect()
		print("Card layout %s %s: logical=%s gallery=%s details=%s footer=%s columns=%d" % [label, dimensions, bounds.size, modal.gallery.size, modal.details_scroll.get_parent().get_parent().size, modal.footer.get_global_rect(), modal.gallery.grid.columns])
		check(bounds.encloses(modal.footer.get_global_rect()), label + " fixed footer " + str(dimensions))
		check(bounds.encloses(modal.confirm_button.get_global_rect()), label + " confirm reachable")
		check(modal.gallery.get_global_rect().end.x <= modal.details_scroll.get_global_rect().position.x, label + " columns separated")
		var gallery_position: int = modal.gallery.scroll.scroll_vertical
		var footer_rect: Rect2 = modal.footer.get_global_rect()
		modal.details_scroll.scroll_vertical = 10000
		await settle()
		check(modal.gallery.scroll.scroll_vertical == gallery_position, label + " independent details scroll")
		check(modal.footer.get_global_rect() == footer_rect, label + " scroll never moves footer")
		if label == "replace":
			check(bounds.encloses(modal.incoming_portrait.get_global_rect()), "Incoming pinned while details scroll")
		modal.details_scroll.scroll_vertical = 0
		await capture(label + "-%d" % dimensions.x)

func offer() -> void:
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	host.show_outcome()
func run() -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	current_scene = host
	var modal = host.card_management
	modal.save_quit_button.show()
	var screen_id: int = host.screen.get_instance_id()
	for dimensions in LANDSCAPE:
		root.size = dimensions
		offer()
		await settle()
		check(modal.shade.visible and modal.layer > 100, "Full screen overlay above HUD")
		check(modal.shade.get_global_rect() == root.get_visible_rect(), "Covers entire viewport " + str(dimensions))
		check(host.screen.process_mode == Node.PROCESS_MODE_DISABLED, "Underlying screen input disabled")
		var event = InputEventMouseButton.new()
		event.position = modal.margin.get_global_rect().position-Vector2.ONE
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		root.push_input(event, true)
		event.pressed = false
		root.push_input(event, true)
		check(not host.current_deck_viewer.shade.visible, "Covered HUD cannot activate")
		check(modal.confirm_button.disabled, "Selection required")
		check(not modal.gallery.filters.visible, "Small offers hide filters")
		var selected: Resource = modal.gallery.visible_cards[0]
		modal.gallery.grid.get_child(0).pressed.emit()
		check(modal.selected_card == selected and modal.selection.text.contains(selected.card_name), "Selection updates details immediately")
		check(not modal.confirm_button.disabled and modal.gallery.grid.get_child(0).get_node("SelectionBorder").visible, "Single visible selection")
		check(modal.selected_card != null, "Tap updates inline selection")
		await settle()
		check(root.get_visible_rect().encloses(modal.footer.get_global_rect()), "Footer stays in viewport")
		check(not modal.gallery.scroll.is_ancestor_of(modal.confirm_button), "Confirm outside gallery scroll")
		check(modal.gallery.get_global_rect().end.y <= modal.details_panel.get_global_rect().position.y,
			"Centered offer row is above the compact detail strip")
		check(modal.gallery.grid.columns == modal.gallery.cards.size(), "Five-card offer fits in one landscape row")
		await capture("acquire-%d" % dimensions.x)
		var checkpoint: Dictionary = Save.encode(host.state)
		var revision: int = modal.revision
		var scroll_position: int = modal.gallery.scroll.scroll_vertical
		modal.view_deck_button.pressed.emit()
		var archive = host.current_deck_viewer
		check(archive.layer > modal.layer and archive.shade.visible, "Deck archive opens above reward")
		check(archive.composition.families.reduce(func(total, n): return total + n, 0) == host.state.player_pool().size(),
			"Composition matches the actual owned deck")
		if dimensions.x == 1280:
			await settle()
			await capture("archive")
		modal.confirm_button.pressed.emit()
		check(Save.encode(host.state) == checkpoint, "Covered reward cannot commit and opening archive consumes no RNG")
		archive.dismiss()
		check(modal.revision == revision and modal.selected_card == selected and modal.gallery.scroll.scroll_vertical == scroll_position,
			"Archive return preserves offers, selection and scroll")
		var before: int = host.state.acquired_cards.size()
		modal.confirm_button.pressed.emit()
		modal.confirm_button.pressed.emit()
		check(host.state.acquired_cards.size() == before + 1, "Acquire exactly once")
		check(modal.feedback.get_child_count() > 0, "Accepted acquisition creates short read-only feedback")
		while modal.closing: await process_frame
		check(not modal.shade.visible and host.screen.process_mode == Node.PROCESS_MODE_INHERIT, "Fade out releases modal and input")
		check(host.screen.get_instance_id() == screen_id, "Expedition screen retained")
	# Mandatory upgrades stay open in the same node, with a fresh unselected gallery.
	host.state.start_upgrade_event(2)
	host.show_outcome()
	await settle()
	var upgrade: Resource = modal.gallery.cards[0]
	modal.select_card(upgrade)
	check(modal.heading.text.contains("2 upgrades remaining"), "Remaining counter")
	check(modal.compared.size() == 2 and modal.compared[0].card_data == upgrade,
		"Comparison includes the existing definition")
	var preview: Button = modal.compared[1]
	check(preview.card_data.effects == upgrade.with_upgrade(upgrade.upgrade_level + 1).effects, "Right portrait shows actual next upgrade")
	await settle()
	check(preview.card_scale > 0.4 and preview.card_scale == modal.compared[0].card_scale,
		"Both comparison portraits retain the same readable proportions")
	await layout_checks("upgrade")
	var old_revision: int = modal.revision
	modal.confirm_button.pressed.emit()
	check(host.state.upgrades_remaining == 1 and modal.shade.visible and modal.selected_card == null, "Refresh in place between upgrades")
	check(modal.gallery.cards.all(func(c): return c.identity_key() != upgrade.identity_key()), "Identity excluded for event")
	host._management_confirmed("upgrade", upgrade, old_revision)
	check(host.state.upgrades_remaining == 1, "Stale confirmation ignored")
	var cancel = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	check(modal.shade.visible and host.state.pending_choice == "upgrade", "Mandatory upgrades cannot cancel")
	var encoded: Dictionary = Save.encode(host.state)
	var resumed = Save.new().decode(encoded)
	check(resumed.upgrades_remaining == 1 and resumed.upgrade_candidates().size() == host.state.upgrade_candidates().size(), "Incomplete upgrades resume")
	modal.select_card(modal.gallery.cards[0])
	modal.confirm_button.pressed.emit()
	check(host.state.pending_choice.is_empty(), "Last upgrade finishes via State")
	# Fill the authoritative deck using its existing acquisition rules.
	while host.state.player_pool().size() < host.state.deck_limit():
		host.state.pending_choice = "card"
		host.state.card_offers = host.state.random_card_offers()
		host.state.choose_card(0)
	offer()
	modal.select_card(modal.gallery.cards[0])
	var incoming: Resource = modal.selected_card
	modal.confirm_button.pressed.emit()
	check(modal.mode == "replace" and host.state.pending_card == incoming, "Full deck transitions directly to replacement")
	check(modal.confirm_button.disabled and modal.decline_button.visible, "Replacement requires outgoing identity")
	await settle()
	check(modal.incoming_portrait.card_data == incoming, "Incoming visible without another modal")
	var retained: Array = host.state.player_pool()
	var outgoing: Resource = modal.gallery.cards[0]
	modal.select_card(outgoing)
	var key: String = outgoing.identity_key()
	check(modal.selection.text.contains(outgoing.card_name), "Outgoing comparison updates")
	check(modal.compared.size() == 2 and modal.compared[0].card_data == outgoing and modal.compared[1].card_data == incoming,
		"Replacement compares the exact owned card and reward")
	encoded = Save.encode(host.state)
	resumed = Save.new().decode(encoded)
	check(resumed.pending_card.identity_key() == incoming.identity_key() and resumed.pending_choice == "replace", "Pending replacement survives version 1 save")
	await settle()
	await layout_checks("replace")
	modal.confirm_button.pressed.emit()
	modal.confirm_button.pressed.emit()
	check(host.state.player_pool().size() == retained.size(), "Replacement capacity unchanged")
	check(host.state.player_pool().all(func(c): return c.identity_key() != key), "Exactly outgoing identity removed")
	check(host.state.player_pool().any(func(c): return c.identity_key() == incoming.identity_key()), "Incoming identity acquired")
	# Decline consumes the reward without mutating ownership.
	retained = host.state.player_pool()
	offer()
	modal.select_card(modal.gallery.cards[0])
	modal.confirm_button.pressed.emit()
	modal.decline_button.pressed.emit()
	modal.decline_button.pressed.emit()
	check(host.state.pending_choice.is_empty() and host.state.player_pool() == retained, "Decline is single-use and retains deck")
	# A drag release cannot select a card, even when Button emits pressed.
	host.state.start_upgrade_event(2)
	host.show_outcome()
	await settle()
	var scroll = modal.gallery.scroll
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = scroll.get_global_rect().get_center()
	touch.pressed = true
	scroll._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = touch.position + Vector2(0,-80)
	scroll._input(drag)
	touch.pressed = false
	scroll._input(touch)
	modal.gallery.grid.get_child(0).pressed.emit()
	check(modal.selected_card == null, "Swipe never selects")
	# Reopen/teardown while fade is active; there is only one retained overlay.
	var id: int = modal.get_instance_id()
	host.show_outcome()
	host.show_outcome()
	check(host.card_management.get_instance_id() == id, "Repeated open reuses one overlay")
	modal.dismiss()
	host.show_outcome()
	await create_timer(0.3).timeout
	check(modal.shade.visible and not modal.closing, "Reopen cancels obsolete close callback")
	# Force genuinely overflowing details using a disposable definition, not library edits.
	var long_card: Resource = Cards.CARDS[0].duplicate(true)
	long_card.description = "Long comparison details remain readable while scrolling.\n".repeat(40)
	modal.dismiss(true)
	modal.present("card", [long_card])
	check(is_zero_approx(modal.shade.modulate.a), "Opening starts a subtle fade")
	await modal.motion.finished
	check(is_equal_approx(modal.shade.modulate.a, 1.0), "Opening finishes fully opaque")
	modal.select_card(long_card)
	await settle()
	check(modal.details_scroll.get_v_scroll_bar().max_value > modal.details_scroll.get_v_scroll_bar().page, "Long descriptions overflow only details scroll")
	var gallery_offset: int = modal.gallery.scroll.scroll_vertical
	var footer_before: Rect2 = modal.footer.get_global_rect()
	var wheel = InputEventMouseButton.new()
	wheel.position = modal.details_scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await settle()
	check(modal.details_scroll.scroll_vertical > 0, "Mouse wheel moves long details")
	check(modal.gallery.scroll.scroll_vertical == gallery_offset, "Details wheel does not scroll gallery")
	check(modal.footer.get_global_rect() == footer_before, "Details wheel does not move actions")
	check(Cards.CARDS[0].description != long_card.description, "Disposable detail fixture leaves card definitions unchanged")
	# Authored visual fixtures exercise rare offers, the price strip and compact safe insets.
	root.size = Vector2i(1280, 720)
	var rare: Resource = preload("res://cards/108_bastion_foundry.tres")
	var offers: Array = [Cards.CARDS[0], Cards.CARDS[4], rare, Cards.CARDS[14], Cards.CARDS[19]]
	modal.present("card", offers)
	modal.select_card(rare)
	await settle()
	check(modal.gallery.visible_cards == offers and modal.selected_card == rare, "Rare reward order and identity are preserved")
	await capture("rare")
	var prices: Dictionary = {}
	for card in offers: prices[card.identity_key()] = 25 if card.tier == 3 else 15
	modal.present("purchase", offers, 0, null, 34, "Card prices", prices, 20)
	modal.select_card(rare)
	check(modal.confirm_button.disabled and modal.context.text.contains("25 Salvage"), "Unaffordable rare purchase remains selectable for inspection")
	modal.select_card(offers[0])
	check(not modal.confirm_button.disabled and modal.context.text.contains("5"), "Affordable offer shows the post-purchase balance")
	await settle()
	await capture("outpost")
	root.size = Vector2i(686, 384)
	await settle()
	preload("res://scripts/ui/card_screen_margins.gd").apply(modal.margin, 20, Vector4(34, 10, 8, 18))
	await settle()
	check(modal.margin.get_global_rect().encloses(modal.footer.get_global_rect()) and modal.footer.get_global_rect().position.x >= 54,
		"Asymmetric safe margins keep the purchase action reachable")
	await capture("compact-insets")
	var preferences = preload("res://scripts/ui/menu_preferences.gd")
	var previous: int = preferences.ui_motion()
	preferences.set_ui_motion(0)
	modal.dismiss(true)
	modal.present("card_batch", offers.slice(0, 2))
	check(not modal.confirm_button.disabled and modal.selected_card == null, "Batch confirmation keeps both cards without requiring a selection")
	check(modal.shade.modulate.a == 1.0, "Minimal motion reveals the reward immediately")
	modal.accepted("card_batch", modal.confirmation_snapshot("card_batch"))
	check(modal.feedback.get_child_count() == 0, "Minimal motion omits the confirmation projection")
	preferences.set_ui_motion(previous)
	host.free()
	await settle()
	print("Card management: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
