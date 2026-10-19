@tool
extends Node3D
# RESPONSIBILITY: Drift existing scene-authored decorations; no spawning or gameplay interaction.
## TUNE: Number of visible child meshes; duplicate an authored child to extend the available set.
@export_range(0, 8, 1) var asteroid_count: int = 6:
	set(value):
		asteroid_count = value
		if is_node_ready():
			_visibility()
## TUNE: Local units/second in the background plane, deliberately far behind combat ships.
@export var drift_velocity: Vector3 = Vector3(0.035, 0.008, 0.0)
## TUNE: Radians/second. Child transforms remain the editable starting poses.
@export var spin_speed: Vector3 = Vector3(0.012, 0.02, 0.009)
@export_range(12.0, 60.0, 1.0) var wrap_width: float = 30.0
@export_range(4.0, 30.0, 1.0) var wrap_height: float = 9.0
var elapsed: float = 0.0
var poses: Array[Transform3D] = []


func _ready() -> void:
	for child in get_children():
		poses.append(child.transform)
	_visibility()


func _visibility() -> void:
	for i in range(get_child_count()):
		get_child(i).visible = i < asteroid_count


func _process(delta: float) -> void:
	# Keep editor-authored positions stable when inspecting/saving the scene.
	if Engine.is_editor_hint():
		return
	elapsed += delta
	for i in range(mini(poses.size(), get_child_count())):
		var child: Node3D = get_child(i)
		var t: float = elapsed * (0.7 + i * 0.13)
		child.position = poses[i].origin + drift_velocity * t
		child.position.x = wrapf(child.position.x, -wrap_width * 0.5, wrap_width * 0.5)
		child.position.y = wrapf(child.position.y, -wrap_height * 0.5, wrap_height * 0.5)
		child.basis = poses[i].basis * Basis.from_euler(spin_speed * t)
