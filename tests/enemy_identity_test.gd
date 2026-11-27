extends SceneTree
const Flavor = preload("res://scripts/ui/enemy_card_flavor.gd")
const Board = preload("res://scenes/board_3d.tscn")
const Card = preload("res://scenes/card.tscn")
const Briefing = preload("res://scripts/ui/tactical_briefing.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Progression = preload("res://encounters/expedition_rules.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/enemy-identity")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/enemy-identity/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func fits(label: Label, name: String) -> void:
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var width: float = minf(120.0,label.size.x) if label.name == "TitleLabel" else label.size.x
	for line in label.text.split("\n"):
		check(
			font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * label.scale.x <= width + 1,
			name + ": text fits its actual width"
		)


func run() -> void:
	var previous := Preferences.skip_cinematics()
	var canonical := {}
	var view = Card.instantiate()
	root.add_child(view)
	for faction in Flavor.Factions.DEFAULTS:
		for ship in faction.standard_roster + faction.elite_roster + [faction.mothership]:
			if ship == null:
				continue
			check(
				ship.subtitle.begins_with(faction.display_name),
				"Catalog profile exposes faction in existing subtitle"
			)
			check(not ship.summary.is_empty(), "Every encounter has a short threat summary")
			var scaled: Resource = Progression.progression.scaled_enemy(ship, 4, true)
			check(
				Flavor.faction(scaled) == faction.id,
				"Scaled profiles keep their display-only faction identity"
			)
			var row := Briefing.new()
			root.add_child(row)
			row.configure(ship, 1, 0, "", false, false)
			check(
				(
					row._contact.text.contains(faction.display_name)
					and row._profile.text == ship.summary
				),
				"Existing tactical briefing receives faction and threat copy"
			)
			row.free()
			for id in Flavor.TITLES.get(faction.id, {}):
				var base: Resource = load("res://cards/%s.tres" % id)
				canonical[base.identity_key()] = base.card_name
				for level in range(mini(base.max_upgrades, base.upgrade_effects.size()) + 1):
					var card: Resource = base.with_upgrade(level)
					var before := var_to_str(
						[
							card.effects,
							card.cost,
							card.family,
							card.identity_key(),
							card.description,
							card.card_name
						]
					)
					view.display_title = Flavor.title(card, scaled)
					view.card_data = card
					view.refresh_card()
					check(view.size == Vector2(198, 294), "Aliases preserve exact card geometry")
					fits(view.get_node("TitleLabel"), view.display_title)
					var description: Label = view.get_node("DescriptionLabel")
					check(
						(
							description.get_line_count() * description.get_line_height()
							<= description.size.y + 1
						),
						"Mechanical description remains fully visible"
					)
					check(
						(
							var_to_str(
								[
									card.effects,
									card.cost,
									card.family,
									card.identity_key(),
									card.description,
									card.card_name
								]
							)
							== before
						),
						"Flavor cannot change card mechanics or identity"
					)
					check(
						Flavor.title(card, null) == card.card_name,
						"Unknown/player context retains canonical title"
					)
					var storm = preload("res://scripts/combat_modifier.gd").new()
					storm.kind = {"materials": 6, "energy": 2, "crew": 7}[card.family]
					storm.active = true
					storm.ion_factor = 2.0
					check(
						Flavor.title(storm.preview(card), scaled) == Flavor.title(card, scaled),
						"Storm previews preserve faction aliases and upgrades"
					)
					storm.free()
	view.free()
	var scenarios := [
		["siege_monitor", "enemy/iron_counterbattery", Vector2i(960, 540)],
		["choir_spore", "42_overloaded_warhead", Vector2i(960, 540)],
		["axiom_7", "19_system_disruption", Vector2i(1280, 720)],
		["rustjack", "42_overloaded_warhead", Vector2i(1280, 573)]
	]
	for scenario in scenarios:
		root.size = scenario[2]
		root.content_scale_size = Vector2i(960, 540)
		var profile: Resource = load("res://ships/enemy/%s.tres" % scenario[0])
		Preferences.set_skip_cinematics(true)
		var board = Board.instantiate()
		board.setup_settings = {"player_ship": 0, "enemy_data": profile, "modifier": 0, "seed": 8871}
		board.get_node("BattleEffects").enabled = false
		board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate(
			true
		)
		board.get_node("CardMotion").settings.travel_seconds = 0.03
		root.add_child(board)
		board.enemy_timer.stop()
		for frame in 3:
			await process_frame
		check(
			board.get_node("ModeLabel/Subtitle").text == profile.subtitle,
			"Faction/role persists when intro is skipped"
		)
		fits(board.get_node("ModeLabel/Subtitle"), profile.ship_name + " subtitle")
		var before: Dictionary = board._both_states()
		var rng_before := [board.hand.rng.state,board.enemy_hand.rng.state,board.enemy_ai.rng.state,board.ftl.rng.state]
		Preferences.set_skip_cinematics(false)
		var director = board.cinematic_director
		director.introduction(profile.ship_name, profile.subtitle)
		var deadline := Time.get_ticks_msec() + 5000
		while director._intro_caption.modulate.a < 0.95 and Time.get_ticks_msec() < deadline:
			await process_frame
		check(
			(
				director._intro_name.text == profile.ship_name
				and director._intro_class.text == profile.subtitle
			),
			"Actual intro displays name, faction and trait"
		)
		fits(director._intro_class, "Cinematic identity")
		await capture(scenario[0] + "-intro")
		director.skip_button.emit_signal("pressed")
		await process_frame
		check(
			(
				not director.active
				and board._both_states() == before
				and [board.hand.rng.state,board.enemy_hand.rng.state,board.enemy_ai.rng.state,board.ftl.rng.state] == rng_before
			),
			"Skip restores battle without altering combat or RNG"
		)
		Preferences.set_skip_cinematics(true)
		var card: Resource = load("res://cards/%s.tres" % scenario[1])
		board.enemy_hand.cards[0] = card
		board.current_actor = "enemy"
		board.set("enemy_" + card.family, 99)
		board._act("enemy", 0, false)
		await board.action_finished
		await process_frame
		board.enemy_timer.stop()
		var motion = board.get_node("CardMotion")
		check(not motion.lingering_cards.is_empty(), "Real enemy action presents a card")
		if not motion.lingering_cards.is_empty():
			var cue = motion.lingering_cards[0].get_children().filter(func(node): return node is Button)[0]
			var expected := Flavor.title(card, profile)
			check(
				cue.card_data == card and cue.display_title == expected,
				"Actual reveal uses the same card Resource with its themed title"
			)
			fits(cue.get_node("TitleLabel"), expected)
			check(
				board.get_node("LastActionLabel").text.contains(expected),
				"Last-action text matches the visible enemy card title"
			)
		await capture(scenario[0] + "-card")
		board.free()
		await process_frame
	for id in canonical:
		check(load(id).card_name == canonical[id], "Shared source names remain unchanged")
	Preferences.set_skip_cinematics(previous)
	print("Enemy identity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
