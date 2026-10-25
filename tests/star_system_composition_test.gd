extends SceneTree
const Data = preload("res://scripts/presentation/star_system/visual_system.gd")
const Settings = preload("res://scripts/presentation/star_system/map_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var settings = Settings.new()
 var entries: Array = []
 for i in range(6): entries.append({"index":i,"model_kind":["mining_operation","research_station","quarantined_colony","spatial_anomaly","derelict_starship","battle"][i]})
 entries.append({"index":-2,"model_kind":"trading_outpost"})
 var before: String = var_to_str(entries)
 var rng := RandomNumberGenerator.new()
 rng.seed = 88
 var rng_state: int = rng.state
 var fallbacks := 0
 var start: int = Time.get_ticks_usec()
 var unique: Dictionary = {}
 for seed_value in range(300):
  var number: int = seed_value%5+1
  var sample_entries: Array = entries.duplicate(true)
  if seed_value%3!=0:
   for index in range(6): sample_entries[index].model_kind = "battle" if seed_value%3==1 else "spatial_anomaly"
  var data: Dictionary = Data.generate(seed_value,number,sample_entries,settings)
  check(data==Data.generate(seed_value,number,sample_entries,settings),"Cosmetic placement reconstructs deterministically")
  check(data.anchors.size()==7,"Exactly six unchanged IDs and outpost anchor")
  var occupied: Array = [{"position":Vector3.ZERO,"radius":2.6,"label":false}]
  for p in data.planets: occupied.append({"position":p.position,"radius":p.radius*1.5,"label":p.encounter!=-1})
  for entry in entries:
   check(data.anchors.has(entry.index),"Every encounter index retained")
  var order: Array = data.placement.keys()
  order.sort()
  for index in order:
   var placed: Dictionary = data.placement[index]
   check(placed.valid,"Placement always finds usable default space")
   check(Data.clearance(placed.position,placed.radius,occupied)>=settings.destination_clearance-0.0001,"Visible model surfaces clear sun, planets and earlier PoIs")
   check(settings.system_bounds.has_point(Vector2(placed.position.x,placed.position.z)),"Standalone destination stays inside current borders")
   if not placed.fallback:
    var radius: float = Vector2(placed.position.x,placed.position.z).length()
    check(radius>=placed.region.x-0.001 and radius<=placed.region.y+0.001,"Category radial preference preserved")
   else: fallbacks += 1
   occupied.append({"position":placed.position,"radius":placed.radius,"label":true})
  unique[str(data.anchors[-2])] = true
 check(unique.size()>290,"Outposts do not repeat a fixed anchor or ring position")
 var sparse: Array = [{"position":Vector3.ZERO,"radius":2.6,"label":false}]
 var fallback: Dictionary = Data.place_destination(entries[-1],Data.random_for(42,1,"forced-fallback"),[],sparse,settings,0)
 check(fallback.valid and fallback.fallback,"Zero candidate budget exercises terminating deterministic grid fallback")
 check(Data.clearance(fallback.position,fallback.radius,sparse)>=settings.destination_clearance,"Fallback obeys physical clearance")
 check(fallback==Data.place_destination(entries[-1],Data.random_for(42,1,"forced-fallback"),[],sparse,settings,0),"Fallback deterministic")
 check(var_to_str(entries)==before and rng.state==rng_state,"Placement never mutates input or supplied gameplay RNG")
 print("System composition: %d checks; 300 systems; %d natural fallbacks; %.2f ms/system for generation plus reconstruction; %d failures" % [checks,fallbacks,(Time.get_ticks_usec()-start)/300000.0,failures])
 quit(1 if failures else 0)
