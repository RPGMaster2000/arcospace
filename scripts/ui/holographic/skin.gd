@tool
extends RefCounted
## Creates style instances so local visual changes never mutate shared assets.
const Frame = preload("res://scripts/ui/holographic/frame.gd")
const Settings = preload("res://scripts/ui/holographic/skin_settings.gd")
const DEFAULT = preload("res://resources/presentation/holographic_skin.tres")
const Sound = preload("res://scripts/audio/sfx.gd")


static func frame(role: String, tint: Color = Color.TRANSPARENT, state: String = "", skin: Settings = DEFAULT) -> Frame:
	var box := Frame.new()
	var accent := tint if tint != Color.TRANSPARENT else skin.edge
	match role:
		"warning": accent = skin.warning if tint == Color.TRANSPARENT else tint
		"reward": accent = skin.reward if tint == Color.TRANSPARENT else tint
		"selection": accent = skin.friendly if tint == Color.TRANSPARENT else tint
	var active := state in ["pressed", "selected"]
	var disabled := state == "disabled"
	var focus := role == "focus"
	var compact := role in ["compact", "marker", "status"]
	box.bg_color = Color(skin.surface.lerp(accent, 0.21 if active else (0.12 if state == "hover" else 0.035)), skin.surface.a)
	box.depth_color = skin.surface_depth
	box.border_color = Color(accent, 0.28 if disabled else (0.96 if active or focus else 0.73))
	box.border_width_top = 1.6 if active or focus else skin.line_width
	box.cut = skin.corner_cut * (0.66 if compact else 1.0)
	box.details = 2 if role in ["panel", "dialog", "warning", "reward", "selection"] else 1
	box.draw_center = not focus
	box.shadow_size = 3 if active else 2
	box.shadow_color = Color(accent, skin.glow * (0.75 if active or focus else 0.36))
	if disabled: box.bg_color = Color(skin.surface_depth, 0.9)
	box.content_margin_left = skin.padding.x
	box.content_margin_right = skin.padding.x
	box.content_margin_top = skin.padding.y
	box.content_margin_bottom = skin.padding.y
	if compact: box.set_content_margin_all(skin.compact_padding)
	apply_assets(box, role, state, skin)
	return box


static func apply_assets(box: Frame, role: String, state: String = "", skin: Settings = DEFAULT) -> void:
	var key := role + "." + state
	var image: Texture2D = skin.frames.get(key, skin.frames.get(role, skin.frames.get(role.get_slice(".", 0))))
	var base := role.get_slice(".", 0)
	box.background_texture = skin.backgrounds.get(key, skin.backgrounds.get(role, skin.backgrounds.get(base)))
	box.ornament = skin.ornaments.get(key, skin.ornaments.get(role, skin.ornaments.get(base)))
	if image == null: return
	var replacement := StyleBoxTexture.new()
	replacement.texture = image
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var extent := image.get_width() if side in [SIDE_LEFT, SIDE_RIGHT] else image.get_height()
		replacement.set_texture_margin(side, clampf(skin.slice_margins[side], 0, extent * 0.45))
	box.frame_texture = replacement


static func family(key: String, skin: Settings = DEFAULT) -> Color:
	match key:
		"materials", "synthesizer": return skin.materials
		"energy", "reactor": return skin.energy
		"crew", "quarters": return skin.crew
		"hull": return skin.hull
		"shields": return skin.shield
		"salvage": return skin.reward
		_: return skin.edge


static func family_surface(key: String, skin: Settings = DEFAULT) -> Color:
	match key:
		"materials", "synthesizer": return skin.materials_surface
		"energy", "reactor": return skin.energy_surface
		"crew", "quarters": return skin.crew_surface
		_: return skin.surface


static func action(button: Button, tint: Color = Color.TRANSPARENT, primary: bool = false, skin: Settings = DEFAULT) -> void:
	var role := "tab" if button.toggle_mode else "button"
	var accent := (skin.friendly if primary else skin.edge) if tint == Color.TRANSPARENT else tint
	for key in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := frame("focus" if key == "focus" else role, accent, "pressed" if key == "hover_pressed" else key, skin)
		if primary and key in ["normal", "hover", "pressed"]: box.bg_color = box.bg_color.lerp(accent, 0.18)
		button.add_theme_stylebox_override(key, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, skin.text)
	button.add_theme_color_override("font_disabled_color", skin.muted)


static func audio(event: StringName, scope: Node) -> void:
	if not event.is_empty(): Sound.play(event, scope)


static func plate(host: Control, box: StyleBox, inset := Vector2.ZERO) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	panel.add_theme_stylebox_override("panel", box)
	host.add_child(panel, false, Node.INTERNAL_MODE_FRONT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = -inset.x
	panel.offset_right = inset.x
	panel.offset_top = -inset.y
	panel.offset_bottom = inset.y
	return panel
