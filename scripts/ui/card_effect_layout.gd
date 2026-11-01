@tool
extends Control
## Compact, responsive card-face rows. Presentation only: effect dictionaries remain authoritative.
const Effects = preload("res://scripts/ui/card_effect_rows.gd")
const Data = preload("res://scripts/cards/card_data.gd")
const INK = Color("#e9f3fc")
const TEAL = Color("#64d6d0")
const AMBER = Color("#f0b978")
const RED = Color("#f58b86")

var body: VBoxContainer
var scroll: ScrollContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	scroll.add_child(body)

func _panel(treatment: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	match treatment:
		"conditional":
			style.bg_color = Color("#12323a")
			style.border_color = TEAL
			style.set_border_width_all(1)
		"risk":
			style.bg_color = Color("#392a20")
			style.border_color = AMBER
			style.set_border_width_all(1)
		"pierce":
			style.bg_color = Color("#3a242b")
			style.border_color = RED
			style.border_width_left = 3
		_:
			style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _row(text: String, kind: String = "") -> Control:
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 4)
	if not kind.is_empty():
		var icons: Dictionary = {
			"damage": "attack", "pierce": "pierce", "break_shields": "shield",
			"shields": "shield", "hull": "hull", "self_damage": "risk",
			"self_damage_regular": "risk", "materials": "materials",
			"energy": "energy", "crew": "resource_store", "synthesizer": "production",
			"reactor": "production", "quarters": "production",
			"enemy_production": "sabotage", "sabotage": "sabotage",
			"random_sabotage": "sabotage", "steal": "swap", "drain": "sabotage",
			"swap_resource": "swap", "swap_shields": "swap",
			"production_other": "production", "shield_collapse": "shield",
			"shield_collapse_below": "shield"
		}
		var asset: String = "res://assets/ui/card_effects/%s.png" % icons.get(kind, "energy")
		if ResourceLoader.exists(asset):
			var picture := TextureRect.new()
			picture.texture = load(asset)
			picture.custom_minimum_size = Vector2(13, 13)
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(picture)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 10)
	label.add_theme_font_size_override("bold_font_size", 10)
	label.add_theme_color_override("default_color", INK)
	label.text = text
	container.add_child(label)
	return container

func _plain_markup(markup: String) -> String:
	# The structured data already carries the effect identity; strip its old fake
	# background blocks so only real Godot panels own the decoration.
	return markup.replace("[bgcolor=#123a40]", "").replace("[bgcolor=#42301e]", "").replace("[bgcolor=#43232b]", "").replace("[/bgcolor]", "")

func _add_effect_rows(effects: Dictionary, target: VBoxContainer, conditional: bool = false) -> void:
	for key in effects:
		if key == "conditional":
			var rule: Dictionary = effects[key]
			var outer := _panel("conditional")
			target.add_child(outer)
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 2)
			outer.add_child(column)
			var predicate: Dictionary = rule.duplicate(true)
			predicate["then"] = {}
			predicate.erase("else")
			var title := _row("[color=#7be4dc]◇ " + Data.describe_effects({"conditional": predicate}).trim_suffix(": ") + "[/color]")
			column.add_child(title)
			_add_effect_rows(rule.get("then", {}), column, true)
			if not rule.get("else", {}).is_empty():
				column.add_child(_row("[color=#7be4dc]ELSE[/color]"))
				_add_effect_rows(rule["else"], column, true)
			continue
		if key == "pierce" and float(effects[key]) >= 1.0:
			continue # Represented on the damage row.
		var rows: Array[String] = Effects.describe({key: effects[key]})
		if key == "damage" and effects.has("pierce"):
			rows = Effects.describe({"damage": effects[key], "pierce": effects.pierce})
		for markup in rows:
			var treatment := ""
			if key in ["self_damage", "self_damage_regular", "shield_collapse"]:
				treatment = "risk" if key != "shield_collapse" else ""
			elif key == "damage" and float(effects.get("pierce", 0.0)) >= 1.0:
				treatment = "pierce"
			elif key == "shield_collapse_below":
				treatment = "conditional"
			if treatment.is_empty():
				target.add_child(_row(_plain_markup(markup), key))
			else:
				var panel := _panel(treatment)
				target.add_child(panel)
				panel.add_child(_row(_plain_markup(markup), key))

func configure(card: Resource) -> void:
	if not is_node_ready():
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if card == null:
		return
	_add_effect_rows(card.effects, body)
	if card.play_again:
		body.add_child(_row("[color=#7be4dc]↻[/color] Play again"))
