extends Control
# Owns the terminal title/results reveal; combat/rewards are already committed.
@export_range(0.1, 2.0) var title_fade_duration: float = 0.55
@export_range(0.1, 3.0) var title_move_duration: float = 1.0
@export_range(0.05, 1.0) var line_fade_duration: float = 0.22
var started: bool = false
var running: bool = false
var animation: Tween
var banner: Label
var lines: VBoxContainer


func play() -> void:
	if started or not visible:
		return
	started = true
	running = true
	$Shade.color.a = 0.92
	var panel: Control = $Panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var title: Label = $Panel/Title
	banner = title.duplicate()
	banner.name = "ResultBanner"
	add_child(banner)
	banner.position = Vector2(0, size.y * 0.5 - 32)
	banner.size = Vector2(size.x, 64)
	banner.modulate.a = 0
	var cover := ColorRect.new()
	cover.color = Color.TRANSPARENT
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	for child in panel.get_children():
		if child is CanvasItem:
			child.modulate.a = 0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(size.x * 0.15, size.y * 0.42)
	scroll.size = Vector2(size.x * 0.7, size.y * 0.21)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	move_child(cover, get_child_count() - 1)
	lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	for path in ["Details", "Rewards", "BattlesWon"]:
		var source: Label = panel.get_node(path)
		if not source.visible:
			continue
		for text in source.text.split("\n", false):
			var line := Label.new()
			line.text = text
			line.add_theme_font_override("font", preload("res://assets/fonts/emoji_ui.tres"))
			line.add_theme_font_size_override("font_size", 20)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.modulate.a = 0
			lines.add_child(line)
	var controls: Array[Control] = []
	var disabled_states: Dictionary = {}
	for path in ["RepairMinus", "RepairAmount", "RepairPlus", "Repair", "RepairPreview", "NextEncounter", "Continue", "Configure"]:
		var node: Control = panel.get_node_or_null(path)
		if node == null or not node.visible:
			continue
		# Keep authored horizontal grouping, center the repair row on wider displays.
		if path == "RepairPreview":
			node.size = Vector2(minf(680, size.x * 0.7), 56)
			node.position = Vector2((size.x - node.size.x) * 0.5, size.y * 0.64)
		elif path.begins_with("Repair"):
			node.position.x += (size.x - 740) * 0.5
			node.position.y = size.y * 0.74
		else:
			node.position = Vector2((size.x - node.size.x) * 0.5, size.y * (0.83 if path == "NextEncounter" else 0.88))
		controls.append(node)
		if node is BaseButton:
			disabled_states[node] = node.disabled
			node.disabled = true
	animation = create_tween()
	animation.tween_property(banner, "modulate:a", 1.0, title_fade_duration)
	animation.tween_property(banner, "position:y", size.y * 0.20, title_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var line_delay: float = 0.0
	for line in lines.get_children():
		animation.parallel().tween_property(line, "modulate:a", 1.0, line_fade_duration).set_delay(line_delay)
		line_delay += line_fade_duration
	for node in controls:
		animation.parallel().tween_property(node, "modulate:a", 1.0, 0.3).set_delay(line_delay)
	animation.chain().tween_callback(func():
		running = false
		for button in disabled_states:
			if is_instance_valid(button):
				button.disabled = disabled_states[button]
		cover.queue_free())
