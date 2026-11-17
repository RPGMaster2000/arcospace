extends SceneTree
## Supplied mapping, optional-art fallback and one real six-category battle hand.
const Motifs = preload("res://scripts/ui/card_motifs.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Face = preload("res://scripts/ui/card_face_text.gd")
const Scene = preload("res://scenes/card.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run() -> void:
	var file := FileAccess.open("res://docs/card_icon_mapping.csv", FileAccess.READ)
	check(file != null, "Supplied CSV is retained for exact mapping verification")
	var rows := {}
	var header := file.get_csv_line()
	check(
		header == PackedStringArray(["card_number", "card_name", "icon_key", "icon_path"]),
		"Read the supplied schema unchanged"
	)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 4:
			rows[int(row[0])] = row
	check(
		Cards.CARDS.size() == 80 and rows.size() == 80 and Motifs.ASSIGNMENTS.size() == 81,
		"All 80 shared identities plus one private enemy entry"
	)
	var view = Scene.instantiate()
	root.add_child(view)
	var used := {}
	for base in Cards.CARDS:
		var number: int = base.resource_path.get_file().get_slice("_", 0).to_int()
		var expected: PackedStringArray = rows[number]
		check(
			Motifs.ASSIGNMENTS[base.identity_key()] == expected[2],
			"Exact supplied motif for " + base.resource_path
		)
		for level in range(mini(base.max_upgrades, base.upgrade_effects.size()) + 1):
			var card: Resource = base.with_upgrade(level)
			var before := var_to_str(
				[card.effects, card.cost, card.description, card.card_name, card.identity_key()]
			)
			view.card_data = card
			var icon: TextureRect = view.get_node("ArtPlaceholder/EffectMotif")
			var texture := Motifs.texture_for(card)
			check(
				texture != null and texture.resource_path == expected[3],
				"Base/upgraded identity resolves its assigned PNG"
			)
			check(
				(
					icon.texture == texture
					and icon.visible
					and not view.get_node("ArtPlaceholder/Ship").visible
				),
				"Motif replaces only the placeholder foreground"
			)
			check(
				(
					icon.modulate == view.family_tint
					and icon.scale == Vector2.ONE
					and icon.size == Vector2(72, 56)
				),
				"Native motif size and existing family tint"
			)
			check(
				(
					icon.position == Vector2(51, 0)
					and view.get_node("ArtPlaceholder").size == Vector2(174, 56)
					and view.size == Vector2(198, 294)
				),
				"Centered inside the unchanged artwork/card geometry"
			)
			check(
				(
					view.get_node("ArtPlaceholder/Backdrop").visible
					and view.get_node("ArtPlaceholder/Grid0").visible
				),
				"Original procedural backing remains"
			)
			check(
				view.get_node("DescriptionLabel").text == Face.card_text(card),
				"Printed effect text is unchanged"
			)
			check(
				(
					var_to_str(
						[
							card.effects,
							card.cost,
							card.description,
							card.card_name,
							card.identity_key()
						]
					)
					== before
				),
				"Motif lookup never changes gameplay data"
			)
			used[expected[2]] = texture
		var storm := preload("res://scripts/combat_modifier.gd").new()
		storm.kind = {"energy": 2, "materials": 6, "crew": 7}[base.family]
		storm.active = true
		storm.ion_factor = 2.0
		check(
			Motifs.texture_for(storm.preview(base.with_upgrade(1))) == used[expected[2]],
			"Storm inspection previews retain the same motif"
		)
		storm.free()
	check(
		used.size() == 12 and Motifs.textures.size() == 12,
		"All twelve supplied textures load once into the shared cache"
	)
	for key in used:
		check(
			used[key].get_size() == Vector2(72, 56) and Motifs.textures[key] == used[key],
			"One reusable native-size Resource per motif"
		)
	var enemy: Resource = load("res://cards/enemy/iron_counterbattery.tres")
	view.card_data = enemy
	check(
		view.get_node("ArtPlaceholder/EffectMotif").texture == used.pierce,
		"Private Iron Counterbattery uses piercing motif"
	)
	check(not Cards.CARDS.has(enemy), "Enemy-only card remains outside the player library")
	var renamed: Resource = Cards.CARDS[0].with_upgrade(0)
	renamed.card_name = "Translated display name"
	check(
		Motifs.texture_for(renamed) == used.shield,
		"Lookup never depends on localized/display names"
	)
	var full_art: Resource = Cards.CARDS[0].with_upgrade(0)
	full_art.set_meta("card_art", used.attack)
	view.card_data = full_art
	check(
		(
			view.get_node("FullCardArt").visible
			and view.get_node("FullCardArt").texture == used.attack
			and not view.get_node("ArtPlaceholder").visible
		),
		"Explicit FullCardArt has priority"
	)
	var missing = preload("res://scripts/cards/card_data.gd").new()
	missing.card_name = "Unmapped optional card"
	view.card_data = missing
	check(
		(
			Motifs.texture_for(missing) == null
			and not view.get_node("ArtPlaceholder/EffectMotif").visible
			and view.get_node("ArtPlaceholder/Ship").visible
		),
		"Unmapped identity retains the complete old placeholder"
	)
	# Simulate an unavailable optional texture without deleting purchased source files.
	Motifs.textures.shield = null
	view.card_data = Cards.CARDS[0]
	check(
		(
			not view.get_node("ArtPlaceholder/EffectMotif").visible
			and view.get_node("ArtPlaceholder/Ship").visible
			and view.get_node("ArtPlaceholder/Accent").visible
		),
		"Missing texture safely restores the old foreground"
	)
	Motifs.textures.shield = used.shield
	view.card_data = Cards.CARDS[0]
	check(
		view.get_node("ArtPlaceholder/EffectMotif").visible,
		"Rebinding a valid texture restores its motif"
	)
	view.card_data = null
	check(
		not view.get_node("ArtPlaceholder/EffectMotif").visible,
		"Empty slots never show stale motifs"
	)
	view.free()
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {
		"player_ship": 0, "enemy_data": preload("res://ships/enemy/sentinel.tres"), "modifier": 0
	}
	board.get_node("BattleEffects").enabled = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(960, 540)
	root.add_child(board)
	board.enemy_timer.stop()
	board.player_materials = 30
	board.player_energy = 30
	board.player_crew = 30
	var hand: Array[Resource] = []
	for number in [1, 3, 11, 21, 24, 19]:
		hand.append(Cards.CARDS[number - 1])
	board.hand.cards.assign(hand)
	board.refresh_display()
	for frame in 4:
		await process_frame
	var categories := {}
	for path in board.card_slots:
		var card = board.get_node(path)
		categories[Motifs.ASSIGNMENTS[card.card_data.identity_key()]] = true
		check(
			card.get_node("ArtPlaceholder/EffectMotif").visible,
			"Real six-card hand presents its motif"
		)
	check(
		categories.size() == 6,
		"Six different supplied categories appear in the production battle hand"
	)
	if DisplayServer.get_name() != "headless":
		check(
			RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0],
			"Requested renderer is active"
		)
		if OS.get_environment("ARCOSPACE_CARD_ICON_CAPTURE") == "1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://docs/card_icon_hand.webp")
	board.queue_free()
	await process_frame
	print("Card motifs: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
