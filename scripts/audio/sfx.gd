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
var _ui_confirm_frame: int = -10


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
			if (
				victim == null
				or int(player.get_meta(&"priority")) < int(victim.get_meta(&"priority"))
				or (
					int(player.get_meta(&"priority")) == int(victim.get_meta(&"priority"))
					and float(player.get_meta(&"started")) < float(victim.get_meta(&"started"))
				)
			):
				victim = player
	if count >= event.concurrency_limit:
		return false
	var voice: AudioStreamPlayer = free_voice if free_voice != null else victim
	if voice == null:
		return false
	voice.stop()
	# A lightweight stream duplicate shares PCM data until modified. Force imported
	# WAV/OGG/MP3 replacements to one-shot without mutating the catalog resource.
	var stream: AudioStream = streams[_rng.randi_range(0, streams.size() - 1)].duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	voice.stream = stream
	voice.volume_db = event.volume_db
	voice.pitch_scale = event.pitch_scale * (1.0 + _rng.randf_range(-event.pitch_variation, event.pitch_variation))
	voice.set_meta(&"event", event_id)
	voice.set_meta(&"priority", event.priority)
	voice.set_meta(&"started", now)
	voice.set_meta(&"frame", Engine.get_process_frames())
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
func bind_button(button: BaseButton) -> void:
	if button.has_meta(&"sfx_bound"):
		return
	button.set_meta(&"sfx_bound", true)
	# Hover is silent. Defer keyboard/controller focus until the pointer press and
	# its confirmation have been handled, so clicking cannot also sound navigation.
	button.focus_entered.connect(func(): _focus_ui.call_deferred(weakref(button)))
	# pressed already passed the input/disabled guard; an action may disable its button.
	button.pressed.connect(func(): _queue_confirm(button))


func _queue_confirm(button: BaseButton) -> void:
	_ui_confirm_frame = Engine.get_process_frames()
	var screen: Node = button.get_tree().current_scene
	var scope: Node = screen if is_instance_valid(screen) else button
	# Wait until every pressed callback has supplied its more specific action cue.
	_confirm_ui.call_deferred(weakref(scope), _ui_confirm_frame)


func _confirm_ui(scope_ref: WeakRef, input_frame: int) -> void:
	var scope: Node = scope_ref.get_ref() as Node
	if not is_instance_valid(scope): return
	for player in players:
		if (
			player.playing
			and int(player.get_meta(&"frame", -1)) == input_frame
			and int(player.get_meta(&"priority", 0)) > 0
		):
			return
	play_event(&"ui_confirm", scope)


func _focus_ui(button_ref: WeakRef) -> void:
	var button: BaseButton = button_ref.get_ref() as BaseButton
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if button.disabled or not button.has_focus() or button.is_hovered() or button.button_pressed:
		return
	if Engine.get_process_frames() <= _ui_confirm_frame + 1:
		return
	_play_ui(&"ui_select", button)


func _play_ui(event_id: StringName, button: BaseButton) -> void:
	if not button.is_inside_tree():
		return
	# A rebuilt panel must not cut off its confirmation; the screen owns UI tails.
	var screen: Node = button.get_tree().current_scene
	play_event(event_id, screen if is_instance_valid(screen) else button)


# Explicit gateway also works when SceneTree regression scripts preload presentation code
# before autoload names are registered. No gameplay state or file paths cross this boundary.
static func play(event_id: StringName, scope: Node) -> bool:
	if not is_instance_valid(scope) or not scope.is_inside_tree():
		return false
	var service: Node = scope.get_node_or_null("/root/Sfx")
	return service.play_event(event_id, scope) if service != null else false


static func bind_ui(button: BaseButton) -> void:
	var bind := func():
		var service: Node = button.get_node_or_null("/root/Sfx")
		if service != null:
			service.bind_button(button)
	if button.is_node_ready():
		bind.call()
	else:
		button.ready.connect(bind, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	stop_all()
