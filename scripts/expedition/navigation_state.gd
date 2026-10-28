extends RefCounted
# A validated, scene-free movement hook. Consumers receive world-space distance,
# never camera motion, elapsed UI time or an implied gameplay effect.
signal movement_advanced(distance: float)
var _movement_position: Array = []
# Transient origin of the current validated sample, for swept-path consumers.
var movement_origin: Array = []
# Authoritative movement position, target and uninterrupted journey, shared by all destinations.
var position: Array = []
var target: Array = []
var leg_active: bool = false

static func valid_point(value: Variant, allow_empty: bool = true) -> bool:
	if not value is Array: return false
	if value.is_empty(): return allow_empty
	if value.size() != 3: return false
	for coordinate in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000: return false
	return true

func begin(point: Array = []) -> bool:
	target = point.duplicate()
	if leg_active: return false
	leg_active = true
	return true

func stop() -> void:
	leg_active = false
	target.clear()
	rebase_movement()

func reset_system() -> void:
	stop()
	position.clear()

func snapshot() -> Dictionary:
	return {"position": position.duplicate(), "target": target.duplicate(), "leg_active": leg_active}

func restore(data: Dictionary) -> bool:
	if not valid_point(data.get("position")) or not valid_point(data.get("target")): return false
	if not data.get("leg_active") is bool: return false
	if not data.leg_active and not data.target.is_empty(): return false
	position = data.position.duplicate()
	target = data.target.duplicate()
	leg_active = data.leg_active
	rebase_movement()
	return true


# Sampling baselines are transient: discontinuities and restores must never accrue distance.
# Rebasing deliberately does not alter the authoritative position used by save/resume.
func rebase_movement(point: Array = []) -> bool:
	if not valid_point(point): return false
	_movement_position = point.duplicate()
	return true


# Explicit position checkpoints (travel start, save and arrival) never advance consumers.
func checkpoint_position(point: Array) -> bool:
	if not valid_point(point, false): return false
	position = point.duplicate()
	rebase_movement(point)
	return true


# The coordinator supplies only actual ship-motion samples from an eligible travel phase.
# An unknown first sample establishes a baseline, including immediately after a restore.
func report_movement(point: Array) -> float:
	if not valid_point(point, false): return 0.0
	if not leg_active:
		rebase_movement()
		return 0.0
	var distance: float = 0.0
	if not _movement_position.is_empty():
		var previous := Vector3(_movement_position[0],_movement_position[1],_movement_position[2])
		var current := Vector3(point[0],point[1],point[2])
		distance = previous.distance_to(current)
	movement_origin = _movement_position.duplicate()
	checkpoint_position(point)
	if is_finite(distance) and distance > 0.0:
		movement_advanced.emit(distance)
		return distance
	return 0.0
