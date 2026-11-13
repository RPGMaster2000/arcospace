extends RefCounted
## Scene-free conservative region/sphere clearance. Only new generation calls this.
## No RNG, mesh colliders or sampled asteroid transforms are used.
static func point(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

static func intersects_sphere(item: Dictionary, center: Vector3, radius: float) -> bool:
	var local: Vector3 = center-point(item.position)
	var region: Dictionary = item.region
	match region.shape:
		"sphere": return local.length() <= float(region.radius)+radius
		"ellipsoid":
			return ellipsoid_distance(local,point(region.axes)) <= radius
		"belt":
			var plane := Vector2(local.x,local.z).rotated(-float(region.angle))
			var ratio: float = region.ratio
			var vertical: float = maxf(0.0,absf(local.y)-float(region.half_height))
			if vertical > radius: return false
			var outer := ellipsoid_distance(Vector3(plane.x,plane.y,0),Vector3(region.outer,float(region.outer)*ratio,1))
			if Vector2(outer,vertical).length() > radius: return false
			# A guaranteed interior distance lower bound preserves a clear inner hole.
			var normalized := Vector2(plane.x/float(region.inner),plane.y/(float(region.inner)*ratio)).length()
			if normalized < 1.0 and (1.0-normalized)*float(region.inner)*minf(1.0,ratio) > radius: return false
			return true
		"pockets":
			var plane := Vector2(local.x,local.z).rotated(-float(region.angle))
			var vertical := maxf(0.0,absf(local.y)-float(region.half_height))
			for pocket in region.pockets:
				var at := (plane-Vector2(pocket.offset[0],pocket.offset[1])).rotated(-float(pocket.angle))
				var horizontal := ellipsoid_distance(Vector3(at.x,at.y,0),Vector3(pocket.axes[0],pocket.axes[1],1))
				if Vector2(horizontal,vertical).length() <= radius: return true
			return false
	return true # Unknown geometry cannot establish safe clearance.

# Exact external point/ellipsoid distance by a bounded monotone Lagrange solve.
# Interior points have zero distance to the solid volume.
static func ellipsoid_distance(at: Vector3, axes: Vector3) -> float:
	if axes.x <= 0 or axes.y <= 0 or axes.z <= 0: return 0.0
	if (at/axes).length_squared() <= 1.0: return 0.0
	var square := axes*axes
	var low := 0.0
	var high := at.length()*maxf(axes.x,maxf(axes.y,axes.z))
	for iteration in range(48):
		var middle := (low+high)*0.5
		var closest := square*at/(square+Vector3.ONE*middle)
		if (closest/axes).length_squared() > 1.0: low = middle
		else: high = middle
	var closest := square*at/(square+Vector3.ONE*high)
	return at.distance_to(closest)


const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const MAX_ATTEMPTS = 32

static func home_radius(margin: float) -> float:
	# Same full scale/atmosphere envelope used by VisualSystem.planet_extent.
	return 1.8 * 1.5 * 1.035 + margin

static func protect_home(state: Resource, records: Array, candidates: Array) -> Array:
	var result: Array = []
	var radius := home_radius(state.defense.tuning.environment_visual_margin)
	var bounds := Layout.bounds(state.layout_expansion)
	for item in records:
		if not intersects_sphere(item,state.defense.home,radius):
			result.append(item)
			continue
		# Stellar influence cannot be moved off its star. An impossible optional
		# region is omitted instead of moving the homeworld or changing combat rules.
		if item.type == "SOLAR_INTERFERENCE": continue
		for attempt in range(MAX_ATTEMPTS):
			var replacement: Dictionary = {}
			var seed_value := hash("%d:%d:%s:home-clearance:%d" % [state.seed_used,state.system_number,item.id,attempt])
			if item.type == "ASTEROID_FIELD":
				for generated in Asteroids.generate(seed_value,state.system_number,candidates,state.layout_expansion):
					if generated.id == item.id: replacement = generated
			elif item.type == "SPACE_STORM":
				replacement = item.duplicate(true)
				var axes := point(item.region.axes)
				if attempt < candidates.size(): replacement.position = candidates[attempt].duplicate()
				else:
					var rng := RandomNumberGenerator.new()
					rng.seed = seed_value
					if bounds.size.x <= axes.x*2 or bounds.size.y <= axes.z*2: break
					replacement.position = [rng.randf_range(bounds.position.x+axes.x,bounds.end.x-axes.x),item.position[1],rng.randf_range(bounds.position.y+axes.z,bounds.end.y-axes.z)]
				var at := point(replacement.position)
				if not bounds.encloses(Rect2(Vector2(at.x-axes.x,at.z-axes.z),Vector2(axes.x*2,axes.z*2))): continue
			if not replacement.is_empty() and state.defense.v2 and not preload("res://scripts/expedition/route_environments.gd").relevant(replacement,state.defense): continue
			if replacement.is_empty() or intersects_sphere(replacement,state.defense.home,radius): continue
			replacement.generation.clearance_attempt = attempt+1
			result.append(JSON.parse_string(JSON.stringify(replacement)))
			break
	return result

# Saved generation metadata opts new layouts into clearance; historical systems
# are never reinterpreted. This margin is shared by map and scene-free layout.
static func solar_clearance(records: Array) -> float:
	for item in records:
		if item.type == "SOLAR_INTERFERENCE" and item.generation.get("celestial_clearance",false) == true:
			return float(item.region.radius)+clampf(float(item.generation.get("visual_margin",0.6)),0.0,3.0)
	return 0.0
