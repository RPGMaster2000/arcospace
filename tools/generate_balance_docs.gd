extends SceneTree
# Regenerate with: godot --headless --path . --script tools/generate_balance_docs.gd
const Rules = preload("res://encounters/expedition_rules.tres")
const Ships = preload("res://scripts/ship_library.gd")
const Cards = preload("res://scripts/card_library.gd")
const State = preload("res://scripts/expedition_state.gd")
const Mod = preload("res://scripts/combat_modifier.gd")
const Jump = preload("res://scripts/ftl_drive.gd")
const Board = preload("res://scripts/board.gd")
const Hand = preload("res://scripts/card_hand.gd")

func cell(value: Variant) -> String:
	return str(value).replace("|", " / ").replace("\n", " ")

func row(values: Array) -> String:
	var parts: Array[String] = []
	for value in values: parts.append(cell(value))
	return "| " + " | ".join(parts) + " |\n"

func source(resource: Resource) -> String:
	return "`" + resource.resource_path.trim_prefix("res://") + "`"

func write_doc(name: String, contents: String) -> void:
	var file = FileAccess.open("res://docs/balance/" + name + ".md", FileAccess.WRITE)
	file.store_string(contents)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/balance")
	var text: String = "# Ships\n\nGenerated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; F/R/H = Fabricator/Reactor/Hangar. Production identifiers: `synthesizer` / `reactor` / `quarters`.\n\n"
	text += "| Ship | Type / special attribute | Hull / Shields | M/E/C | F/R/H | Emergency Jump turns / resistance | Rank | FTL reward (defeat **or escape**) | Destruction Salvage | Generation weight | Edit |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
	var profiles: Array = Ships.PLAYERS.duplicate()
	profiles.append_array(Rules.enemy_ships)
	for ship in profiles:
		var player: bool = ship in Ships.PLAYERS
		text += row([ship.ship_name, ship.subtitle + ("; " + ship.summary if not ship.summary.is_empty() else ""), "%d / %d" % [ship.hull_capacity, ship.shields], "%d/%d/%d" % [ship.materials,ship.energy,ship.crew], "%d/%d/%d" % [ship.synthesizer,ship.reactor,ship.quarters], "%d / %s%%" % [ship.ftl_turns,ship.ftl_resistance * 100] if player else "Inactive (enemy has no jump mechanic)", "Player" if player else ["Standard","Elite","Boss"][ship.enemy_rank], "—" if player else ship.interstellar_ftl_reward, "—" if player else ship.destruction_salvage_reward, "—" if player else ship.encounter_weight, source(ship)])
	text += "\nEnemy profiles also serialize Emergency Jump defaults (14 turns, 0 resistance); these are unused. No rank-based hidden multipliers. Rank is a balancing label; stats and both rewards are independent fields.\n\n"
	text += "Escape: **0 Salvage**, full profile FTL reward once; enemy is completed and cannot be farmed. Resource victory: %d Salvage and full profile FTL reward. Victory repairs: %d Hull per Salvage, capped at capacity. Standalone combat destruction fallback: %d Salvage. Enemy registry and resource-victory Salvage: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.\n" % [Rules.resource_victory_salvage, Board.HULL_PER_SALVAGE, Board.DESTRUCTION_SALVAGE]
	write_doc("ships", text)
	text = "# Cards\n\nGenerated from `scripts/card_library.gd` and loaded CardData Resources. Edit each listed `.tres`; descriptions are presentation only, `effects` controls gameplay. Costs spend the listed family. Effects below are exact unmodified values.\n\n"
	text += "| Card | Family / cost | Rarity | Exact effects | Hull / Shields restored | Extra action | Upgrade reduction / maximum levels | Edit |\n|---|---|---|---|---|---|---|---|\n"
	for card in Cards.CARDS:
		text += row([card.card_name, "%s / %d" % [card.family,card.cost], ["Common","Uncommon","Rare"][card.tier-1], "`" + JSON.stringify(card.effects) + "`", "%d / %d" % [card.effects.get("hull",0),card.effects.get("shields",0)], card.play_again, "%d / %d" % [card.upgrade_cost_reduction,card.max_upgrades], source(card)])
	var hand = Hand.new()
	text += "\n## Draws and upgrades\n\nSix-card hands; maximum %d copies per identity and at most one card of each tier above Common. Tier 2 draw chance %s%%, locked through round %d; Tier 3 chance %s%%. Temporal Rift multiplies Tier 2 chance by %s. Missing eligible higher-tier bucket falls back to Common. Tune CardHand/EnemyHand in `scenes/board.tscn` or defaults in `scripts/card_hand.gd`.\n\n" % [hand.max_copies, hand.tier_two_chance * 100, hand.tier_two_locked_turns, hand.tier_three_chance * 100, Mod.TEMPORAL_DROP_MULTIPLIER]
	hand.free()
	text += "Acquisitions offer 3 distinct library cards (respecting the reward tier floor), choose exactly 1; add a weighted entry to both ships' shared expedition pool. Upgrades clone player identities only: cost decreases by the table amount per level, floor 1; effects unchanged. Enemy copies and library Resources are never changed. Fully exhausted upgrade candidates grant %d Salvage instead. Tune `CardData` fields / `ExpeditionRules.unavailable_upgrade_salvage`.\n\n" % Rules.unavailable_upgrade_salvage
	text += "## Effect keys (`scripts/card_effects.gd`)\n\n| Key | Resolution |\n|---|---|\n| `hull`, `shields`, resource or production key | Add to acting ship; excess Hull is Ablative Plating |\n| `damage`, `pierce` | Damage; floor(damage × pierce) bypasses Shields, remaining damage consumes Shields then Hull/plating |\n| `break_shields` | Remove specified enemy Shields before damage |\n| `drain`, `steal` | Remove available enemy resource (floor 0); steal adds the amount actually removed to actor |\n| `sabotage` | Lower every enemy production by amount; floor 1 |\n| `production_other` | Add specified production/resource only if corresponding resource differs from card family |\n| `random_gain` | Uniformly choose one of 3 resources and add amount |\n| `random_gain_other`, `random_gain_range_other` | Uniformly choose one of 2 other families; fixed amount or inclusive uniform integer range |\n| `swap_shields` | Exchange current Shield amounts |\n| `shield_collapse` | Remove all enemy Shields; at or above threshold, stated chance of regular self-damage |\n| `shield_collapse_below` | Remove all enemy Shields strictly below threshold |\n| `self_damage` / `self_damage_regular` | Direct Hull/plating loss / Shield-first damage |\n\nDiscard gives floor(cost / 3) matching resources (`scripts/board.gd`). Extra actions grant no turn income or Emergency Jump charge. **Planned, not implemented:** Tier 3 card library, deck trimming. Pirate rewards currently use Uncommon-or-better, the highest populated tier; no empty rare selection screen.\n"
	write_doc("cards", text)
	var state = State.new()
	text = "# Points of interest and generation\n\nGenerated from `encounters/expedition_rules.tres` and all referenced PoI Resources. Each completed PoI grants **+1 FTL Drive charge once**, in addition to rewards below. Extra FTL in a row adds to this base. All next-battle values apply once; Hull/Salvage and interstellar charge apply immediately.\n\n"
	text += "| Generation category | Min / max | Weight |\n|---|---|---|\n"
	text += row(["Ordinary", "%d / %d" % [Rules.minimum_ordinary, Rules.maximum_ordinary], Rules.ordinary_weight])
	text += row(["Hazardous", "%d / %d" % [Rules.minimum_hazardous, Rules.maximum_hazardous], Rules.hazardous_weight])
	text += row(["Enemy", "%d / %d" % [Rules.minimum_battles, Rules.maximum_battles], Rules.battle_weight])
	text += "\nTotal %d progression encounters plus an independently scheduled optional Trading Outpost; requirement = actual non-trading PoI count + 1. Service visits give zero charge and do not increase the requirement. Valid count combinations are sampled with weight ordinary_weight^ordinary × hazardous_weight^hazards × battle_weight^enemies. Each category samples Resources by encounter_weight without replacement until exhausted. At least 1 enemy; reward floor 1. Invalid bounds warn and fall back to one enemy plus available PoIs (all enemies if no PoIs). No hidden reduction in travel requirement. Tune counts/weights/registry in `encounters/expedition_rules.tres`; type weights in each PoI/ship Resource.\n\n" % Rules.encounters_per_system
	for category in ["Ordinary", "Hazardous", "Services"]:
		text += "## " + category + "\n\n"
		if category == "Services" and Rules.trading_outpost != null:
			state.rules = Rules
			state.service = {"poi":Rules.trading_outpost}
			var prices: Array[String] = []
			for bought in range(7):
				state.station_production_purchases = bought
				prices.append(str(state.service_cost(3)))
			text += "First station: system %d–%d; subsequent system-number intervals %d–%d, hard cap 3. The seeded station RNG is independent of encounter/loot RNG. Unlimited purchases and free revisits until departure, with no travel charge, requirement increase, penalties or survey. Pending paid choices must resolve before another purchase or departure. Each confirmation revision can spend once.\n\n" % [Rules.minimum_station_interval,Rules.maximum_station_interval,Rules.minimum_station_interval,Rules.maximum_station_interval]
			text += "Repairs select 0 through min(available Salvage, missing permanent Hull), cost 1 Salvage per Hull, and never create plating. Zero selection cannot confirm. The shared rate/limit rule is `scripts/repair_rules.gd`, also used by post-battle repairs. Supply/card base prices and shipyard base price are editable in `encounters/trading_outpost.tres` approach Salvage Cost; supply amount/production amount remain editable outcome Resources. Shipyard cost for purchase n: base + increment × (n−1) + acceleration × (n−1) × (n−2) / 2. Current increment %d, acceleration %d; prices %s. Counter combines all production categories and resets only when a later station appears; permanent upgrades persist. Intervals and escalation parameters: `ExpeditionRules` Inspector. The table shows initial prices; repair amount is variable.\n\n" % [Rules.production_price_increment,Rules.production_price_acceleration,", ".join(prices)]
		var locations: Array = [Rules.trading_outpost] if category == "Services" else Rules.pois
		for poi in locations:
			if poi == null: continue
			if category != "Services" and poi.hazardous != (category == "Hazardous"): continue
			text += "### %s\n\nEdit %s; expand Approaches → Success / Failure. Generation weight (ignored for service stations): %s. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.\n\n" % [poi.title,source(poi),poi.encounter_weight]
			text += "| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |\n|---|---|---|---|---|---|\n"
			for approach in poi.approaches:
				text += row([approach.title, "None" if approach.requirement.is_empty() else "%s ≥%d" % [State.LABELS[approach.requirement],approach.minimum_production], approach.salvage_cost, "%s%%" % (approach.success_chance*100), state.describe_outcome(approach.success), "Not rolled" if approach.success_chance >= 1 else "%s%%: %s" % [(1-approach.success_chance)*100,state.describe_outcome(approach.failure)]])
			text += "\n"
	text += "## Progression safeguard\n\nIf a PoI has no affordable, unlocked approach whose worst possible Hull outcome leaves Hull >0, **Navigation survey** becomes available. Completing the survey forfeits all normal loot and grants only that PoI's +1 charge, with guaranteed next-battle penalty `%s`. The independent Trading Outpost never needs or permits a survey. Entering and leaving it is free; only a confirmed purchase spends Salvage. Unlimited affordable services and free revisits while present; ignoring a station never blocks departure. Tune `ExpeditionRules.survey_penalty`. Full-Hull repairs are locked. Return leaves an uncompleted PoI untouched.\n\n" % JSON.stringify(Rules.survey_penalty)
	text += "All escaped enemies complete normally and award their full profile charge. Repeated result/approach calls cannot award more charge. Charge resets on entering the next system; unspent charge does not carry. Pending choices must be resolved before leaving. Hull 0 ends the expedition; voluntarily lethal approaches and battle losses remain possible. The simulation guarantees charge availability for surviving players, not victory against every enemy. **Not implemented:** hostile follow-up battles from pirate debris; current pirate hazards use Hull costs.\n"
	write_doc("pois", text)
	text = "# Battle modifiers\n\nGenerated numerical constants: `scripts/combat_modifier.gd`, `ftl_drive.gd`, `board.gd`, and expedition Resources. Serialized combat names (`FTLDrive`, `ftl_turns`, `ftl_resistance`) remain for scene compatibility; they mean **Emergency Jump**, not interstellar FTL Drive.\n\n"
	text += "| Modifier | Exact behavior / duration | Adjust |\n|---|---|---|\n"
	text += row(["PoI bonuses / penalties", "Bonuses and penalties add independently. Starting Materials/Energy/Crew = max(0, base + total positive - min(abs(total negative), floor(base * 0.5))). Positive bonuses have no PoI cap and never enlarge the penalty cap. Shields add with floor zero. Pending until next battle, then consumed once before normal income; repeated initialization cannot reapply. Emergency Jump charge adds, capped to ship target; offline uses longest individual duration. Travel and service visits do not consume modifiers. No temporary production effects.", "Outcome.next_battle; scripts/expedition_state.gd"])
	text += row(["Supported next-battle keys", "materials, energy, crew, shields, emergency_jump_charge, emergency_jump_offline (positive duration)", "encounters/*.tres → approaches → outcome"])
	text += row(["Hull / plating", "Hull persists capped to ship capacity between battles. Battle repairs above capacity become plating; damage consumes plating before permanent Hull. Plating clears between battles. PoI/victory repairs cannot create plating.", "ShipData.hull_capacity; card effects; board.gd"])
	text += row(["Shipyard production", "Chosen production upgrade adds permanently for expedition; station-local escalating purchase prices reset at the next station, without losing upgrades; only permanent base+upgrade production unlocks PoI approaches. Battle card production does not carry. PoIs never modify production.", "Trading Outpost outcome.production_choice"])
	text += row(["Tactical victory", "+%d each starting Materials/Energy/Crew next battle if finish Hull exceeds starting Hull (plating can qualify); escapes eligible; additive stacking" % Board.TACTICAL_RESOURCES, "board.gd: TACTICAL_RESOURCES"])
	text += row(["Strategic victory", "+%d starting Shields next battle if final total production exceeds enemy total; escapes eligible; additive stacking" % Board.STRATEGIC_SHIELDS, "board.gd: STRATEGIC_SHIELDS"])
	text += row(["Emergency Jump", "+1 charge each normal player turn, including first; extra actions give 0. Ship-specific target. Disabled turns give 0 charge and prevent escape; charge is retained.", "ships/*.tres: ftl_turns; ftl_drive.gd"])
	text += row(["Emergency Jump disruption", "Chance = clamp(min(permanent Hull damage × %s, %s) × (1 − ship resistance), 0, 1); disabled for %d full player turns. Shields/plating alone do not trigger. No new disruption while already offline." % [Jump.FAILURE_CHANCE_PER_DAMAGE,Jump.MAX_FAILURE_CHANCE,Jump.DISABLED_TURNS], "ftl_drive.gd constants; ShipData.ftl_resistance"])
	text += row(["Interstellar FTL Drive", "Required = non-trading PoI count + 1. Independent Trading Outpost: zero charge, zero requirement increase, no survey or departure cost. PoIs +1 plus optional extra; enemy defeat/escape gives profile reward once. Reset on system entry. Can leave at threshold without clearing rest.", "ship.interstellar_ftl_reward; outcome.extra_ftl_charge; expedition_state.gd"])
	text += row(["Event timing", "First event round 1 + random integer %d–%d; next event %d–%d rounds after previous ends; active events last %d full rounds. One random modifier (0–5, uniform) per generated enemy." % [Mod.MIN_INTERVAL,Mod.MAX_INTERVAL,Mod.MIN_INTERVAL,Mod.MAX_INTERVAL,Mod.ACTIVE_ROUNDS], "combat_modifier.gd; expedition_state.gd"])
	text += row(["Asteroid belt", "%s%% independent hit per ship, %d Shield-first damage; instant, repeats every %d–%d rounds" % [Mod.ASTEROID_CHANCE*100,Mod.ASTEROID_DAMAGE,Mod.MIN_INTERVAL,Mod.MAX_INTERVAL], "combat_modifier.gd: ASTEROID_*, *_INTERVAL"])
	text += row(["Ion storm", "50% ×2 / 50% ×0.5 Energy card effects for 3 rounds; half rounds down. Cost unchanged. Recursively scales numbers except pierce, shield_collapse_below, threshold, chance; legacy sabotage true counts as 1.", "combat_modifier.gd: begin_round, _scaled"])
	text += row(["Solar flare", "Shields unavailable for 3 rounds; stored Shields restored afterward. Shield gains and swapping ignored during flare.", "combat_modifier.gd: ACTIVE_ROUNDS, play"])
	text += row(["Nebula", "Initial miss %d%%; each later full round adds uniform integer −%d…+%d, clamped 0–%d%%. Miss cancels combat card effects except direct self_damage; card cost paid. Whole battle." % [Mod.NEBULA_START,Mod.NEBULA_STEP,Mod.NEBULA_STEP,Mod.NEBULA_MAX], "combat_modifier.gd: NEBULA_*; is_combat"])
	text += row(["Temporal Rift", "Tier 2 draw chance ×%s for entire battle (15%% → 30%%); early-round lock and hand caps remain." % Mod.TEMPORAL_DROP_MULTIPLIER, "combat_modifier.gd: TEMPORAL_DROP_MULTIPLIER; CardHand"])
	text += "\nResource victory requires each resource ≥100 by default (`Board.resource_goal`). Turn income equals current production. Expedition state is in memory only; restart/ship selection/app exit ends the run. **Planned, not implemented:** persistent save/load. No other expedition currency, travel spending, hidden rank multipliers, or permanent card-effect upgrades.\n"
	write_doc("battle_modifiers", text)
	print("Generated four balance references from current Resources and constants.")
	quit()
