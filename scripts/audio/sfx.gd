extends Node
# RESPONSIBILITY: Play catalog events with bounded voices, isolated RNG and scene ownership.
# DOES NOT: Resolve gameplay, select music or synthesize audio at runtime.
@export var catalog: Resource
const POOL_SIZE: int = 12
const SETTINGS_PATH = preload("res://scripts/ui/menu_preferences.gd").PATH
var volume: float = 1.0
var players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _last_played: Dictionary = {}


func _ready() -> void:
	# Load after import; @tool card scripts can parse this singleton on a clean editor scan.
	if catalog == null:
		catalog = load("res://resources/audio/sound_catalog.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize() # Independent generator; never call global rand* functions here.
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		players.append(player)
		player.finished.connect(_release.bind(player))
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	set_volume(float(settings.get_value("sfx", "volume", 1.0)), false)


func set_volume(value: float, persist: bool = true) -> void:
	volume = clampf(value, 0.0, 1.0)
	var bus: int = AudioServer.get_bus_index(&"SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)) - 8.0)
		AudioServer.set_bus_mute(bus, volume <= 0.0)
	if volume <= 0.0:
		stop_all() # Unmuting must not resume old impacts.
	if persist:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("sfx", "volume", volume)
		if settings.save(SETTINGS_PATH) != OK:
			push_warning("Could not save Sound Effects Volume")


# Scope is the existing presentation node. Its exit stops all its voices immediately.
# Missing events, empty variant lists and null streams fail silently without gameplay effects.
func play_event(event_id: StringName, scope: Node) -> bool:
	if volume <= 0.0 or not is_instance_valid(scope) or not scope.is_inside_tree():
		return false
	var event: Resource = catalog.find_event(event_id) if catalog != null else null
	if event == null or not event.enabled:
		return false
	var streams: Array[AudioStream] = []
	for stream in event.streams:
		if stream != null:
			streams.append(stream)
	if streams.is_empty():
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	var key: StringName = event.replay_group if event.replay_group != &"" else event_id
	if now - float(_last_played.get(key, -10000.0)) < event.replay_interval:
		return false
	var count: int = 0
	var free_voice: AudioStreamPlayer
	var victim: AudioStreamPlayer
	for player in players:
		if not player.playing:
			free_voice = player
			continue
		if player.get_meta(&"event", &"") == event_id:
			count += 1
		if int(player.get_meta(&"priority", 0)) < event.priority:
			if victim == null or int(player.get_meta(&"priority")) < int(victim.get_meta(&"priority")) or (int(player.get_meta(&"priority")) == int(victim.get_meta(&"priority")) and float(player.get_meta(&"started")) < float(victim.get_meta(&"started"))):
				victim = player
	if count >= event.concurrency_limit:
		return false
	var voice: AudioStreamPlayer = free_voice if free_voice != null else victim
	if voice == null:
		return false
	voice.stop()
	voice.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	voice.volume_db = event.volume_db
	voice.pitch_scale = event.pitch_scale * (1.0 + _rng.randf_range(-event.pitch_variation, event.pitch_variation))
	voice.set_meta(&"event", event_id)
	voice.set_meta(&"priority", event.priority)
	voice.set_meta(&"started", now)
	voice.set_meta(&"scope", scope.get_instance_id())
	var on_exit: Callable = stop_scope.bind(scope.get_instance_id())
	if not scope.tree_exiting.is_connected(on_exit):
		scope.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	_last_played[key] = now
	voice.play()
	return true


func _release(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null
	player.set_meta(&"event", &"")


func stop_scope(scope_id: int) -> void:
	for player in players:
		if int(player.get_meta(&"scope", 0)) == scope_id:
			_release(player)


func stop_all() -> void:
	for player in players:
		_release(player)


# Opt-in binding at shared UI factories; no tree-wide scanning or generic event bus.
# Specialized controls can pass an empty confirm event to avoid duplicate action cues.
func bind_button(button: BaseButton, confirm: StringName = &"ui_confirm") -> void:
	if button.has_meta(&"sfx_bound"):
		return
	button.set_meta(&"sfx_bound", true)
	button.mouse_entered.connect(func():
		if not button.disabled: play_event(&"ui_select", button))
	button.focus_entered.connect(func():
		if not button.disabled: play_event(&"ui_select", button))
	if confirm != &"":
		button.pressed.connect(func():
			if not button.disabled: play_event(confirm, button))
