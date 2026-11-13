extends Node3D

const Installations = preload("res://scripts/expedition/defense_installations.gd")

const READY := Color(0.25, 0.85, 0.72, 0.45)
const COVERED := Color(0.6, 1.0, 0.36, 0.85)
const PREVIEW := Color(0.36, 0.73, 1.0, 0.75)

var query: Callable
var deploy: Callable
var button: Button
var popup: Control
var picker: OptionButton
var detail: Label
var build: Button
var rings: Dictionary = {}
var preview: Node3D
var snapshot: Dictionary
var site_ids: Array = []
var selected: String = ""
var map: Control
var transition := false
var camera_before := {}
var arrows: Array[Button] = []

func configure(column: VBoxContainer, overlay: Control, options: Callable, request: Callable) -> void:
	map = overlay
	query = options
	deploy = request
	button = Button.new()
	button.name = "DefensiveConstruction"
	button.text = "Defenses"
	button.focus_mode = Control.FOCUS_NONE
	column.add_child(button)
	button.pressed.connect(_open)
	popup = Control.new()
	popup.name = "KineticTurretConstruction"
	popup.z_index = 30
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.hide()
	overlay.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centered := CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(centered)
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := PanelContainer.new()
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111c2b")
	style.border_color = Color("47748a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	backing.add_theme_stylebox_override("panel", style)
	centered.add_child(backing)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 300
	panel.add_theme_constant_override("separation", 6)
	backing.add_child(panel)
	var title := Label.new()
	title.name = "ConstructionTitle"
	title.text = "Kinetic Turret"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	picker = OptionButton.new()
	panel.add_child(picker)
	picker.item_selected.connect(_select_site)
	detail = Label.new()
	panel.add_child(detail)
	build = Button.new()
	build.name = "BuildTurret"
	panel.add_child(build)
	build.pressed.connect(_build)
	var close := Button.new()
	close.text = "Close"
	panel.add_child(close)
	close.pressed.connect(popup.hide)
	popup.visibility_changed.connect(func():
		if not popup.visible:
			if is_instance_valid(preview): preview.hide()
			_restore_camera())
	for step in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if step < 0 else "›"
		arrow.tooltip_text = "Previous site" if step < 0 else "Next site"
		arrow.custom_minimum_size = Vector2(64, 64)
		arrow.add_theme_font_size_override("font_size", 38)
		popup.add_child(arrow)
		arrow.anchor_left = 0.0 if step < 0 else 1.0
		arrow.anchor_right = arrow.anchor_left
		arrow.anchor_top = 0.5
		arrow.anchor_bottom = 0.5
		arrow.offset_left = 18.0 if step < 0 else -82.0
		arrow.offset_right = arrow.offset_left + 64.0
		arrow.offset_top = -32.0
		arrow.offset_bottom = 32.0
		arrow.pressed.connect(_step_site.bind(step))
		arrows.append(arrow)
	centered.name = "ConstructionPanel"

func _open() -> void:
	if popup.visible: return
	var modern: bool = snapshot.get("v2", false)
	picker.visible = not modern
	picker.get_parent().get_node("ConstructionTitle").visible = not modern
	for arrow in arrows: arrow.visible = modern
	var panel := popup.get_node("ConstructionPanel")
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if modern else Control.PRESET_FULL_RECT)
	if modern:
		panel.offset_top = -214.0
		panel.offset_bottom = -18.0
		var camera = map.camera
		camera_before = {"transform": camera.transform, "viewing": camera.viewing,
			"pan": camera.pan_offset, "zoom": camera.zoom_scale, "target": camera.zoom_target}
	picker.clear()
	site_ids = snapshot.get("construction_sites", {}).keys()
	for id in site_ids:
		picker.add_item(snapshot.construction_sites[id].title + (" · Built" if snapshot.turrets.has(id) else ""))
	popup.show()
	if not site_ids.is_empty():
		var first := 0
		if modern:
			for i in site_ids.size():
				if not snapshot.turrets.has(site_ids[i]):
					first = i
					break
		_select_site(first)
	else:
		detail.text = "No eligible construction sites in this system."
		build.text = "Build turret"
		build.disabled = true

