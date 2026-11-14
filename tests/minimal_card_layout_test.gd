extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
const Scene = preload("res://scenes/card.tscn")
const Modifier = preload("res://scripts/combat_modifier.gd")
var checks := 0
var failures := 0
var records: Array = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280, 720)
	var views: Array = []
	for slot in range(6):
		var view = Scene.instantiate()
		view.inspection_enabled = false
		root.add_child(view)
		view.position = Vector2(24 + slot * 204, 20)
		views.append(view)
	var all: Array = []
	for base in Cards.CARDS:
		for level in range(mini(base.max_upgrades, base.upgrade_effects.size()) + 1):
			var card: Resource = base.with_upgrade(level)
			all.append(card)
			var storm := Modifier.new()
			storm.kind = {"energy": 2, "materials": 6, "crew": 7}[card.family]
			storm.active = true
			storm.ion_factor = 2.0
			var amplified: Resource = storm.preview(card)
			amplified.set_meta("layout_storm", true)
			all.append(amplified)
			storm.free()
	for start in range(0, all.size(), 6):
		for slot in range(6):
			if start + slot >= all.size():
				break
			views[slot].card_data = all[start + slot]
		for frame in range(2):
			await process_frame
		for slot in range(6):
			if start + slot >= all.size():
				break
			var view = views[slot]
			var card: Resource = view.card_data
			var id: String = (
				"%s / upgrade %d%s"
				% [
					card.identity_key(),
					card.upgrade_level,
					" / storm ×2" if card.has_meta("layout_storm") else ""
				]
			)
			var title: Label = view.get_node("TitleLabel")
			var cost: Label = view.get_node("CostLabel")
			var text: Label = view.get_node("DescriptionLabel")
			var footer: Button = view.get_node("DiscardButton")
			check(
				view.size == Vector2(198, 294) and view.custom_minimum_size == Vector2(198, 294),
				id + " exact card geometry"
			)
			check(cost.text == str(card.cost), id + " exact resource cost")
			check(
				view.get_node("ArtPlaceholder/Backdrop").get_global_rect().size.is_equal_approx(
					view.get_node("ArtPlaceholder").get_global_rect().size
				),
				id + " placeholder paint fills the enlarged artwork region"
			)
			check(
				view.get_node("ArtPlaceholder").size == Vector2(174, 60),
				id + " common enlarged artwork band"
			)
			check(
				text.get_theme_font_size("font_size") == 16 and text.size.x == 178,
				id + " larger shared effect typography without per-card shrinking"
			)
			check(
				cost.get_rect().end.x <= 194 and cost.position.x >= 157,
				id + " full cost stays inside card and clears icon"
			)
			for symbol in ["↻", "■", "◆", "●", "≤", "≥"]:
				check(
					text.get_theme_font("font").has_char(symbol.unicode_at(0)),
					id + " bundled font supplies " + symbol
				)
			var font: Font = title.get_theme_font("font")
			var lines := title.text.split("\n")
			check(lines.size() <= 2, id + " no hidden title line")
			check(
				title.text.replace("\n", " ") == card.card_name.trim_suffix("++").trim_suffix("+"),
				id + " complete name preserved"
			)
			check(
				font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= 126,
				id + " title first line clears cost icon"
			)
			if lines.size() > 1:
				check(
					(
						font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
						<= title.size.x
					),
					id + " full-width second title line fits"
				)
				check(
					(
						(
							title.position.y
							+ font.get_height(18)
							+ title.get_theme_constant("line_spacing")
						)
						>= cost.get_rect().end.y
					),
					id + " second title line below cost"
				)
			check(
				title.get_rect().end.y <= view.get_node("ArtPlaceholder").position.y,
				id + " header clears art"
			)
			check(
				view.get_node("ResourceIcon").get_node(card.family.capitalize()).visible,
				id + " resource-family icon visible"
			)
			check(
				(
					footer.text.contains(str(floori(card.cost / 3.0)))
					and footer.tooltip_text.contains(card.family.capitalize())
				),
				id + " authoritative discard value and family"
			)
			var footer_width := (
				footer
				. get_theme_font("font")
				. get_string_size(
					footer.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					footer.get_theme_font_size("font_size")
				)
				. x
			)
			check(footer_width <= footer.size.x - 8, id + " complete text-only discard footer fits")
			check(not text.text.is_empty(), id + " effect summary present")
			check(
				not text.clip_text and text.max_lines_visible == -1,
				id + " important effects never hidden by clipping/ellipsis"
			)
			for hand_scale in [1.0, (960.0 - 32 - 50) / (198 * 6)]:
				view.discard_target_height = 44.0 / hand_scale
				view.refresh_card()
				# Label shaping is the production renderer's actual measured text.
				var needed: float = text.get_minimum_size().y
				var available: float = footer.position.y - 7 - text.position.y
				check(
					needed <= available + 0.1,
					(
						id
						+ (
							" effect overflow scale %s: need %.1f / %.1f (%s)"
							% [hand_scale, needed, available, text.text.replace("\n", " | ")]
						)
					)
				)
			check(view.size == Vector2(198, 294), id + " footer cannot expand card")
			records.append(
				{
					"id": card.identity_key(),
					"level": card.upgrade_level,
					"amplified": card.has_meta("layout_storm"),
					"name": card.card_name,
					"text": text.text,
					"lines": text.get_line_count(),
					"height": text.get_minimum_size().y,
					"font": text.get_theme_font_size("font_size"),
					"art_size": str(view.get_node("ArtPlaceholder").size),
					"effect_width": text.size.x
				}
			)
			view.discard_target_height = 44
			view.refresh_card()
	for view in views:
		view.free()
	var directory := "res://.godot/testlogs/minimal-cards"
	DirAccess.make_dir_recursive_absolute(directory)
	var report := FileAccess.open(directory + "/layout-audit.json", FileAccess.WRITE)
	report.store_string(
		JSON.stringify(
			{"variants": all.size(), "checks": checks, "failures": failures, "cards": records}, "  "
		)
	)
	report.close()
	print(
		"Minimal card layout: %d variants, %d checks, %d failures" % [all.size(), checks, failures]
	)
	quit(1 if failures else 0)
