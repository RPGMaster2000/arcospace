extends RefCounted
# Beginner-first walkthrough. Keys remain stable for contextual help links.
const Modifier = preload("res://scripts/combat_modifier.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")

const ORDER = [
	"start", "map", "battle", "resources", "cards", "defenses",
	"victory", "rewards", "emp", "failure", "preview", "allocation",
	"effects", "modifiers", "icons"
]

static func sections(font: Font) -> Dictionary:
	var hull: String = Style.icon("hull", font)
	var shields: String = Style.icon("shields", font)
	var materials: String = Style.icon("materials", font)
	var energy: String = Style.icon("energy", font)
	var crew: String = Style.icon("crew", font)
	var salvage: String = Style.icon("salvage", font)
	var result: Dictionary = {
		"start": ["1. Choose your ship",
			"Each ship starts with different strengths, supplies and a unique card. Pick one and begin an expedition. Tap its card to see what it does."],
		"map": ["2. Explore the star system",
			"Choose a destination on the 3D map and fly there. You can visit places for supplies, repairs or rewards, or meet hostile ships. Some destinations offer different ways to approach them. Read the choices before continuing.\n\nIn defense missions, enemy ships move while your ship travels. Stopping to plan or entering an encounter pauses that movement."],
		"battle": ["3. Take turns playing cards",
			"Battles are turn-based. On your turn, choose a card from your hand. Its cost is shown on the card, and playing it uses the matching resource. Cards can attack, repair, protect or improve your supplies. After your action, the enemy gets a turn.\n\nYou can discard a card instead of playing it to recover one third of its cost, rounded down. Cards marked Play again give another action immediately."],
		"resources": ["4. Keep your supplies coming",
			"%s [color=#ef9da8]Materials[/color] pay for red cards.\n%s [color=#8fc5ff]Energy[/color] pays for blue cards.\n%s [color=#98ddb0]Crew[/color] pays for green cards.\n\nEach has a production system: Synthesizer makes Materials, Reactor makes Energy, and Quarters makes Crew at the start of your turns. Cards can improve these systems, giving you more to spend later." % [materials, energy, crew]],
		"defenses": ["5. Protect your ship",
			"%s Shields take most incoming damage first. Restore them with defensive cards.\n%s Hull is your ship's health. When Shields run out, ordinary damage hits Hull. Some attacks go directly through Shields. If your Hull reaches zero, you lose the fight.\n\nHull damage can carry into later encounters. Repair when you have the chance." % [shields, hull]],
		"victory": ["6. Win the encounter",
			"Reduce the enemy's Hull to zero to win. You can also win by reaching the battle's tower or resource victory targets, or by escaping with a fully charged EMP Pulse when available. Watch the enemy's Shields and Hull as you attack."],
		"rewards": ["7. Improve your ship and move on",
			"After encounters, you may gain cards, upgrade cards or collect rewards. Choose upgrades that help your ship's strengths. %s Salvage is kept between battles and can pay for repairs and services.\n\nFinish the current system's objective to unlock faster-than-light (FTL) travel to the next system. Then explore, fight and upgrade again." % salvage],
		"emp": ["EMP Pulse: an alternative way out",
			"Your EMP Pulse charges at the start of your turns. When it is ready and online, activate it on your turn to escape and win the encounter. Hull damage can temporarily disable it; damaged Shields alone cannot. EMP Pulse is separate from FTL travel between star systems."],
		"failure": ["If production breaks down",
			"If two or more of your production systems reach zero, a three-turn warning begins. Restore enough production before it runs out or you lose. Only your own turns count down."],
		"preview": ["Look before you play",
			"Hold a card to preview it without using it. Choose INSPECT for full details and upgraded versions. You can inspect cards you cannot afford. On desktop, right-click discards a card; on touchscreens, use the card controls."],
		"allocation": ["Choose which cards you draw",
			"Power Allocation lets you favor Attack, Defense or Systems cards in future draws. Balanced leaves your preferences even. This changes draw chances, not the cards you already hold or what they cost."],
		"effects": ["Useful card words",
			"Damage normally hits Shields first. Hull damage bypasses Shields. Drain removes enemy supplies; Steal takes them for you. Sabotage lowers enemy production. Swap exchanges the named supplies. If means an effect depends on the current situation."],
		"modifiers": ["Battlefield conditions",
			"Some battles have a special condition that affects both ships. Check the condition shown before choosing your cards. You can tap it for details."],
	}
	var icon_lines: PackedStringArray = []
	for key in ["hull", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters", "salvage", "travel", "jump"]:
		icon_lines.append(Style.icon(key, font) + "  " + Style.meaning(key))
	result["icons"] = ["Icon Legend", "\n".join(icon_lines)]
	return result

static func text(font: Font, section: String = "") -> String:
	var content: Dictionary = sections(font)
	var order: Array = ORDER.duplicate()
	if content.has(section):
		order.erase(section)
		order.push_front(section)
	var links: PackedStringArray = []
	for key in ORDER:
		links.append("[url=%s]%s[/url]" % [key, content[key][0]])
	var lines: PackedStringArray = [
		"[font_size=28][b]GAME REFERENCE[/b][/font_size]",
		"Start here: choose a ship, explore, play cards, and improve your ship.",
		" · ".join(links)
	]
	for key in order:
		lines.append("[font_size=25][b]%s[/b][/font_size]\n%s" % [content[key][0], content[key][1]])
	return "\n\n".join(lines)
