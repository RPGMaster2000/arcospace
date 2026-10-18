extends RefCounted
# RESPONSIBILITY: Register selectable player ships and the standard enemy fallback pool.
# EXTEND: Player selection currently assumes three entries in battle_setup.gd and battle_setup.tscn.
const PLAYERS = [preload("res://ships/endeavour.tres"), preload("res://ships/thunderbolt.tres"), preload("res://ships/titania.tres")]
const ENEMIES = [preload("res://ships/marauder.tres"), preload("res://ships/sentinel.tres"), preload("res://ships/reclaimer.tres")]
