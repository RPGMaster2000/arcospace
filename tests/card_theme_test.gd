extends SceneTree
const Cards = preload("res://scripts/cards/card_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Scene = preload("res://scenes/card.tscn")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func rgb(color: Color) -> Color:
	return Color(color.r, color.g, color.b)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var rng_before: int = Effects.combat_rng.state
	var palettes := {
		"materials": Color("ff7b76"), "energy": Color("6bd8ff"), "crew": Color("8eeb9c")
	}
	var backgrounds: Array[Color] = []
	for family in palettes:
		var view: Button = Scene.instantiate()
		view.inspection_enabled = false
		root.add_child(view)
		for card in Cards.CARDS:
			if card.family == family and card.cost > 0:
				view.card_data = card
				break
		var definition: String = JSON.stringify(
			[view.card_data.effects, view.card_data.cost, view.card_data.description]
		)
		var text: String = view.get_node("DescriptionLabel").text
		var expected: Color = palettes[family]
		var style: StyleBoxFlat = view.get_theme_stylebox("normal")
		backgrounds.append(style.bg_color)
		check(view.presentation_settings.card_base_color == Color("0b1724"), "Requested navy base")
		check(view.family_tint == expected, family + " exact requested primary color")
		check(
			(
				rgb(style.border_color) == expected
				and style.border_color.a >= 0.7
				and style.border_width_top == 2
			),
			family + " crisp two-pixel outline"
		)
		check(
			view.get_node("CostLabel").get_theme_color("font_color") == expected,
			family + " colored cost"
		)
		check(rgb(view.get_node("CostRule").default_color) == expected, family + " colored divider")
		check(
			view.get_node("ResourceIcon/" + family.capitalize()).color == expected,
			family + " original icon uses resource theme"
		)
		var wash: TextureRect = view.get_node("ThemeWash")
		check(
			wash.texture.gradient.get_color(0).a > wash.texture.gradient.get_color(2).a,
			family + " gradient fades toward body"
		)
		check(wash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gradient cannot intercept input")
		check(
			(
				view.get_node("ArtPlaceholder/Ship") is Polygon2D
				and view.get_node("ArtPlaceholder/Grid0") is Line2D
			),
			"Original main placeholder retained without new artwork"
		)
		var second: Button = Scene.instantiate()
		second.inspection_enabled = false
		root.add_child(second)
		second.card_data = view.card_data
		check(
			second.get_node("ThemeWash").texture == wash.texture,
			"Gradient texture shared between same-family cards"
		)
		second.free()
		check(
			style.shadow_size == 3 and style.shadow_color.a <= 0.10,
			"Unselected glow is subtle and bounded"
		)
		var body_font: FontVariation = view.get_node("DescriptionLabel").get_theme_font("font")
		var title_font: FontVariation = view.get_node("TitleLabel").get_theme_font("font")
		check(
			(
				is_equal_approx(body_font.variation_embolden, 0.65)
				and title_font.variation_embolden >= 0.2
				and view.get_node("DiscardButton").get_theme_font("font") == body_font
			),
			"Consistent modestly heavier typography including footer"
		)
		check(
			(
				view.get_node("DiscardButton").text
				== "Discard +%d %s" % [floori(view.card_data.cost / 3.0), family.capitalize()]
			),
			"Text-only footer preserves exact return without extra icons"
		)
		var bounds := view.get_rect()
		var base_scale := view.scale
		view.set_interaction_emphasis(true, true)
		style = view.get_theme_stylebox("normal")
		check(
			(
				style.border_width_top == 3
				and rgb(style.shadow_color) == expected
				and style.shadow_size == 4
			),
			family + " selected outline and family glow"
		)
		check(
			(
				style.expand_margin_top == 0
				and style.expand_margin_bottom == 0
				and style.expand_margin_left == 0
				and style.expand_margin_right == 0
				and view.get_rect() == bounds
				and view.scale == base_scale
			),
			"Selection never expands visual or input bounds"
		)
		view.set_ion_glow(true, Color.BLUE)
		check(
			rgb(view.get_theme_stylebox("normal").shadow_color) == expected,
			"Selected resource glow survives HUD storm refresh"
		)
		view.set_interaction_emphasis(false, false)
		style = view.get_theme_stylebox("normal")
		check(
			style.shadow_color == Color(Color.BLUE, 0.24) and style.shadow_size == 4,
			"Existing unselected storm cue retained"
		)
		view.set_ion_glow(false)
		view.set_preview_selected(true)
		view.set_interaction_emphasis(false, false)
		check(
			view.get_theme_stylebox("normal").border_width_top == 3,
			"Held preview keeps selection after touch release"
		)
		view.set_preview_selected(false)
		check(
			(
				view.get_theme_stylebox("normal").border_width_top == 2
				and view.get_theme_stylebox("normal").shadow_size == 3
			),
			"Preview dismissal restores unselected state"
		)
		view.set_playable(false, 0)
		view.set_discardable(true)
		style = view.get_theme_stylebox("normal")
		check(
			rgb(style.border_color) == expected and style.border_color.a < 0.94,
			"Unaffordable dimming retains family"
		)
		check(
			(
				view.get_node("DescriptionLabel").modulate.r >= 0.8
				and view.get_node("DescriptionLabel").modulate.a == 1
			),
			"Unaffordable rules remain high contrast"
		)
		check(
			(
				not view.get_node("DiscardButton").disabled
				and view.get_node("CostLabel").get_theme_color("font_color") == expected
			),
			"Discard remains available; cost retains its family"
		)
		view.set_playable(true, 1)
		check(
			view.get_node("DescriptionLabel").modulate == Color.WHITE,
			"Affordable state restores full text brightness"
		)
		check(
			(
				view.get_node("DescriptionLabel").text == text
				and (
					JSON.stringify(
						[view.card_data.effects, view.card_data.cost, view.card_data.description]
					)
					== definition
				)
			),
			"All state changes preserve card text and gameplay data"
		)
		view.free()
	check(
		(
			backgrounds[0] != backgrounds[1]
			and backgrounds[1] != backgrounds[2]
			and backgrounds[0] != backgrounds[2]
		),
		"Resource backgrounds differ"
	)
	check(Effects.combat_rng.state == rng_before, "Styling never consumes combat RNG")
	print("Card themes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
