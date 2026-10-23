extends RefCounted

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Share encounter glyphs, colors, fonts and control styling.
# Presentation only: replace glyphs here later without touching encounter logic.
const EMOJI_FONT = preload("res://assets/fonts/ArcospaceEmoji.ttf")
const UI_FONT = preload("res://assets/fonts/emoji_ui.tres")
const ICONS = {
	"mining_operation": ["⛏️", "MINE"],
	"gas_giant": ["🪐", "GAS"],
	"derelict_starship": ["🚀", "WRECK"],
	"research_station": ["🛰️", "LAB"],
	"trading_outpost": ["⚖", "TRADE"],
	"spatial_anomaly": ["✨", "RIFT"],
	"radiation_nebula": ["☢️", "RAD"],
	"distress_signal": ["📡", "SOS"],
	"pirate_debris_field": ["☠️", "DEBRIS"],
	"unstable_wormhole": ["🌀", "RIFT"],
	"quarantined_colony": ["⚕️", "COLONY"],
	"battle": ["🚀", "COMBAT"],
	"synthesizer": ["🛠️", "SYNTH"],
	"reactor": ["⚡", "REACTOR"],
	"quarters": ["👥", "QUARTERS"],
	"approach": ["🔎", "SCAN"],
	"card": ["🃏", "CARD"],
	"automated": ["⚙️", "AUTO"],
	"industrial": ["🏭", "INDUSTRY"],
	"deep_mining": ["💎", "CORE"],
	"elite": ["⚔️", "ELITE"],
	"boss": ["⚔️", "BOSS"],
	"hull": ["❤️", "HULL"],
	"shields": ["🛡️", "SHIELDS"],
	"salvage": ["🪨", "SALVAGE"],
	"materials": ["🛠️", "MATERIALS"],
	"energy": ["⚡", "ENERGY"],
	"crew": ["👥", "CREW"],
	"travel": ["🌌", "FTL"],
	"jump": ["⚡", "EMP"],
	"hazard": ["⚠️", "HAZARD"]
}
const MEANINGS = {
	"hull": "Hull — permanent damage persists; excess Hull is temporary Ablative Plating.",
	"shields": "Shields — temporary protection, reset between battles.",
	"salvage": "Salvage — persistent expedition currency for repairs and services.",
	"materials": "Materials — combat resource produced by Synthesizer.",
	"energy": "Energy — combat resource produced by Reactor.",
	"crew": "Crew — combat resource produced by Quarters.",
	"synthesizer": "Synthesizer — Materials gained each player turn.",
	"reactor": "Reactor — Energy gained each player turn.",
	"quarters": "Quarters — Crew gained each player turn.",
	"travel": "FTL Drive — interstellar charge; resets on entering a new system.",
	"jump": "EMP Pulse — combat escape charge, separate from interstellar travel.",
	"hazard": "Hazard / modifier — tap to inspect conditions and effects.",
	"card": "Cards - acquired cards join your expedition pool; enemies keep the base library."
}


static func meaning(key: String) -> String:
	return MEANINGS.get(key, key.replace("_", " ").capitalize())


static func modifier_key(kind: int) -> String:
	return [
		"approach", "mining_operation", "energy", "hazard", "radiation_nebula", "spatial_anomaly"
	][clampi(kind, 0, 5)]


const COLORS = {
	"ordinary": Color("5d9c7b"),
	"hazard": Color("d69b58"),
	"battle": Color("ce7777"),
	"special": Color("6aa7d7")
}


static func icon(key: String, font: Font, text_only: bool = false) -> String:
	var entry: Array = ICONS.get(key, ICONS.approach)
	if (
		not text_only
		and (
			EMOJI_FONT.has_char(str(entry[0]).unicode_at(0))
			or font.has_char(str(entry[0]).unicode_at(0))
		)
	):
		return entry[0]
	return "[" + str(entry[1]) + "]"


static func approach_key(poi: Resource, slot: int) -> String:
	if poi_key(poi) == "mining_operation" and slot < 4:
		return ["mining_operation", "automated", "industrial", "deep_mining"][slot]
	var requirement: String = poi.approaches[slot].requirement
	return requirement if not requirement.is_empty() else poi_key(poi)


static func classification(encounter: Dictionary) -> String:
	if encounter.kind == "battle":
		return "battle"
	if encounter.poi.hazardous:
		return "hazard"
	return "special" if encounter.poi.anomalous_presentation else "ordinary"


static func poi_key(poi: Resource) -> String:
	return poi.resource_path.get_file().get_basename()


static func style(accent: Color, selected: bool = false, muted: bool = false) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color("263e55") if selected else Color("192b3c")
	box.border_color = accent if not muted else Color("394653")
	if muted:
		box.bg_color = Color("182330")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func action(button: Button, primary: bool = false) -> void:
	if not Engine.is_editor_hint():
		Sound.bind_ui(button)
	var focus = style(COLORS.special, true)
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("98c6ef")
	button.add_theme_stylebox_override("focus", focus)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var box = style(COLORS.special, key == "pressed", key == "disabled")
		if primary and key != "disabled":
			box.bg_color = Color("e8f1f7")
		button.add_theme_stylebox_override(key, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color("172b3b") if primary else Color("e3edf6"))
	button.add_theme_color_override("font_disabled_color", Color("a7b8c9"))
