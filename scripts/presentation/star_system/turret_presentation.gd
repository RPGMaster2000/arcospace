extends Node3D

const Installations = preload("res://scripts/expedition/defense_installations.gd")

const READY := Color(0.25, 0.85, 0.72, 0.45)
const COVERED := Color(0.6, 1.0, 0.36, 0.85)
const PREVIEW := Color(0.36, 0.73, 1.0, 0.75)

var query: Callable
var deploy: Callable
var button: Button
var popup: PopupPanel
var picker: OptionButton
var detail: Label
var build: Button
var rings: Dictionary = {}
var preview: Node3D
var snapshot: Dictionary
var site_ids: Array = []
var selected: String = ""

func configure(column: VBoxContainer, options: Callable, request: Callable) -> void:
	query = options
	deploy = request
	button = Button.new()
	button.name = "DefensiveConstruction"
	button.text = "Defenses"
	button.focus_mode = Control.FOCUS_NONE
	column.add_child(button)
	button.pressed.connect(_open)
	popup = PopupPanel.new()
	popup.name = "KineticTurretConstruction"
	popup.transient = true
	popup.exclusive = true
	add_child(popup)
	var backing := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111c2b")
	style.border_color = Color("47748a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	backing.add_theme_stylebox_override("panel", style)
	popup.add_child(backing)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 300
	panel.add_theme_constant_override("separation", 6)
	backing.add_child(panel)
	var title := Label.new()
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
	popup.popup_hide.connect(func():
		if is_instance_valid(preview): preview.hide())

func _open() -> void:
	picker.clear()
	site_ids = snapshot.get("construction_sites", {}).keys()
	for id in site_ids:
		picker.add_item(snapshot.construction_sites[id].title + (" · Built" if snapshot.turrets.has(id) else ""))
	if not site_ids.is_empty():
		picker.select(0)
		_select_site(0)
	else:
		detail.text = "No eligible construction sites in this system."
		build.text = "Build turret"
		build.disabled = true
	popup.popup_centered(Vector2i(330, 232))

func _select_site(index: int) -> void:
	selected = site_ids[index]
	var options: Dictionary = query.call(selected)
	var installed: Dictionary = snapshot.turrets.get(selected, {})
	var radius: float = installed.get("radius", options.radius)
	detail.text = "%d Salvage available · %d / %d built\n%.1f units engagement radius\n%s" % [
		options.salvage, snapshot.turrets.size(), options.capacity, radius,
		"Installed" if not installed.is_empty() else "Deploy at the highlighted position."]
	build.text = "Build · %d Salvage" % options.cost
	build.disabled = not options.allowed
	if is_instance_valid(preview): preview.queue_free()
	preview = _model() if installed.is_empty() else Node3D.new()
	preview.add_child(_ring(radius, PREVIEW))
	preview.position = _point(snapshot.construction_sites[selected].position)
	add_child(preview)

func _build() -> void:
	if deploy.call(selected):
		picker.set_item_text(picker.selected, snapshot.construction_sites[selected].title + " · Built")
		_select_site(picker.selected)
	else:
		build.disabled = true

func refresh(value: Dictionary) -> void:
	snapshot = value
	for id in value.get("turrets", {}):
		var turret: Dictionary = value.turrets[id]
		var center := _point(turret.position)
		if not rings.has(id):
			var model := _model()
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
