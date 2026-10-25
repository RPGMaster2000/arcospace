extends SceneTree
# Render-only diagnostic. This script intentionally uses existing state APIs only.
func _initialize(): call_deferred("run")
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
 root.get_texture().get_image().save_png("res://.godot/testlogs/polish-"+name+".png")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 host.rules = host.rules.duplicate()
 host.rules.debug_seed = 1042
 host.rules.log_rolls = false
 host.rules.chasedown_chance = 0
 root.add_child(host)
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size = dimensions
  host.show_system()
  await create_timer(0.95).timeout
  await capture("visual-overview-%d" % dimensions.x)
 var map = host.star_map
 map.travel(0)
 await create_timer(0.22).timeout
 await capture("selection-travel")
 await create_timer(1.5).timeout
 host.state.start_upgrade_event(2)
 host.show_outcome()
 host.card_management.select_card(host.card_management.gallery.cards[0])
 await create_timer(0.6).timeout
 await capture("visual-upgrade")
 host.free()
 print("Star system polish visual captures complete")
 quit()
