extends RefCounted
## Stateless Defense reward transactions. All mutable data belongs to the supplied
## ExpeditionState and its existing deck, effects and DefenseState components.
const Requirement = preload("res://scripts/expedition/approach_requirement.gd")


class Resolution:
	extends RefCounted
	# Detached transaction facts, not a second reward/expedition ledger.
	var resolved := false
	var interrupted := false


static func _tier_one_count(state: Resource) -> int:
	var count := 0
	for card in state.available_reward_cards():
		if card.tier == 1:
			count += 1
	return count


# Reward-specific availability precedes the facade's shared production/price/Hull
# gates. Preserve reason precedence for approaches containing multiple rewards.
static func reward_requirement(state: Resource, approach: Resource) -> RefCounted:
	var reward: Dictionary = approach.get_meta("strategic_reward")
	var reason := ""
	if reward.has("decoy") and state.decoys >= state.DECOY_CAPACITY:
		reason = "Tactical Decoy inventory full"
	if (
		reward.has("extraction")
		and (state.defense.complete or state.poi_effects.extraction_source >= 0)
	):
		reason = "Extraction already online or system secured"
	if (
		reward.has("turret")
		and not state.can_deploy_poi_turret(int(approach.get_meta("source_encounter", -1)))
	):
		reason = "Free turret already used or location unavailable"
	if (
		reward.has("mothership")
		and (not state.poi_effects.mothership.is_empty() or state.defense.complete)
	):
		reason = "Mothership research is already active or the system is secured"
	if state.defense.complete and (reward.has("pause") or reward.has("reduction") or reward.has("pressure_relief")):
		reason = "System secured; Pressure effects are no longer needed"
	if int(reward.get("hull", 0)) < 0 and state.hull <= -int(reward.hull):
		reason = "Requires more than %d Hull" % -int(reward.hull)
	if reward.has("cards"):
		if _tier_one_count(state) < 2:
			reason = "Fewer than two eligible unowned Tier 1 cards remain"
		if state.deck_limit() < 2:
			reason = "Deck capacity must support both reward identities"
	return null if reason.is_empty() else Requirement.new(Requirement.Kind.UNAVAILABLE, reason)


static func reward_rng(state: Resource, index: int) -> RandomNumberGenerator:
	# Established namespace and index dependency; never consume gameplay RNG.
	var generator := RandomNumberGenerator.new()
	generator.seed = hash(
		"%d:%d:%d:defense-poi-reward:v1" % [state.seed_used, state.system_number, index]
	)
	return generator


# The facade checks encounter/mode access first. Its shared approach gate calls
# reward_requirement above; that pure query never recurses into resolution.
static func resolve(state: Resource, index: int, slot: int) -> Resolution:
	var result := Resolution.new()
	var approaches: Array = state.poi_approaches(index)
	if slot < 0 or slot >= approaches.size():
		return result
	var approach: Resource = approaches[slot]
	if not state.locked_reason(approach).is_empty():
		return result
	# All eligibility checks precede the encounter's only completion mutation.
	if not state._complete_encounter(index):
		return result
	state._commit_activity_time(float(approach.get_meta("strategic_seconds")))
	result.resolved = true
	if state.run_ended:
		result.interrupted = true
		state.last_outcome = "The invasion ended the expedition during this operation."
		return result
	# No RNG construction, success marker or reward before this boundary. Effects
	# activate after their acquisition cost, including interrupted strategic spans.
	_apply_reward(state, index, approach)
	return result


static func _apply_reward(state: Resource, index: int, approach: Resource) -> void:
	var reward: Dictionary = approach.get_meta("strategic_reward")
	var generator := reward_rng(state, index)
	state.last_poi_success = 1
	state.last_outcome = approach.get_meta("strategic_description")
	state.salvage -= approach.salvage_cost
	_apply_salvage(state, reward, generator)
	_apply_effects(state, reward)
	_apply_inventory(state, index, reward, generator)


static func _apply_salvage(
	state: Resource, reward: Dictionary, generator: RandomNumberGenerator
) -> void:
	if reward.has("salvage_range"):
		var amount := generator.randi_range(reward.salvage_range[0], reward.salvage_range[1])
		state.salvage += amount
		state.last_outcome = "+%d Salvage recovered." % amount
	state.salvage += int(reward.get("salvage", 0))


static func _apply_effects(state: Resource, reward: Dictionary) -> void:
	if reward.has("pressure_relief"):
		state.defense.relieve_pressure(reward.pressure_relief)
	if reward.has("production"):
		var boost: Dictionary = reward.production
		state.poi_effects.grant_production(boost.category, boost.amount, boost.battles)
	if reward.has("pause"):
		state.poi_effects.pause = maxf(state.poi_effects.pause, reward.pause)
	if reward.has("reduction"):
		state.poi_effects.reduction = maxf(state.poi_effects.reduction, reward.reduction)
	if reward.has("fuel"):
		state.poi_effects.fuel = maxf(state.poi_effects.fuel, reward.fuel)
	if reward.has("mothership"):
		state.poi_effects.mothership = reward.mothership


static func _apply_inventory(
	state: Resource, index: int, reward: Dictionary, generator: RandomNumberGenerator
) -> void:
	if reward.has("cards"):
		state.start_card_batch(generator)
	if reward.has("next_battle"):
		state.add_modifiers(reward.next_battle)
	if reward.has("hull"):
		state.hull += int(reward.hull)
		if reward.hull > 0: state.hull = mini(state.ship().hull_capacity, state.hull)
	if reward.has("turret"):
		state._install_poi_turret(index)
	if reward.has("decoy"):
		state.decoys += 1
	if reward.has("extraction"):
		state.poi_effects.start_extraction(index)
