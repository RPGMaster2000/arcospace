extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
const Settings = preload("res://resources/card_presentation.tres")
const Data = preload("res://scripts/cards/card_data.gd")
var checks: int = 0
var failures: int = 0
var taps: int = 0
var discards: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for n in range(8): await process_frame
func click(point: Vector2, button: int, pressed: bool) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	root.push_input(motion,true)
	var event = InputEventMouseButton.new()
	event.position=point; event.global_position=point; event.button_index=button; event.pressed=pressed
	root.push_input(event,true)
func touch(point: Vector2, pressed: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.position=point; event.index=3; event.pressed=pressed
	root.push_input(event,true)
func overlay() -> Node: return root.get_node_or_null("CardInspection")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/inspection-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	var original: String = snapshot()
	var sample = preload("res://scripts/cards/card_data.gd").new()
	sample.effects = {"damage": 6}
	var summary = preload("res://scripts/ui/card_summary.gd")
	for length in [49, 50]:
		sample.description = "a".repeat(length)
		check(summary.card_text(sample) == sample.description, "Full description retained through 50 characters")
	sample.description = "a".repeat(51)
	check(summary.card_text(sample) == summary.describe(sample.effects), "Shorthand begins above 50 characters")
	check(summary.card_text(sample, 60) == sample.description, "Inspector threshold can retain longer text")
	var view=load("res://scenes/card.tscn").instantiate()
	view.position=Vector2(25,180)
	root.add_child(view)
	view.pressed.connect(func(): taps+=1)
	view.discard_requested.connect(func(): discards+=1)
	for base in Cards.CARDS:
		for level in [0,1,2]:
			view.card_data=base.with_upgrade(level)
			await process_frame
			var art: Control=view.get_node("ArtPlaceholder")
			var description: Label=view.get_node("DescriptionLabel")
			check(art.position==Vector2(12,101) and art.size==Vector2(174,74) and art.visible,"Fixed artwork "+view.card_data.card_name)
			check(description.get_theme_font_size("font_size")==14 and description.position.y==180,"Compact font and fixed description")
			check(description.get_minimum_size().y<=view.get_node("DiscardButton").position.y-description.position.y,"Description clears footer")
			check(view.get_node("TitleLabel").position.y+view.get_node("TitleLabel").get_minimum_size().y<=101 and view.get_node("TitleLabel").get_line_count()<=2,"Full title clears artwork")
	view.card_data=Cards.CARDS[52]
	await settle()
	var point: Vector2=view.get_global_rect().get_center()
	click(point,MOUSE_BUTTON_LEFT,true); click(point,MOUSE_BUTTON_LEFT,false)
	check(taps==1,"Normal tap remains a tap")
	click(point,MOUSE_BUTTON_RIGHT,true); click(point,MOUSE_BUTTON_RIGHT,false)
	check(discards==1,"Right click still discards")
	view.disabled=true
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await create_timer(.25).timeout
	check(overlay()!=null and overlay().is_open(),"Unaffordable card middle-click inspection")
	if overlay()==null:
		quit(1); return
	click(point,MOUSE_BUTTON_MIDDLE,false)
	check(overlay().current_card==view.card_data and overlay().visual.card_data==view.card_data,"Original card resource reused")
	check(overlay().visual.get_node("DescriptionLabel").text==view.get_node("DescriptionLabel").text and overlay().visual.get_node("ArtPlaceholder").get_rect()==view.get_node("ArtPlaceholder").get_rect(),"Identical internal text and artwork geometry")
	check(overlay().visual.scale.x==overlay().visual.scale.y and not overlay().visual.get_node("DiscardButton").visible,"Uniform noninteractive copy")
	for size in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450),Vector2i(686,384)]:
		root.size=size
		await settle()
		var inspect=overlay()
		check(inspect.combined_rect.position.x>=15 and inspect.combined_rect.end.x<=inspect.shade.size.x-15,"Combined horizontal margins")
		check(inspect.info.position.x>=inspect.visual.position.x+198*inspect.visual.scale.x+19,"Side by side without overlap")
		check(inspect.info.get_global_rect().end.y<=inspect.shade.size.y-15,"Panel fits viewport %s: panel=%s shade=%s minimum=%s" % [size,inspect.info.get_global_rect(),inspect.shade.size,inspect.info.get_minimum_size()])
		check(inspect.close_button.get_global_rect().end.y<=inspect.info.get_global_rect().end.y,"Close always visible")
		check(inspect.level_panels.size()==3 and inspect.level_panels[0].get_meta("current_level"),"All levels, highlighted base")
		await capture("landscape-%d" % size.x)
	overlay().close_button.pressed.emit()
	root.size=Vector2i(1281,720) # A resize during dismissal must not strand a modal.
	await create_timer(.25).timeout
	check(not overlay().is_open() and taps==1 and discards==1,"Close is read-only")
	view.disabled=false
	root.size=Vector2i(1280,720)
	await settle()
	point=view.get_global_rect().get_center()
	# Genuine touchscreen hold remains open after release and never activates a Button.
	touch(point,true)
	await create_timer(.48).timeout
	check(overlay().is_open(),"Touch hold opens inspection")
	touch(point,false)
	await settle()
	check(overlay().is_open() and taps==1 and discards==1,"Touch release does not activate/play")
	var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true)
	await create_timer(.25).timeout
	check(not overlay().is_open(),"Escape closes overlay")
	# Movement cancels a pending hold before the gallery's drag handler consumes the event.
	touch(point,true)
	var drag=InputEventScreenDrag.new(); drag.index=3; drag.position=point+Vector2(0,30); drag.relative=Vector2(0,30)
	root.push_input(drag,true)
	await create_timer(.48).timeout
	touch(drag.position,false)
	check(not overlay().is_open(),"Movement cancels pending hold")
	# Source replacement cancels a pending timer; closing the source view dismisses an open overlay.
	touch(point,true)
	view.card_data=Cards.CARDS[61].with_upgrade(2)
	await create_timer(.48).timeout
	check(not overlay().is_open(),"Changed hand card cancels pending hold")
	touch(point,false)
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await create_timer(.25).timeout
	click(point,MOUSE_BUTTON_MIDDLE,false)
	check(overlay().level_panels[2].get_meta("current_level") and overlay().heading.text==Cards.CARDS[61].card_name,"Current upgrade highlighted; base name retained")
	check(overlay().level_panels[0].get_child(0).get_child(1).text==Data.describe_effects(Cards.CARDS[61].effects),"Base details from actual unmodified definition")
	check(overlay().level_panels[2].get_child(0).get_child(1).text==Data.describe_effects(Cards.CARDS[61].upgrade_effects[1]),"Upgrade II details from actual definition")
	view.hide()
	await settle()
	check(not overlay().is_open(),"Hidden source closes inspection")
	view.show()
	view.card_data=null
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await process_frame
	click(point,MOUSE_BUTTON_MIDDLE,false)
	check(not overlay().is_open(),"Empty hand slots cannot inspect a missing card")
	view.free()
	var transient=load("res://scenes/card.tscn").instantiate()
	transient.card_data=Cards.CARDS[0]
	transient.position=Vector2(25,180)
	root.add_child(transient)
	await settle()
	point=transient.get_global_rect().get_center()
	touch(point,true)
	transient.free()
	await create_timer(.48).timeout
	touch(point,false)
	check(not overlay().is_open(),"Removing a source safely cancels its pending timer")
	await test_gallery()
	await test_battle()
	check(snapshot()==original,"All card values unchanged")
	print("Card inspection: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func snapshot() -> String:
	var values: Array=[]
	for card in Cards.CARDS: values.append([card.identity_key(),card.cost,card.family,card.tier,card.effects,card.upgrade_effects,card.play_again])
	return JSON.stringify(values)
func test_gallery() -> void:
	var host=load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	current_scene=host
	host.state.pending_choice="card"; host.state.card_offers=host.state.random_card_offers()
	host.show_outcome()
	await settle()
	var portrait: Control=host.card_gallery.grid.get_child(0)
	var point: Vector2=portrait.get_global_rect().get_center()
	var scroll_before: int=host.scroll.scroll_vertical
	touch(point,true)
	await create_timer(.48).timeout
	check(overlay().is_open(),"Gallery touch hold opens shared overlay")
	touch(point,false)
	check(host.state.pending_choice=="card" and host.state.acquired_cards.is_empty() and host.card_management.selected_card == null,"Hold never acquires or opens confirmation")
	overlay().dismiss(true)
	await create_timer(.3).timeout
	check(host.scroll.scroll_vertical==scroll_before,"Scroll position preserved")
	# Wait out the intentional release debounce and use the card's restored position.
	point=portrait.get_global_rect().get_center()
	for attempt in range(120):
		if host.card_gallery.scroll.allows_activation() and Time.get_ticks_msec()>=portrait.hold_input.blocked_until: break
		await process_frame
	# Short tap updates inline details; only the fixed footer acquires.
	click(point,MOUSE_BUTTON_LEFT,true); click(point,MOUSE_BUTTON_LEFT,false)
	check(host.card_management.selected_card == portrait.card_data,"Normal acquisition tap selects inline details")
	host.card_management.confirm_button.pressed.emit()
	await create_timer(.25).timeout
	host._show_current_deck()
	await settle()
	portrait=host.current_deck_viewer.gallery.grid.get_child(0)
	point=portrait.get_global_rect().get_center()
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await create_timer(.25).timeout
	click(point,MOUSE_BUTTON_MIDDLE,false)
	check(overlay().is_open(),"Deck viewer uses same inspection overlay")
	var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true)
	await create_timer(.25).timeout
	check(not overlay().is_open() and host.current_deck_viewer.shade.visible,"Escape closes only read-only overlay, preserving parent viewer")
	host.current_deck_viewer.dismiss()
	host.state.start_upgrade_event(2); host.show_outcome()
	await settle()
	portrait=host.card_gallery.grid.get_child(0)
	point=portrait.get_global_rect().get_center()
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await create_timer(.25).timeout
	click(point,MOUSE_BUTTON_MIDDLE,false)
	check(overlay().is_open() and host.state.upgrades_remaining==2 and host.state.upgraded_cards.is_empty(),"Upgrade gallery inspection spends no upgrade")
	overlay().dismiss(true)
	while host.state.pending_choice == "upgrade":
		host.state.choose_upgrade(host.state.upgrade_candidates()[0].identity_key())
	while host.state.player_pool().size() < host.state.deck_limit():
		host.state.pending_choice="card"; host.state.card_offers=host.state.random_card_offers(); host.state.choose_card(0)
	host.state.pending_choice="card"; host.state.card_offers=host.state.random_card_offers(); host.state.choose_card(0)
	host.show_outcome()
	await settle()
	host._select_replacement(host.state.player_pool()[1])
	var selected_key: String=host.replacement_key
	var incoming: Resource=host.state.pending_card
	portrait=host.card_gallery.grid.get_child(0)
	point=portrait.get_global_rect().get_center()
	touch(point,true)
	await create_timer(.48).timeout
	touch(point,false)
	check(overlay().is_open() and host.replacement_key==selected_key and host.state.pending_card==incoming and host.state.player_pool().size()==36,"Replacement hold preserves selection, fixed incoming and ownership")
	click(Vector2(5,5),MOUSE_BUTTON_LEFT,true)
	click(Vector2(5,5),MOUSE_BUTTON_LEFT,false)
	await create_timer(.25).timeout
	check(not overlay().is_open() and host.view_kind=="replacement" and host.replacement_key==selected_key,"Outside dismissal preserves replacement screen")
	# Actual scroll gesture before the hold deadline must scroll and never inspect/select.
	var scroll=host.card_gallery.scroll
	scroll.scroll_vertical=0; scroll.blocked_until=0
	await settle()
	point=host.card_gallery.grid.get_child(0).get_global_rect().get_center()
	touch(point,true)
	var drag=InputEventScreenDrag.new(); drag.index=3; drag.position=point+Vector2(0,-80); drag.relative=Vector2(0,-80)
	root.push_input(drag,true)
	await create_timer(.48).timeout
	touch(drag.position,false)
	check(not overlay().is_open() and scroll.scroll_vertical>0 and host.replacement_key==selected_key,"Gallery drag cancels hold and selection")
	await create_timer(.2).timeout
	scroll.scroll_vertical=0
	await settle()
	point=host.card_gallery.grid.get_child(0).get_global_rect().get_center()
	click(point,MOUSE_BUTTON_MIDDLE,true)
	await create_timer(.25).timeout
	click(point,MOUSE_BUTTON_MIDDLE,false)
	host.free()
	await settle()
	check(not overlay().is_open(),"Source removal safely dismisses overlay")

