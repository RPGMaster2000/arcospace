extends Resource
# RESPONSIBILITY: Own expedition state, generation, rewards and battle handoff.
# DOES NOT: Create UI nodes, animate travel or resolve individual combat actions.
# EXTEND: Deck owns card transactions; this facade coordinates encounters and persistence.
class_name ExpeditionState
signal deck_changed
signal progress_committed
signal defense_advanced(events: Dictionary)
const Defense = preload("res://scripts/expedition/defense_state.gd")
const TemporalRift = preload("res://scripts/expedition/temporal_rift.gd")
const SystemLayout = preload("res://scripts/expedition/system_layout.gd")
const RouteEnvironments = preload("res://scripts/expedition/route_environments.gd")
var layout_expansion: float = 0.0
var orbit_clearance: float = 0.0
var game_mode: String = "exploration"
var defense: RefCounted
var rifts := TemporalRift.new()
const PoiEffects = preload("res://scripts/expedition/defense_poi_effects.gd")
var poi_effects := PoiEffects.new()
var defense_poi_version: int = 0
const DefensePois = preload("res://scripts/expedition/defense_poi_approaches.gd")
const DECOY_CAPACITY := 2
const DECOY_MAP_SETTINGS = preload("res://resources/presentation/star_system_settings.tres")
var decoys := 0

func is_defense() -> bool:
	return game_mode == "defense"

func consume_defense_reveal() -> bool:
	if not is_defense() or not defense.reveal_pending: return false
	defense.reveal_pending = false
	progress_committed.emit()
	return true

func bind_defense_movement() -> void:
	if defense != null: defense.poi_effects = poi_effects
	if not navigation.movement_advanced.is_connected(_advance_defense):
		navigation.movement_advanced.connect(_advance_defense)

func _advance_defense(distance: float) -> void:
	if not is_defense() or defense == null or not can_navigate(): return
	_advance_strategy(distance * rules.defense_tuning.seconds_per_distance,
		Defense.point(navigation.movement_origin), Defense.point(navigation.position), false)

# Activity commits and movement share event ordering and collision handling.
func _advance_strategy(seconds: float, from: Vector3, to: Vector3, carry: bool) -> void:
	if not is_defense() or defense == null or defense.complete or run_ended: return
	var previous_rift: String = TemporalRift.active(environmental_instances).get("id", "")
	var events: Dictionary = defense.advance_time(seconds, from, to, carry,
		rifts.advance_span.bind(defense, environmental_instances))
	var extraction_salvage: int = poi_effects.advance_extraction(events.elapsed)
	salvage += extraction_salvage
	events.extraction_salvage = extraction_salvage
	var rift_changed: bool = previous_rift != TemporalRift.active(environmental_instances).get("id", "")
	for unit in defense.units:
		if unit.status == "arrived": encounters[unit.encounter].completed = true
	var target: Dictionary = defense.unit_for(travel_destination) if not carry else {}
	var target_lost: bool = not target.is_empty() and not defense.available(target)
	events.target_lost = target_lost
	if events.contact >= 0 or events.missile_contact >= 0 or defense.failed() or target_lost:
		navigation.checkpoint_position(Defense.wire(events.position))
		navigation.stop()
		travel_destination = -1
		pending_destination = -1
		navigation_origin = FREE_DESTINATION
	if defense.failed():
		run_ended = true
		poi_effects.stop_extraction()
	if not carry: poi_effects.consume_distance(from.distance_to(events.position))
	defense_advanced.emit(events)
	if not carry and (events.contact >= 0 or events.arrivals > 0 or events.escalated or events.revealed
			or events.missile_event or events.decoy_changed or defense.failed() or target_lost
			or not events.spawned.is_empty() or rift_changed or extraction_salvage > 0):
		progress_committed.emit()

func _commit_activity_time(seconds: float) -> void:
	if not is_defense() or defense == null or defense.complete or run_ended: return
	if navigation.position.size() != 3: return
	var total: float = seconds + defense.deferred_seconds
	defense.deferred_seconds = 0.0
	var position: Vector3 = Defense.point(navigation.position)
	_advance_strategy(total, position, position, true)

var run_ended: bool = false
const BattleSetup = preload("res://scripts/combat/battle_setup.gd")
const BattleResult = preload("res://scripts/combat/battle_result.gd")
const ShipState = preload("res://scripts/combat/ship_combat_state.gd")
var _recorded_results: Dictionary = {}