func _select_site(index: int, focus_camera: bool = true) -> void:
	if transition or index < 0 or index >= site_ids.size(): return
	picker.select(index)
	selected = site_ids[index]
	var options: Dictionary = query.call(selected)
	var installed: Dictionary = snapshot.turrets.get(selected, {})
	var radius: float = installed.get("radius", options.radius)
	detail.text = "%d Salvage available · %d / %d built\n%.1f units engagement radius\n%s" % [
		options.salvage, Installations.purchased_count(snapshot.turrets), options.capacity, radius,
		"Installed" if not installed.is_empty() else "Deploy at the highlighted position."]
	if snapshot.get("v2", false):
		detail.text = "Kinetic Turret · %d Salvage · Range %.1f\n%s · %d / %d built" % [
			options.cost, radius, snapshot.construction_sites[selected].title, Installations.purchased_count(snapshot.turrets), options.capacity]
	build.text = "Build · %d Salvage" % options.cost
	build.disabled = not options.allowed
	if is_instance_valid(preview): preview.queue_free()
	preview = _model() if installed.is_empty() else Node3D.new()
	preview.add_child(_ring(radius, PREVIEW))
	preview.position = _point(snapshot.construction_sites[selected].position)
	add_child(preview)
	if focus_camera and snapshot.get("v2", false): _focus_site(preview.position)

func _step_site(direction: int) -> void:
	if transition or site_ids.size() < 2: return
	_select_site(posmod(picker.selected + direction, site_ids.size()))

func _focus_site(at: Vector3) -> void:
	transition = true
	build.disabled = true
	for arrow in arrows: arrow.disabled = true
	var camera = map.camera
	camera.frame(at + Vector3(2.0, 25.0, 27.0), at, 0.32, &"construction")
	camera.motion.finished.connect(func():
		if not popup.visible: return
		transition = false
		for arrow in arrows: arrow.disabled = site_ids.size() < 2
		build.disabled = not query.call(selected).allowed)

func _restore_camera() -> void:
	transition = false
	if camera_before.is_empty() or not is_instance_valid(map): return
	var camera = map.camera
	camera.cancel()
	camera.transform = camera_before.transform
	camera.viewing = camera_before.viewing
	camera.pan_offset = camera_before.pan
	camera.zoom_scale = camera_before.zoom
	camera.zoom_target = camera_before.target
	camera_before.clear()

func _build() -> void:
	if transition or build.disabled: return
	if deploy.call(selected):
		picker.set_item_text(picker.selected, snapshot.construction_sites[selected].title + " · Built")
		_select_site(picker.selected, false)
	else:
		build.disabled = true

func refresh(value: Dictionary) -> void:
	snapshot = value
	for id in value.get("turrets", {}):
		var turret: Dictionary = value.turrets[id]
		var center := _point(turret.position)
		if not rings.has(id):
			var model := _model()
			if str(id).begins_with(Installations.FREE_PREFIX):
				# Keep the authoritative root/range centered on the PoI; show the
				# weapon above the existing rocky body instead of inside its mesh.
				var height := preload("res://scripts/expedition/system_layout.gd").planetary_radius("mining_operation")
				for part in model.get_children(): part.position.y += height
			model.position = center
			add_child(model)
			var ring := _ring(turret.radius, READY)
			model.add_child(ring)
			rings[id] = ring
		var covered: bool = value.units.any(func(unit):
			return unit.status == "active" and (not unit.mothership or value.revealed) \
				and Installations.covers(turret, _point(unit.position)))
		rings[id].material_override.albedo_color = COVERED if covered else READY

static func _point(at: Array) -> Vector3:
	return Vector3(at[0], at[1], at[2])

static func _ring(radius: float, tint: Color) -> MeshInstance3D:
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(65):
		var angle := TAU * float(index) / 64.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		geometry.surface_add_vertex(direction * (radius - 0.07) + Vector3.UP * 0.05)
		geometry.surface_add_vertex(direction * (radius + 0.07) + Vector3.UP * 0.05)
	geometry.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = tint
	var ring := MeshInstance3D.new()
	ring.mesh = geometry
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring

static func _model() -> Node3D:
	var model := Node3D.new()
	model.name = "KineticTurret"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("64d7ad")
	for part in [
		[Vector3(0.85, 0.22, 0.85), Vector3(0, 0.11, 0)],
		[Vector3(0.48, 0.45, 0.52), Vector3(0, 0.43, 0)],
		[Vector3(0.18, 0.16, 0.8), Vector3(-0.18, 0.65, 0.28)],
		[Vector3(0.18, 0.16, 0.8), Vector3(0.18, 0.65, 0.28)],
	]:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position = part[1]
		model.add_child(instance)
	return model

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(popup) and popup.visible and event.is_action_pressed("ui_cancel"):
		popup.hide()
	elif is_instance_valid(popup) and popup.visible and snapshot.get("v2", false):
		if event.is_action_pressed("ui_left"): _step_site(-1)
		elif event.is_action_pressed("ui_right"): _step_site(1)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(popup): popup.queue_free()
