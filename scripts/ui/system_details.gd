extends RefCounted
## Read-only presentation from authoritative encounter/Defense ledgers. No retained state.
const Variation = preload("res://scripts/expedition/system_variation.gd")
const Warfare = preload("res://scripts/expedition/defense_warfare.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")


static func active_enemies(state: Resource) -> Array:
	var result: Array = []
	var faction: Resource = Factions.find(state.rules, state.faction_id)
	for unit in state.defense.units:
		if not state.defense.available(unit) or state.encounters[unit.encounter].completed:
			continue
		var profile: Resource = state.enemy_profile(state.encounters[unit.encounter])
		var deployment: Dictionary = state.defense.deployment(unit)
		result.append(
			{
				"index": unit.encounter,
				"name": profile.ship_name,
				"faction": faction.display_name if faction != null else "Unassigned",
				"class": Warfare.ROLES[deployment.role][0] if not deployment.is_empty() else ("Mothership" if unit.mothership else profile.strategic_class),
				"role_details": contact_details(state, unit, profile),
				"status":
				(
					"Advancing"
					if unit.mothership and state.defense.mothership_advancing
					else "Deployed"
				),
				"speed": state.defense._speed(unit),
				"relative_speed":
				state.defense._speed(unit) / maxf(0.001, state.defense.tuning.enemy_speed),
				"arrival_damage": state.defense.arrival_damage(unit),
				"mothership": unit.mothership
			}
		)
	return result


static func contact_details(state: Resource, unit: Dictionary, profile: Resource) -> String:
	if unit.is_empty(): return ""
	var deployment: Dictionary = state.defense.deployment(unit)
	if deployment.is_empty(): return ""
	var label: Array = Warfare.ROLES[deployment.role]
	var rank: String = ["Standard", "Elite", "Boss"][profile.enemy_rank]
	var speed: float = state.defense._speed(unit)
	var target: Vector3 = state.defense.target_for(unit)
	var objective := "Tactical Decoy" if target != state.defense.home else "Homeworld"
	var motion := "Holding position" if speed == 0.0 else "%.2f u/s · %s in %.1fs" % [
		speed, objective, unit.position.distance_to(target) / speed]
	return "%s · %s · %s\n%s" % [label[0], rank, motion, label[4]]


static func text(state: Resource) -> String:
	var faction: Resource = Factions.find(state.rules, state.faction_id)
	var enemies := active_enemies(state)
	var rows: Array[String] = [
		"[b]SYSTEM DETAILS — STARFRONT %d[/b]" % state.system_number,
		"Faction: %s" % [faction.display_name if faction != null else "Unassigned (legacy system)"],
		"",
		"[b]ACTIVE ENEMY FORCES · %d[/b]" % enemies.size()
	]
	var geography: Dictionary = state.system_variation
	if geography.get("version") == 2:
		rows.insert(2, "%s · %s · %s" % [Variation.system_title(geography),
			Variation.SIZE_CLASSES[int(geography.size_class)], Variation.HOME_REGIONS[int(geography.home_region)]])
		rows.insert(3, "%s%s · %s intensity" % [Variation.STARS[int(geography.star)][0],
			"" if geography.companion.is_empty() else " + companion", ["Low", "Moderate", "High"][int(geography.intensity)]])
	if not state.defense.military.is_empty():
		var formation: String = state.defense.military.formation
		var position := 4 if geography.get("version") == 2 else 2
		rows.insert(position, Warfare.describe(formation))
		rows.insert(position + 1, Warfare.brief(formation))
	if enemies.is_empty():
		rows.append("No deployed enemy vessels.")
	for enemy in enemies:
		rows.append("[b]%s[/b] · %s · %s" % [enemy.name, enemy["class"], enemy.status])
		var movement := (
			"Stationary"
			if enemy.speed == 0
			else "%.0f%% standard speed" % (enemy.relative_speed * 100)
		)
		var arrival := (
			"Expedition-ending arrival"
			if enemy.mothership
			else "%d homeworld damage" % enemy.arrival_damage
		)
		rows.append("%s · %s · %s" % [enemy.faction, movement, arrival])
		if not enemy.role_details.is_empty(): rows.append(enemy.role_details)
	rows.append_array(["", "[b]BATTLE MODIFIERS — TEMPORARY[/b]"])
	var temporary: Array[String] = []
	for bonuses in [state.pending_bonuses, state.pending_penalties]:
		var description: String = state.describe_modifiers(bonuses)
		if not description.is_empty():
			temporary.append("Next battle: " + description)
	var effects: String = state.poi_effects.summary()
	for category in state.PRODUCTION:
		effects = effects.replace(category + " production", state.LABELS[category] + " production")
	if not effects.is_empty():
		temporary.append(effects)
	if (
		not state.poi_effects.mothership.is_empty()
		or state.poi_effects.pause > 0
		or state.poi_effects.reduction > 0
		or state.poi_effects.extraction_source >= 0
	):
		temporary.append("Research, Pressure and extraction effects expire on system departure.")
	for enemy in enemies:
		# Location preview only. Never assign or replace the frozen battle-entry snapshot.
		var environment: Dictionary = state.battle_environment(enemy.index)
		var modifier: int = EnvironmentData.modifier_id(environment)
		if not environment.get("friendly_support", {}).is_empty():
			var support: Dictionary = environment.friendly_support
			temporary.append(
				(
					"%s: Kinetic Turret support — %d damage every %d rounds"
					% [enemy.name, support.damage, support.interval]
				)
			)
		if modifier != 0:
			temporary.append(
				(
					"%s: %s — at current location; fixed on battle entry"
					% [enemy.name, Modifiers.NAMES[modifier]]
				)
			)
	rows.append("\n".join(temporary) if not temporary.is_empty() else "None")
	rows.append_array(["", "[b]PERSISTENT — ACQUIRED UPGRADES[/b]"])
	var upgrades: Array[String] = []
	for category in state.PRODUCTION:
		var amount: int = state.production_upgrades.get(category, 0)
		if amount > 0:
			upgrades.append("%s +%d" % [state.LABELS[category], amount])
	var card_upgrades: Dictionary = state.upgraded_cards
	for card in state.player_pool():
		var level: int = card_upgrades.get(card.identity_key(), 0)
		if level > 0:
			upgrades.append("%s · upgrade %d" % [card.card_name, level])
	rows.append(
		(
			"\n".join(upgrades)
			if not upgrades.is_empty()
			else "None (ship baseline production excluded)"
		)
	)
	var boss := (
		"Neutralized — system liberated"
		if state.defense.complete
		else ("Destroyed — clear remaining forces" if state.defense.mothership_destroyed() else (
			"Advancing"
			if state.defense.mothership_advancing
			else ("Revealed" if state.defense.revealed else "Unrevealed")
		))
	)
	rows.append_array(
		[
			"",
			"[b]DEFENSE[/b]",
			(
				"Homeworld: %d/%d · Turrets deployed: %d"
				% [
					state.defense.integrity,
					state.defense.tuning.base_integrity,
					state.defense.turrets.size()
				]
			),
			(
				"Pressure: %.0f%% · Mothership: %s"
				% [
					100 * state.defense.pressure / maxf(1, state.defense.tuning.pressure_maximum),
					boss
				]
			),
			"Missiles in flight: %d" % state.defense.missiles.active.size()
		]
	)
	return "\n".join(rows)
