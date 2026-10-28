extends SceneTree
# Count actual layout work while idle, then mutate geometry/content through normal signals.
class Screen extends "res://scripts/ui/expedition_screen.gd":
	var sync_count := 0
	func _sync_map_rect() -> void:
		sync_count += 1
		super()
class Tile extends "res://scripts/ui/encounter_tile.gd":
	var measure_count := 0
	func _measure_content() -> void:
		measure_count += 1
		super()
class Map extends Control:
	var hud_regions: Array[Rect2] = []
var checks := 0
var failures := 0
func _initialize() -> void:
	# Retained exploration-mode regression.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle():
	for i in range(60): await process_frame
func run():
	var state = preload("res://scripts/expedition_state.gd").new()
	state.start(0,preload("res://encounters/expedition_rules.tres"),1042)
	var screen = Screen.new()
	root.add_child(screen)
	screen.reset_view("system",state,true,Callable())
	var map = Map.new()
	screen.mount_map(map)
	screen.map_layout(true,false)
	await settle()
	var syncs: int = screen.sync_count
	await settle()
	check(screen.sync_count == syncs,"Stable screen does no per-frame geometry work")
	state.salvage = 123456
	screen.resource_bar.exploration(state)
	await settle()
	check(screen.sync_count > syncs,"HUD content invalidates exclusion geometry")
	syncs = screen.sync_count
	root.content_scale_size = Vector2i(1680,720)
	root.size = Vector2i(1680,720)
	await settle()
	check(screen.sync_count > syncs and map.size == screen.size,"Resize updates full-screen map geometry")
	check(not map.hud_regions.is_empty(),"HUD exclusion regions follow event-driven layout")
	var tile = Tile.new()
	tile.configure("Choice", "Short outcome", Color.WHITE)
	tile.set_compact(true)
	root.add_child(tile)
	tile.size.x = 320
	await settle()
	var measures: int = tile.measure_count
	var height: float = tile.size.y
	await settle()
	check(tile.measure_count == measures,"Stable tile does no per-frame measurement")
	tile.details.text = "A lengthy authored outcome that remains fully visible. ".repeat(5)
	await settle()
	check(tile.measure_count > measures and tile.size.y > height,"Content change reserves actual wrapped height")
	measures = tile.measure_count
	tile.size.x = 640
	await settle()
	check(tile.measure_count > measures,"Tile resize invalidates measurement")
	measures = tile.measure_count
	await settle()
	check(tile.measure_count == measures,"Layout settles again after resizing")
	tile.collapse_requirement("Synthesizer 12 required (2); "+"a very long authored requirement ".repeat(3))
	await settle()
	measures = tile.measure_count
	await settle()
	check(tile.measure_count == measures,"Locked wrapping also settles without layout feedback")
	check(tile.heading.get_theme_font_size("font_size") >= 14,"Settled long requirement retains readable typography")
	var late = Tile.new()
	root.add_child(late)
	late.configure("Late configuration", "Visible outcome", Color.WHITE)
	late.size.x = 320
	await settle()
	check(late.measure_count > 0 and late.size.y >= late.minimum_height,"Controls can be configured after entering the tree")
	late.free()
	tile.free()
	screen.free()
	print("Layout invalidation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
