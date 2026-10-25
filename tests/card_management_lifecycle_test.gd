extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Scene = preload("res://scenes/expedition.tscn")
var checks: int = 0
var failures: int = 0
var store = Save.new()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func mount(state: Resource) -> Control:
	var host = Scene.instantiate()
	host.save_store = store
	host.resume_data = {"state": state}
	root.add_child(host)
	current_scene = host
	return host
func quit_resume(host: Control) -> Control:
	var original: Dictionary = Save.encode(host.state)
	host.card_management.save_quit_button.pressed.emit()
	host.card_management.save_quit_button.pressed.emit()
	check(host.phase == host.Phase.EXITED, "Save & Quit succeeds once with modal open")
	await process_frame
	await process_frame
	check(not is_instance_valid(host), "Old overlay and controller freed during fade")
	var menu = current_scene
	var saved: Dictionary = store.load_run()
	check(not saved.is_empty() and Save.encode(saved.state) == original, "Committed choice saved without cosmetic data")
	var resumed: Control = mount(saved.state)
	menu.free()
	check(resumed.card_management.shade.visible, "Resume directly reconstructs modal")
	return resumed
func run() -> void:
	store.path = "user://card_management_lifecycle.json"
	store.clear_run()
	var state = State.new()
	state.start(0, preload("res://encounters/expedition_rules.tres"), 8119)
	state.pending_choice = "card"
	state.card_offers = state.random_card_offers()
	var host: Control = mount(state)
	var offers: Array = state.card_offers.duplicate()
	host = await quit_resume(host)
	check(host.card_gallery.cards == offers and host.card_management.confirm_button.disabled, "Exact offers restored with no stale selection")
	var chosen: Resource = host.card_gallery.cards[0]
	host.card_management.select_card(chosen)
	host.card_management.confirm_button.pressed.emit()
	host.card_management.confirm_button.pressed.emit()
	check(store.load_run().state.acquired_cards.size() == 1, "Existing acquisition autosave occurs once")
	host.state.start_upgrade_event(2)
	host.show_outcome()
	host.card_management.select_card(host.card_gallery.cards[0])
	host.card_management.confirm_button.pressed.emit()
	var first_key: String = host.state.upgraded_this_event.keys()[0]
	host = await quit_resume(host)
	check(host.state.upgrades_remaining == 1 and host.card_management.heading.text.contains("1 upgrades remaining"), "Remaining mandatory upgrade restored")
	check(host.card_gallery.cards.all(func(c): return c.identity_key() != first_key), "Spent event identity stays excluded")
	host.show_system()
	check(host.card_management.shade.visible and host.state.pending_choice == "upgrade", "Overview cannot bypass mandatory upgrade")
	host.card_management.select_card(host.card_gallery.cards[0])
	host.card_management.confirm_button.pressed.emit()
	while host.state.player_pool().size() < host.state.deck_limit():
		host.state.pending_choice = "card"
		host.state.card_offers = host.state.random_card_offers()
		host.state.choose_card(0)
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	host.state.choose_card(0)
	host.show_outcome()
	var incoming_key: String = host.state.pending_card.identity_key()
	host = await quit_resume(host)
	check(host.card_management.mode == "replace" and host.incoming_portrait.card_data.identity_key() == incoming_key, "Incoming replacement restored")
	var removed_key: String = host.card_gallery.cards[0].identity_key()
	host.card_management.select_card(host.card_gallery.cards[0])
	host.replace_button.pressed.emit()
	host.replace_button.pressed.emit()
	var saved: Resource = store.load_run().state
	check(saved.pending_choice.is_empty() and saved.player_pool().size() == saved.deck_limit(), "Replacement commit autosaved exactly once")
	check(saved.player_pool().all(func(c): return c.identity_key() != removed_key), "Removed identity remains absent on resume")
	# Battle/FTL ownership cancels the modal synchronously before handing off.
	host.state.start_upgrade_event(1)
	host.show_outcome()
	host._begin_presentation(host.Phase.BATTLE_ENTRY)
	check(not host.card_management.shade.visible and host.screen.process_mode == Node.PROCESS_MODE_INHERIT, "Battle transition tears down overlay/input lock")
	host.free()
	await process_frame
	store.clear_run()
	print("Card management lifecycle: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