func test_battle() -> void:
	var board=load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled=false
	root.add_child(board)
	current_scene=board
	board.enemy_timer.stop()
	if board.battle_effects.busy: await board.battle_effects.finished
	board.player_materials=0; board.player_energy=0; board.player_crew=0
	board.refresh_display()
	await settle()
	var card: Control=board.get_node(board.card_slots[0])
	var before: String=JSON.stringify([board._both_states(),board.turn_number,board.current_actor,board.hand.cards,board.salvage])
	var point: Vector2=card.get_global_rect().get_center()
	touch(point,true)
	await create_timer(.48).timeout
	touch(point,false)
	check(board.hud.tactical.source == card and not overlay().is_open(),"Unaffordable combat card holds into tactical preview")
	board.hud.tactical.open_inspection()
	await create_timer(.25).timeout
	check(overlay().is_open(), "Inspect opens existing full overlay from unaffordable preview")
	check(JSON.stringify([board._both_states(),board.turn_number,board.current_actor,board.hand.cards,board.salvage])==before,"Combat inspection never spends, discards, draws or advances turn")
	await capture("combat")
	overlay().dismiss(true)
	board.hud.tactical.dismiss(true)
	# A pending hold changing to another card cancels release activation on the new identity too.
	var old_card: Resource=card.card_data
	touch(point,true)
	card.card_data=Cards.CARDS[0]
	await create_timer(.48).timeout
	touch(point,false)
	check(not overlay().is_open() and board.turn_number==1,"Hand replacement cancels pending gesture safely")
	card.card_data=old_card
	board.free()
	await settle()
