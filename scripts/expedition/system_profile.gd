extends Resource
class_name SystemProfile

# Data-only profile bias. One generator and one gameplay RNG serve every profile.
const IDS = ["quiet", "industrial", "hostile", "ancient"]
@export var id: String = "industrial"
@export var display_name: String = "Industrial System"
@export var ordinary_weight: float = 1.0
@export var hazardous_weight: float = 1.0
@export var battle_weight: float = 1.0
@export var poi_weights: Dictionary = {}
@export_range(0, 1, 0.01) var outpost_chance: float = 0.08
@export var chasedown_multiplier: float = 1.0
@export var tolerance_min: int = 5
@export var tolerance_max: int = 9
@export_range(0, 1, 0.01) var sensitive_chance: float = 0.25
@export var star_hue_bias: float = 0.08
@export var nebula_chance: float = 0.3

static func for_id(profile_id: String) -> Resource:
	var known: String = profile_id if profile_id in IDS else "industrial"
	return load("res://resources/system_profiles/%s.tres" % known)
