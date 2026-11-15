extends SceneTree
const Catalog = preload("res://scripts/expedition/faction_catalog.gd")
const Details = preload("res://scripts/ui/system_details.gd")
const SAVE = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/fleet-expansion")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/fleet-expansion/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func activate(control: Control, touch: bool) -> void:
	for pressed in [true, false]:
		var event: InputEvent = (
			InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		)
		if event is InputEventMouseButton:
			event.button_index = MOUSE_BUTTON_LEFT
		else:
			event.index = 0
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280, 720)
	var profiles: Array = []
	for faction in Catalog.DEFAULTS:
		for profile in Catalog.roster(faction):
			if profile.minimum_defense_system > 1:
				profiles.append(profile)
		if faction.mothership_minimum_system > 1:
			profiles.append(faction.mothership)
	check(profiles.size() == 11, "Eight standard ships and three new motherships")
	for profile in profiles:
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {
			"player_ship": 0, "enemy_ship": 0, "enemy_data": profile, "modifier": 0
		}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		await settle()
		var model: Node3D = board.get_node("BattleView/Viewport/Battlefield/EnemyShip")
		check(
			model.scene_file_path == profile.model_scene.resource_path,
			"Actual battlefield uses authored model: " + profile.ship_name
		)
		check(
			(
				board.enemy_hull_capacity == profile.hull_capacity
				and board.enemy_shields == profile.shields
			),
			"Combat values match new profile"
		)
		check(
			board.enemy_hand.card_pool == profile.starting_cards,
			"Actual enemy hand uses the defined existing-card deck"
		)
		check(
			model.has_method("animate_hit") and model.has_method("set_shield_strength"),
			"Existing animation interface intact"
		)
		var parts := model.get_node("Body").find_children("*", "MeshInstance3D", true, false)
		check(parts.size() <= 12, "Conservative primitive draw count")
		for part in parts:
			check(part.mesh is PrimitiveMesh, "Only native primitive meshes")
			var box: AABB = part.mesh.get_aabb()
			for corner in range(8):
				var point: Vector3 = (
					model.get_node("Shield").global_transform.affine_inverse()
					* (part.global_transform * box.get_endpoint(corner))
				)
				check(
					point.length() < 1.05,
					"Shield encloses " + profile.ship_name + " / " + part.name
				)
		await capture(profile.resource_path.get_file().get_basename() + "-battle")
		# Unobstructed silhouette evidence without changing any combat/profile values.
		model.get_node("Shield").hide()
		await capture(profile.resource_path.get_file().get_basename() + "-hull")
		board.free()
		await process_frame
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "defense"
	host.rules.factions.assign([Catalog.DEFAULTS[2]])
	host.rules.debug_seed = 42
	root.add_child(host)
	host.state.defense.complete = true
	check(host.state.generate_system(), "Production overview advances to expanded fleet system")
	host.show_system()
	await settle()
	var hud = host.screen.overview_hud
	for dimensions in [
		Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 573)
	]:
		root.size = dimensions
		await settle()
		for ratio in [.25, .65, .9]:
			host.state.defense.pressure = ratio * host.state.defense.tuning.pressure_maximum
			host.screen.set_defense_status(host.state)
			check(
				is_equal_approx(hud.pressure_bar.value, ratio * 100),
				"Pressure bar reads authoritative normalized pressure"
			)
			check(
				(
					hud.pressure_fill.bg_color
					== (
						Color("77e596")
						if ratio < .5
						else (Color("ffaf58") if ratio < .8 else Color("ff646e"))
					)
				),
				"Pressure danger palette"
			)
		host.state.defense.pressure = 0
		host.screen.set_defense_status(host.state)
		check(
			root.get_visible_rect().encloses(hud.panels[2].get_global_rect()),
			"Consolidated panel fits viewport"
		)
		check(hud.details_button.get_global_rect().size.y >= 44, "Android touch target retained")
		check(
			hud.turret_count.text.begins_with("Turrets: 0"), "Empty sites are not deployed turrets"
		)
		await capture("overview-%d-%d" % [dimensions.x, dimensions.y])
		var before := SAVE.encode(host.state)
		await activate(hud.details_button, dimensions.x == 960)
		var overlay = host.screen.system_details_overlay
		check(
			overlay.shade.visible and not host._map_input_allowed(),
			"Real mouse/touch opens details and blocks map gestures"
		)
		check(
			(
				overlay.body.text.contains("ACTIVE ENEMY FORCES")
				and not overlay.body.text.contains("AXIOM Command Nexus")
			),
			"Hidden mothership identity stays private"
		)
		check(
			root.get_visible_rect().encloses(overlay.panel.get_global_rect()),
			"Scrolling details panel fits viewport"
		)
		await capture("details-%d-%d" % [dimensions.x, dimensions.y])
		await activate(overlay.close, dimensions.x == 960)
		check(not overlay.shade.visible, "Mouse/touch closes modal")
		check(
			SAVE.encode(host.state) == before,
			"Opening, closing and rendering details cannot advance strategic time or RNG"
		)
	var sites: Array = host.state.defense.construction_sites.keys()
	check(not sites.is_empty(),"Construction fixture has a legal site")
	if not sites.is_empty():
		host.state.salvage = host.state.defense.tuning.turret_salvage_cost
		check(host._deploy_turret(sites[0]),"Actual successful purchase deploys a turret")
		check(hud.turret_count.text.begins_with("Turrets: 1"),"Deployment notification refreshes the actual count")
		var restored: Resource = SAVE.new().decode(SAVE.encode(host.state),host.state.rules)
		check(restored != null,"Installed turret restores")
		if restored != null:
			host.screen.set_defense_status(restored)
			check(hud.turret_count.text.begins_with("Turrets: 1"),"Restored authoritative turret count displayed")
	# Actual touch selection of an expanded-roster map marker, followed by travel.
	var target: Control = host.star_map.markers[0]
	for tap in range(2):
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = target.get_global_rect().get_center()
			event.pressed = pressed
			root.push_input(event, true)
	check(
		host.state.travel_destination == 0 and host.state.navigation.leg_active,
		"Expanded-fleet map marker supports Android selection and travel"
	)
	host.free()
	await process_frame
	print("Faction expansion visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
