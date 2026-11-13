extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const CAPTURES = "res://.godot/testlogs/tactical-decoy"

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.defense_tuning = Rules.defense_tuning.duplicate(true)
	rules.defense_tuning.v2_maximum_reinforcements = 0
	rules.log_rolls = false
	var state := State.new()
	state.start(0, rules, 1042)
	return state

func test_position(state: Resource) -> Vector3:
	var ship := State.Defense.point(state.navigation.position)
	for distance in [5.0, 8.0, 11.0]:
		for i in range(32):
			var at: Vector3 = ship + (Vector3.RIGHT * float(distance)).rotated(Vector3.UP, TAU * i / 32.0)
			if state.decoy_placement(at).is_empty(): return at
	return Vector3.INF

func advance(state: Resource, seconds: float) -> void:
	var ship := State.Defense.point(state.navigation.position)
	state._advance_strategy(seconds, ship, ship, true)

func model_checks() -> void:
	var state := fresh()
	var fleet: RefCounted = state.defense
	var salvage: int = state.salvage
	var index := -1
	for i in state.encounters.size():
		var encounter: Dictionary = state.encounters[i]
		if encounter.kind == "poi" and encounter.poi.resource_path.ends_with("derelict_starship.tres"): index = i
	if index == -1:
		for i in state.encounters.size():
			if state.encounters[i].kind == "poi":
				index = i
				state.encounters[i].poi = preload("res://encounters/derelict_starship.tres")
				break
	var options: Array = state.poi_approaches(index)
	var beacon := options.size() - 1
	state.decoys = 2
	check(not state.resolve_approach(index, beacon) and state.decoys == 2, "Full inventory blocks the reward before consuming the PoI")
	state.decoys = 0
	check(state.resolve_approach(index, beacon) and state.decoys == 1 and state.salvage == salvage,
		"Derelict grants one guaranteed beacon without salvage")
	check(not state.resolve_approach(index, beacon), "Reward cannot be repeated")
	var at := test_position(state)
	check(at.is_finite(), "A legal point exists within deployment range")
	if not at.is_finite(): return
	check(state.decoy_placement(State.Defense.point(state.navigation.position)) == "Too close to your ship", "Player clearance enforced")
	check(state.decoy_placement(Vector3(80.0, 0.0, 0.0)) == "Outside navigation bounds", "Bounds enforced")
	var ship_position: Array = state.navigation.position.duplicate()
	state.navigation.checkpoint_position(State.Defense.wire(fleet.home + Vector3.UP * 5.0))
	check(state.decoy_placement(fleet.home) == "Homeworld", "Solid body is excluded")
	var poi: Vector3 = fleet.anchors.values()[0]
	state.navigation.checkpoint_position(State.Defense.wire(poi + Vector3.UP * 5.0))
	check(state.decoy_placement(poi) == "Too close to a destination", "PoI interaction radius is excluded")
	state.navigation.checkpoint_position([0.0, 0.0, 0.0])
	check(state.decoy_placement(Vector3(20.0, 0.0, 0.0)) == "Outside deployment range", "Deployment range is enforced")
	state.navigation.checkpoint_position(ship_position)
	var unit: Dictionary = fleet.unit_for(0)
	var other: Dictionary = fleet.unit_for(1)
	var homeward: Vector3 = (fleet.home - at).normalized()
	unit.position = at + homeward * 5.0
	other.position = at - homeward * 17.0
	var storm := State.EnvironmentData.Storms.generate(3, state.system_number, 1.0, [], [])
	storm.position = State.Defense.wire(at)
	storm.configuration.subtype = "ion"
	storm.visual.color = State.Modifiers.storm_color(2).to_html(false)
	state.environmental_instances = [storm]
	check(fleet.decoy_targets(at, 15.0) == [0], "Preview excludes the distant attacker and mothership")
	check(state.deploy_decoy(at) and state.decoys == 0 and fleet.target_for(unit) == at and fleet.target_for(other) == fleet.home,
		"Deployment inside an Ion Storm redirects exactly the previewed attacker")
	check(not state.deploy_decoy(at), "Cannot deploy another active decoy")
	advance(state, 2.5)
	check(fleet.target_for(other) == at, "Swept radius entry diverts an approaching attacker")
	check(State.EnvironmentData.modifier_id(state.battle_environment(0)) == 2, "Combat inside the storm receives existing Ion modifier")
	var save := JSON.parse_string(JSON.stringify(Save.encode(state))) as Dictionary
	var restored := Save.new().decode(save, state.rules)
	check(restored != null, "An active beacon survives save/load")
	if restored == null: return
	check(restored.defense.decoy == fleet.decoy and restored.decoys == 0, "Save retains affected ships and remaining lifetime")
	var frozen: Dictionary = state.battle_environment(0)
	advance(state, 5.0)
	for step in range(20): advance(restored, 0.25)
	check(fleet.decoy.is_empty() and restored.defense.decoy.is_empty(), "First enemy arrival destroys the beacon")
	check(fleet.target_for(unit) == fleet.home and fleet.target_for(other) == fleet.home and fleet.integrity == 100,
		"Every affected attacker resumes homeward flight without homeworld damage")
	check(unit.position.is_equal_approx(restored.defense.unit_for(0).position)
		and other.position.is_equal_approx(restored.defense.unit_for(1).position), "Route resumption agrees across step sizes")
	check(State.EnvironmentData.modifier_id(frozen) == 2 and frozen.is_read_only(), "Captured Ion modifier remains frozen")

