extends Control
## A development scene with the production components and a texture swap example.
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
const Reticle = preload("res://scripts/ui/holographic/reticle.gd")
const Cards = preload("res://scripts/cards/card_library.gd")

var _section: GridContainer
var _dialog: PanelContainer
var _progress: ProgressBar
var _original_profile := -1


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Holo.DEFAULT.surface_depth
	add_child(back)
	back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["top", "bottom", "left", "right"]:
		margins.add_theme_constant_override("margin_" + side, Holo.DEFAULT.padding.x)
	scroll.add_child(margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", Holo.DEFAULT.spacing + 4)
	margins.add_child(stack)
	stack.add_child(_label("Arcospace UI Showcase", Holo.DEFAULT.heading_size, Holo.DEFAULT.text))
	var palette := HFlowContainer.new()
	stack.add_child(palette)
	for key in ["edge", "materials", "energy", "crew", "hull", "shield", "friendly", "hostile", "warning", "reward", "muted"]:
		var swatch := Button.new()
		swatch.text = key.capitalize()
		swatch.disabled = true
		var tint: Color = Holo.DEFAULT.get(key)
		swatch.add_theme_stylebox_override("disabled", Holo.frame("compact", tint))
		swatch.add_theme_color_override("font_disabled_color", tint)
		palette.add_child(swatch)

	_section = GridContainer.new()
	_section.columns = 3
	_section.add_theme_constant_override("h_separation", Holo.DEFAULT.spacing)
	_section.add_theme_constant_override("v_separation", Holo.DEFAULT.spacing)
	stack.add_child(_section)
	for role in ["panel", "compact", "warning", "selection", "dialog", "reward"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Holo.frame(role))
		_section.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		column.add_child(_label(role.capitalize(), Holo.DEFAULT.label_size + 3, Holo.DEFAULT.text))
		match role:
			"panel": _build_meter(column)
			"compact": column.add_child(_label("Materials 18  ·  +4/t", Holo.DEFAULT.label_size, Holo.DEFAULT.materials))
			"warning": column.add_child(_label("Pressure 72 / 100", Holo.DEFAULT.label_size, Holo.DEFAULT.warning))
			"selection":
				var reticle := Reticle.new()
				reticle.custom_minimum_size = Vector2(64, 58)
				column.add_child(reticle)
			"dialog":
				_dialog = panel
				_button(column, "Replay entrance", func(): Motion.reveal(_dialog))
			"reward": column.add_child(_label("+15 Salvage", Holo.DEFAULT.label_size, Holo.DEFAULT.reward))

	var actions := HFlowContainer.new()
	stack.add_child(actions)
	_button(actions, "Intercept", func(): _progress.value = fmod(_progress.value + 27.0, 101.0), Holo.DEFAULT.friendly)
	var tab := Button.new()
	tab.text = "Selected"
	tab.toggle_mode = true
	tab.set_pressed_no_signal(true)
	_style_button(actions, tab, Holo.DEFAULT.energy)
	var locked := _button(actions, "FTL locked", Callable(), Holo.DEFAULT.warning)
	locked.disabled = true
	_button(actions, "Abort", func(): _progress.value = 20.0, Holo.DEFAULT.hostile)
	var replacement := Holo.DEFAULT.duplicate(true) as Holo.Settings
	var checker := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("193247"), Color("50365c")])
	checker.gradient = gradient
	checker.fill_to = Vector2(1, 1)
	replacement.frames["button.normal"] = checker
	replacement.backgrounds["compact"] = checker
	var sample := PanelContainer.new()
	sample.add_theme_stylebox_override("panel", Holo.frame("compact", Color.TRANSPARENT, "", replacement))
	sample.add_child(_label("Panel art", Holo.DEFAULT.label_size, Holo.DEFAULT.text))
	actions.add_child(sample)
	var authored := Button.new()
	authored.text = "Texture replacement"
	authored.custom_minimum_size.y = Holo.DEFAULT.touch_height
	Holo.action(authored, Color.TRANSPARENT, false, replacement)
	actions.add_child(authored)

	var motion := OptionButton.new()
	for label in ["Minimal preview", "Standard preview", "Cinematic preview"]: motion.add_item(label)
	_original_profile = Motion.Preferences.ui_motion()
	motion.select(_original_profile)
	motion.item_selected.connect(func(profile: int):
		# A scene-local preview. Launching the showcase never writes preferences.
		Motion.Preferences._ui_motion = profile
		Motion.reveal(_dialog))
	_style_button(actions, motion, Holo.DEFAULT.edge)

	stack.add_child(_label("Card rarity", Holo.DEFAULT.heading_size, Holo.DEFAULT.text))
	var hand := HFlowContainer.new()
	stack.add_child(hand)
	for tier in [1, 2, 3]:
		for card in Cards.CARDS:
			if card.tier != tier: continue
			var view: Button = preload("res://scenes/card.tscn").instantiate()
			view.inspection_enabled = false
			view.card_data = card
			hand.add_child(view)
			break
	resized.connect(func(): _section.columns = 2 if size.x < 640 else 3)


func _build_meter(column: VBoxContainer) -> void:
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(115, 9)
	_progress.show_percentage = false
	_progress.value = 67
	column.add_child(_progress)
	Meter.attach(_progress, Holo.DEFAULT.shield)
	var readout := _label("Shields 67 / 100", Holo.DEFAULT.label_size, Holo.DEFAULT.text)
	column.add_child(readout)
	_progress.value_changed.connect(func(value): readout.text = "Shields %d / 100" % value)


func _label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Holo.DEFAULT.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


func _style_button(parent: Control, button: Button, tint: Color) -> void:
	button.custom_minimum_size.y = Holo.DEFAULT.touch_height
	Holo.action(button, tint)
	parent.add_child(button)
	Motion.bind_button(button)


func _button(parent: Control, title: String, action: Callable, tint: Color = Color.TRANSPARENT) -> Button:
	var button := Button.new()
	button.text = title
	_style_button(parent, button, tint)
	if action.is_valid(): button.pressed.connect(action)
	return button



func _exit_tree() -> void:
	if _original_profile >= 0: Motion.Preferences._ui_motion = _original_profile
