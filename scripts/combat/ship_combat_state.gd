extends RefCounted
# Authoritative ship attributes. Rule modules receive detached snapshots.
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]

var hull: int = 30
var hull_capacity: int = 30
var shields: int = 10
var materials: int = 16
var energy: int = 16
var crew: int = 16
var synthesizer: int = 2
var reactor: int = 2
var quarters: int = 2


func snapshot() -> Dictionary:
	return {
		"hull": hull,
		"hull_capacity": hull_capacity,
		"shields": shields,
		"materials": materials,
		"energy": energy,
		"crew": crew,
		"synthesizer": synthesizer,
		"reactor": reactor,
		"quarters": quarters,
	}


# Only combat attributes cross this boundary; diagnostic metadata is never stored.
func apply_snapshot(values: Dictionary) -> void:
	hull = int(values["hull"])
	hull_capacity = int(values["hull_capacity"])
	shields = int(values["shields"])
	materials = int(values["materials"])
	energy = int(values["energy"])
	crew = int(values["crew"])
	synthesizer = int(values["synthesizer"])
	reactor = int(values["reactor"])
	quarters = int(values["quarters"])


func copy() -> RefCounted:
	var result = get_script().new()
	result.apply_snapshot(snapshot())
	return result
