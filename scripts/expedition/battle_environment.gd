extends RefCounted
## Shared scene-free wire model. ExpeditionState owns mutable instances; consumers
## receive detached read-only views. No generation, simulation or overlap policy yet.
const NONE = "NONE"
const ASTEROID_FIELD = "ASTEROID_FIELD"
const SOLAR_INTERFERENCE = "SOLAR_INTERFERENCE"
const SPACE_STORM = "SPACE_STORM"
const TEMPORAL_RIFT = "TEMPORAL_RIFT"
const TYPES = [NONE, ASTEROID_FIELD, SOLAR_INTERFERENCE, SPACE_STORM, TEMPORAL_RIFT]
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")


# JSON-shaped records keep visuals and future simulation on the same instance ID.
# region/configuration are reserved data, not implemented geometry or effect rules.
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
	return true


# Phase 1 deliberately ignores physical instances. Future spatial selection belongs
# here, using a dedicated generation stream; never consume State or combat RNG.
static func evaluate(state: Resource, location: Array, _instances: Array,
		encounter_index: int = -1, legacy_modifier: int = 0) -> Dictionary:
	return frozen({"version": 1, "type": NONE, "instance_id": "",
		"intensity": 0.0, "configuration": {}, "visual": {},
		"location": location, "run_seed": str(state.seed_used),
		"system_number": state.system_number, "encounter_index": encounter_index,
		"legacy_modifier": legacy_modifier})


static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary: return false
	# Only neutral physical snapshots exist in this phase. Future selection needs
	# explicit validation/versioning before enabling another type.
	if value.get("version") != 1 or value.get("type") != NONE or value.get("instance_id") != "": return false
	if not _intensity(value.get("intensity")) or value.intensity != 0: return false
	if not Navigation.valid_point(value.get("location")): return false
	if not value.get("run_seed") is String or not value.run_seed.is_valid_int(): return false
	if not _integer(value.get("system_number"), 1) or not _integer(value.get("encounter_index"), -1): return false
	if not _integer(value.get("legacy_modifier"), 0) or value.legacy_modifier >= Modifiers.NAMES.size(): return false
	for key in ["configuration", "visual"]:
		if not value.get(key) is Dictionary or not _wire(value[key]): return false
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
	return value == null or value is bool or value is int
