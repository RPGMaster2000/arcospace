extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	# Retained exploration-mode regression.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle():
	for i in range(24): await process_frame
func run():
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	var index := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle": index = i
	host.map_destination = index
	host.show_battle_preview(index)
	await settle()
	var briefing = host.view.get_child(0)
	var modifier = briefing.find_child("ModifierDetails",true,false)
	var children: Array = briefing.get_children()
	var rng: int = host.state.rng.state
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await settle()
		check(briefing.compact == (dimensions.y < 600),"Existing panel switches typography at breakpoint")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page+1,"Live resize fits without scrolling")
		check(briefing.get_children() == children,"Resize retains all controls and modal identity")
		check(modifier.pressed.get_connections().size() == 2,"One presentation callback plus existing UI sound binding")
	# Reconfiguration is also safe for a future reusable encounter panel.
	briefing.configure(host.state.enemy_profile(host.state.encounters[index]),3,2,"+5 Energy",true,true)
	await settle()
	check(briefing.get_children() == children,"Updating facts does not duplicate widgets")
	check(briefing.compact,"Pursuit retains compact layout")
	modifier.pressed.emit()
	check(briefing._overlay.body.text.contains(host.state.Modifiers.description(2)),"Existing modifier button uses updated rules")
	check(host.state.rng.state == rng,"Layout consumes no gameplay RNG")
	host.free()
	print("Tactical live resize: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
