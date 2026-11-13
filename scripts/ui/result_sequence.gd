extends Control
## Presentation only. All amounts are snapshots of already-committed results.
@export_range(0.1, 2.0) var title_fade_duration: float = 0.18
@export_range(0.1, 3.0) var title_move_duration: float = 0.18
@export_range(0.05, 1.0) var line_fade_duration: float = 0.12
var started := false
var running := false
var animation: Tween
var banner: Label
var lines: VBoxContainer
var subtitle: Label
var rewards: HBoxContainer
var details_button: Button
var skip_button: Button
var details_overlay: CanvasLayer
var summary: Dictionary = {}
var values: Array = []
var controls: Array[Control] = []
var disabled_states: Dictionary = {}
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const FONT = preload("res://assets/fonts/emoji_ui.tres")

func set_summary(data: Dictionary) -> void:
	if started: return
	var cause := "Enemy Destroyed"
	if data.escaped_by_ftl: cause = "Enemy neutralized · allied recovery" if data.defense_recovery else "Enemy neutralized"
	elif data.result_cause == "systems_failure": cause = "Enemy Systems Disabled"
	if data.winner != "player": cause = "Both ships lost" if data.winner == "draw" else "Your vessel was lost"
	if data.system_secured:
		cause = "Mothership neutralized · allied recovery" if data.escaped_by_ftl else ("Mothership Systems Disabled" if data.result_cause == "systems_failure" else "Mothership Destroyed")
	summary = {"cause":cause,"earned":int(data.get("salvage_earned",0)),"balance":int(data.salvage),
		"hull":int(data.result_hull if data.result_recorded else data.player.hull),"battles":int(data.battles_won),
		"upgrades":int(data.get("upgrades_available",0)),"details":data.rewards_text,
		"recorded":bool(data.result_recorded)}

func label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	banner = label($Panel/Title.text,48)
	banner.add_theme_color_override("font_color",$Panel/Title.get_theme_color("font_color"))
	banner.name = "ResultBanner"
	add_child(banner)
	subtitle = label(summary.get("cause",""),24)
	add_child(subtitle)
	rewards = HBoxContainer.new()
	rewards.add_theme_constant_override("separation",12)
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rewards)
	for entry in [["🪨 Salvage earned","earned"],["❤️ Hull remaining","hull"],["⚔ Battles won","battles"],["✦ Card upgrades","upgrades"]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewards.add_child(column)
		var value := label("0",34)
		column.add_child(value)
		column.add_child(label(entry[0],18))
		values.append({"node":value,"target":int(summary.get(entry[1],0))})
	lines = VBoxContainer.new()
	add_child(lines)
	lines.add_child(label("Salvage balance · %d" % int(summary.get("balance",0)),20))
	details_button = Button.new()
	details_button.text = "Details"
	details_button.custom_minimum_size = Vector2(160,42)
	add_child(details_button)
	details_overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(details_overlay)
	details_button.pressed.connect(func():
		details_overlay.show_text($Panel/Details.text + "\n\n" + str(summary.get("details",""))))
	skip_button = Button.new()
	skip_button.text = "Skip Animation"
	skip_button.custom_minimum_size = Vector2(160,44)
	add_child(skip_button)
	skip_button.pressed.connect(skip)
	for path in ["NextEncounter","Continue","Configure"]:
		var node: Control = panel.get_node(path)
		if not node.visible: continue
		controls.append(node)
		if node is BaseButton:
			disabled_states[node] = node.disabled
			node.disabled = true
			node.modulate.a = 0.0
	fit()
	resized.connect(fit)
	banner.modulate.a = 0
	rewards.modulate.a = 0
	animation = create_tween()
	animation.tween_property(banner,"modulate:a",1.0,title_fade_duration)
	animation.parallel().tween_property(banner,"position:y",banner.position.y,title_move_duration).from(banner.position.y+8.0)
	animation.tween_property(rewards,"modulate:a",1.0,line_fade_duration)
	for item in values:
		animation.parallel().tween_method(display_count.bind(item.node),0.0,float(item.target),0.35)
	animation.chain().tween_callback(finish)
	if Preferences.skip_cinematics() or not Preferences.battle_vfx(): skip.call_deferred()

func fit() -> void:
	if not is_instance_valid(banner): return
	banner.position = Vector2(24,size.y*0.12)
	banner.size = Vector2(size.x-48,64)
	subtitle.position = Vector2(24,size.y*0.25)
	subtitle.size = Vector2(size.x-48,52)
	rewards.position = Vector2(size.x*0.08,size.y*0.39)
	rewards.size = Vector2(size.x*0.84,105)
	lines.position = Vector2(24,size.y*0.61)
	lines.size = Vector2(size.x-48,40)
	details_button.position = Vector2((size.x-160)*0.5,size.y*0.7)
	skip_button.position = Vector2(size.x-184,16)
	for node in controls:
		node.position = Vector2((size.x-node.size.x)*0.5,size.y*(0.81 if node is BaseButton else 0.93))

func display_count(value: float, node: Label) -> void:
	if is_instance_valid(node): node.text = str(roundi(value))

func finish() -> void:
	if not running: return
	running = false
	for item in values:
		if is_instance_valid(item.node): item.node.text = str(item.target)
	banner.modulate.a = 1
	rewards.modulate.a = 1
	for button in disabled_states:
		if is_instance_valid(button):
			button.disabled = disabled_states[button]
			button.modulate.a = 1
	skip_button.hide()

func skip() -> void:
	if animation and animation.is_valid(): animation.kill()
	finish()

func _exit_tree() -> void:
	if animation and animation.is_valid(): animation.kill()
