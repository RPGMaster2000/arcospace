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


# Shared presentation notification, without an autoload or save-game fields.
class Events extends RefCounted:
	signal battle_vfx_changed(enabled: bool)
	signal ui_motion_changed(profile: int)
static var events := Events.new()


static func battle_vfx() -> bool:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return bool(settings.get_value("presentation", "battle_vfx", true))


static func set_battle_vfx(enabled: bool) -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("presentation", "battle_vfx", enabled)
	var error: Error = settings.save(PATH)
	if error == OK:
		events.battle_vfx_changed.emit(enabled)
	return error


static func strategic_time_overview() -> bool:
	var settings := ConfigFile.new()
	settings.load(PATH)
	return bool(settings.get_value("presentation", "strategic_time_overview", true))


static func set_strategic_time_overview(enabled: bool) -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("presentation", "strategic_time_overview", enabled)
	return settings.save(PATH)


static var _ui_motion := -1


static func ui_motion() -> int:
	if _ui_motion < 0:
		var settings := ConfigFile.new()
		settings.load(PATH)
		_ui_motion = clampi(int(settings.get_value("presentation", "ui_motion", 1)), 0, 2)
	return _ui_motion


static func set_ui_motion(profile: int) -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("presentation", "ui_motion", clampi(profile, 0, 2))
	var result := settings.save(PATH)
	if result == OK:
		_ui_motion = clampi(profile, 0, 2)
		events.ui_motion_changed.emit(_ui_motion)
	return result
