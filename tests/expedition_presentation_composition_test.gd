extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Screen = preload("res://scripts/ui/expedition_screen.gd")
var failures: int = 0
var choices: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func icon(key: String) -> String:
	return key

func choose(key: String) -> void:
	choices.append(key)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for mode in ["exploration", "defense"]:
		var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
		rules.game_mode = mode
		rules.log_rolls = false
		var state = State.new()
		state.start(0, rules, 1042)
		var before: Dictionary = Save.encode(state)
		var entries: Array = Screen.map_entries(state, icon)
		check(not entries.is_empty(), "Generated encounters have map entries")
		for entry in entries:
			if entry.index == state.SERVICE_INDEX:
				check(entry.model_kind == "trading_outpost" and not entry.completed, "Outpost retains its free-return presentation")
			else:
				check(entry.name == state.encounters[entry.index].title and entry.completed == state.encounters[entry.index].completed, "Entries retain authoritative encounter identity and completion")
		check(Save.encode(state) == before, "Map presentation does not change gameplay, cards, navigation or RNG")
		var screen = Screen.new()
		root.add_child(screen)
		screen.reset_view("outcome", state, false, icon)
		state.pending_choice = "resource"
		state.choice_amount = 7
		before = Save.encode(state)
		screen.present_rewards(state, preload("res://resources/visual/alpha_visual_settings.tres"), false, choose, func(): pass)
		check(Save.encode(state) == before, "Reward presentation does not commit choices")
		var option: Button = screen.grid.get_child(0)
		option.pressed.emit()
		check(choices.back() == state.RESOURCES[0] and Save.encode(state) == before, "Reward emits intent without spending or granting resources")
		var count: int = choices.size()
		screen.reset_view("system", state, false, icon)
		option.pressed.emit()
		check(choices.size() == count, "Detached reward controls cannot route a new view")
		screen.free()
	print("Expedition presentation composition: %d failures" % failures)
	quit(1 if failures else 0)
