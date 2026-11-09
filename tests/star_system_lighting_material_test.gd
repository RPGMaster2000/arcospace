extends SceneTree
const Lighting = preload("res://scripts/presentation/star_system/stellar_lighting.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var settings = preload("res://resources/presentation/star_system_settings.tres").duplicate(true)
	var star := Vector3(2,1,-3)
	for kind in ["rocky","barren","terrestrial","frozen","desert","volcanic","gas_giant"]:
		var preset: ShaderMaterial = Planets.PRESETS[kind]
		var colors: Array = []
		for index in range(1,6): colors.append(preset.get_shader_parameter("color_%d" % index))
		var specimen := {"index":0,"radius":0.8,"type":kind,"material_seed":123,"rotation":0.3}
		var planet: Node3D = Planets.build(specimen,settings)
		Lighting.calibrate(planet,settings,star)
		var surface: ShaderMaterial = planet.get_node("Surface").material_override
		check(surface != preset and surface.get_shader_parameter("stellar_lighting_enabled") == true,"Map surface is an independent calibrated material")
		check(surface.get_shader_parameter("stellar_position") == star,"Translated star is used by the shader")
		check(surface.get_shader_parameter("noise") == preset.get_shader_parameter("noise"),"Existing noise and planetary variety are retained")
		check(preset.get_shader_parameter("stellar_lighting_enabled") != true,"Other scenes' shared presets are not opted into map lighting")
		check(surface.get_shader_parameter("minimum_roughness") == (0.72 if kind == "gas_giant" else 0.55),"Gas layers retain softer material response than rocky surfaces")
		var atmosphere_count := 0
		for mesh in planet.find_children("*","MeshInstance3D",true,false):
			var air: ShaderMaterial = mesh.material_override as ShaderMaterial
			if air == null or not air.shader.resource_path.ends_with("atmosphere.gdshader"): continue
			atmosphere_count += 1
			check(is_equal_approx(float(air.get_shader_parameter("alpha")),0.16 if kind in ["terrestrial","frozen","gas_giant"] else 0.08),"Existing material families retain distinct atmosphere strengths")
		check(atmosphere_count == (0 if kind in ["rocky","barren"] else 1),"No new atmosphere shells or rocky-planet halos")
		for index in range(1,6): check(colors[index-1] == preset.get_shader_parameter("color_%d" % index),"Preset colors are never mutated")
		planet.free()
	var original = load("res://scenes/ship_3d.tscn").instantiate()
	root.add_child(original)
	var map_ship: Node3D = Models.ship(preload("res://ships/player/endeavour.tres"))
	root.add_child(map_ship)
	var hull: StandardMaterial3D = map_ship.get_child(0).hull_material
	var color: Color = hull.albedo_color
	var damage_pass: Material = hull.next_pass
	Lighting.calibrate(map_ship,settings,star)
	check(hull.rim_enabled and hull.rim < 0.1,"Native lit spacecraft rim is restrained and applied in place")
	check(hull.albedo_color == color and hull.next_pass == damage_pass,"Ship colors and existing damage/repair passes are retained")
	check(not original.hull_material.rim_enabled,"Battle ship's material remains unchanged")
	settings.directional_rim_intensity = 0.0
	Lighting.calibrate(map_ship,settings,star)
	check(not hull.rim_enabled,"Visual rim setting can disable the map effect")
	var fallback_settings = settings.duplicate()
	fallback_settings.imported_planets = false
	var fallback = Planets.build({"index":0,"radius":0.8,"type":"barren","material_seed":123,"rotation":0.0},fallback_settings)
	check(fallback.get_node("Surface").material_override.get_shader_parameter("stellar_lighting_enabled") == true,"GL-compatible fallback uses the same calibration")
	fallback.free()
	map_ship.free()
	original.free()
	print("Lighting material isolation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
