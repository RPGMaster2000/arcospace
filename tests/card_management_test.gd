extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks: int = 0
var failures: int = 0
var host: Control
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for n in range(16): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/card-management-" + label + ".png")
func layout_checks(label: String) -> void:
	var modal = host.card_management
	for dimensions in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1680,720)]:
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
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1680,720)]:
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
		check(modal.gallery.size.x / (modal.gallery.size.x + modal.details_scroll.get_parent().get_parent().size.x) > 0.59, "Gallery owns majority of width")
		await capture("acquire-%d" % dimensions.x)
		var before: int = host.state.acquired_cards.size()
		modal.confirm_button.pressed.emit()
		modal.confirm_button.pressed.emit()
		check(host.state.acquired_cards.size() == before + 1, "Acquire exactly once")
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
	check(modal.selection.text == "After Upgrade" and modal.details.get_child_count()==2, "Upgrade details contain only heading and real upgraded card")
	var preview: Button
	for child in modal.details.get_children():
		if child.get_script() == preload("res://scripts/ui/card_portrait.gd"):
			preview = child
	check(preview != null and preview.card_data.effects == upgrade.with_upgrade(upgrade.upgrade_level + 1).effects, "Right portrait shows actual next upgrade")
	await settle()
	check(preview.card_scale > 1.0 and preview.card_scale <= 1.2, "Upgrade portrait enlarges within available space")
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
	host.free()
	await settle()
	print("Card management: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
