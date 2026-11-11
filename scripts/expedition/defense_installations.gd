extends RefCounted

const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const KINETIC = "KINETIC_TURRET"
const CELESTIAL_SITES = ["gas_giant", "mining_operation", "quarantined_colony"]

static func sites(home: Vector3, anchors: Dictionary, encounters: Array) -> Dictionary:
	var result: Dictionary = {}
	var radial := home.normalized()
	var tangent := Vector3.UP.cross(radial)
	_add_site(result, "home", "Homeworld perimeter", home - radial * 4.8 + tangent * 3.5, home, anchors)
	_add_site(result, "flank_a", "Approach relay A", home * 0.68 + tangent * 6.5, home, anchors)
	_add_site(result, "flank_b", "Approach relay B", home * 0.68 - tangent * 6.5, home, anchors)
	for index in encounters.size():
		if not anchors.has(index) or encounters[index].kind != "poi": continue
		var entry: Dictionary = encounters[index]
		if entry.poi.resource_path.get_file().get_basename() not in CELESTIAL_SITES: continue
		var anchor: Vector3 = anchors[index]
		_add_site(result, "poi_%d" % index, entry.title + " perimeter",
			anchor + anchor.normalized() * 3.6, home, anchors)
	return result

static func _add_site(result: Dictionary, id: String, title: String, preferred: Vector3,
		home: Vector3, anchors: Dictionary) -> void:
	var tangent := Vector3.UP.cross(preferred.normalized())
	for offset in [0.0, 2.0, -2.0, 4.0, -4.0]:
		var at: Vector3 = preferred + tangent * offset
		if at.length() < 15.5 or absf(at.x) > 26.0 or absf(at.z) > 26.0: continue
		if at.distance_to(home) < 4.2 or at.distance_to(home * 0.78) < 2.8: continue
		if anchors.values().any(func(anchor): return at.distance_to(anchor) < 3.4): continue
		if result.values().any(func(site): return at.distance_to(_point(site.position)) < 3.4): continue
		result[id] = {"title": title, "position": [at.x, at.y, at.z]}
		return

static func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func valid_deployments(value: Variant, eligible: Dictionary) -> bool:
	if not value is Dictionary or value.size() > 8: return false
	for id in value:
		var turret: Variant = value[id]
		if not eligible.has(id) or not turret is Dictionary or turret.size() != 6 or turret.get("owner") != "player": return false
		if not Navigation.valid_point(turret.get("position"), false): return false
		if _point(turret.position).distance_to(_point(eligible[id].position)) > 0.001: return false
		var radius: Variant = turret.get("radius")
		if not (radius is float or radius is int) or not is_finite(float(radius)) or radius < 1 or radius > 28: return false
		if not valid_support(turret) or turret.is_empty(): return false
	return true

static func valid_support(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	return value.get("type") == KINETIC and _positive_integer(value.get("damage"), 1000) \
		and _positive_integer(value.get("interval"), 100)

static func _positive_integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value == floor(float(value)) and value >= 1 and value <= maximum

static func covers(turret: Dictionary, at: Vector3) -> bool:
	return at.distance_squared_to(_point(turret.position)) <= float(turret.radius) ** 2

static func support_at(turrets: Dictionary, location: Array) -> Dictionary:
	if location.size() != 3: return {}
	var ids := turrets.keys()
	ids.sort()
	for id in ids:
		var turret: Dictionary = turrets[id]
		if covers(turret, _point(location)):
			return {"type": KINETIC, "damage": int(turret.damage), "interval": int(turret.interval)}
	return {}
