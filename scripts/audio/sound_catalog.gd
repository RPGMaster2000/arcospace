extends Resource
# RESPONSIBILITY: Consolidate replaceable event Resources; no file paths in callers.
@export var events: Array[Resource] = []


func find_event(event_id: StringName) -> Resource:
	for event in events:
		if event != null and event.event_id == event_id:
			return event
	return null
