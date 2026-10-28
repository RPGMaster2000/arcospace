extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")
const Board = preload("res://scenes/board_3d.tscn")
const Cards = preload("res://scripts/cards/card_library.gd")
const StatusPanel = preload("res://scripts/ui/battle_modifier_panel.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for kind in [6,7]:
			var board = Board.instantiate()
			board.setup_settings = {"modifier":kind,"player_ship":0,"enemy_ship":0}
			board.get_node("BattleEffects").enabled = false
			board.get_node("CardMotion").settings.enabled = false
			root.add_child(board)
			board.enemy_timer.stop()
			var mod = board.modifier
			var display = board.get_node("ModifierDisplay")
			display.cinematic_enabled = false
			var meter = display.get_node("Meter")
			check(mod.kind == kind,"Board retains appended modifier ID")
			var field = board.get_node("BattleView/Viewport/Battlefield")
			check(field.scene_file_path == preload("res://scripts/board_3d.gd").BATTLEFIELDS[kind].resource_path,"Both storms select their explicit Ion variant, never a normal/planetary arena")
			var ion = preload("res://scenes/battlefield_ion_storm.tscn").instantiate()
			check(field.get_node("Camera3D").transform == ion.get_node("Camera3D").transform,"Inherited Ion camera/framing preserved")
			var backdrop: ShaderMaterial = field.get_node("MeshInstance3D").material_override
			var ion_backdrop: ShaderMaterial = ion.get_node("MeshInstance3D").material_override
			check(backdrop.shader == ion_backdrop.shader, "Both storm variants retain the Ion panorama shader")
			check(backdrop.shader.resource_path == "res://shaders/battle_panorama.gdshader", "Storm scenes use the panorama shader, not legacy procedural space")
			check(backdrop.get_shader_parameter("panorama") != null, "Storm panorama texture is assigned")
			check(backdrop.get_shader_parameter("panorama_tint") != ion_backdrop.get_shader_parameter("panorama_tint"), "Storm variant preserves distinct atmosphere tint")
			check(not field.has_node("BackgroundObjects/Planet"),"No planetary decoration in either storm")
			check(board.get_node("BattleView").preset.resource_path.ends_with("metal_storm.tres" if kind == 6 else "psionic_storm.tres"),"Matching storm grade, never normal or Temporal")
			ion.free()
			mod.next_round = 2
			check(StatusPanel.compact_status(mod,1).contains("Next storm in 1"),"New storm countdown")
			var announcement: String = mod.begin_round(2)
			check(announcement.contains(Mod.NAMES[kind].to_upper()),"Activation name")
			for factor in [0.5,2.0]:
				mod.ion_factor = factor
				board.turn_number = 2
				board.refresh_display()
				check(meter.get_node("Text").text.contains(Mod.storm_family(kind).capitalize()),"HUD affected family")
				check(meter.get_node("Text").text.contains("halved" if factor == 0.5 else "doubled"),"HUD multiplier")
				check(meter.get_node("Text").modulate == Mod.storm_color(kind),"Amber/violet HUD identity")
				check(meter.current_rules.contains("50%") and meter.current_rules.contains("costs stay unchanged"),"Pre-battle/full rules explain shared mechanics")
				var snapshot: Dictionary = board._display_snapshot()
				for index in range(snapshot.cards.size()):
					var original: Resource = board.hand.cards[index]
					var shown: Dictionary = snapshot.cards[index]
					check(shown.ion_glow == (original.family == Mod.storm_family(kind)),"Only matching cards glow")
					check(shown.storm_color == Mod.storm_color(kind,true),"Card glow tint supplied")
				check(mod.status_text(2).contains("SUPPRESSED" if factor == 0.5 else "AMPLIFIED"),"Active status text")
				display.cinematic_enabled = true
				display.warning_seconds = 0.01
				await display.warning(kind,true,mod.storm_text())
				check(display.get_node("Flash").text.contains(Mod.STORMS[kind].short + " SURGE"),"Per-card surge uses storm identity")
				check(display.get_node("Flash").modulate.r == Mod.storm_color(kind).r,"Surge tint")
				display.announce("Unrelated alert")
				check(display.get_node("Flash").modulate.r == 1.0,"Storm tint does not leak into other announcements")
				display.cinematic_enabled = false
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/testlogs/storm-%d-%d.png" % [kind,dimensions.x])
			mod.begin_round(mod.ends_round)
			board.refresh_display()
			check(not mod.active and StatusPanel.compact_status(mod,board.turn_number).contains("Next storm"),"Expiry restores countdown")
			check(board._display_snapshot().cards.all(func(card): return not card.ion_glow),"Expiry clears glows")
			board.queue_free()
			await process_frame
	print("Storm presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
