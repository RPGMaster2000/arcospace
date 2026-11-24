extends RefCounted
## Small seeded low-poly surface for the stand-alone Exploration prototype.
## Independent of expedition RNG, planet assets, and campaign/save state.

const HALF_SIZE := 64.0
const GRID_COUNT := 64
const STEP := HALF_SIZE * 2.0 / GRID_COUNT
const POI_SITES := [
	Vector2(-29.0, -24.0), # signal spire
	Vector2(29.0, -20.0), # sealed vault
	Vector2(-28.0, 27.0), # survey wreck
	Vector2(29.0, 27.0) # geothermal extractor
]


static func make_noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	return noise


static func height_at(x: float, z: float, hills: FastNoiseLite, ridges: FastNoiseLite) -> float:
	var height := hills.get_noise_2d(x, z) * 8.0
	var ridge := 1.0 - absf(ridges.get_noise_2d(x, z))
	height += ridge * ridge * 4.2 - 2.0
	# Local level ground under the four installations and the starting point.
	var landing_sites: Array[Vector2] = [Vector2(0, 6)]
	landing_sites.append_array(POI_SITES)
	for site in landing_sites:
		var distance := Vector2(x, z).distance_to(site)
		if distance < 9.0:
			var blend := 1.0 - smoothstep(3.0, 9.0, distance)
			height = lerpf(height, 0.8, blend)
	return height


static func terrain_color(height: float, x: float, z: float, details: FastNoiseLite) -> Color:
	var color := Color("#826b59")
	if height < -2.0:
		color = Color("#5b5559")
	elif height > 6.0:
		color = Color("#b39976")
	elif height > 2.5:
		color = Color("#a68a6c")
	var variation := details.get_noise_2d(x * 2.0, z * 2.0) * 0.13
	return color.lightened(maxf(0.0, variation)).darkened(maxf(0.0, -variation))


static func terrain_mesh(hills: FastNoiseLite, ridges: FastNoiseLite, details: FastNoiseLite) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(GRID_COUNT):
		for ix in range(GRID_COUNT):
			var x := -HALF_SIZE + float(ix) * STEP
			var z := -HALF_SIZE + float(iz) * STEP
			var a := Vector3(x, height_at(x, z, hills, ridges), z)
			var b := Vector3(x + STEP, height_at(x + STEP, z, hills, ridges), z)
			var c := Vector3(x, height_at(x, z + STEP, hills, ridges), z + STEP)
			var d := Vector3(x + STEP, height_at(x + STEP, z + STEP, hills, ridges), z + STEP)
			# Separate triangle vertices create deliberate low-poly facets.
			_triangle(surface, a, c, b, terrain_color((a.y + b.y + c.y) / 3.0, x, z, details))
			_triangle(surface, b, c, d, terrain_color((b.y + c.y + d.y) / 3.0, x + STEP, z + STEP, details))
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)
