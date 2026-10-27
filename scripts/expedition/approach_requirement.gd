extends RefCounted
# Detached requirement facts. State evaluates eligibility; UI chooses wording and layout.
enum Kind { NONE, PRODUCTION, SALVAGE, FULL_HULL }
var kind: Kind
var attribute: String
var required: int
var current: int

func _init(type: Kind = Kind.NONE, key: String = "", minimum: int = 0, available: int = 0) -> void:
	kind = type
	attribute = key
	required = minimum
	current = available

func is_locked() -> bool:
	return kind != Kind.NONE
