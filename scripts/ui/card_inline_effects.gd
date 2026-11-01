extends RefCounted
## Presentation only: integrate colored symbols with existing mechanically authored descriptions.
## Keep identical typography for every card, including upgraded cards.

const Data = preload("res://scripts/cards/card_data.gd")

static func render(card: Resource) -> String:
	var source: String = card.description
	if source.is_empty():
		source = Data.describe_effects(card.effects)
		if card.play_again:
			source += "; Play again"
	source = source.replace("[", "［").replace("]", "］")
	var tokens: Array[Dictionary] = [
		{"word": "Materials", "glyph": "■", "color": "#ff8075"},
		{"word": "Energy", "glyph": "◆", "color": "#7cdbff"},
		{"word": "Crew", "glyph": "●", "color": "#98e79c"},
		{"word": "Shields", "glyph": "⬡", "color": "#8bd3ff"},
		{"word": "Hull", "glyph": "▰", "color": "#f2b49a"},
		{"word": "Synthesizer", "glyph": "⚙", "color": "#ff8075"},
		{"word": "Reactor", "glyph": "⚙", "color": "#7cdbff"},
		{"word": "Quarters", "glyph": "⚙", "color": "#98e79c"}
	]
	for entry in tokens:
		var pattern := RegEx.new()
		pattern.compile("(?i)\\b" + str(entry.word) + "\\b")
		source = pattern.sub(source, "[color=%s]%s[/color] %s" % [
			entry.color, entry.glyph, entry.word
		], true)
	return source
