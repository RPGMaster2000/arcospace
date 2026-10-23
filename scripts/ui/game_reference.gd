extends RefCounted
# RESPONSIBILITY: One source of player-facing reference content, shared by contextual entry points.
const Modifier = preload("res://scripts/combat_modifier.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")

static func sections(font: Font) -> Dictionary:
	var result: Dictionary = {
		"resources": ["Resources and Production", "Materials, Energy and Crew pay for their matching card families. Synthesizer makes Materials, Reactor makes Energy, and Quarters makes Crew at the start of your own turn. Restoring production keeps future turns supplied."],
		"defenses": ["Hull and Shields", "Shields absorb ordinary damage before Hull. Piercing damage bypasses some or all Shields; self-damage can hit Hull directly. Repair restores Hull, while Shield restoration rebuilds your protective reserve."],
		"emp": ["EMP Pulse", "EMP charges at the start of your turns until the ship's charge target is reached. When fully charged and online on your turn, EMP Pulse lets you escape and win the encounter. Permanent Hull damage can disrupt the drive for five of your turns; Shield damage cannot."],
		"failure": ["Systems Failure", "Two or more production systems at zero start a three-own-turn countdown. Opponent turns do not consume your recovery time, and an activation during your own turn spares that turn. Restore enough production so fewer than two systems remain disabled before the countdown expires, or lose the battle."],
		"cards": ["Cards and Upgrades", "A card's family determines which reserve pays its printed cost. Ordinary play ends your action; cards marked play again give another action without another turn's income or EMP charge. Discard returns one third of the printed cost, rounded down, in its family resource. Upgrades strengthen your owned cards without changing their cost; inspect to compare the base card and both upgrade levels."],
		"preview": ["Tactical Preview", "Hold a combat card to raise it without playing it. Tap INSPECT for full effects and upgrades; tap outside or press Cancel to lower it. On desktop, I previews a focused card and inspects a raised card; middle-click inspects directly, and right-click discards. Controller Y previews a focused card and INSPECT remains available through focus navigation.\n\n+ cyan/green: gain or repair · − red-orange: loss or damage · ? amber: possible or random effect · $ neutral: payment; $! means unaffordable. Unaffordable cards can still be previewed and inspected. Highlights identify affected systems, not guaranteed final values."],
		"allocation": ["Power Allocation", "Balanced keeps normal draw preferences. Offense, Defense and Systems favor matching cards among future eligible draws. Allocation does not change card costs or effects, replace your current hand, or bypass rarity and early-round limits."],
		"effects": ["Card Effect Terminology", "Piercing bypasses Shields. Sabotage reduces production, while drain removes stored resources and stealing transfers them to you. Swaps exchange the named reserves; conditional effects use the current situation to select a branch. Random effects choose at resolution, so a preview marks every possible target with ?. Shield breaking happens before ordinary damage."],
	}
	var modifiers: PackedStringArray = []
	for kind in range(Modifier.NAMES.size()):
		modifiers.append("[b]%s[/b]\n%s" % ["Standard / None" if kind == 0 else Modifier.NAMES[kind], Modifier.description(kind)])
	result["modifiers"] = ["Battlefield Modifiers", "\n\n".join(modifiers)]
	var icons: PackedStringArray = []
	var keys: Array = Style.MEANINGS.keys()
	for key in Style.ICONS:
		if key not in keys: keys.append(key)
	for key in keys: icons.append(Style.icon(key, font) + "  " + Style.meaning(key))
	result["icons"] = ["Icon Legend", "\n".join(icons)]
	return result

static func text(font: Font, section: String = "") -> String:
	var content: Dictionary = sections(font)
	var order: Array = content.keys()
	if content.has(section):
		order.erase(section)
		order.push_front(section)
	var links: PackedStringArray = []
	for key in content: links.append("[url=%s]%s[/url]" % [key, content[key][0]])
	var lines: PackedStringArray = ["[font_size=28][b]GAME REFERENCE[/b][/font_size]", " · ".join(links)]
	for key in order: lines.append("[font_size=25][b]%s[/b][/font_size]\n%s" % [content[key][0], content[key][1]])
	return "\n\n".join(lines)
