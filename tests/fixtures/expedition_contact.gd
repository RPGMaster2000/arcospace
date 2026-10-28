extends RefCounted
# Drive the real movement/contact rules without waiting for render-frame travel timing.
# Startup and process-restart tests must not bypass defense combat eligibility.
static func reach(state: Resource, index: int) -> bool:
	if not state.is_defense(): return state.can_engage(index)
	if state.can_engage(index): return true
	var unit: Dictionary = state.defense.unit_for(index)
	if unit.is_empty() or not state.defense.available(unit): return false
	state.navigation.checkpoint_position(state.navigation.position)
	state.begin_free_travel(state.Defense.wire(unit.position))
	for step in range(128):
		if not state.navigation.leg_active: break
		var position: Vector3 = state.Defense.point(state.navigation.position)
		state.navigation.report_movement(state.Defense.wire(position.move_toward(unit.position, 1.0)))
		if state.defense.contact >= 0: break
	return state.defense.contact == index and state.can_engage(index)
