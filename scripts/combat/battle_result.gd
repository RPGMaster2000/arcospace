extends RefCounted
# Encounter completion and persistent values, independent of Board/hand lifetimes.
const TACTICAL_RESOURCES: int = 5
const STRATEGIC_SHIELDS: int = 10
var result_id: int = get_instance_id()
var encounter_index: int = -1
var system_number: int = 0
var winner: String = ""
var result_cause: String = ""
var escaped_by_ftl: bool = false
var player_hull: int = 0
var salvage: int = 0
var battles_won: int = 0
var earned_tactical: bool = false
var earned_strategic: bool = false
var tactical_resources: int = TACTICAL_RESOURCES
var strategic_shields: int = STRATEGIC_SHIELDS