const Modifiers = preload("res://scripts/combat_modifier.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
# Sole mutable owner. The map and battles receive detached views, never this array.
var environmental_instances: Array = []
# Static exploration battle anchors only; DefenseState remains the moving authority.
var encounter_positions: Dictionary = {}


const Ships = preload("res://scripts/ships/ship_library.gd")
const Requirement = preload("res://scripts/expedition/approach_requirement.gd")
const Repairs = preload("res://scripts/repair_rules.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const PRODUCTION = preload("res://scripts/combat/ship_combat_state.gd").PRODUCTION
const RESOURCES = preload("res://scripts/combat/ship_combat_state.gd").RESOURCES
const LABELS = {
	"synthesizer": "Synthesizer",
	"reactor": "Reactor",
	"quarters": "Quarters",
	"materials": "Materials",
	"energy": "Energy",
	"crew": "Crew",
	"shields": "Shields",
	"emp_pulse_charge": "EMP Pulse charge",
	"emp_pulse_offline": "EMP Pulse offline turns"
}
var rules: Resource
var player_ship: int = 0
var hull: int = 0
var salvage: int = 0
var battles_won: int = 0
const SystemGenerator = preload("res://scripts/expedition/system_generator.gd")
const Profiles = preload("res://scripts/expedition/system_profile.gd")
const Pressure = preload("res://scripts/expedition/system_pressure.gd")
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const ChasedownRollPolicy = preload("res://scripts/expedition/chasedown_roll_policy.gd")
const FREE_DESTINATION = -3
var pressure: int = 0
var system_profile: String = "industrial"
var ftl_access: bool = false
var navigation := Navigation.new()
var chasedown_roll_policy := ChasedownRollPolicy.new()
var system_number: int = 0
var system_name: String = ""
var encounters: Array[Dictionary] = []
# Independent service visit, deliberately outside the regular progression encounters.
const SERVICE_INDEX = -2
var service: Dictionary = {}
var next_outpost_system: int = 0
var station_production_purchases: int = 0
# Each confirmation carries this revision; an old confirmation can never spend twice.
var service_revision: int = 0
var station_rng := RandomNumberGenerator.new()

const Deck = preload("res://scripts/expedition/expedition_deck.gd")
var _deck := Deck.new()
# Compatibility/codec facade, never parallel state. Collection containers are copies;
# CardData definitions remain shared read-only values as in the existing battle contract.
# Normal callers mutate through choose/replace/upgrade; setters support restored fixtures.
var acquired_cards: Array[Resource]:
	get: return _deck.acquired_cards.duplicate()
	set(value): _deck.acquired_cards = value.duplicate()
var upgraded_cards: Dictionary:
	get: return _deck.upgraded_cards.duplicate()
	set(value): _deck.upgraded_cards = value.duplicate()
var removed_starting_cards: Dictionary:
	get: return _deck.removed_starting_cards.duplicate()
	set(value): _deck.removed_starting_cards = value.duplicate()
var pending_card: Resource:
	get: return _deck.pending_card
	set(value): _deck.pending_card = value
var upgrades_remaining: int:
	get: return _deck.upgrades_remaining
	set(value): _deck.upgrades_remaining = value
var upgraded_this_event: Dictionary:
	get: return _deck.upgraded_this_event.duplicate()
	set(value): _deck.upgraded_this_event = value.duplicate()
var card_offers: Array[Resource]:
	get: return _deck.card_offers.duplicate()
	set(value): _deck.card_offers = value.duplicate()
var pending_choice: String:
	get: return _deck.pending_choice
	set(value): _deck.pending_choice = value

var production_upgrades: Dictionary = {}
var pending_bonuses: Dictionary = {}
var pending_penalties: Dictionary = {}
var choice_amount: int = 0
var last_outcome: String = ""
# -1 = no rolled PoI result (station/survey/battle); 0 = worse branch; 1 = success branch.
var last_poi_success: int = -1
# Travel interruption counters; the codec persists unresolved encounters and cancellation state.
var navigation_origin: int = -1
var travel_destination: int = -1
var pending_destination: int = -1
var chasedown_index: int = -1
var chasedowns_this_system: int = 0
var chasedown_rng := RandomNumberGenerator.new()
var field_repairs_open: bool = false  # Set only by the exploration controller while the system view is open.
var active_battle: int = -1
var rng := RandomNumberGenerator.new()
var seed_used: int = 0

#region Run setup



func environment_view() -> Array:
	return EnvironmentData.frozen(environmental_instances)

func defense_map_view() -> Dictionary:
	var view: Dictionary = defense.snapshot()
	view.temporal_rift = TemporalRift.active(environmental_instances).duplicate(true)
	return view

func can_place_decoy() -> bool:
	return is_defense() and defense != null and decoys > 0 and defense.decoy.is_empty() \
		and not defense.complete and can_navigate() and not navigation.leg_active

func decoy_placement(at: Vector3) -> String:
	if not can_place_decoy(): return "Decoy unavailable"
	if not at.is_finite() or absf(at.y) > 0.001 or not SystemLayout.bounds(layout_expansion).has_point(Vector2(at.x, at.z)):
		return "Outside navigation bounds"
	if navigation.position.size() != 3: return "Ship position unavailable"
	var distance := at.distance_to(Defense.point(navigation.position))
	if distance > defense.tuning.decoy_deploy_range: return "Outside deployment range"
	if distance < 1.0: return "Too close to your ship"
	var sun: Dictionary = {}
	for item in environmental_instances:
		if item.type == EnvironmentData.SOLAR_INTERFERENCE and EnvironmentData.Solar.valid(item):
			sun = item
			break
	var center := Vector3.ZERO if sun.is_empty() else Defense.point(sun.position)
	var radius: float = EnvironmentData.Solar.CORE_RADIUS_PER_SCALE * DECOY_MAP_SETTINGS.sun_core_scale if sun.is_empty() else sun.configuration.star_radius
	if at.distance_to(center) <= radius + 0.35: return "Stellar surface"
	if at.distance_to(defense.home) <= 1.8 * 1.5 * 1.035 + 0.35: return "Homeworld"
	for body in defense.decorative_bodies:
		if at.distance_to(body.position) <= float(body.radius) * 1.5 * 1.035 + 0.35: return "Planetary surface"
	var planetary := SystemLayout.planetary_radii(encounters)
	for index in defense.anchors:
		var interaction_radius := maxf(DECOY_MAP_SETTINGS.orbit_radius, float(planetary.get(index, 1.2)) + 1.0)
		if at.distance_to(defense.anchors[index]) <= interaction_radius + 0.35: return "Too close to a destination"
	for turret in defense.turrets.values():
		if at.distance_to(Defense.point(turret.position)) <= 1.35: return "Turret installation"
	for unit in defense.units:
		if unit.status == "active" and at.distance_to(unit.position) < 0.75: return "Hostile ship"
	return ""

func deploy_decoy(at: Vector3) -> bool:
	if not decoy_placement(at).is_empty(): return false
	defense.place_decoy(at)
	decoys -= 1
	progress_committed.emit()
	return true

func has_missile(index: int) -> bool:
	return is_defense() and defense != null and defense.missiles.active.has(index)

func resolve_missile(index: int, approach: String) -> bool:
	if not has_missile(index) or defense.missiles.pending != index or run_ended: return false
	var seconds: float
	match approach:
		"direct": seconds = defense.tuning.missile_intercept_seconds
		"precision":
			if int(production_upgrades.get("reactor", 0)) <= 0: return false
			seconds = defense.tuning.missile_precision_seconds
		"emp":
			if modifier_value("emp_pulse_charge") <= 0: return false
			pending_bonuses.emp_pulse_charge = int(pending_bonuses.get("emp_pulse_charge", 0)) - 1
			seconds = defense.tuning.missile_emp_seconds
		_: return false
	defense.missiles.active.erase(index)
	defense.missiles.pending = -1
	_commit_activity_time(seconds)
	progress_committed.emit()
	return true

func refresh_defense_bodies() -> void:
	if not is_defense() or layout_expansion <= 0.0: return
	var visual := preload("res://scripts/presentation/star_system/visual_system.gd").generate(
		seed_used, system_number, [], preload("res://resources/presentation/star_system_settings.tres"),
		system_profile, layout_expansion, orbit_clearance)
	preload("res://scripts/presentation/star_system/defense_presentation.gd").layout(
		visual, defense.snapshot(), SystemLayout.planetary_indices(encounters), layout_expansion, orbit_clearance,
		SystemLayout.planetary_radii(encounters))
	defense.decorative_bodies = visual.planets.slice(1)


func battle_location(index: int) -> Array:
	if index < 0 or index >= encounters.size() or encounters[index].kind != "battle": return []
	if is_defense():
		var unit: Dictionary = defense.unit_for(index)
		# Battle is located at the visible hostile, including at swept contact.
		# Player/hostile centers can differ by interception radius.
		if not unit.is_empty() and unit.status == "active": return Defense.wire(unit.position)
		return []
	if encounters[index].get("chasedown", false):
		var at: Array = encounters[index].get("intercept_position", [])
		return at.duplicate() if at.size() == 3 else []
	return encounter_positions.get(str(index), []).duplicate()


func turret_support(index: int) -> Dictionary:
	if not is_defense() or defense == null: return {}
	return Defense.Installations.support_at(defense.turrets, battle_location(index))

func can_deploy_turret(site: String) -> bool:
	return is_defense() and defense != null and can_navigate() and not navigation.leg_active \
		and not defense.complete and defense.construction_sites.has(site) and not defense.turrets.has(site) \
		and Defense.Installations.purchased_count(defense.turrets) < mini(2, defense.tuning.turret_capacity) and salvage >= defense.tuning.turret_salvage_cost

func deploy_turret(site: String) -> bool:
	if not can_deploy_turret(site): return false
	var tuning: Resource = defense.tuning
	defense.turrets[site] = {"type": Defense.Installations.KINETIC, "owner": "player",
		"position": defense.construction_sites[site].position.duplicate(), "radius": tuning.turret_radius,
		"damage": tuning.turret_damage, "interval": tuning.turret_round_interval}
	salvage -= tuning.turret_salvage_cost
	progress_committed.emit()
	return true

# Called by the authoritative PoI transaction; never moves an anchor or spends Salvage.
func can_deploy_poi_turret(index: int) -> bool:
	if not is_defense() or defense == null or not can_visit(index): return false
	return Defense.Installations.free_count(defense.turrets) == 0 and Defense.Installations.purchased_count(defense.turrets) <= 2 and not defense.complete \
		and Defense.Installations.free_sites(defense.anchors, encounters).has(Defense.Installations.FREE_PREFIX + str(index))

func deploy_poi_turret(index: int) -> bool:
	if not can_deploy_poi_turret(index): return false
	_install_poi_turret(index)
	return true

func _install_poi_turret(index: int) -> void:
	var id: String = Defense.Installations.FREE_PREFIX + str(index)
	var tuning: Resource = defense.tuning
	defense.turrets[id] = {"type":Defense.Installations.KINETIC,"owner":"player",
		"position":Defense.wire(defense.anchors[index]),"radius":tuning.turret_radius,
		"damage":tuning.turret_damage,"interval":tuning.turret_round_interval}

func battle_environment(index: int) -> Dictionary:
	var snapshot: Dictionary = EnvironmentData.evaluate(self, battle_location(index), environmental_instances,
		index, int(encounters[index].get("modifier", 0)) if index >= 0 and index < encounters.size() else 0)
	var support := turret_support(index)
	var advantage: String = poi_effects.mothership if is_defense() and defense.unit_for(index).get("mothership",false) else ""
	if support.is_empty() and advantage.is_empty(): return snapshot
	var combined := snapshot.duplicate(true)
	if not support.is_empty(): combined.friendly_support = support
	if not advantage.is_empty(): combined.mothership_advantage = advantage
	return EnvironmentData.snapshot(combined)


# Preview is a pure query; only Persistence captures the authoritative entry snapshot.
func preview_modifier(index: int) -> int:
	if index < 0 or index >= encounters.size(): return 0
	return EnvironmentData.modifier_id(EnvironmentData.evaluate(self, battle_location(index),
		environmental_instances, index, int(encounters[index].get("modifier", 0))))


func encounter_at(index: int) -> Dictionary:
	return service if index == SERVICE_INDEX else encounters[index]


func start(ship_index: int, configuration: Resource, seed_override: int = 0) -> void:
	run_ended = false
	poi_effects = PoiEffects.new()
	defense_poi_version = 0
	decoys = 0
	rules = configuration
	game_mode = rules.game_mode
	player_ship = clampi(ship_index, 0, Ships.PLAYERS.size() - 1)
	hull = ship().hull_capacity
	salvage = 0
	battles_won = 0
	system_number = 0
	pressure = 0
	ftl_access = false
	navigation = Navigation.new()
	bind_defense_movement()
	chasedown_roll_policy = ChasedownRollPolicy.new()
	next_outpost_system = 0
	station_production_purchases = 0
	service_revision += 1
	production_upgrades.clear()
	pending_bonuses.clear()
	pending_penalties.clear()
	_deck.reset()
	_recorded_results.clear()
	last_poi_success = -1
	active_battle = -1
	field_repairs_open = false
	var chosen_seed: int = seed_override if seed_override != 0 else rules.debug_seed
	if chosen_seed == 0:
		rng.randomize()
	else:
		rng.seed = chosen_seed
	seed_used = rng.seed
	# Separate stream: station probability draws cannot change encounter generation or loot rolls.
	station_rng.seed = seed_used ^ 0x53544154494F4E
	chasedown_rng.seed = seed_used ^ 0x4348415345
	# Retain this legacy station-stream draw: removing it changes seeded profile outposts.
	# The saved counter is compatibility data; profile probabilities now choose actual stations.
	next_outpost_system = _station_interval()
	generate_system()


func ship() -> Resource:
	return Ships.PLAYERS[player_ship]


func production(key: String) -> int:
	return int(ship().get(key)) + int(production_upgrades.get(key, 0))


#endregion

#region Systems and navigation


# Pure travel plan. Strategic seconds per distance remain unchanged.
func travel_speed_profile(distance: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var boosted: float = minf(maxf(0.0,distance),poi_effects.fuel) if is_defense() else 0.0
	if boosted > 0: result.append(Vector2(boosted,1.5))
	if distance > boosted: result.append(Vector2(distance-boosted,1.0))
	return result

func can_jump() -> bool:
	return (
		hull > 0
		and not run_ended
		and active_battle < 0
		and not chasedown_unresolved()
		and pending_choice.is_empty()
		and system_objective_complete()
	)


# Persistent system objective boundary, independent of transient UI/battle readiness.
# Future objective modes change this condition, while every Jump caller keeps can_jump().
func system_objective_complete() -> bool:
	return defense != null and defense.complete if is_defense() else ftl_access and not mandatory_boss_pending()


func mandatory_boss_pending() -> bool:
	if is_defense(): return false
	var found: bool = false
	for encounter in encounters:
		if encounter.get("mandatory_boss", false):
			found = true
			if not encounter.completed:
				return true
	# Fail closed if a malformed/custom milestone loses its mandatory encounter.
	return not found and rules.progression.is_boss_system(system_number)


func difficulty_level() -> int:
	return rules.progression.difficulty_level(system_number)


func _enemy_index(items: Array) -> int:
	if difficulty_level() == 1:
		return _weighted_index(items)
	var elites: Array = []
	var others: Array = []
	for profile in items:
		if profile.enemy_rank == 1:
			elites.append(profile)
		else:
			others.append(profile)
	if elites.is_empty() or others.is_empty():
		return _weighted_index(items)
	var bucket: Array = (
		elites
		if rng.randf() < rules.progression.elite_probability(items, system_number)
		else others
	)
	return items.find(bucket[_weighted_index(bucket)])


func _weighted_index(items: Array) -> int:
	var total: float = 0.0
	for item in items:
		total += maxf(0.01, item.encounter_weight)
	var roll: float = rng.randf() * total
	for index in range(items.size()):
		roll -= maxf(0.01, items[index].encounter_weight)
		if roll <= 0:
			return index
	return items.size() - 1


func _station_interval() -> int:
	var low: int = clampi(rules.minimum_station_interval, 2, 3)
	var high: int = clampi(rules.maximum_station_interval, low, 3)
	return station_rng.randi_range(low, high)


# Generate encounters from one rules registry; both map and grid read this same array.
# Transition eligibility stays here; the generator replaces mandatory Boss slots independently of presentation.
func generate_system() -> bool:
	if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0:
		return false
	if system_number > 0 and not can_jump():
		return false
	_recorded_results.clear()
	environmental_instances.clear()
	layout_expansion = rules.system_expansion
	orbit_clearance = rules.planet_orbit_clearance if rules.defense_v2 and layout_expansion > 0.0 else 0.0
	poi_effects.leave_system()
	SystemGenerator.generate(self)
	bind_defense_movement()
	refresh_defense_bodies()
	if is_defense(): rifts.reset(seed_used, system_number, defense.tuning.rift_initial_delay)
	encounter_positions = {} if is_defense() else preload("res://scripts/presentation/star_system/visual_system.gd").battle_positions(self)
	var routed: bool = is_defense() and defense.v2
	var route_points: Array = RouteEnvironments.points(defense) if routed else encounter_positions.values()
	environmental_instances = RouteEnvironments.asteroid(seed_used, system_number, defense, route_points) if routed \
		else EnvironmentData.Asteroids.generate(seed_used, system_number, route_points, layout_expansion)
	var solar = preload("res://scripts/expedition/solar_regions.gd")
	var star_settings = preload("res://resources/presentation/star_system_settings.tres")
	var influence := solar.generate(seed_used, system_number, [0.0, 0.0, 0.0],
		solar.CORE_RADIUS_PER_SCALE * star_settings.sun_core_scale, rules.solar_influence_radius_range,
		0.8 if layout_expansion > 0.0 else 1.0)
	if not routed or RouteEnvironments.relevant(influence, defense): environmental_instances.append(influence)
	var hostile_positions: Array = []
	for index in encounters.size():
		var location := battle_location(index)
		if not location.is_empty(): hostile_positions.append(location)
	var storm := EnvironmentData.Storms.generate(seed_used, system_number, rules.space_storm_chance,
		route_points if routed else hostile_positions, environmental_instances, layout_expansion)
	if routed: storm = RouteEnvironments.storm(storm, defense, route_points, environmental_instances)
	if not storm.is_empty(): environmental_instances.append(storm)
	if is_defense(): environmental_instances = preload("res://scripts/expedition/environment_clearance.gd").protect_home(self,environmental_instances,route_points)
	navigation.reset_system()
	if is_defense(): navigation.checkpoint_position(Defense.wire(defense.start))
	# A new system ends the leg but preserves the exploration risk cooldown.
	chasedown_roll_policy.reset_leg()
	progress_committed.emit()
	return true


# Preserve the historical draw exactly: deleting it shifts enemies, objectives,
# pressure and loot. New encounters are neutral until physical phenomena exist.
# The override remains useful for historical-distribution regression comparisons.
func _roll_battle_modifier() -> int:
	Modifiers.roll_encounter(rng)
	return 0


func enemy_profile(encounter: Dictionary) -> Resource:
	var base: Resource = encounter.get("enemy_data", Ships.ENEMIES[int(encounter.get("enemy", 0))])
	var scaled: Resource = rules.progression.scaled_enemy(base, int(encounter.get("system_number", system_number)), is_defense())
	return scaled if is_defense() else Pressure.scaled_enemy(scaled, pressure)


func profile_name() -> String:
	return Profiles.for_id(system_profile).display_name


func system_profile_data() -> Resource:
	return Profiles.for_id(system_profile)


func profile_chasedown_multiplier() -> float:
	return system_profile_data().chasedown_multiplier


func objective_locked(index: int) -> bool:
	if index < 0 or index >= encounters.size(): return false
	var prerequisite: int = int(encounters[index].get("objective_prerequisite", -1))
	return prerequisite >= 0 and (prerequisite >= encounters.size() or not encounters[prerequisite].completed)


func identify_objective(index: int) -> void:
	if index >= 0 and index < encounters.size() and encounters[index].has("objective_role") and not encounters[index].get("objective_known", false):
		encounters[index].objective_known = true
		progress_committed.emit()


func objective_marker(index: int) -> String:
	if index < 0 or index >= encounters.size() or not encounters[index].has("objective_role"): return ""
	if encounters[index].completed: return "✓"
	if not encounters[index].get("objective_known", false): return "?"
	return "🔒" if objective_locked(index) else "!"


func ftl_status() -> String:
	if is_defense():
		if defense.complete: return "FTL READY"
		if defense.mothership_advancing:
			return "MOTHERSHIP ADVANCING · ETA %.1fs" % (defense.unit_for(defense.mothership_index()).position.distance_to(defense.home) / defense.tuning.mothership_speed)
		if defense.v2:
			return "MOTHERSHIP ACTIVE" if defense.revealed else "MOTHERSHIP REVEAL AT %d PRESSURE" % defense.reveal_threshold()
		return "MOTHERSHIP ACTIVE" if defense.revealed else "INTERCEPT TO LOCATE MOTHERSHIP"
	if mandatory_boss_pending(): return "BOSS LOCK"
	if ftl_access: return "FTL READY"
	for index in range(encounters.size()):
		if encounters[index].get("objective_role", "") == "access" and encounters[index].get("objective_known", false) and not objective_locked(index):
			return "FTL OBJECTIVE AVAILABLE"
	return "FTL LOCKED"


func encounter_pressure_risk(index: int) -> bool:
	if is_defense(): return false
	if index < 0 or index >= encounters.size(): return false
	var entry: Dictionary = encounters[index]
	return entry.get("pressure_sensitive", false) and not entry.has("objective_role") and pressure > int(entry.get("pressure_tolerance", 99999))


func pressure_risk_description(index: int) -> String:
	return "Pressure risk: −2 Energy next battle" if encounter_pressure_risk(index) else ""


# Completion is the only ledger: services and Chasedowns never add system pressure.
func _complete_encounter(index: int) -> bool:
	if index < 0 or index >= encounters.size() or encounters[index].completed or objective_locked(index): return false
	var risk: bool = encounter_pressure_risk(index)
	encounters[index].completed = true
	if not is_defense() and not encounters[index].get("chasedown", false): pressure += 1
	if encounters[index].get("objective_role", "") == "access": ftl_access = true
	for entry in encounters:
		if int(entry.get("objective_prerequisite", -1)) == index: entry.objective_known = true
	if risk: add_modifiers({"energy": -2})
	return true


func can_survey(index: int) -> bool:
	if is_defense() and defense_poi_version == 1: return false
	if not can_visit(index) or index == SERVICE_INDEX or objective_locked(index) or encounters[index].kind != "poi":
		return false
	for approach in encounters[index].poi.approaches:
		if not locked_reason(approach).is_empty():
			continue
		var worst: int = approach.success.hull
		if approach.success_chance < 1:
			worst = mini(worst, approach.failure.hull)
		if hull + worst > 0:
			return false
	return true


func survey(index: int) -> bool:
	if not can_survey(index):
		return false
	last_poi_success = -1
	_complete_encounter(index)
	add_modifiers(rules.survey_penalty)
	_commit_activity_time(rules.defense_tuning.poi_seconds)
	last_outcome = (
		"Navigation survey completed. No Salvage or other rewards. Next battle: "
		+ describe_modifiers(rules.survey_penalty)
	)
	progress_committed.emit()
	return true


func can_visit(index: int) -> bool:
	if is_defense() and defense != null:
		var unit: Dictionary = defense.unit_for(index)
		if not unit.is_empty() and not defense.available(unit): return false
		if defense.contact >= 0 and index != defense.contact: return false
		if defense.missiles.pending >= 0 and index != defense.missiles.pending: return false
	if run_ended or hull <= 0 or active_battle >= 0 or not pending_choice.is_empty():
		return false
	if chasedown_unresolved() and index != chasedown_index:
		return false
	if index == chasedown_index and chasedown_unresolved() and encounters[index].response < 0:
		return false
	if index == SERVICE_INDEX:
		return not service.is_empty()
	if has_missile(index): return true
	return index >= 0 and index < encounters.size() and not encounters[index].completed


func cancel_travel() -> void:
	navigation.stop()
	chasedown_roll_policy.reset_leg()
	travel_destination = -1
	pending_destination = -1
	navigation_origin = FREE_DESTINATION
	progress_committed.emit()


func navigation_destination(index: int, player: Vector3, fallback: Vector3) -> Vector3:
	if not is_defense(): return fallback
	var unit: Dictionary = defense.unit_for(index)
	return defense.intercept_point(index, player) if has_missile(index) or (not unit.is_empty() and defense.available(unit)) else fallback


func can_engage(index: int) -> bool:
	if not can_visit(index) or has_missile(index): return false
	if not is_defense(): return true
	var unit: Dictionary = defense.unit_for(index)
	return unit.is_empty() or defense.contact == index


# Roll once at actual movement initiation; arrival, menus and battle returns never call this.
# Independent RNG leaves authored encounter generation and PoI outcome rolls unchanged.
func can_navigate() -> bool:
	return (not is_defense() or defense == null or (defense.contact < 0 and defense.missiles.pending < 0)) and not run_ended and hull > 0 and active_battle < 0 and pending_choice.is_empty() and not chasedown_unresolved()


func begin_travel(destination: int, forced_roll: float = -1.0) -> bool:
	if not can_navigate() or not can_visit(destination): return false
	return _begin_navigation(destination, [], forced_roll)


func begin_free_travel(point: Array, forced_roll: float = -1.0) -> bool:
	if not can_navigate() or not Navigation.valid_point(point, false): return false
	return _begin_navigation(FREE_DESTINATION, point, forced_roll)


func _begin_navigation(destination: int, point: Array, forced_roll: float) -> bool:
	var new_leg: bool = navigation.begin(point)
	if new_leg: chasedown_roll_policy.reset_leg()
	pending_destination = -1
	travel_destination = destination
	var intercepted: bool = try_chasedown(destination, forced_roll) if new_leg else false
	if intercepted:
		travel_destination = -1
		navigation.stop()
		chasedown_roll_policy.reset_leg()
	progress_committed.emit()
	return intercepted


func advance_chasedown_cooldown(seconds: float) -> void:
	chasedown_roll_policy.advance(seconds)


func update_navigation_position(point: Array) -> void:
	navigation.checkpoint_position(point)


func effective_chasedown_chance() -> float:
	return clampf((rules.chasedown_chance + pressure * rules.pressure_chasedown_increment) * profile_chasedown_multiplier(), 0.0, rules.maximum_chasedown_chance)


func arrive_free_destination() -> void:
	if travel_destination != FREE_DESTINATION: return
	navigation.stop()
	chasedown_roll_policy.reset_leg()
	travel_destination = -1
	navigation_origin = FREE_DESTINATION
	pending_destination = -1
	progress_committed.emit()


func try_chasedown(destination: int, forced_roll: float = -1.0) -> bool:
	if is_defense(): return false
	if not can_navigate(): return false
	if destination != FREE_DESTINATION and (not can_visit(destination) or destination < 0 or encounters[destination].kind != "poi"): return false
	if navigation_origin == destination and destination != FREE_DESTINATION: return false
	if navigation_origin != FREE_DESTINATION and (navigation_origin < 0 or navigation_origin >= encounters.size() or encounters[navigation_origin].kind != "poi"): return false
	if chasedowns_this_system >= maxi(0, rules.chasedown_limit): return false
	var pool: Array = []
	for profile in rules.enemy_ships:
		if profile.enemy_rank == 0:
			pool.append(profile)
	if pool.is_empty():
		for profile in Ships.ENEMIES:
			if profile.enemy_rank == 0:
				pool.append(profile)
	if pool.is_empty():
		return false
	var chance: float = effective_chasedown_chance()
	if chance <= 0:
		return false
	if not chasedown_roll_policy.claim_roll(navigation.leg_active): return false
	var roll: float = chasedown_rng.randf() if forced_roll < 0 else forced_roll
	if roll >= chance:
		return false
	var total: float = 0.0
	for profile in pool:
		total += maxf(0.01, profile.encounter_weight)
	var selection: float = chasedown_rng.randf() * total
	var enemy: Resource = pool.back()
	for profile in pool:
		selection -= maxf(0.01, profile.encounter_weight)
		if selection <= 0:
			enemy = profile
			break
	pending_destination = destination
	chasedowns_this_system += 1
	chasedown_index = encounters.size()
	# Existing encounter/result pipeline; pursuit grants no FTL access or pressure.
	encounters.append(
		{
			"kind": "battle",
			"enemy": maxi(0, Ships.ENEMIES.find(enemy)),
			"enemy_data": enemy,
			"system_number": system_number,
			"modifier": 0,
			"mandatory_boss": false,
			"chasedown": true,
			"response": -1,
			"title": "Sublight Chasedown",
			"completed": false
		}
	)
	return true


func chasedown_unresolved() -> bool:
	return (
		chasedown_index >= 0
		and chasedown_index < encounters.size()
		and not encounters[chasedown_index].completed
	)


# The cancelled destination is historical context only while the interception is unresolved.
# Optional coordinates on that existing encounter retain the actual stop across v1 saves.
func stop_intercepted_travel(position: Array = []) -> void:
	if chasedown_index < 0: return
	travel_destination = -1
	if position.size() in [2,3] and not encounters[chasedown_index].has("intercept_position"):
		encounters[chasedown_index].intercept_position = position.duplicate()
	var stored: Array = encounters[chasedown_index].get("intercept_position", [])
	if stored.size() == 2: stored = [stored[0], 0.0, stored[1]]
	navigation.checkpoint_position(stored)
	navigation.stop()
	chasedown_roll_policy.reset_leg()
	progress_committed.emit()

func intercepted_position() -> Array:
	if chasedown_index < 0: return []
	return encounters[chasedown_index].get("intercept_position", []).duplicate()


func choose_chasedown_response(choice: int) -> bool:
	if (
		hull <= 0
		or not chasedown_unresolved()
		or active_battle >= 0
		or not pending_choice.is_empty()
	):
		return false
	var encounter: Dictionary = encounters[chasedown_index]
	if encounter.response >= 0 or choice < 0 or choice >= rules.chasedown_responses.size():
		return false
	var response: Dictionary = rules.chasedown_responses[choice]
	encounter.response = choice
	add_modifiers(response.get("modifiers", {}))
	hull = maxi(1, hull + int(response.get("hull", 0)))
	progress_committed.emit()
	return true


func arrive_destination(index: int) -> void:
	navigation.stop()
	chasedown_roll_policy.reset_leg()
	if chasedown_index >= 0:
		encounters[chasedown_index].erase("intercept_position")
	navigation_origin = index
	if index == travel_destination: travel_destination = -1
	if index == pending_destination and not chasedown_unresolved():
		pending_destination = -1
	progress_committed.emit()


#endregion

#region Approaches and modifiers


func poi_description(index: int) -> String:
	var poi: Resource = encounter_at(index).poi
	if is_defense() and defense_poi_version == 1 and index != SERVICE_INDEX:
		return DefensePois.description(poi.resource_path.get_file().get_basename())
	return poi.description

func poi_approaches(index: int) -> Array:
	var poi: Resource = encounter_at(index).poi
	if not is_defense() or defense_poi_version != 1 or index == SERVICE_INDEX:
		return poi.approaches
	var result: Array = []
	for row in DefensePois.definitions(poi.resource_path.get_file().get_basename()):
		row.approach.set_meta("source_encounter",index)
		result.append(row.approach)
	return result

func _defense_poi_reward_rng(index: int) -> RandomNumberGenerator:
	# Existing reward APIs accept an injected generator. Fork only this transaction
	# so its quantity/card draws cannot perturb future system generation.
	var generator := RandomNumberGenerator.new()
	generator.seed = hash("%d:%d:%d:defense-poi-reward:v1" % [seed_used,system_number,index])
	return generator

func _resolve_defense_poi(index: int, slot: int) -> bool:
	var approaches: Array = poi_approaches(index)
	if slot < 0 or slot >= approaches.size(): return false
	var approach: Resource = approaches[slot]
	if not locked_reason(approach).is_empty(): return false
	var reward: Dictionary = approach.get_meta("strategic_reward")
	# All validations precede mutation, including scarce identity rewards.
	if reward.has("cards"):
		var eligible := 0
		for card in available_reward_cards():
			if card.tier == 1: eligible += 1
		if eligible < 2: return false
	if reward.has("turret") and not can_deploy_poi_turret(index): return false
	if reward.has("mothership") and not poi_effects.mothership.is_empty(): return false
	if not _complete_encounter(index): return false
	_commit_activity_time(float(approach.get_meta("strategic_seconds")))
	if run_ended:
		last_outcome = "The invasion ended the expedition during this operation."
		progress_committed.emit()
		return true
	var reward_rng := _defense_poi_reward_rng(index)
	last_poi_success = 1
	last_outcome = approach.get_meta("strategic_description")
	if reward.has("salvage_range"):
		var amount := reward_rng.randi_range(reward.salvage_range[0],reward.salvage_range[1])
		salvage += amount
		last_outcome = "+%d Salvage recovered." % amount
	salvage += int(reward.get("salvage",0))
	if reward.has("production"):
		var boost: Dictionary = reward.production
		poi_effects.grant_production(boost.category,boost.amount,boost.battles)
	if reward.has("pause"): poi_effects.pause = maxf(poi_effects.pause,reward.pause)
	if reward.has("reduction"): poi_effects.reduction = maxf(poi_effects.reduction,reward.reduction)
	if reward.has("fuel"): poi_effects.fuel = maxf(poi_effects.fuel,reward.fuel)
	if reward.has("mothership"): poi_effects.mothership = reward.mothership
	if reward.has("cards"): start_card_batch(reward_rng)
	if reward.has("next_battle"): add_modifiers(reward.next_battle)
	if reward.has("hull"): hull = mini(ship().hull_capacity,hull+int(reward.hull))
	if reward.has("turret"): _install_poi_turret(index)
	if reward.has("decoy"): decoys += 1
	if reward.has("extraction"): poi_effects.start_extraction(index)
	progress_committed.emit()
	return true

# Preserve gate order: production, price, then a full Hull repair target.
func approach_requirement(approach: Resource) -> RefCounted:
	if approach.has_meta("strategic_reward"):
		var reward: Dictionary = approach.get_meta("strategic_reward")
		var reason := ""
		if reward.has("decoy") and decoys >= DECOY_CAPACITY: reason = "Tactical Decoy inventory full"
		if reward.has("extraction") and (defense.complete or poi_effects.extraction_source >= 0):
			reason = "Extraction already online or system secured"
		if reward.has("turret") and not can_deploy_poi_turret(int(approach.get_meta("source_encounter",-1))): reason = "Free turret already used or location unavailable"
		if reward.has("mothership") and (not poi_effects.mothership.is_empty() or defense.complete): reason = "Mothership research is already active or the system is secured"
		if defense.complete and (reward.has("pause") or reward.has("reduction")): reason = "System secured; Pressure effects are no longer needed"
		if reward.has("cards"):
			var count := 0
			for card in available_reward_cards():
				if card.tier == 1: count += 1
			if count < 2: reason = "Fewer than two eligible unowned Tier 1 cards remain"
			if deck_limit() < 2: reason = "Deck capacity must support both reward identities"
		if not reason.is_empty(): return Requirement.new(Requirement.Kind.UNAVAILABLE,reason)
	if not approach.requirement.is_empty():
		var available: int = production(approach.requirement)
		if available < approach.minimum_production:
			return Requirement.new(Requirement.Kind.PRODUCTION, approach.requirement, approach.minimum_production, available)
	if salvage < approach.salvage_cost:
		return Requirement.new(Requirement.Kind.SALVAGE, "salvage", approach.salvage_cost, salvage)
	if approach.success.hull > 0 and hull >= ship().hull_capacity:
		return Requirement.new(Requirement.Kind.FULL_HULL, "hull", ship().hull_capacity, hull)
	return Requirement.new()


# Compatibility wording for existing callers. Eligibility is evaluated only above.
func locked_reason(approach: Resource) -> String:
	var requirement = approach_requirement(approach)
	match requirement.kind:
		Requirement.Kind.PRODUCTION:
			return "Requires %s ≥%d (you have %d)" % [LABELS[requirement.attribute], requirement.required, requirement.current]
		Requirement.Kind.SALVAGE:
			return "Requires %d Salvage (you have %d)" % [requirement.required, requirement.current]
		Requirement.Kind.FULL_HULL:
			return "Hull already full"
		Requirement.Kind.UNAVAILABLE:
			return requirement.attribute
	return ""


# Validate/pay the approach, roll its outcome and complete the PoI before applying rewards.
# forced_roll is a deterministic test hook; normal play uses this expedition's RNG.
func resolve_approach(index: int, approach_index: int, forced_roll: float = -1.0) -> bool:
	if index == SERVICE_INDEX or not can_visit(index) or objective_locked(index) or encounter_at(index).kind != "poi":
		return false
	if is_defense() and defense_poi_version == 1:
		return _resolve_defense_poi(index,approach_index)
	var poi: Resource = encounter_at(index).poi
	if approach_index < 0 or approach_index >= poi.approaches.size():
		return false
	var approach: Resource = poi.approaches[approach_index]
	if not locked_reason(approach).is_empty():
		return false
	salvage -= approach.salvage_cost
	var roll: float = rng.randf() if forced_roll < 0 else forced_roll
	var success: bool = roll < approach.success_chance
	var outcome: Resource = approach.success if success else approach.failure
	if not _complete_encounter(index):
		return false
	last_poi_success = 1 if success else 0
	# The roll and seed are printed for reproducing balance reports.
	if rules.log_rolls:
		print(
			(
				"Expedition seed=%d system=%d encounter=%d approach=%d roll=%.4f success=%s"
				% [seed_used, system_number, index, approach_index, roll, success]
			)
		)
	last_outcome = outcome.blurb + "\n" + describe_outcome(outcome)
	if approach.salvage_cost > 0:
		last_outcome += "\nSpent %d Salvage." % approach.salvage_cost
	_apply_outcome(outcome)
	_commit_activity_time(rules.defense_tuning.poi_seconds)
	progress_committed.emit()
	return true


# Apply immediate Hull/Salvage and queue next-battle modifiers plus at most one choice type.
# EXTEND: New reward fields also need EncounterOutcome, describe_outcome and expedition UI/test coverage.
func _apply_outcome(outcome: Resource) -> void:
	salvage += outcome.salvage
	# Combined Hull model: neutral outcomes preserve purchased plating. Positive PoI repairs
	# cannot add plating; damaging PoIs reduce the combined total (agreed single-value rule).
	if outcome.hull < 0:
		hull = maxi(0, hull + outcome.hull)
	elif outcome.hull > 0 and hull < ship().hull_capacity:
		hull = mini(ship().hull_capacity, hull + outcome.hull)
	add_modifiers(outcome.next_battle)
	if outcome.card_reward:
		last_outcome += _deck.start_card_reward(ship(), rules, rng, outcome.minimum_card_tier)
	elif outcome.upgrade_card:
		if upgrade_candidates().is_empty():
			salvage += rules.unavailable_upgrade_salvage
			last_outcome += (
				"\nAll cards fully upgraded: +%d Salvage instead."
				% rules.unavailable_upgrade_salvage
			)
		else:
			start_upgrade_event(1)
	elif outcome.resource_choice > 0:
		pending_choice = "resource"
		choice_amount = outcome.resource_choice
	elif outcome.production_choice > 0:
		pending_choice = "production"
		choice_amount = outcome.production_choice


func add_modifiers(values: Dictionary) -> void:
	for key in values:
		var amount: int = int(values[key])
		# Temporary production modifiers are unsupported; outpost upgrades use their own ledger.
		if key in PRODUCTION:
			continue
		if key == "emp_pulse_offline":
			pending_bonuses[key] = maxi(int(pending_bonuses.get(key, 0)), amount)
		elif amount > 0:
			pending_bonuses[key] = int(pending_bonuses.get(key, 0)) + amount
		elif amount < 0:
			pending_penalties[key] = int(pending_penalties.get(key, 0)) + amount


func modifier_value(key: String) -> int:
	return int(pending_bonuses.get(key, 0)) + int(pending_penalties.get(key, 0))


## Resource penalties cap against unmodified ship starts, before normal turn income.
func starting_value(profile: Resource, key: String) -> int:
	var base: int = int(profile.get(key))
	var penalty: int = absi(int(pending_penalties.get(key, 0)))
	if key in RESOURCES:
		penalty = mini(penalty, floori(base * 0.5))
	return maxi(0, base + int(pending_bonuses.get(key, 0)) - penalty)


func describe_modifiers(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key in values:
		parts.append("%+d %s" % [values[key], LABELS.get(key, key)])
	return " · ".join(parts)


func describe_outcome(outcome: Resource) -> String:
	var parts: Array[String] = []
	if outcome.salvage != 0:
		parts.append("%+d Salvage" % outcome.salvage)
	if outcome.hull != 0:
		parts.append("%+d permanent Hull" % outcome.hull)
	for key in outcome.next_battle:
		parts.append("%+d %s next battle" % [outcome.next_battle[key], LABELS.get(key, key)])
	if outcome.card_reward:
		parts.append(
			(
				"Choose 1 of 3 %scards"
				% ("uncommon-or-better " if outcome.minimum_card_tier > 1 else "")
			)
		)
	if outcome.upgrade_card:
		parts.append("Upgrade one player card")
	if outcome.resource_choice > 0:
		parts.append("+%d starting resource of choice next battle" % outcome.resource_choice)
	if outcome.production_choice > 0:
		parts.append("+%d production of choice for expedition" % outcome.production_choice)
	return " · ".join(parts)


func pending_description() -> String:
	var parts: Array[String] = []
	var keys: Array = pending_bonuses.keys()
	for key in pending_penalties:
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var positive: int = int(pending_bonuses.get(key, 0))
		var negative: int = int(pending_penalties.get(key, 0))
		if positive > 0:
			parts.append("+%d %s" % [positive, LABELS.get(key, key)])
		if negative < 0:
			parts.append("%d %s" % [negative, LABELS.get(key, key)])
	return "None" if parts.is_empty() else " · ".join(parts)


#endregion

#region Repairs and services


func field_repair_limit() -> int:
	if not field_repairs_open or active_battle >= 0 or not pending_choice.is_empty() or hull <= 0:
		return 0
	return Repairs.max_quantity(hull, ship().hull_capacity, salvage, Repairs.FIELD_SALVAGE_PER_HULL)


# A confirmation is consumed once. A second purchase requires a fresh revision/selection.
func field_repair(amount: int, revision: int) -> bool:
	if revision != service_revision or amount <= 0 or amount > field_repair_limit():
		return false
	salvage -= Repairs.quantity_cost(amount, Repairs.FIELD_SALVAGE_PER_HULL)
	hull += amount
	service_revision += 1
	progress_committed.emit()
	return true


func station_plating_mode() -> bool:
	return hull >= ship().hull_capacity


func station_hull_ceiling() -> int:
	return ship().hull_capacity + (Repairs.STATION_PLATING_LIMIT if station_plating_mode() else 0)


func station_hull_unit_cost() -> int:
	return Repairs.PLATING_SALVAGE_PER_POINT if station_plating_mode() else 1


func station_hull_title() -> String:
	if not station_plating_mode():
		return "Repair Hull"
	return "Ablative Plating Full" if hull >= station_hull_ceiling() else "Install Ablative Plating"


## Shared quantity bounds; damaged Hull uses 1:1 repairs, full Hull uses 2:1 plating.
func station_repair_limit() -> int:
	return Repairs.max_quantity(hull, station_hull_ceiling(), salvage, station_hull_unit_cost())


func service_is_repair(slot: int) -> bool:
	return (
		not service.is_empty()
		and slot >= 0
		and slot < service.poi.approaches.size()
		and service.poi.approaches[slot].success.hull > 0
	)


func service_cost(slot: int, repair_amount: int = 1) -> int:
	if service.is_empty() or slot < 0 or slot >= service.poi.approaches.size():
		return 0
	var approach: Resource = service.poi.approaches[slot]
	if approach.success.hull > 0:
		return Repairs.quantity_cost(repair_amount, station_hull_unit_cost())
	if approach.success.production_choice > 0:
		var bought: int = station_production_purchases
		return (
			approach.salvage_cost
			+ rules.production_price_increment * bought
			+ rules.production_price_acceleration * bought * (bought - 1) / 2
		)
	return approach.salvage_cost


func service_locked_reason(slot: int) -> String:
	if not can_visit(SERVICE_INDEX):
		return "Station unavailable or resolve pending choice first"
	if slot < 0 or slot >= service.poi.approaches.size():
		return "Unknown service"
	var approach: Resource = service.poi.approaches[slot]
	if (
		approach.success.card_reward
		and available_reward_cards(approach.success.minimum_card_tier).is_empty()
	):
		return "No unowned cards meet this reward's minimum tier"
	if approach.success.hull > 0 and hull >= station_hull_ceiling():
		return "Ablative Plating Full"
	var cost: int = service_cost(slot)
	if salvage < cost:
		return "Requires %d Salvage (you have %d)" % [cost, salvage]
	return ""


# Use a confirmation revision to reject stale purchases; services never complete a progression PoI.
func purchase_service(slot: int, revision: int, repair_amount: int = 0) -> bool:
	if revision != service_revision or not service_locked_reason(slot).is_empty():
		return false
	var outcome: Resource = service.poi.approaches[slot].success
	if outcome.hull > 0 and (repair_amount <= 0 or repair_amount > station_repair_limit()):
		return false
	var cost: int = service_cost(slot, repair_amount)
	if cost < 0 or cost > salvage:
		return false
	# Validate everything before spending; consume confirmation before applying any reward.
	last_poi_success = -1
	salvage -= cost
	service_revision += 1
	last_outcome = "Spent %d Salvage. " % cost
	if outcome.hull > 0:
		var plating: bool = station_plating_mode()
		hull += repair_amount
		last_outcome += (
			("Installed %d Ablative Plating." if plating else "Repaired %d permanent Hull.")
			% repair_amount
		)
	else:
		if outcome.production_choice > 0:
			station_production_purchases += 1
		last_outcome += describe_outcome(outcome)
		_apply_outcome(outcome)
	_commit_activity_time(rules.defense_tuning.poi_seconds)
	progress_committed.emit()
	return true


#endregion

#region Owned cards and rewards


## Compatibility name: always the unmodified enemy library, never expedition acquisitions.
func shared_pool() -> Array[Resource]:
	var pool: Array[Resource] = []
	pool.assign(Cards.CARDS)
	return pool


# Build owned identities with player-only upgrade copies; shared_pool remains the enemy base library.
func player_pool() -> Array[Resource]:
	return _deck.player_pool(ship())


func acquired_draw_weights() -> Dictionary:
	return _deck.acquired_draw_weights(rules)


func available_reward_cards(minimum_tier: int = 1) -> Array[Resource]:
	return _deck.available_reward_cards(ship(), minimum_tier)


func random_card_offers(minimum_tier: int = 1) -> Array[Resource]:
	return _deck.random_card_offers(ship(), rules, rng, minimum_tier)


func start_card_batch(generator: RandomNumberGenerator = null) -> bool:
	return is_defense() and deck_limit() >= 2 and _deck.start_card_batch(ship(),rng if generator == null else generator)

func confirm_card_batch() -> bool:
	return _commit_deck_choice(_deck.confirm_card_batch(ship(),rules))

func replacement_pool() -> Array[Resource]:
	var result: Array[Resource] = []
	for card in player_pool():
		if card.identity_key() not in _deck.batch_protected: result.append(card)
	return result

func card_batch_active() -> bool:
	return _deck.batch_active

func choose_card(index: int) -> bool:
	return _commit_deck_choice(_deck.choose_card(index, ship(), rules))


func deck_limit() -> int:
	return _deck.deck_limit(ship(), rules)


# A successful card transaction notifies live hands before the existing autosave boundary.
func _commit_deck_choice(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	if _deck.batch_active and pending_choice.is_empty():
		var continuation: Dictionary = _deck.advance_card_batch(ship(),rules)
		result.message += continuation.message
		result.deck_changed = result.deck_changed or continuation.deck_changed
	last_outcome += result.message
	if result.deck_changed:
		deck_changed.emit()
	progress_committed.emit()
	return true


func deck_snapshot() -> Dictionary:
	return _deck.snapshot()


# Save codec has already validated registry references and the version-1 payload.
func restore_deck(data: Dictionary, cards: Dictionary) -> void:
	_deck.restore(data, cards)


func replace_card(key: String) -> bool:
	return _commit_deck_choice(_deck.replace_card(key, ship(), rules))


func decline_card() -> bool:
	return _commit_deck_choice(_deck.decline_card())


func choose_attribute(key: String) -> bool:
	if pending_choice == "resource" and key in RESOURCES:
		add_modifiers({key: choice_amount})
		last_outcome += "\nNext battle: +%d %s." % [choice_amount, LABELS[key]]
	elif pending_choice == "production" and key in PRODUCTION:
		production_upgrades[key] = int(production_upgrades.get(key, 0)) + choice_amount
		last_outcome += "\nExpedition: +%d %s." % [choice_amount, LABELS[key]]
	else:
		return false
	pending_choice = ""
	progress_committed.emit()
	return true


#endregion

#region Upgrade events


func upgrade_candidates() -> Array[Resource]:
	return _deck.upgrade_candidates(ship())


func choose_upgrade(key: String) -> bool:
	return _commit_deck_choice(_deck.choose_upgrade(key, ship()))


func battle_upgrade_count(result: BattleResult) -> int:
	if result.winner != "player" or result.escaped_by_ftl:
		return 0
	if active_battle < 0 or active_battle >= encounters.size():
		return 0
	var encounter: Dictionary = encounters[active_battle]
	if encounter.get("chasedown", false):
		return maxi(0, rules.chasedown_upgrades)
	var rank: int = enemy_profile(encounter).enemy_rank
	return maxi(
		0, [rules.standard_upgrades, rules.elite_upgrades, rules.boss_upgrades][clampi(rank, 0, 2)]
	)


# One event upgrades each identity at most once; a later event may upgrade it again.
func start_upgrade_event(count: int) -> void:
	last_outcome += _deck.start_upgrade_event(count, ship())


func finish_upgrades() -> void:
	if _deck.finish_upgrades(ship()):
		progress_committed.emit()


#endregion

#region Battle handoff


# Produce one encounter's data, consuming temporary bonuses once at entry.
func prepare_battle(index: int = -1, enemy_data: Resource = null, environment: Dictionary = {}) -> BattleSetup:
	if index >= Defense.Missiles.FIRST_ID: return null
	if is_defense() and not defense.unit_for(index).is_empty() and not can_engage(index):
		return null
	last_poi_success = -1
	active_battle = index
	field_repairs_open = false
	var setup = BattleSetup.new()
	setup.encounter_index = index
	setup.system_number = system_number
	setup.player_ship = player_ship
	setup.player_profile = ship()
	setup.enemy_profile = enemy_data
	if index >= 0 and index < encounters.size():
		var encounter: Dictionary = encounters[index]
		if encounter.kind == "battle":
			setup.enemy_ship = int(encounter.get("enemy", 0))
			if enemy_data == null:
				setup.enemy_profile = enemy_profile(encounter)
		if is_defense() and defense.unit_for(index).get("mothership", false):
			setup.emp_requirement_bonus = rules.defense_tuning.mothership_emp_bonus
		setup.chasedown_charge_cap = encounter.get("chasedown", false) and encounter.get("response", -1) == 1
	setup.environment = battle_environment(index) if environment.is_empty() else EnvironmentData.snapshot(environment)
	setup.modifier = EnvironmentData.modifier_id(setup.environment)
	setup.player_state = ShipState.new()
	setup.player_state.configure_profile(ship())
	setup.player_state.hull = hull
	for key in PRODUCTION:
		setup.player_state.set(key, maxi(0, production(key) + (poi_effects.bonus(key) if is_defense() else 0)))
	for key in RESOURCES + ["shields"]:
		setup.player_state.set(key, starting_value(ship(), key))
	if setup.enemy_profile != null:
		setup.enemy_state = ShipState.new()
		setup.enemy_state.configure_profile(setup.enemy_profile)
	setup.salvage = salvage
	setup.battles_won = battles_won
	if is_defense(): setup.emp_victory_message = "Enemy systems disabled. Allied recovery forces have secured the vessel."
	setup.emp_charge = modifier_value("emp_pulse_charge")
	setup.emp_offline = maxi(0, modifier_value("emp_pulse_offline"))
	setup.player_cards = player_pool()
	setup.identity_weights = acquired_draw_weights()
	setup.enemy_cards = (
		setup.enemy_profile.starting_cards.duplicate()
		if setup.enemy_profile != null and not setup.enemy_profile.starting_cards.is_empty()
		else shared_pool()
	)
	pending_bonuses.clear()
	pending_penalties.clear()
	return setup


func victory_salvage(result: BattleResult) -> int:
	if result.escaped_by_ftl:
		return 0
	var destruction: int = rules.destruction_salvage
	if (
		active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].kind == "battle"
	):
		destruction = enemy_profile(encounters[active_battle]).destruction_salvage_reward
	var reward: int = destruction
	return reward * rules.elite_salvage_multiplier if _elite_defeated(result) else reward


func _defense_salvage(result: BattleResult, unit: Dictionary) -> Dictionary:
	var tuning: Resource = defense.tuning
	var rank: int = 2 if unit.mothership else clampi(enemy_profile(encounters[active_battle]).enemy_rank, 0, 2)
	if result.escaped_by_ftl:
		return {"recovery": maxi(0, tuning.emp_recovery_salvage[rank])}
	return {"standard": victory_salvage(result), "victory": maxi(0, tuning.victory_salvage_bonus[rank])}


func _elite_defeated(result: BattleResult) -> bool:
	return (
		result.winner == "player"
		and not result.escaped_by_ftl
		and active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].kind == "battle"
		and enemy_profile(encounters[active_battle]).enemy_rank == 1
	)


func elite_resource_reward(result: BattleResult) -> int:
	return rules.elite_resource_bonus if _elite_defeated(result) else 0


# Persist a result and complete the encounter once; escape resolves Boss navigation too.
# Defense currency is owned here. The result returns its committed balance and breakdown.
func record_battle(result: BattleResult) -> bool:
	if run_ended or _recorded_results.has(result.result_id):
		return false
	if result.system_number != system_number or result.encounter_index != active_battle:
		return false
	# Reject a stale/reopened result before copying its currency or queuing another reward.
	if (
		active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].completed
	):
		return false
	var unit: Dictionary = {}
	if is_defense():
		if defense.complete or defense.failed(): return false
		unit = defense.unit_for(active_battle)
		if unit.is_empty() or not defense.available(unit) or defense.contact != active_battle: return false
		if result.escaped_by_ftl and result.winner != "player": return false
	if result.winner == "player" and active_battle >= 0 and not _complete_encounter(active_battle):
		return false
	_recorded_results[result.result_id] = true
	if is_defense():
		result.salvage_rewards = _defense_salvage(result, unit) if result.winner == "player" else {}
		result.salvage = salvage
		for amount in result.salvage_rewards.values():
			result.salvage += amount
		poi_effects.completed_battle()
	hull = clampi(result.player_hull, 0, ship().hull_capacity)
	salvage = result.salvage
	battles_won = result.battles_won
	if result.winner != "player":
		run_ended = true
		poi_effects.stop_extraction()
		progress_committed.emit()
		return true
	if active_battle >= 0:
		encounters[active_battle].resolution = "escaped" if result.escaped_by_ftl else "defeated"
		if is_defense():
			defense.neutralize(active_battle)
			if defense.complete:
				poi_effects.leave_system()
				if not defense.secured_reward_claimed:
					defense.secured_reward_claimed = true
					result.salvage_rewards.secured = defense.tuning.secured_salvage
					salvage += result.salvage_rewards.secured
			for remaining in defense.units:
				if remaining.status == "secured": encounters[remaining.encounter].completed = true
			defense_advanced.emit({"contact": -1, "arrivals": 0, "spawned": []})
	if result.winner == "player":
		var elite_bonus: int = elite_resource_reward(result)
		if elite_bonus > 0:
			add_modifiers({"materials": elite_bonus, "energy": elite_bonus, "crew": elite_bonus})
		if result.earned_tactical:
			add_modifiers(
				{
					"materials": result.tactical_resources,
					"energy": result.tactical_resources,
					"crew": result.tactical_resources
				}
			)
		if result.earned_strategic:
			add_modifiers({"shields": result.strategic_shields})
		var count: int = battle_upgrade_count(result)
		if count > 0:
			last_outcome = "Combat victory — upgrade %d different cards." % count
			start_upgrade_event(count)

	var before_activity := salvage
	_commit_activity_time(rules.defense_tuning.battle_seconds)
	if salvage > before_activity:
		result.salvage_rewards.extraction = salvage - before_activity
	result.salvage = salvage
	progress_committed.emit()
	return true


#endregion
