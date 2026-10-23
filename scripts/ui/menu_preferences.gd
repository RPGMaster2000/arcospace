extends RefCounted
# RESPONSIBILITY: Persist cinematic preference alongside the existing audio preference.
const PATH: String = "user://music.cfg"


static func skip_cinematics() -> bool:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return bool(settings.get_value("presentation", "skip_cinematics", false))


static func set_skip_cinematics(enabled: bool) -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("presentation", "skip_cinematics", enabled)
	return settings.save(PATH)


static func preview_hint_seen() -> bool:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return bool(settings.get_value("presentation", "preview_hint_seen", false))


static func mark_preview_hint_seen() -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("presentation", "preview_hint_seen", true)
	return settings.save(PATH)
