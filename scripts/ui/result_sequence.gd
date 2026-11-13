extends Control
## Presentation only. All amounts are snapshots of already-committed results.
@export_range(0.1, 2.0) var title_fade_duration: float = 0.32
@export_range(0.1, 3.0) var title_move_duration: float = 0.42
@export_range(0.05, 1.0) var line_fade_duration: float = 0.24
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Effects = preload("res://scripts/visual/visual_effects.gd")
const SETTINGS = preload("res://resources/visual/alpha_visual_settings.tres")
const FONT = preload("res://assets/fonts/emoji_ui.tres")
const REVEAL_SECONDS := 1.55
var started := false
var running := false
var animation: Tween
var banner: Label
var identity_icon: Label
var lines: VBoxContainer
var subtitle: Label
var rewards: GridContainer
var details_button: Button
var skip_button: Button
var details_overlay: CanvasLayer
var summary: Dictionary = {}
var values: Array = []
var controls: Array[Control] = []
var animated: Array[Control] = []
var disabled_states: Dictionary = {}
var fit_queued := false
var burst: ResultBurst
var title_progress := 0.0:
	set(value):
		title_progress = value
		position_title()

# Cheap UI geometry, no particle emitters, textures, lights or gameplay RNG.
# EMP uses electronic arcs rather than destruction/explosion imagery.
class ResultBurst extends Control:
	var accent := Color.CYAN
	var electronic := false
	var victory := true
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()
	func _draw() -> void:
		var center := Vector2(size.x*0.5,size.y*0.14+36)
		var radius := lerpf(28, minf(190,size.x*0.24),progress)
		var color := accent
		color.a = sin(progress*PI)*(0.26 if victory else 0.10)
		draw_arc(center,radius,0,TAU,64,color,2.0,true)
		if electronic:
			draw_arc(center,radius*0.72,progress*TAU,progress*TAU+PI*1.3,48,color,3.0,true)
		elif victory:
			for i in range(24):
				var direction := Vector2.from_angle(TAU*i/24.0)
				draw_line(center+direction*(radius+6),center+direction*(radius+lerpf(24,4,progress)),color,2.0,true)

func set_summary(data: Dictionary) -> void:
	if started: return
	var cause := "Enemy Destroyed"
	var symbol := "⚔"
	if data.escaped_by_ftl:
		cause = "Enemy neutralized · allied recovery" if data.defense_recovery else "Enemy neutralized"
		symbol = "⚡"
	elif data.result_cause == "systems_failure":
		cause = "Enemy Systems Disabled"
		symbol = "⏻"
	if data.winner != "player":
		cause = "Both ships lost" if data.winner == "draw" else "Your vessel was lost"
		symbol = "◇"
	if data.system_secured:
		cause = "Mothership neutralized · allied recovery" if data.escaped_by_ftl else ("Mothership Systems Disabled" if data.result_cause == "systems_failure" else "Mothership Destroyed")
		if not data.escaped_by_ftl: symbol = "✦"
	summary = {"cause":cause,"symbol":symbol,"emp":bool(data.escaped_by_ftl),"victory":data.winner == "player",
		"earned":int(data.get("salvage_earned",0)),"balance":int(data.salvage),
		"hull":int(data.result_hull if data.result_recorded else data.player.hull),"battles":int(data.battles_won),
		"upgrades":int(data.get("upgrades_available",0)),"details":data.rewards_text,
		"recorded":bool(data.result_recorded)}

func label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.minimum_size_changed.connect(queue_fit)
	node.text = text
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

