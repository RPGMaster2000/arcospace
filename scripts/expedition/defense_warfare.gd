extends RefCounted
## Later Starfront doctrine. All rolls use a private stream and all committed combat stats are saved.
const Variation = preload("res://scripts/expedition/system_variation.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Deck = preload("res://scripts/expedition/expedition_deck.gd")
const ShipState = preload("res://scripts/combat/ship_combat_state.gd")

const FORMATIONS := ["assault", "pincer", "vanguard", "encirclement", "spearhead"]
const NAMES := ["Concentrated Assault", "Pincer Attack", "Vanguard and Heavy Reserves",
	"Encirclement", "Mothership Spearhead"]
const BRIEFS := [
	"One concentrated approach gives turrets and decoys several targets.",
	"Two flanks arrive in sequence. Cover one approach while intercepting the other.",
	"Fast attackers lead. A longer opening gap precedes heavy reserves.",
	"Three approach groups spread the defense across the map.",
	"Heavy escorts cover the mothership approach while ordinary attackers press Homeworld."
]
const ROLES := {
	"raider": ["Raider", 1.15, "crew", {"steal":1.60, "damage":1.22, "disruption":1.2},
		"Fast attacker focused on stealing reserves and piercing defenses."],
	"vanguard": ["Vanguard", 1.10, "energy", {"damage":1.50, "disruption":1.35},
		"Fast frontline attacker focused on breaking Shields and exploiting openings."],
	"siege": ["Siege Ship", 0.85, "materials", {"damage":1.42, "production":1.40, "economy":1.24},
		"Slow heavy attacker focused on industrial production and heavy strikes."],
	"disruptor": ["Disruptor", 1.0, "crew", {"disruption":1.54, "steal":1.45, "production":1.20},
		"Targets enemy production and reserves with sabotage and theft."],
	"escort": ["Heavy Escort", 0.90, "materials", {"shields":1.55, "hull":1.50, "production":1.25},
		"Durable escort focused on Shield regeneration and Hull recovery."],
	"mothership": ["Mothership", 1.0, "", {"damage":1.25, "production":1.28, "shields":1.2},
		"Capital attacker with stronger opening reserves and late-battle draws."],
}
const OPENING := [
	["vanguard", "disruptor", "siege", "raider", "escort"],
	["raider", "disruptor", "vanguard", "siege", "escort"],
	["vanguard", "raider", "vanguard", "disruptor", "siege"],
	["disruptor", "raider", "siege", "vanguard", "escort"],
	["escort", "vanguard", "disruptor", "escort", "siege"],
]
const RESERVES := [
	["vanguard", "siege", "escort", "disruptor", "raider"],
	["disruptor", "vanguard", "siege", "raider", "escort"],
	["siege", "escort", "disruptor", "siege", "escort"],
	["raider", "disruptor", "siege", "escort", "vanguard"],
	["escort", "siege", "escort", "disruptor", "vanguard"],
]
const GROUPS := [[0, 0, 0, 0, 0], [0, 1, 0, 1, 1], [0, 0, 1, 1, 1],
	[0, 1, 2, 0, 1], [0, 1, 1, 0, 0]]
const FRONT_ANGLES := [[1.66], [1.35, -1.93], [1.22, 2.03],
	[1.06, -1.23, 2.43], [2.29, -1.45]]
const TACTICS := {
	"vanguard":{"damage":1.45, "disruption":1.20},
	"raider":{"damage":1.42, "disruption":1.22},
	"siege":{"damage":1.45, "production":1.12},
	"disruptor":{"damage":1.25, "disruption":1.28},
	"escort":{"damage":1.22, "hull":1.18, "shields":1.12},
	"mothership":{"damage":1.20, "production":1.12},
}
const STANDARD_STATS = ShipState.RESOURCES + ShipState.PRODUCTION + ["hull_capacity", "shields"]
const DRAW_RATES := [
	[[0.18, 0.05], [0.22, 0.06], [0.25, 0.08]],
	[[0.20, 0.05], [0.25, 0.08], [0.28, 0.10]],
	[[0.22, 0.05], [0.28, 0.10], [0.30, 0.12]]
]


static func describe(id: String) -> String:
	return NAMES[FORMATIONS.find(id)] if id in FORMATIONS else ""


static func brief(id: String) -> String:
	return BRIEFS[FORMATIONS.find(id)] if id in FORMATIONS else ""


static func available_formation(id: String, system: int) -> bool:
	var index := FORMATIONS.find(id)
	return system >= 3 and index >= 0 and (index < 3 or system >= 4)


static func plan(state: Resource, faction: Resource, previous: String) -> Dictionary:
	var rng := Variation.rng_for(state.seed_used, state.system_number, "military-doctrine")
	var stage := clampi(state.system_number - 3, 0, 2)
	var configured: Array = state.rules.defense_tuning.formation_weights
	var weights: Array = configured[stage].duplicate() if configured.size() > stage and configured[stage].size() == FORMATIONS.size() else [40.0, 30.0, 30.0, 15.0, 15.0]
	var bias: int = {"scavenger_clans":2, "iron_directorate":0, "axiom_collective":1, "hollow_choir":3}.get(faction.id, -1)
	for i in FORMATIONS.size():
		if not available_formation(FORMATIONS[i], state.system_number):
			weights[i] = 0.0
		elif bias == i:
			weights[i] *= 1.10
	var requested: String = state.developer_test.get("formation", "") if state.system_number == state.developer_test.get("stage", 0) else ""
	var index := FORMATIONS.find(requested)
	if not available_formation(requested, state.system_number):
		var alternate := weights.duplicate()
		if previous in FORMATIONS:
			alternate[FORMATIONS.find(previous)] = 0.0
		if alternate.any(func(weight): return weight > 0):
			weights = alternate
		index = Variation.weighted(rng, weights)
	var opening := [3 + int(rng.randf() < 0.45), 4, 4 + int(rng.randf() < 0.55)]
	return {"version":1, "formation":FORMATIONS[index], "opening":opening[stage], "reserves":3 + stage,
		"cap":4 + int(stage == 2), "speed":1.1 + 0.1 * stage, "pressure":1.1 + 0.1 * stage,
		"interval":28.0 - 2 * stage, "stage":stage}


static func wave_delay(plan_data: Dictionary, ordinal: int) -> float:
	var interval: float = plan_data.interval
	match plan_data.formation:
		"vanguard": return interval + 5.0 if ordinal == 0 else interval - 4.0 if ordinal % 2 else interval
		"pincer": return interval + (2.0 if ordinal % 2 == 0 else -2.0)
		"spearhead": return interval - 2.0 if ordinal == 0 else interval
	return interval


static func roster(state: Resource, faction: Resource, military: Dictionary, opening: Array, reserves: Array, mother: int) -> void:
	var rng := Variation.rng_for(state.seed_used, state.system_number, "military-roster")
	var standard := Factions.roster(faction, state.system_number)
	if standard.is_empty():
		standard = Factions.roster(faction)
	var elites := Factions.defense_elites(faction, state.system_number)
	var formation := FORMATIONS.find(military.formation)
	var stage: int = military.stage
	var override_rank: int = state.developer_enemy_rank()
	var elite_count := 0
	var opening_elites := 0
	for index in opening + reserves:
		var reserve: bool = index in reserves
		var slot := reserves.find(index) if reserve else opening.find(index)
		var blueprint: Array = RESERVES[formation] if reserve else OPENING[formation]
		var role: String = blueprint[slot]
		var cap: bool = elite_count < 2 + stage and (reserve or opening_elites < mini(2, 1 + stage))
		var chance: float = [0.15, 0.25, 0.35][stage]
		chance *= 1.24 if reserve else (1.0 - 0.24 * reserves.size() / opening.size())
		var elite := cap and not elites.is_empty() and rng.randf() < chance
		var base := _choose_ship(elites if elite else standard, role, faction, rng)
		if override_rank == 0 or (override_rank == 1 and not elites.is_empty()):
			base = _choose_ship(elites if override_rank == 1 else standard, role, faction, rng)
		elif override_rank >= 0:
			base = state.DeveloperLaunch.enemy(state, base, index, faction)
		role = _compatible_role(base, role)
		if base.enemy_rank == 1:
			elite_count += 1
			if not reserve: opening_elites += 1
		var group: int = GROUPS[formation][slot] if not reserve else slot % FRONT_ANGLES[formation].size()
		_set_entry(state, index, base, military, role, group)
	var mothership: Resource = state.encounters[mother].enemy_data
	_set_entry(state, mother, mothership, military, "mothership", 0)


static func _compatible_role(ship: Resource, role: String) -> String:
	if role in ["siege", "escort"] and ship.strategic_class == "Light": return "vanguard"
	if role == "raider" and ship.strategic_class == "Heavy": return "disruptor"
	return role


static func _choose_ship(pool: Array, role: String, faction: Resource, rng: RandomNumberGenerator) -> Resource:
	var weights: Array = []
	for ship in pool:
		var weight: float = maxf(0.01, float(faction.enemy_weights.get(ship.resource_path, ship.encounter_weight)))
		if role in ["siege", "escort"] and ship.strategic_class == "Heavy":
			weight *= 6.0
		elif role in ["vanguard", "raider"] and ship.strategic_class == "Light":
			weight *= 5.0
		elif _compatible_role(ship, role) != role:
			weight *= 0.10
		weights.append(weight)
	return pool[Variation.weighted(rng, weights)]


static func _set_entry(state: Resource, index: int, base: Resource, military: Dictionary, role: String, group: int) -> void:
	var entry: Dictionary = state.encounters[index]
	var stage: int = military.stage
	var scaled: Resource = state.rules.progression.scaled_enemy(base, state.system_number, true)
	var rank: int = 2 if role == "mothership" else base.enemy_rank
	var stats := {}
	for stat in STANDARD_STATS:
		stats[stat] = int(scaled.get(stat))
	var income: int = [1 + stage, 2 + stage, 2 + 2 * stage][rank]
	for key in ShipState.RESOURCES:
		stats[key] += income
	var family := preferred_family(base, role)
	if stage > 0 and rank > 0:
		stats[ShipState.PRODUCTION[ShipState.RESOURCES.find(family)]] += 1
	var rates: Array = DRAW_RATES[stage][rank]
	var profile := _role_profile(base, role, family)
	for stat in stats:
		profile.set(stat, stats[stat])
	var pool := Deck.enemy_pool(profile, state.system_number, true, true)
	var cards: Array[String] = []
	for card in pool:
		cards.append(card.identity_key())
	entry.enemy_data = base
	entry.title = "Mothership" if role == "mothership" else base.ship_name
	entry.defense_deployment = JSON.parse_string(JSON.stringify({"role":role, "group":group, "stats":stats, "tier_two":rates[0], "tier_three":rates[1],
		"cards":cards, "families":profile.card_family_weights, "effects":profile.card_effect_weights,
		"tactics":profile.tactical_weights, "variation":profile.tactical_variation,
		"movement":float(military.speed) * ROLES[role][1],
		"arrival_damage":state.rules.defense_tuning.base_attack_damage + (5 if role == "siege" else 0)}))


static func preparation_sites(state: Resource, slots: Array) -> Array:
	var preferred: Array = {
		"assault":["derelict_starship", "pirate_debris_field"],
		"pincer":["spatial_anomaly", "derelict_starship", "distress_signal"],
		"vanguard":["distress_signal", "radiation_nebula", "pirate_debris_field"],
		"encirclement":["distress_signal", "derelict_starship", "spatial_anomaly"],
		"spearhead":["raider_cache", "pirate_debris_field", "radiation_nebula"],
	}.get(state.defense.military.get("formation"), [])
	if preferred.is_empty(): return []
	var candidates: Array = slots.filter(func(index):
		return index >= 0 and not Layout.PLANETARY.has(state.encounters[index].poi.resource_path.get_file().get_basename()))
	candidates.sort_custom(func(a, b):
		var left: int = preferred.find(state.encounters[a].poi.resource_path.get_file().get_basename())
		var right: int = preferred.find(state.encounters[b].poi.resource_path.get_file().get_basename())
		return (left if left >= 0 else 99) < (right if right >= 0 else 99) if left != right else a < b)
	if candidates.is_empty() and state.SERVICE_INDEX in slots:
		candidates.append(state.SERVICE_INDEX)
	return candidates.slice(0, 2 if state.defense.military.formation == "pincer" else 1)


static func preferred_family(ship: Resource, role: String) -> String:
	if role == "mothership":
		var best: String = "materials"
		for family in ShipState.RESOURCES:
			if ship.card_family_weights.get(family, 1.0) > ship.card_family_weights.get(best, 1.0):
				best = family
		return best
	return ROLES[role][2]


static func _role_profile(base: Resource, role: String, family: String) -> Resource:
	var profile := base.duplicate()
	profile.card_family_weights = base.card_family_weights.duplicate()
	profile.card_effect_weights = base.card_effect_weights.duplicate()
	profile.card_family_weights[family] = profile.card_family_weights.get(family, 1.0) * 1.18
	var weights: Dictionary = ROLES[role][3]
	for key in weights:
		profile.card_effect_weights[key] = profile.card_effect_weights.get(key, 1.0) * weights[key]
	profile.tactical_weights = base.tactical_weights.duplicate()
	var tactics: Dictionary = TACTICS[role]
	var defaults := {"damage":1.0, "hull":1.0, "shields":0.4, "production":4.0, "disruption":0.4}
	for key in tactics:
		profile.tactical_weights[key] = profile.tactical_weights.get(key, defaults[key]) * tactics[key]
	profile.tactical_variation = minf(base.tactical_variation, 0.10 if base.enemy_rank == 0 else 0.08)
	return profile


static func battle_profile(base: Resource, deployment: Dictionary) -> Resource:
	var profile := base.duplicate()
	for stat in STANDARD_STATS:
		profile.set(stat, int(deployment.stats[stat]))
	profile.card_family_weights = deployment.families.duplicate()
	profile.card_effect_weights = deployment.effects.duplicate()
	profile.tactical_weights = deployment.tactics.duplicate()
	profile.tactical_variation = float(deployment.variation)
	return profile


static func card_pool(deployment: Dictionary, profile: Resource) -> Array[Resource]:
	var catalogue := {}
	for card in Deck.Cards.CARDS + profile.starting_cards:
		catalogue[card.identity_key()] = card
	var pool: Array[Resource] = []
	for id in deployment.cards:
		pool.append(catalogue[id])
	return pool


static func place(state: Resource, fleet: RefCounted, military: Dictionary) -> bool:
	var rng := Variation.rng_for(state.seed_used, state.system_number, "military-positions")
	var formation := FORMATIONS.find(military.formation)
	var headings: Array = FRONT_ANGLES[formation]
	var heading: float = atan2(fleet.home.z, fleet.home.x)
	var mirror := -1.0 if rng.randf() < 0.5 else 1.0
	var orbit_edge := 4.15
	for index in Layout.planetary_radii(state.encounters):
		orbit_edge = maxf(orbit_edge, fleet.anchors[index].length() + Layout.planetary_radius(
			state.encounters[index].poi.resource_path.get_file().get_basename()))
	var minimum: float = state.system_variation.get("minimum_arrival", 20.0)
	var attackers: Array = fleet.units.filter(func(unit): return not unit.mothership and not unit.reinforcement)
	var reserves: Array = fleet.units.filter(func(unit): return unit.reinforcement)
	var mother: Dictionary = fleet.unit_for(fleet.mothership_index())
	var mother_origin: Vector3 = mother.position
	if military.formation == "spearhead":
		var proposed := _position(fleet, heading + mirror * 2.54, 0.83)
		if _clear(fleet, proposed, orbit_edge, []):
			mother_origin = proposed
	for attempt in 72:
		var occupied: Array = [mother_origin]
		var positions: Array[Vector3] = []
		var arrivals: Array[float] = []
		for slot in attackers.size():
			var unit: Dictionary = attackers[slot]
			var info: Dictionary = state.encounters[unit.encounter].defense_deployment
			var group: int = info.group
			var center: float = headings[group]
			var width := 0.37 if attempt < 42 else 0.64
			var speed: float = fleet._speed(unit)
			for candidate in 20:
				var radial := rng.randf_range(0.65, 1.0)
				if military.formation == "vanguard" and group == 0: radial *= 0.94
				var at := _position(fleet, heading + mirror * (center + rng.randf_range(-width, width)), radial)
				if not _clear(fleet, at, orbit_edge, occupied): continue
				var eta: float = at.distance_to(fleet.home) / speed
				if eta < minimum or not _respondable(fleet, at, speed, eta): continue
				var path_clear := true
				for previous in positions.size():
					var other_speed: float = fleet._speed(attackers[previous])
					if fleet.approach_blocked(at, speed, positions[previous], other_speed, 0.4) \
						or fleet.approach_blocked(positions[previous], other_speed, at, speed, 0.4):
						path_clear = false
						break
				if not path_clear: continue
				arrivals.append(eta)
				positions.append(at)
				occupied.append(at)
				break
			if positions.size() != slot + 1: break
		if positions.size() != attackers.size(): continue
		arrivals.sort()
		var battle_time: float = fleet.tuning.battle_seconds
		if arrivals[1] - arrivals[0] < 0.8 or arrivals[2] - arrivals[0] < battle_time + 0.5: continue
		if not _intercept_opening(fleet, attackers, positions): continue
		var entries: Array[Vector3] = []
		for unit in reserves:
			var info: Dictionary = state.encounters[unit.encounter].defense_deployment
			var center: float = headings[info.group]
			for retry in 30:
				var offset := rng.randf_range(-0.5, 0.5)
				var radial := rng.randf_range(0.77, 1.0)
				var at := _position(fleet, heading + mirror * (center + offset), radial)
				var speed: float = fleet._speed(unit)
				var eta: float = at.distance_to(fleet.home) / speed
				if eta < minimum or not _clear(fleet, at, orbit_edge, [mother_origin]):
					continue
				entries.append(at)
				break
		if entries.size() != reserves.size(): continue
		mother.position = mother_origin
		mother.route_origin = mother_origin
		for slot in positions.size():
			attackers[slot].position = positions[slot]
			attackers[slot].route_origin = positions[slot]
		for slot in entries.size():
			reserves[slot].position = entries[slot]
			reserves[slot].route_origin = entries[slot]
		return true
	return false


static func _position(fleet: RefCounted, heading: float, fraction: float) -> Vector3:
	var direction := Vector3(cos(heading), 0, sin(heading))
	var limit := Layout.bounds(fleet.layout_expansion).end.x - 2.0
	var boundary := limit / maxf(absf(direction.x), absf(direction.z))
	return direction * lerpf(0.65 * limit, boundary, fraction)


static func _clear(fleet: RefCounted, at: Vector3, outer: float, occupied: Array) -> bool:
	if at.length() < outer + 1.6 or at.distance_to(fleet.start) < 7.0 or at.distance_to(fleet.home) < 9.0:
		return false
	if Geometry3D.get_closest_point_to_segment(Vector3.ZERO, at, fleet.home).length() < 3.5:
		return false
	var gap: float = 2.0 * fleet.tuning.interception_radius + 0.75
	if occupied.any(func(other): return at.distance_to(other) < gap):
		return false
	if fleet.construction_sites.values().any(func(site): return at.distance_to(fleet.point(site.position)) < 1.7):
		return false
	return not fleet.anchors.values().any(func(anchor): return at.distance_to(anchor) < 3.4)


static func _respondable(fleet: RefCounted, at: Vector3, speed: float, eta: float) -> bool:
	var intercept: Vector3 = fleet._intercept(at, fleet.home, speed, fleet.start)
	var seconds: float = fleet.start.distance_to(intercept) * fleet.tuning.seconds_per_distance
	return eta >= seconds + fleet.tuning.battle_seconds + 3.0


# Check two swept contacts with the normal battle-time cost between them. This is
# a lower bar than a perfect defense and still leaves flanks and PoIs as choices.
static func _intercept_opening(fleet: RefCounted, attackers: Array, positions: Array[Vector3]) -> bool:
	var remaining := positions.duplicate()
	var speeds: Array = attackers.map(func(unit): return fleet._speed(unit))
	var player: Vector3 = fleet.start
	for battle in 2:
		var best := INF
		var hit := -1
		var destination := player
		for i in remaining.size():
			var at: Vector3 = remaining[i]
			var target: Vector3 = fleet._intercept(at, fleet.home, speeds[i], player)
			var travel: float = player.distance_to(target) * fleet.tuning.seconds_per_distance
			if travel <= 0.0: continue
			var velocity := (target - player) / travel
			for j in remaining.size():
				var enemy: Vector3 = remaining[j]
				var speed: float = speeds[j]
				var contact: float = fleet.hit_time(player - enemy, velocity - (fleet.home - enemy).normalized() * speed,
					fleet.tuning.interception_radius, minf(travel, enemy.distance_to(fleet.home) / speed))
				if contact >= best: continue
				best = contact
				hit = j
				destination = player + velocity * contact
		if hit < 0: return false
		player = destination
		remaining.remove_at(hit)
		speeds.remove_at(hit)
		var span: float = best + fleet.tuning.battle_seconds
		for i in remaining.size():
			var at: Vector3 = remaining[i]
			if at.distance_to(fleet.home) <= span * speeds[i]:
				return false
			remaining[i] = at.move_toward(fleet.home, span * speeds[i])
	return true


static func valid_plan(data: Variant, system: int) -> bool:
	if not data is Dictionary or not available_formation(str(data.get("formation", "")), system): return false
	var stage := clampi(system - 3, 0, 2)
	var waves: Variant = data.get("waves")
	if not waves is Array or waves.size() != 3 + stage or not waves.all(func(delay): return Variation.number(delay, 20.0, 35.0)):
		return false
	return data.get("version") == 1 and data.get("stage") == stage and Variation.number(data.get("opening"), [3, 4, 4][stage], [4, 4, 5][stage]) \
		and data.opening == floorf(data.opening) \
		and data.get("reserves") == 3 + stage and data.get("cap") == 4 + int(stage == 2) \
		and Variation.number(data.get("speed"), 1.0, 1.4) and Variation.number(data.get("pressure"), 1.0, 1.4) \
		and Variation.number(data.get("interval"), 20.0, 32.0)


static func valid_deployment(data: Variant, profile: Resource) -> bool:
	if not data is Dictionary or data.get("role") not in ROLES: return false
	if not Variation.number(data.get("group"), 0.0, 2.0) or data.group != floorf(data.group) or not data.get("stats") is Dictionary: return false
	if not Variation.number(data.get("movement"), 0.8, 1.65) or not Variation.number(data.get("arrival_damage"), 1, 105):
		return false
	if data.arrival_damage != floorf(data.arrival_damage): return false
	for stat in STANDARD_STATS:
		var value: Variant = data.stats.get(stat)
		if not Variation.number(value, 1.0 if stat == "hull_capacity" else 0.0, 1000.0) or value != floorf(value):
			return false
	for key in ["tier_two", "tier_three"]:
		if not Variation.number(data.get(key), 0.0, 0.4): return false
	if not Variation.number(data.get("variation"), 0.0, 1.0): return false
	for field in ["families", "effects", "tactics"]:
		if not data.get(field) is Dictionary or data[field].size() > 32: return false
		for weight in data[field].values():
			if not Variation.number(weight, 0.001, 1000.0): return false
	var ids: Variant = data.get("cards")
	if not ids is Array or ids.is_empty() or ids.size() > 160: return false
	var known := {}
	for card in Deck.Cards.CARDS + profile.starting_cards:
		known[card.identity_key()] = true
	return ids.all(func(id): return id is String and known.has(id))