func expiration_checks() -> void:
	var state := fresh()
	state.decoys = 2
	var at := test_position(state)
	var fleet: RefCounted = state.defense
	fleet.tuning.enemy_speed = 0.0
	var mothership: Dictionary = fleet.unit_for(fleet.mothership_index())
	check(state.deploy_decoy(at), "Beacon can be deployed before an enemy enters")
	advance(state, 14.5)
	check(not fleet.decoy.is_empty() and fleet.target_for(mothership) == fleet.home, "The mothership ignores the beacon before it expires")
	advance(state, 0.5)
	check(fleet.decoy.is_empty() and state.decoys == 1, "Beacon clears by its lifetime without spending another item")
	var saved: Dictionary = Save.encode(state)
	var restored := Save.new().decode(saved, state.rules)
	check(restored != null and restored.decoys == 1 and restored.defense.decoy.is_empty(), "Stored item survives reload")
	saved.erase("decoys")
	restored = Save.new().decode(saved, state.rules)
	check(restored != null and restored.decoys == 0, "Legacy saves default to empty inventory")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "%s/%s-%s.png" % [CAPTURES, label, RenderingServer.get_current_rendering_method()]
	check(root.get_texture().get_image().save_png(path) == OK, "Captured " + label)

func presentation_checks() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var state := fresh()
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state": state, "battle": {}}
	root.add_child(host)
	for frame in range(8): await process_frame
	check(not host.decoy_button.visible, "Empty inventory hides the action")
	state.decoys = 2
	for frame in range(3): await process_frame
	var map = host.star_map
	check(host.decoy_button.visible and host.decoy_button.text.ends_with("2"), "Inventory action displays quantity")
	await capture("inventory")
	host.decoy_button.pressed.emit()
	check(host.decoy_confirmation.shade.visible, "Deploy opens confirmation")
	host.decoy_confirmation.initiate.pressed.emit()
	check(is_instance_valid(map.decoy_preview), "Confirmation starts world-space placement")
	var at := test_position(state)
	var current: Vector3 = map.decoy_point()
	map.camera.pan_offset += Vector2(at.x - current.x, at.z - current.z)
	map.camera.overview(map.settings, true)
	var target: Dictionary = state.defense.unit_for(0)
	target.position = at + Vector3(0.0, 0.0, 4.0)
	map.sync_defense(state.defense_map_view())
	for frame in range(3): await process_frame
	check(map.decoy_preview.position.distance_to(at) < 0.01 and not host.decoy_place.disabled, "Preview tracks the center of the view")
	await capture("placement")
	host._cancel_decoy()
	check(state.decoys == 2 and not is_instance_valid(map.decoy_preview), "Cancel consumes nothing and removes preview")
	host._begin_decoy_placement()
	current = map.decoy_point()
	map.camera.pan_offset += Vector2(at.x - current.x, at.z - current.z)
	map.camera.overview(map.settings, true)
	for frame in range(3): await process_frame
	host._place_decoy()
	check(state.decoys == 1 and is_instance_valid(map.active_decoy), "Confirmation consumes one item and displays the beacon")
	await capture("active")
	advance(state, 5.0)
	check(not is_instance_valid(map.active_decoy), "Destroyed beacon disappears from the map")
	await capture("released")
	host.free()

func run() -> void:
	model_checks()
	expiration_checks()
	await presentation_checks()
	root.get_node("Music").play_track("")
	await create_timer(0.15).timeout
	print("Tactical Decoy: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