func play() -> void:
	if started or not visible or not summary.get("recorded",false): return
	started = true
	running = true
	$Shade.color.a = 0.9
	var panel: Control = $Panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for path in ["Title","Details","Rewards","BattlesWon"]:
		panel.get_node(path).modulate.a = 0.0
		panel.get_node(path).mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst = ResultBurst.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.accent = Color("77ddff") if summary.emp else $Panel/Title.get_theme_color("font_color")
	burst.electronic = summary.emp
	burst.victory = summary.victory
	add_child(burst)
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner = label($Panel/Title.text,56)
	banner.add_theme_color_override("font_color",burst.accent)
	banner.name = "ResultBanner"
	add_child(banner)
	identity_icon = label(summary.symbol,30)
	identity_icon.add_theme_color_override("font_color",burst.accent)
	add_child(identity_icon)
	subtitle = label(summary.cause,24)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle)
	rewards = GridContainer.new()
	rewards.columns = 4
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.minimum_size_changed.connect(queue_fit)
	rewards.add_theme_constant_override("h_separation",12)
	rewards.add_theme_constant_override("v_separation",8)
	add_child(rewards)
	for entry in [["🪨","Salvage earned","earned"],["❤️","Hull remaining","hull"],["⚔","Battles won","battles"],["✦","Card upgrades","upgrades"]]:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation",0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewards.add_child(column)
		var icon := label(entry[0],26)
		column.add_child(icon)
		var value := label("0",34)
		column.add_child(value)
		var caption := label(entry[1],18)
		column.add_child(caption)
		if entry[2] == "upgrades" and summary.upgrades > 0:
			for item in [icon,value,caption]: item.add_theme_color_override("font_color",SETTINGS.victory_accent_color)
		values.append({"node":value,"icon":icon,"column":column,"target":int(summary.get(entry[2],0))})
		animated.append(column)
	lines = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.minimum_size_changed.connect(queue_fit)
	add_child(lines)
	lines.add_child(label("Salvage balance · %d" % int(summary.balance),20))
	details_button = Button.new()
	details_button.text = "Details"
	details_button.custom_minimum_size = Vector2(160,44)
	details_button.focus_mode = Control.FOCUS_ALL
	add_child(details_button)
	details_overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(details_overlay)
	details_button.pressed.connect(func():
		details_overlay.show_text($Panel/Details.text+"\n\n"+str(summary.details)))
	skip_button = Button.new()
	skip_button.text = "Skip Animation"
	skip_button.custom_minimum_size = Vector2(160,44)
	skip_button.focus_mode = Control.FOCUS_ALL
	add_child(skip_button)
	skip_button.pressed.connect(skip)
	for path in ["NextEncounter","Continue","Configure"]:
		var node: Control = panel.get_node(path)
		if not node.visible: continue
		controls.append(node)
		if node is BaseButton:
			disabled_states[node] = node.disabled
			node.disabled = true
			animated.append(node)
		else: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animated.append_array([banner,identity_icon,subtitle,lines])
	fit()
	resized.connect(queue_fit)
	for node in animated: node.modulate.a = 0.0
	banner.scale = Vector2.ONE*1.22
	animation = create_tween().set_parallel(true)
	animation.tween_callback(Effects.reveal.bind(banner,SETTINGS,title_fade_duration,1.22))
	animation.tween_property(self,"title_progress",1.0,title_move_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(burst,"progress",1.0,0.7)
	animation.tween_callback(Effects.reveal.bind(identity_icon,SETTINGS,line_fade_duration,0.7)).set_delay(0.20)
	animation.tween_callback(Effects.reveal.bind(subtitle,SETTINGS,line_fade_duration,0.96)).set_delay(0.30)
	for i in values.size():
		var item: Dictionary = values[i]
		var delay := 0.42+i*0.13
		animation.tween_callback(Effects.reveal.bind(item.column,SETTINGS,line_fade_duration,0.78)).set_delay(delay)
		animation.tween_method(display_count.bind(item.node),0.0,float(item.target),0.52).set_delay(delay)
	animation.tween_callback(Effects.reveal.bind(lines,SETTINGS,line_fade_duration,0.96)).set_delay(1.05)
	for button in disabled_states:
		animation.tween_callback(Effects.reveal.bind(button,SETTINGS,line_fade_duration,0.88)).set_delay(1.22)
	animation.tween_interval(maxf(REVEAL_SECONDS,maxf(title_fade_duration,title_move_duration)))
	animation.chain().tween_callback(finish)
	skip_button.grab_focus()
	# No separate reduced-motion setting exists. Preserve Skip Cinematics as an
	# immediate, complete summary; Battle VFX governs combat effects only.
	if Preferences.skip_cinematics(): skip.call_deferred()

# Wrapped labels can report narrow initial minimums until width settles.
func queue_fit() -> void:
	if fit_queued or not is_inside_tree(): return
	fit_queued = true
	fit.call_deferred()

func position_title() -> void:
	if not is_instance_valid(banner): return
	banner.position = Vector2(24,lerpf(size.y*0.29,size.y*0.14,title_progress))

func fit() -> void:
	fit_queued = false
	if not is_instance_valid(banner): return
	var heading_size := clampi(roundi(minf(size.y*0.085,size.x*0.055)),48,68)
	if banner.get_theme_font_size("font_size") != heading_size:
		banner.add_theme_font_size_override("font_size",heading_size)
	banner.size = Vector2(size.x-48,72)
	banner.pivot_offset = banner.size*0.5
	position_title()
	identity_icon.position = Vector2(24,size.y*0.065)
	identity_icon.size = Vector2(size.x-48,36)
	subtitle.position = Vector2(24,size.y*0.28)
	subtitle.size = Vector2(size.x-48,46)
	rewards.columns = 4 if size.x >= 760 else 2
	rewards.position = Vector2(size.x*0.06,size.y*(0.39 if rewards.columns == 4 else 0.34))
	rewards.size = Vector2(size.x*0.88,110 if rewards.columns == 4 else 220)
	lines.position = Vector2(24,size.y*0.63)
	lines.size = Vector2(size.x-48,32)
	details_button.position = Vector2((size.x-160)*0.5,size.y*0.70)
	skip_button.position = Vector2(size.x-184,16)
	for node in controls:
		node.position = Vector2((size.x-node.size.x)*0.5,size.y*(0.82 if node is BaseButton else 0.94))
		node.pivot_offset = node.size*0.5

func display_count(value: float, node: Label) -> void:
	if is_instance_valid(node): node.text = str(roundi(value))

func finish() -> void:
	if not running: return
	running = false
	for node in animated:
		if is_instance_valid(node): Effects.reset(node)
	for item in values:
		if is_instance_valid(item.node): item.node.text = str(item.target)
	title_progress = 1.0
	burst.progress = 1.0
	fit()
	for button in disabled_states:
		if is_instance_valid(button): button.disabled = disabled_states[button]
	skip_button.hide()
	if not details_overlay.shade.visible:
		for button in disabled_states:
			if is_instance_valid(button) and not button.disabled:
				button.grab_focus()
				break

func skip() -> void:
	if animation and animation.is_valid(): animation.kill()
	finish()

func _exit_tree() -> void:
	if animation and animation.is_valid(): animation.kill()
	for node in animated:
		if is_instance_valid(node): Effects.reset(node)
