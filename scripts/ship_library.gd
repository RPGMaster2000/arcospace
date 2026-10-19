extends RefCounted
# RESPONSIBILITY: Register selectable player ships and the standard enemy fallback pool.
# EXTEND: Register profiles here; selection duplicates the existing panel template and pages three at a time.
const PLAYERS = [preload("res://ships/player/endeavour.tres"), preload("res://ships/player/thunderbolt.tres"), preload("res://ships/player/titania.tres"), preload("res://ships/player/ganymede.tres"), preload("res://ships/player/callisto.tres"), preload("res://ships/player/orion.tres")]
const ENEMIES = [preload("res://ships/enemy/marauder.tres"), preload("res://ships/enemy/sentinel.tres"), preload("res://ships/enemy/reclaimer.tres")]
