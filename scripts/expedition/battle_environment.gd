extends RefCounted
## Shared scene-free wire model. ExpeditionState owns mutable instances; consumers
## receive detached read-only views. Selection is pure and snapshots never track the world.
const NONE = "NONE"
const ASTEROID_FIELD = "ASTEROID_FIELD"
const SOLAR_INTERFERENCE = "SOLAR_INTERFERENCE"
const SPACE_STORM = "SPACE_STORM"
const TEMPORAL_RIFT = "TEMPORAL_RIFT"
const TYPES = [NONE, ASTEROID_FIELD, SOLAR_INTERFERENCE, SPACE_STORM, TEMPORAL_RIFT]
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")


# JSON-shaped records keep visuals and future simulation on the same instance ID.
# Asteroid geometry is validated below; other types retain reserved wire data.
static func instance(id: String, type: String, position: Array = []) -> Dictionary:
	return {"id": id, "type": type, "position": position.duplicate(),
		"region": {}, "intensity": 1.0, "configuration": {}, "visual": {},
		"simulation": {}, "generation": {}}


static func valid_instances(value: Variant) -> bool:
	if not value is Array or value.size() > 128: return false
	var ids: Dictionary = {}
	for item in value:
		if not item is Dictionary: return false
		if not item.get("id") is String or item.id.is_empty() or item.id.length() > 128 or ids.has(item.id): return false
		ids[item.id] = true
		if item.get("type") not in TYPES or not Navigation.valid_point(item.get("position")): return false
		if not _intensity(item.get("intensity")): return false
		for key in ["region", "configuration", "visual", "simulation", "generation"]:
			if not item.get(key) is Dictionary or not _wire(item[key]): return false
		# Empty Phase 1 reserved records remain valid but cannot select an effect.
		if item.type == ASTEROID_FIELD and not item.region.is_empty() and (not Asteroids.valid(item) or not Asteroids.valid_visual(item.visual)): return false
	return true


# Explicit legacy effects win. Otherwise choose the lexically smallest containing
# asteroid ID, independent of array order. Other phenomenon types remain reserved.
static func evaluate(state: Resource, location: Array, instances: Array,
		encounter_index: int = -1, legacy_modifier: int = 0) -> Dictionary:
	var result: Dictionary = {"version": 1, "type": NONE, "instance_id": "",
		"intensity": 0.0, "configuration": {}, "visual": {},
		"location": location, "run_seed": str(state.seed_used),
		"system_number": state.system_number, "encounter_index": encounter_index,
		"legacy_modifier": legacy_modifier}
	if legacy_modifier == 0:
		var selected: Dictionary = {}
		for item in instances:
			if not item is Dictionary or item.get("type") != ASTEROID_FIELD: continue
			if not item.get("id") is String or not Asteroids.valid_visual(item.get("visual")) or not Asteroids.contains(item, location): continue
			if selected.is_empty() or item.id < selected.id: selected = item
		if not selected.is_empty():
			result.type = ASTEROID_FIELD
			result.instance_id = selected.id
			result.intensity = selected.intensity
			result.configuration = selected.configuration.duplicate(true)
			result.configuration.region = selected.region.duplicate(true)
			result.configuration.position = selected.position.duplicate()
			result.visual = selected.visual.duplicate(true)
	return snapshot(result)


# Only the selection boundary maps physical phenomena to existing mechanics/arenas.
static func modifier_id(value: Dictionary) -> int:
	var legacy: int = int(value.get("legacy_modifier", 0))
	if legacy != 0: return legacy
	return 1 if value.get("type") == ASTEROID_FIELD else 0


# Canonical typed snapshot fields make JSON restoration identical to live entry.
# Seeds stay decimal strings; arbitrary configuration/visual records use JSON types.
static func snapshot(value: Dictionary) -> Dictionary:
	# Match the single-slot codec's JSON precision before freezing, including
	# optional visual values and non-integral positions.
	var copy: Dictionary = JSON.parse_string(JSON.stringify(value))
	for key in ["version", "system_number", "encounter_index", "legacy_modifier"]:
		copy[key] = int(copy[key])
	copy.intensity = float(copy.intensity)
	var location: Array = []
	for coordinate in copy.location: location.append(float(coordinate))
	copy.location = location
	return frozen(copy)


static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("version") != 1 or value.get("type") not in [NONE, ASTEROID_FIELD]: return false
	if not value.get("instance_id") is String or value.instance_id.length() > 128: return false
	if not _intensity(value.get("intensity")): return false
	if value.type == NONE and (value.instance_id != "" or value.intensity != 0): return false
	if not Navigation.valid_point(value.get("location")): return false
	if not value.get("run_seed") is String or not value.run_seed.is_valid_int(): return false
	if not _integer(value.get("system_number"), 1) or not _integer(value.get("encounter_index"), -1): return false
	if not _integer(value.get("legacy_modifier"), 0) or value.legacy_modifier >= Modifiers.NAMES.size(): return false
	for key in ["configuration", "visual"]:
		if not value.get(key) is Dictionary or not _wire(value[key]): return false
	if value.type == ASTEROID_FIELD:
		if value.instance_id.is_empty() or value.legacy_modifier != 0 or not Asteroids.valid_visual(value.visual): return false
		if not Asteroids.valid({"position": value.configuration.get("position"), "region": value.configuration.get("region")}): return false
	return true


static func frozen(value: Variant) -> Variant:
	var copy: Variant = value.duplicate(true)
	_freeze(copy)
	return copy


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()


static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= 1000000000


static func _intensity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1000000


# Bound optional data and reject objects/resources/non-finite values at the save boundary.
static func _wire(value: Variant, depth: int = 0) -> bool:
	if depth > 8: return false
	if value is Dictionary:
		if value.size() > 128: return false
		for key in value:
			if not key is String or key.length() > 128 or not _wire(value[key], depth + 1): return false
		return true
	if value is Array:
		if value.size() > 256: return false
		for child in value:
			if not _wire(child, depth + 1): return false
		return true
	if value is String: return value.length() <= 4096
	if value is float: return is_finite(value)
	if value is int: return value >= -9007199254740991 and value <= 9007199254740991
	return value == null or value is bool
