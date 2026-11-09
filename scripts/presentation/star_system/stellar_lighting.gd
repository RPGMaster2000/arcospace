extends RefCounted
## Build-time map-only material calibration. No new nodes, lights or passes.
const SHADERS = ["res://third_party/naejimer_planets/shaders/body.gdshader",
	"res://third_party/naejimer_planets/shaders/clouds.gdshader",
	"res://third_party/naejimer_planets/shaders/atmosphere.gdshader",
	"res://shaders/planet_surface.gdshader"]

static func shader(material: ShaderMaterial, settings: Resource, star: Vector3 = Vector3.ZERO) -> void:
	material.set_shader_parameter("stellar_lighting_enabled", true)
	material.set_shader_parameter("stellar_position", star)
	material.set_shader_parameter("stellar_dark_fill", settings.dark_side_fill)
	material.set_shader_parameter("stellar_contrast", settings.day_night_contrast)
	material.set_shader_parameter("stellar_rim_intensity", settings.directional_rim_intensity)

static func calibrate(root: Node3D, settings: Resource, star: Vector3) -> void:
	var cache: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.material_override != null:
			var material: Material = _material(node.material_override, settings, star, cache)
			if material != null: node.material_override = material
		elif node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				var material: Material = _material(node.get_active_material(index), settings, star, cache)
				if material != null: node.set_surface_override_material(index, material)

static func _material(source: Material, settings: Resource, star: Vector3, cache: Dictionary) -> Material:
	if source == null: return null
	if cache.has(source): return cache[source]
	if source is ShaderMaterial:
		if source.shader == null or source.shader.resource_path not in SHADERS: return null
	elif source is StandardMaterial3D:
		# Preserve engine/beacon emission and unshaded presentation effects.
		if source.emission_enabled or source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: return null
	else: return null
	# Authored shared resources must not leak map tuning into battle/menu scenes.
	# Procedural and ship-owned duplicates retain references used by hull tinting.
	var material: Material = source.duplicate() if not source.resource_path.is_empty() else source
	cache[source] = material
	if material is ShaderMaterial:
		shader(material,settings,star)
	else:
		# Godot's native rim is light-dependent, preserves PBR/textures and costs no pass.
		material.rim_enabled = settings.directional_rim_intensity > 0.0
		material.rim = settings.directional_rim_intensity * 0.65
		material.rim_tint = 0.65
	return material
