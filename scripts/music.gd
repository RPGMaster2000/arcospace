extends Node

# RESPONSIBILITY: Keep one music player across screens and coordinate track transitions and muting.
# One player survives scene transitions; every track starts at its beginning.
signal enabled_changed(enabled: bool)
const TRACKS = {
	"starsystem": "res://assets/sound/starsystem.mp3",
	"battle1": "res://assets/sound/battle1.mp3",
	"battle2": "res://assets/sound/battle2.mp3",
	"battle3": "res://assets/sound/battle3.mp3",
	"victory_normal": "res://assets/sound/victory_normal.mp3",
	"victory_special": "res://assets/sound/victory_special.mp3",
	"shipselect": "res://assets/sound/shipselect.mp3",
	"title": "res://assets/sound/title.mp3"
}
const BATTLE_TRACKS = ["battle1", "battle2", "battle3"]
const BASE_VOLUME_DB: float = -12.0
var fade_tween: Tween
const SETTINGS_PATH = preload("res://scripts/ui/menu_preferences.gd").PATH
var enabled: bool = true
var volume: float = 1.0
var current_track: String = ""
var player: AudioStreamPlayer


func _ready() -> void:
	# Settings pause gameplay; audio must remain controllable and audible while open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.volume_db = BASE_VOLUME_DB
	player.bus = &"Music"
	add_child(player)
	player.finished.connect(_finished)
	var settings = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		enabled = bool(settings.get_value("music", "enabled", true))
	set_volume(float(settings.get_value("music", "volume", 1.0)), false)
	_apply_mute()


func play_starmap() -> void:
	play_track("starsystem")


func play_battle() -> void:
	play_track(BATTLE_TRACKS[randi_range(0, BATTLE_TRACKS.size() - 1)], true)


func play_title() -> void:
	play_track("title")


func play_ship_selection() -> void:
	play_track("shipselect")


func fade_title(seconds: float) -> void:
	if current_track != "title": return
	_cancel_fade()
	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -80.0, maxf(seconds, 0.001))
	fade_tween.tween_callback(func():
		player.stop()
		current_track = ""
		player.volume_db = BASE_VOLUME_DB
		fade_tween = null)


func _cancel_fade() -> void:
	if fade_tween != null:
		fade_tween.kill()
		fade_tween = null
	player.volume_db = BASE_VOLUME_DB


func play_result(won: bool, enemy_rank: int = 0) -> void:
	if won:
		play_track("victory_normal" if enemy_rank == 0 else "victory_special")
	else:
		_cancel_fade()
		current_track = ""
		player.stop()


func play_track(track: String, restart: bool = false) -> void:
	if track == current_track and not restart:
		return
	_cancel_fade()
	current_track = track
	player.volume_db = BASE_VOLUME_DB + linear_to_db(1.5) if track == "starsystem" else BASE_VOLUME_DB
	player.stop()
	player.stream = null
	var path: String = TRACKS.get(track, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var source = load(path) as AudioStream
	if source == null:
		return
	# Duplicate before setting loop: never mutate the imported resource.
	var stream = source.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = not track.begins_with("victory_")
		stream.loop_offset = 0.0
	player.stream = stream
	player.play(0.0)
	_apply_mute()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_apply_mute()
	var settings = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("music", "enabled", enabled)
	settings.save(SETTINGS_PATH)
	enabled_changed.emit(enabled)


# Bus gain preserves track-specific gain and cinematic fades on the existing player.
func set_volume(value: float, persist: bool = true) -> void:
	volume = clampf(value, 0.0, 1.0)
	var bus: int = AudioServer.get_bus_index(&"Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(bus, volume <= 0.0)
	if persist:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("music", "volume", volume)
		if settings.save(SETTINGS_PATH) != OK:
			push_warning("Could not save Music Volume")


func _apply_mute() -> void:
	if is_instance_valid(player):
		player.stream_paused = not enabled


func _finished() -> void:
	if not current_track.is_empty() and not current_track.begins_with("victory_") and player.stream != null:
		player.play()
