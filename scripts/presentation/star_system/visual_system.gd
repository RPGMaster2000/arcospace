extends RefCounted
# Deterministic layout and cosmetic data. Never consumes gameplay RNG.
# New exploration systems commit battle anchors once; rendering obeys those anchors.
const Names = preload("res://scripts/presentation/star_system/astronomical_names.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const TYPES = ["rocky", "terrestrial", "desert", "frozen", "volcanic", "gas_giant", "barren"]
const PLANETARY = Layout.PLANETARY
const ROMAN = ["I", "II", "III", "IV"]


static func random_for(seed_value: int, number: int, channel: String) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s:v1" % [seed_value, number, channel])
	return rng

static func orbit_point(planet: Dictionary, angle: float) -> Vector3:
	# Eccentric anomaly parameterization: star at the focus, not ellipse center.
	var a: float = planet.distance
	var e: float = planet.eccentricity
	var point = Vector3(a * (cos(angle) - e), 0, a * sqrt(1.0 - e * e) * sin(angle))
	return Basis(Vector3.UP, planet.orientation) * Basis(Vector3.RIGHT, planet.inclination) * point

static func generate(seed_value: int, number: int, entries: Array, settings: Resource,
		profile: String = "industrial", expansion: float = 0.0, orbit_clearance: float = 0.0) -> Dictionary:
	var rng = random_for(seed_value, number, "planets")
	var factor := Layout.scale_factor(expansion)
	var result: Dictionary = {"name": Names.system_name(seed_value, number), "planets": [], "anchors": {},
		"assignments": {}, "poi_orbits": {}}
	var count: int = rng.randi_range(2, clampi(settings.maximum_planets, 2, 4))
	# Disjoint radial shells guarantee clearance even when inclined paths cross in projection.
	var largest_radius: float = maxf(settings.planet_radius_range.x, settings.planet_radius_range.y)*1.2*1.06*1.5
	var band: float = largest_radius*2.0 + settings.minimum_orbit_spacing + 0.8
	for i in range(count):
		var kind: String = TYPES[rng.randi_range(0, TYPES.size()-1)]
		var inner: float = 2.1 + i * band
		var outer: float = inner + band
		var space: float = settings.minimum_orbit_spacing
		var order: float = float(i)/maxi(1,count-1)
		var radius: float = lerpf(settings.planet_radius_range.x*0.65,settings.planet_radius_range.y*1.2,order)*rng.randf_range(0.94,1.06)
		if i < count/2 and kind == "gas_giant": kind = "rocky"
		radius = clampf(radius, 0.15, (band - space) * 0.45)
		var low: float = inner + radius*1.5 + space * 0.5
		var high: float = outer - radius*1.5 - space * 0.5
		var a: float = rng.randf_range(low, high)
		var allowed_e: float = maxf(0, minf(a-low, high-a) / a)
		var p: Dictionary = {"index": i, "name": result.name + " " + ROMAN[i], "type": kind,
			"radius": radius, "distance": a * factor, "eccentricity": rng.randf_range(0, minf(settings.maximum_eccentricity, allowed_e)),
			"inclination": deg_to_rad(rng.randf_range(-settings.maximum_inclination, settings.maximum_inclination)),
			"orientation": rng.randf_range(0, TAU), "phase": rng.randf_range(0, TAU),
			"rotation": rng.randf_range(0, TAU), "rotation_speed": rng.randf_range(0.015, 0.04),
			"material_seed": rng.randi(), "encounter": -1}
		p.position = orbit_point(p, p.phase)
		result.planets.append(p)
	var eligible: Array = []
	for entry in entries:
		if PLANETARY.has(entry.get("model_kind", "")) and entry.get("profile") == null:
			eligible.append(entry)
	eligible.sort_custom(func(a,b): return a.index < b.index)
	var assignment_rng = random_for(seed_value, number, "assignments")
	for p in result.planets:
		if eligible.is_empty() or assignment_rng.randf() < 0.25: continue
		var candidates: Array = eligible.filter(func(e): return e.model_kind != "gas_giant" or p.index >= count/2)
		if candidates.is_empty(): continue
		var entry: Dictionary = candidates[assignment_rng.randi_range(0,candidates.size()-1)]
		eligible.erase(entry)
		p.encounter = entry.index
		p.type = PLANETARY[entry.model_kind]
		result.assignments[entry.index] = p.index
		result.anchors[entry.index] = p.position
	var occupied: Array = [{"position":Vector3.ZERO,"radius":2.6,"label":false}]
	var orbit_bands: Array[Vector2] = []
	for p in result.planets:
		occupied.append({"position":p.position,"radius":p.radius*1.5,"label":p.encounter!=-1,"named":true})
		orbit_bands.append(Vector2(p.distance, p.distance * p.eccentricity
			+ (planet_extent(p) if orbit_clearance > 0.0 else 0.0)))
	result.placement = {}
	var ordered: Array = entries.duplicate()
	ordered.sort_custom(func(a,b):
		if expansion > 0.0 and is_planetary(a) != is_planetary(b): return is_planetary(a)
		return a.index < b.index)
	for entry in ordered:
		if result.anchors.has(entry.index): continue
		var local = random_for(seed_value,number,"destination-%d" % entry.index)
		var orbital: bool = expansion > 0.0 and is_planetary(entry)
		var ring_gap := 0.7
		if orbital and orbit_clearance > 0.0:
			ring_gap = Layout.planetary_radius(entry.model_kind) + orbit_clearance
		var placed: Dictionary = place_destination(entry,local,result.planets,occupied,settings,48,
			expansion,orbit_bands if orbital else [],ring_gap)
		result.anchors[entry.index] = placed.position
		result.placement[entry.index] = placed
		occupied.append({"position":placed.position,"radius":placed.radius,"label":true})
		if orbital:
			var orbit := circular_orbit(placed.position)
			result.poi_orbits[entry.index] = orbit
			orbit_bands.append(Vector2(orbit.distance,
				Layout.planetary_radius(entry.model_kind) if orbit_clearance > 0.0 else 0.0))
	var star_rng = random_for(seed_value, number, "star")
	# Independent cosmetic streams keep appearance changes away from encounter/loot RNG.
	var profile_data: Resource = preload("res://scripts/expedition/system_profile.gd").for_id(profile)
	if expansion > 0.0:
		var star := weighted_star(star_rng)
		result.star_color = star.color
		result.star_family = star.family
	else:
		var favored: Array = [profile_data.star_hue_bias,0.56,0.64]
		var hue: float = star_rng.randf() if star_rng.randf() < 0.18 else fposmod(float(favored[star_rng.randi_range(0,favored.size()-1)])+star_rng.randf_range(-0.035,0.035),1.0)
		result.star_color = Color.from_hsv(hue,star_rng.randf_range(0.48,0.88),1)
	var atmosphere_rng = random_for(seed_value,number,"atmosphere")
	var bright_chance: float = profile_data.nebula_chance
	result.atmosphere_strength = atmosphere_rng.randf_range(1.1,1.55) if atmosphere_rng.randf() < bright_chance else atmosphere_rng.randf_range(0.7,1.05)
	return result

static func is_planetary(entry: Dictionary) -> bool:
	return PLANETARY.has(entry.get("model_kind", "")) and entry.get("profile") == null

static func planet_extent(planet: Dictionary) -> float:
	return float(planet.radius) * 1.5 * 1.035

static func circular_orbit(position: Vector3) -> Dictionary:
	return {"distance": Vector2(position.x, position.z).length(), "eccentricity": 0.0,
		"inclination": 0.0, "orientation": 0.0}

static func weighted_star(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var family := "unusual"
	var hue: float
	var saturation := rng.randf_range(0.48, 0.82)
	if roll < 0.45:
		family = "yellow"
		hue = rng.randf_range(0.115, 0.163)
		saturation = rng.randf_range(0.28, 0.64)
	elif roll < 0.75:
		family = "orange"
		hue = rng.randf_range(0.045, 0.104)
	elif roll < 0.87:
		family = "blue"
		hue = rng.randf_range(0.51, 0.66)
	elif roll < 0.95:
		family = "red"
		hue = fposmod(rng.randf_range(-0.018, 0.03), 1.0)
	else:
		hue = rng.randf_range(0.20, 0.48) if rng.randf() < 0.5 else rng.randf_range(0.68, 0.92)
	return {"family": family, "color": Color.from_hsv(hue, saturation, 1.0)}

# Only generation-time cosmetic calculations. No live camera or scene is required.
static func placement_region(entry: Dictionary, planets: Array, factor: float = 1.0) -> Vector2:
	var outer: float = planets.back().distance / factor if not planets.is_empty() else 12.0
	match entry.get("model_kind",""):
		"trading_outpost": return Vector2(maxf(7,outer*0.75),minf(27,outer+4)) * factor
		"spatial_anomaly","unstable_wormhole","radiation_nebula": return Vector2(maxf(10,outer*0.85),minf(27,outer+7)) * factor
		"mining_operation": return Vector2(5,maxf(10,outer)) * factor
		"derelict_starship": return Vector2(5,maxf(10,outer*0.85)) * factor
	return Vector2(5,maxf(12,minf(27,outer+4))) * factor

static func model_radius(entry: Dictionary) -> float:
	if entry.get("profile")!=null: return 1.2
	return 2.8 if entry.get("model_kind","") in ["radiation_nebula","spatial_anomaly","unstable_wormhole","gas_giant"] else 1.2

static func clearance(at: Vector3, radius: float, occupied: Array) -> float:
	var result := INF
	for other in occupied: result = minf(result,at.distance_to(other.position)-radius-other.radius)
	return result

static func _project(at: Vector3, context: Dictionary) -> Vector2:
	var point: Vector3 = context.view*at
	return Vector2(0.5+point.x/(-point.z*context.tan_fov*context.aspect*2),0.5-point.y/(-point.z*context.tan_fov*2))

static func _label_rect(at: Vector3, radius: float, named: bool, context: Dictionary, settings: Resource) -> Rect2:
	var pixels: Vector2 = Vector2(116,72) if named else Vector2(48,48)
	var scale: Vector2 = Vector2(context.height*context.aspect,context.height)
	var top := _project(at+Vector3.UP*radius,context)
	return Rect2(top+(Vector2(settings.label_offset.x,-absf(settings.label_offset.y))-Vector2(pixels.x*0.5,pixels.y))/scale,pixels/scale)

static func _contexts(occupied: Array, settings: Resource, expansion: float) -> Array:
	var camera_at: Vector3 = settings.overview_target + (settings.overview_position-settings.overview_target) \
		* sqrt(Layout.scale_factor(expansion)) / settings.default_zoom
	var view := Transform3D(Basis.IDENTITY,camera_at).looking_at(settings.overview_target,Vector3.UP).affine_inverse()
	var contexts: Array = []
	for dimensions in [Vector2(1280,720),Vector2(960,540),Vector2(1680,720)]:
		var context: Dictionary = {"view":view,"tan_fov":tan(deg_to_rad(settings.field_of_view*0.5)),"aspect":dimensions.aspect(),"height":dimensions.y,"rects":[]}
		for other in occupied:
			if other.label: context.rects.append(_label_rect(other.position,other.radius,other.get("named",false),context,settings))
			var center := _project(other.position,context)
			var depth: float = -(view*other.position).z
			var extent: Vector2 = Vector2(other.radius/context.aspect,other.radius)/(depth*context.tan_fov*2)
			context.rects.append(Rect2(center-extent,extent*2))
		contexts.append(context)
	return contexts

static func _composition_score(at: Vector3, radius: float, contexts: Array, settings: Resource) -> float:
	var score := 0.0
	for context in contexts:
		var rect := _label_rect(at,radius,false,context,settings)
		if not Rect2(0.025,0.025,0.95,0.95).encloses(rect): score -= 40
		for other in context.rects:
			if rect.intersects(other): score -= 12+rect.intersection(other).get_area()*1000
	return score

static func place_destination(entry: Dictionary, rng: RandomNumberGenerator, planets: Array, occupied: Array,
		settings: Resource, attempts: int = 48, expansion: float = 0.0, orbit_bands: Array = [], ring_gap: float = 0.7) -> Dictionary:
	var region := placement_region(entry,planets,Layout.scale_factor(expansion))
	var radius := model_radius(entry)
	var contexts := _contexts(occupied,settings,expansion)
	var bounds := Layout.bounds(expansion,settings.system_bounds).grow(-radius)
	var best := Vector3.ZERO
	var best_score := -INF
	var found := false
	var fallback := false
	for attempt in range(attempts):
		var angle: float = rng.randf_range(0,TAU)
		var distance: float = rng.randf_range(region.x,region.y)
		var height := rng.randf_range(-0.45,0.45)
		if not _orbit_clear(distance,orbit_bands,ring_gap): continue
		var at := Vector3(cos(angle)*distance,height if orbit_bands.is_empty() else 0.0,sin(angle)*distance)
		if not bounds.has_point(Vector2(at.x,at.z)): continue
		var gap := clearance(at,radius,occupied)
		if gap<settings.destination_clearance: continue
		var score := _composition_score(at,radius,contexts,settings)+minf(gap,8)*0.15
		if score>best_score:
			best = at
			best_score = score
			found = true
	if not found:
		fallback = true
		# Finite grid fallback, scored rather than accepted blindly after failed rolls.
		for row in range(19):
			for column in range(19):
				var point: Vector2 = bounds.position+bounds.size*Vector2(column/18.0,row/18.0)
				if not _orbit_clear(point.length(),orbit_bands,ring_gap): continue
				var at := Vector3(point.x,0,point.y)
				var gap := clearance(at,radius,occupied)
				if gap<settings.destination_clearance: continue
				var score := _composition_score(at,radius,contexts,settings)+minf(gap,8)*0.15
				if score>best_score:
					best = at
					best_score = score
					found = true
	# Default 48x48 bounds and seven encounters leave ample fallback space. An
	# impossible manual calibration is reported explicitly rather than looping.
	return {"position":best,"radius":radius,"region":region,"fallback":fallback,"valid":found}

static func _orbit_clear(distance: float, bands: Array, gap: float) -> bool:
	for band in bands:
		if absf(distance - band.x) < band.y + gap: return false
	return true


# Reuse the existing placement algorithm and default calibration at system creation.
# Only battle anchors become gameplay state. Moving/cosmetic PoIs stay presentation.
static func battle_positions(state: Resource) -> Dictionary:
	var entries: Array = []
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		if encounter.get("chasedown", false): continue
		var profile: Resource = state.enemy_profile(encounter) if encounter.kind == "battle" else null
		var key: String = ["battle", "elite", "boss"][profile.enemy_rank] if profile != null else encounter.poi.resource_path.get_file().get_basename()
		entries.append({"index": index, "model_kind": key, "profile": profile})
	if not state.service.is_empty():
		entries.append({"index": state.SERVICE_INDEX, "model_kind": "trading_outpost"})
	var layout_seed: int = state.seed_used if state.seed_used != 0 else hash("%d:%d:sky" % [state.seed_used, state.system_number])
	var data: Dictionary = generate(layout_seed, state.system_number, entries,
		preload("res://resources/presentation/star_system_settings.tres"), state.system_profile, state.layout_expansion, state.orbit_clearance)
	var result: Dictionary = {}
	for entry in entries:
		if entry.get("profile") == null: continue
		var at: Vector3 = data.anchors[entry.index]
		result[str(entry.index)] = [at.x, at.y, at.z]
	return JSON.parse_string(JSON.stringify(result))
