extends RefCounted

const BOUNDS = Rect2(-28.0, -28.0, 56.0, 56.0)
const MAX_EXPANSION = 1.5
const PLANETARY = {"mining_operation": "rocky", "gas_giant": "gas_giant",
	"research_station": "frozen", "quarantined_colony": "terrestrial"}

# Zero denotes the layout used by saves created before expansion.
static func scale_factor(expansion: float) -> float:
	return maxf(1.0, expansion)

static func valid_expansion(value: Variant) -> bool:
	return (value is float or value is int) and (value == 0.0 or (value >= 1.0 and value <= MAX_EXPANSION))

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
