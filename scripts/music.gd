extends Node
# One player survives scene transitions. Missing placeholder files stay silent.
signal enabled_changed(enabled: bool)
const TRACKS = {
	"starmap": "res://assets/sound/starmap.mp3",
	"battle1": "res://assets/sound/battle1.mp3",
	"battle2": "res://assets/sound/battle2.mp3",
	"victory": "res://assets/sound/victory.mp3"
}
const SETTINGS_PATH = "user://music.cfg"
var enabled: bool = true
var current_track: String = ""
var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -12.0
	add_child(player)
	player.finished.connect(_finished)
	var settings = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		enabled = bool(settings.get_value("music", "enabled", true))
	_apply_mute()

func play_starmap() -> void:
	play_track("starmap")

func play_battle() -> void:
	play_track("battle1" if randi_range(0, 1) == 0 else "battle2", true)

func play_result(won: bool) -> void:
	if won:
		play_track("victory", true)
	else:
		current_track = ""
		player.stop()

func play_track(track: String, restart: bool = false) -> void:
	if track == current_track and not restart:
		return
	current_track = track
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
		stream.loop = track != "victory"
	player.stream = stream
	player.play()
	_apply_mute()

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_apply_mute()
	var settings = ConfigFile.new()
	settings.set_value("music", "enabled", enabled)
	settings.save(SETTINGS_PATH)
	enabled_changed.emit(enabled)

func _apply_mute() -> void:
	if is_instance_valid(player):
		player.stream_paused = not enabled

func _finished() -> void:
	if current_track != "victory" and player.stream != null:
		player.play()
