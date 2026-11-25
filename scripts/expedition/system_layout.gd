extends RefCounted

const BOUNDS = Rect2(-28.0, -28.0, 56.0, 56.0)
const MAX_EXPANSION = 1.5
const MIN_GEOMETRY = 0.85
const MAX_GEOMETRY = 1.875
const PLANETARY = {"mining_operation": "rocky", "gas_giant": "gas_giant",
	"research_station": "frozen", "quarantined_colony": "terrestrial"}

# Zero denotes the layout used by saves created before expansion.
static func scale_factor(expansion: float) -> float:
	return expansion if expansion > 0.0 else 1.0

static func valid_expansion(value: Variant, later: bool = false) -> bool:
	if not (value is float or value is int): return false
	if later: return value >= MIN_GEOMETRY - 0.00001 and value <= MAX_GEOMETRY + 0.00001
	return value == 0.0 or (value >= 1.0 and value <= MAX_EXPANSION)

static func bounds(expansion: float, base: Rect2 = BOUNDS) -> Rect2:
	var factor := scale_factor(expansion)
	return Rect2(base.position * factor, base.size * factor).abs()

static func planetary_indices(encounters: Array) -> Array[int]:
	var indices: Array[int] = []
	for index in encounters.size():
		var entry: Dictionary = encounters[index]
		if entry.kind == "poi" and PLANETARY.has(entry.poi.resource_path.get_file().get_basename()):
			indices.append(index)
	return indices

static func planetary_radius(model_kind: String) -> float:
	# Independent gas-giant mesh has a 1.25-unit sphere and a 1.5 scale.
	# The other planetary destination models fit within their placement radius.
	return 1.875 if model_kind == "gas_giant" else 1.2

static func planetary_radii(encounters: Array, scales: Dictionary = {}) -> Dictionary:
	var result := {}
	for index in planetary_indices(encounters):
		result[index] = planetary_radius(encounters[index].poi.resource_path.get_file().get_basename()) * float(scales.get(str(index), 1.0))
	return result

# Central exclusion includes the visible core and a navigation margin. A binary
# companion remains a visual body, and its small core is inside this envelope.
static func stellar_clearance(profile: Dictionary) -> float:
	if profile.get("version") != 2: return 3.5
	var variation := preload("res://scripts/expedition/system_variation.gd")
	var stellar := maxf(3.5, variation.star_radius(profile, 2.52) + 0.98)
	var companion: Dictionary = profile.companion
	if companion.is_empty(): return stellar
	var at := Vector2(companion.position[0], companion.position[2])
	return maxf(stellar, at.length() + float(companion.radius) + 0.3)


static func navigable(at: Vector3, expansion: float, margin: float = 0.0) -> bool:
	return at.is_finite() and absf(at.y) < 0.001 and bounds(expansion).grow(-margin).has_point(Vector2(at.x, at.z))


static func clear_orbit(at: Vector3, radii: Dictionary, anchors: Dictionary, margin: float) -> bool:
	for index in radii:
		if absf(at.length() - anchors[index].length()) < float(radii[index]) + margin: return false
	return true
