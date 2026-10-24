extends SceneTree
# Regenerate with: godot --headless --path . --script tools/generate_balance_docs.gd
const Rules = preload("res://encounters/expedition_rules.tres")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const State = preload("res://scripts/expedition_state.gd")
const Mod = preload("res://scripts/combat_modifier.gd")
const Jump = preload("res://scripts/ftl_drive.gd")
const Board = preload("res://scripts/board.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")


func cell(value: Variant) -> String:
	return str(value).replace("|", " / ").replace("\n", " ")


func row(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(cell(value))
	return "| " + " | ".join(parts) + " |\n"


func source(resource: Resource) -> String:
	return "`" + resource.resource_path.trim_prefix("res://") + "`"


func write_doc(name: String, contents: String) -> void:
	if "--cards-only" in OS.get_cmdline_user_args() and name != "cards":
		return
	var file = FileAccess.open("res://docs/balance/" + name + ".md", FileAccess.WRITE)
	file.store_string(contents)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/balance")
	var text: String = "# Ships\n\nGenerated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; S/R/Q = Synthesizer/Reactor/Quarters. Production identifiers: `synthesizer` / `reactor` / `quarters`.\n\n"
	text += "| Ship | Type / special attribute | Hull / Shields | M/E/C | S/R/Q | EMP Pulse turns / resistance | Rank | FTL reward (defeat **or escape**) | Destruction Salvage | Generation weight | Edit |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
	var profiles: Array = Ships.PLAYERS.duplicate()
	profiles.append_array(Rules.enemy_ships)
	for ship in profiles:
		var player: bool = ship in Ships.PLAYERS
		text += row(
			[
				ship.ship_name,
				ship.subtitle + ("; " + ship.summary if not ship.summary.is_empty() else ""),
				"%d / %d" % [ship.hull_capacity, ship.shields],
				"%d/%d/%d" % [ship.materials, ship.energy, ship.crew],
				"%d/%d/%d" % [ship.synthesizer, ship.reactor, ship.quarters],
				(
					"%d / %s%%" % [ship.ftl_turns, ship.ftl_resistance * 100]
					if player
					else "Inactive (enemy has no jump mechanic)"
				),
				"Player" if player else ["Standard", "Elite", "Boss"][ship.enemy_rank],
				"—" if player else ship.interstellar_ftl_reward,
				(
					"—"
					if player
					else (
						ship.destruction_salvage_reward
						* (Rules.elite_salvage_multiplier if ship.enemy_rank == 1 else 1)
					)
				),
				"—" if player else ship.encounter_weight,
				source(ship)
			]
		)
	text += "\nEnemy profiles also serialize EMP Pulse defaults (14 turns, 0 resistance); these are unused. Elite Salvage rewards use the explicit `ExpeditionRules.elite_salvage_multiplier` (default 2); the table shows effective destruction rewards. Other ranks retain their profile rewards.\n\n"
	text += (
		"Escape: **0 Salvage**, full profile FTL reward once; enemy is completed and cannot be farmed. Systems Failure uses the same Salvage and FTL rewards as destruction. Elite victories additionally grant +%d Materials, Energy and Crew for the next battle, stacking with tactical rewards; escapes grant no Elite bonus. Tune `elite_salvage_multiplier` and `elite_resource_bonus` in `encounters/expedition_rules.tres`. Victory repairs: %d Salvage per Hull, capped at capacity. Standalone combat destruction fallback: %d Salvage. Enemy registry and reward settings: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.\n"
		% [
			Rules.elite_resource_bonus,
			Board.RESULT_SALVAGE_PER_HULL,
			Board.DESTRUCTION_SALVAGE
		]
	)
	text += "\n## Card preferences\n\nPlayer starting pools retain 25 original Tier 1 identities plus three targeted sabotage identities each (28 total); unowned identities remain expedition rewards. All enemies draw the full base library. Multipliers are soft and strictly positive. Category multipliers use the strongest matching preference, then multiply the family weight.\n\n"
	text += "| Ship | Starting identities | Family weights | Effect preferences | Tactical weights | Decision variation | Resource |\n|---|---|---|---|---|---|---|\n"
	for ship in profiles:
		text += row(
			[
				ship.ship_name,
				ship.starting_cards.size(),
				JSON.stringify(ship.card_family_weights),
				JSON.stringify(ship.card_effect_weights),
				JSON.stringify(ship.tactical_weights),
				ship.tactical_variation,
				source(ship)
			]
		)
	text += "\nTactical scoring preserves affordable immediate wins and fatal-self-damage avoidance. It values public-state deltas and expected random gains; it cannot inspect player cards or sample future combat outcomes. Elites/bosses use lower score variation. Rank does not bypass costs or turn rules.\n"
	text += pool_reference()
	text += combat_reward_reference()
	text += progression_reference()
	write_doc("ships", text)
	text = "# Cards\n\nGenerated from `scripts/cards/card_library.gd` and loaded CardData Resources. Edit each listed `.tres`; descriptions are presentation only, `effects` controls gameplay. Costs spend the listed family. Effects below are exact unmodified values.\n\n"
	text += pool_reference()
	text += card_expansion_reference()
	var columns: Array = [
		"Card",
		"Family / unchanged cost",
		"Rarity",
		"Allocation",
		"Base effects",
		"Upgrade I",
		"Upgrade II",
		"Extra action (all levels)"
	]
	for ship in Ships.PLAYERS:
		columns.append(ship.ship_name)
	columns.append("Resource")
	text += row(columns)
	var separators: Array = []
	for column in columns:
		separators.append("---")
	text += row(separators)
	for card in Cards.CARDS:
		var cells: Array = [
			card.card_name,
			"%s / %d" % [card.family, card.cost],
			"Tier %d" % card.tier,
			card.allocation_category.capitalize(),
			"`" + JSON.stringify(card.effects) + "`",
			"`" + JSON.stringify(card.upgrade_effects[0]) + "`",
			"`" + JSON.stringify(card.upgrade_effects[1]) + "`",
			card.play_again
		]
		for ship in Ships.PLAYERS:
			cells.append(card in ship.starting_cards)
		cells.append(source(card))
		text += row(cells)
	var hand = Hand.new()
	text += (
		"\n## Draws and upgrades\n\nSix-card hands; maximum %d copies per identity and at most one card of each tier above Common. Tier 2 draw chance %s%%, locked through round %d; Tier 3 chance %s%%. Temporal Rift multiplies Tier 2 chance by %s. Missing eligible higher-tier bucket falls back to Common. Tune CardHand/EnemyHand in `scenes/board.tscn` or defaults in `scripts/cards/card_hand.gd`.\n\n"
		% [
			hand.max_copies,
			hand.tier_two_chance * 100,
			hand.tier_two_locked_turns,
			hand.tier_three_chance * 100,
			Mod.TEMPORAL_DROP_MULTIPLIER
		]
	)
	hand.free()
	text += (
		"Acquisitions offer up to 3 distinct unowned identities, choose 1; 60%% Tier 2 / 40%% Tier 1 per slot when both buckets have candidates (configurable). A missing bucket falls back to remaining eligible identities without violating the minimum tier. Fewer than three eligible identities show fewer choices; exhaustion resolves immediately with an explanation and no currency change. Acquired identities use ×%.1f draw weight within rarity, player only; rarity odds and hand caps remain unchanged. Starting identities each weigh 1. Inspector: `encounters/expedition_rules.tres` → Reward Tier Two Chance / Acquired Card Draw Weight.\n\nEvery card has two full replacement effect dictionaries on its CardData Resource. Upgrade level is independent of rarity; cost and extra-action flag stay unchanged. All player copies, including held cards, resolve to the upgraded identity; enemies always retain base Resources. Production stays +1 per play; upgraded production cards gain immediate resources/defense. Play-again cards gain no new action grants or cost refunds. Hull gains can still create existing Ablative Plating; high-cost repairs scale conservatively. Fully upgraded research retains the existing %d Salvage fallback.\n\n"
		% [Rules.acquired_card_draw_weight, Rules.unavailable_upgrade_salvage]
	)
	text += combat_reward_reference()
	text += "## Effect keys (`scripts/cards/card_effects.gd`)\n\n| Key | Resolution |\n|---|---|\n| `hull`, `shields`, resource or production key | Add to acting ship; excess Hull is Ablative Plating |\n| `damage`, `pierce` | Damage; floor(damage × pierce) bypasses Shields, remaining damage consumes Shields then Hull/plating |\n| `break_shields` | Remove specified enemy Shields before damage |\n| `drain`, `steal` | Remove available enemy resource (floor 0); steal adds the amount actually removed to actor |\n| `sabotage` | Lower every enemy production by amount; floor 1 |\n| `production_other` | Add specified production/resource only if corresponding resource differs from card family |\n| `random_gain` | Uniformly choose one of 3 resources and add amount |\n| `random_gain_other`, `random_gain_range_other` | Uniformly choose one of 2 other families; fixed amount or inclusive uniform integer range |\n| `swap_shields` | Exchange current Shield amounts |\n| `shield_collapse` | Remove all enemy Shields; at or above threshold, stated chance of regular self-damage |\n| `shield_collapse_below` | Remove all enemy Shields strictly below threshold |\n| `self_damage` / `self_damage_regular` | Direct Hull/plating loss / Shield-first damage |\n\nDiscard gives floor(cost / 3) matching resources (`scripts/board.gd`). Extra actions grant no turn income or EMP Pulse charge. **Planned, not implemented:** Tier 3 card library, deck trimming. Pirate rewards currently use Uncommon-or-better, the highest populated tier; no empty rare selection screen.\n"
	text += "\n## Power Allocation\n\nPlayer opening hands contain two Materials-cost, two Energy-cost and two Crew-cost cards, chosen within the actual ship pool with existing rarity and duplicate eligibility. Slot families are seed-shuffled. Eligible fixed Inspector cards keep their slots only within those quotas. Incomplete custom pools fall back to other valid cards rather than blocking a draw. This opening-only guarantee does not constrain replacement families or enemy hands.\n\nBalanced is the default at each battle start. Offense, Defense and Systems multiply matching player cards by the fixed Inspector weight (default 2). Switching is free, unrestricted by turns, and affects future replacement draws only: no hand mutation or RNG consumption on selection. No upgrades, resource costs or cooldowns.\n\nEvery CardData identity has exactly one `allocation_category`, editable in its `cards/*.tres` Resource and retained through both upgrades. Offense covers damage, shield breaking, theft, sabotage and disruption (including Shield Exchange). Defense covers Hull/Shields and protection. Systems covers resource generation and production. Mixed-purpose Salvage Strike and Cataclysm Protocol remain Offense; production cards remain Systems despite upgraded secondary defenses. The table lists every identity's primary purpose. These categories are independent of the gallery's overlapping effect filters and enemy preference categories.\n\nThe existing rarity roll and eligible bucket are chosen first, with the same round lock and duplicate caps. Within that bucket: `weight = identity_weight × existing_preference_weight × allocation_factor`; `P(card) = weight / sum(eligible weights)`. `allocation_factor = matching_draw_weight` only for the selected primary category, otherwise 1. Balanced and a bucket without matching cards therefore use the original probabilities. No cards are removed and every existing positive weight stays positive; cost/affordability never filters draws. Enemy hands do not enable allocation and retain their existing weights and AI.\n\nInspector: `resources/power_allocation.tres` → Matching Draw Weight (default 2.0); Board → Allocation Settings can reference an alternate configuration. The player hand snapshots the value once at battle start; modes never change it during battle. `scripts/ui/power_allocation_popup.gd` owns the reusable centered 2×2 modal. The current-mode emoji sits in the existing combat action strip above the hand, anchored identically at 16:9 and 21:9. Cards, hand timing and dimensions are unchanged.\n"
	text += "\n## Card presentation\n\nNormal cards use 14 px data-derived summaries and a fixed artwork rectangle. Hold or middle-click any card to inspect the original-scene copy beside full base/upgrade effects. Tuning: `resources/card_presentation.tres`; implementation and gesture/confirmation rules: [UI layout](../ui_layout.md#compact-cards-and-universal-inspection). No gameplay values are duplicated in presentation.\n"
	write_doc("cards", text)
	var state = State.new()
	text = "# Points of interest and generation\n\nGenerated from `encounters/expedition_rules.tres` and all referenced PoI Resources. Each completed PoI grants **+1 FTL Drive charge once**, in addition to rewards below. Extra FTL in a row adds to this base. All next-battle values apply once; Hull/Salvage and interstellar charge apply immediately.\n\n"
	text += "| Generation category | Min / max | Weight |\n|---|---|---|\n"
	text += row(
		[
			"Ordinary",
			"%d / %d" % [Rules.minimum_ordinary, Rules.maximum_ordinary],
			Rules.ordinary_weight
		]
	)
	text += row(
		[
			"Hazardous",
			"%d / %d" % [Rules.minimum_hazardous, Rules.maximum_hazardous],
			Rules.hazardous_weight
		]
	)
	text += row(
		["Enemy", "%d / %d" % [Rules.minimum_battles, Rules.maximum_battles], Rules.battle_weight]
	)
	text += (
		"\nTotal %d progression encounters plus an independently scheduled optional Trading Outpost; requirement = actual non-trading PoI count + 1. Service visits give zero charge and do not increase the requirement. Valid count combinations are sampled with weight ordinary_weight^ordinary × hazardous_weight^hazards × battle_weight^enemies. Each category samples Resources by encounter_weight without replacement until exhausted. At least 1 enemy; reward floor 1. Invalid bounds warn and fall back to one enemy plus available PoIs (all enemies if no PoIs). No hidden reduction in travel requirement. Tune counts/weights/registry in `encounters/expedition_rules.tres`; type weights in each PoI/ship Resource.\n\n"
		% Rules.encounters_per_system
	)
	for category in ["Ordinary", "Hazardous", "Services"]:
		text += "## " + category + "\n\n"
		if category == "Services" and Rules.trading_outpost != null:
			state.rules = Rules
			state.service = {"poi": Rules.trading_outpost}
			var prices: Array[String] = []
			for bought in range(7):
				state.station_production_purchases = bought
				prices.append(str(state.service_cost(3)))
			text += (
				"First station: system %d–%d; subsequent system-number intervals %d–%d, hard cap 3. The seeded station RNG is independent of encounter/loot RNG. Unlimited purchases and free revisits until departure, with no travel charge, requirement increase, penalties or survey. Pending paid choices must resolve before another purchase or departure. Each confirmation revision can spend once.\n\n"
				% [
					Rules.minimum_station_interval,
					Rules.maximum_station_interval,
					Rules.minimum_station_interval,
					Rules.maximum_station_interval
				]
			)
			text += (
				"The same Hull service tile repairs damaged Hull for 1 Salvage/Hull up to capacity, then switches to Install Ablative Plating for 2 Salvage/point up to capacity +10. It selects an affordable quantity, previews total cost/result and rejects zero confirmation; at +10 it remains in place disabled. Shared quantity bounds live in `scripts/repair_rules.gd`; post-battle repairs cost 2 Salvage/Hull. Field repairs are separate, accessed through the system Hull popup at 2 Salvage/Hull and cannot create plating. Supply/card base prices and shipyard base price are editable in `encounters/trading_outpost.tres` approach Salvage Cost; supply amount/production amount remain editable outcome Resources. Shipyard cost for purchase n: base + increment × (n−1) + acceleration × (n−1) × (n−2) / 2. Current increment %d, acceleration %d; prices %s. Counter combines all production categories and resets only when a later station appears; permanent upgrades persist. Intervals and escalation parameters: `ExpeditionRules` Inspector. The table shows initial prices; repair amount is variable.\n\n"
				% [
					Rules.production_price_increment,
					Rules.production_price_acceleration,
					", ".join(prices)
				]
			)
		var locations: Array = [Rules.trading_outpost] if category == "Services" else Rules.pois
		for poi in locations:
			if poi == null:
				continue
			if category != "Services" and poi.hazardous != (category == "Hazardous"):
				continue
			text += (
				"### %s\n\nEdit %s; expand Approaches → Success / Failure. Generation weight (ignored for service stations): %s. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.\n\n"
				% [poi.title, source(poi), poi.encounter_weight]
			)
			text += "| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |\n|---|---|---|---|---|---|\n"
			for approach in poi.approaches:
				text += row(
					[
						approach.title,
						(
							"None"
							if approach.requirement.is_empty()
							else (
								"%s ≥%d"
								% [State.LABELS[approach.requirement], approach.minimum_production]
							)
						),
						approach.salvage_cost,
						"%s%%" % (approach.success_chance * 100),
						state.describe_outcome(approach.success),
						(
							"Not rolled"
							if approach.success_chance >= 1
							else (
								"%s%%: %s"
								% [
									(1 - approach.success_chance) * 100,
									state.describe_outcome(approach.failure)
								]
							)
						)
					]
				)
			text += "\n"
	text += (
		"## Progression safeguard\n\nIf a PoI has no affordable, unlocked approach whose worst possible Hull outcome leaves Hull >0, **Navigation survey** becomes available. Completing the survey forfeits all normal loot and grants only that PoI's +1 charge, with guaranteed next-battle penalty `%s`. The independent Trading Outpost never needs or permits a survey. Entering and leaving it is free; only a confirmed purchase spends Salvage. Unlimited affordable services and free revisits while present; ignoring a station never blocks departure. Tune `ExpeditionRules.survey_penalty`. Full-Hull repairs are locked. Return leaves an uncompleted PoI untouched.\n\n"
		% JSON.stringify(Rules.survey_penalty)
	)
	text += "All escaped enemies complete normally and award their full profile charge. Repeated result/approach calls cannot award more charge. The shipping carryover cap is zero: every normal system transition begins at zero charge. New expeditions start at 0. Mandatory Boss encounters must resolve before any transition. Pending choices must be resolved before leaving. Hull 0 ends the expedition; voluntarily lethal approaches and battle losses remain possible. The simulation guarantees charge availability for surviving players, not victory against every enemy. **Not implemented:** hostile follow-up battles from pirate debris; current pirate hazards use Hull costs.\n"
	text += progression_reference()
	write_doc("pois", text)
	text = "# Battle modifiers\n\nGenerated numerical constants: `scripts/combat_modifier.gd`, `ftl_drive.gd`, `board.gd`, and expedition Resources. Serialized combat names (`FTLDrive`, `ftl_turns`, `ftl_resistance`) remain for scene compatibility; they mean **EMP Pulse**, not interstellar FTL Drive.\n\n"
	text += "| Modifier | Exact behavior / duration | Adjust |\n|---|---|---|\n"
	text += row(
		[
			"PoI bonuses / penalties",
			"Bonuses and penalties add independently. Starting Materials/Energy/Crew = max(0, base + total positive - min(abs(total negative), floor(base * 0.5))). Positive bonuses have no PoI cap and never enlarge the penalty cap. Shields add with floor zero. Pending until next battle, then consumed once before normal income; repeated initialization cannot reapply. EMP Pulse charge adds, capped to ship target; offline uses longest individual duration. Travel and service visits do not consume modifiers. No temporary production effects.",
			"Outcome.next_battle; scripts/expedition_state.gd"
		]
	)
	text += row(
		[
			"Supported next-battle keys",
			"materials, energy, crew, shields, emp_pulse_charge, emp_pulse_offline (positive duration)",
			"encounters/*.tres → approaches → outcome"
		]
	)
	text += row(
		[
			"Hull / plating",
			"Hull persists capped to ship capacity between battles. Battle repairs above capacity become plating; damage consumes plating before permanent Hull. Plating clears between battles. PoI/victory repairs cannot create plating.",
			"ShipData.hull_capacity; card effects; board.gd"
		]
	)
	text += row(
		[
			"Shipyard production",
			"Chosen production upgrade adds permanently for expedition; station-local escalating purchase prices reset at the next station, without losing upgrades; only permanent base+upgrade production unlocks PoI approaches. Battle card production does not carry. PoIs never modify production.",
			"Trading Outpost outcome.production_choice"
		]
	)
	text += row(
		[
			"Tactical victory",
			(
				"+%d each starting Materials/Energy/Crew next battle if finish Hull exceeds starting Hull (plating can qualify); escapes eligible; additive stacking"
				% Board.TACTICAL_RESOURCES
			),
			"board.gd: TACTICAL_RESOURCES"
		]
	)
	text += row(
		[
			"Strategic victory",
			(
				"+%d starting Shields next battle if final total production exceeds enemy total; escapes eligible; additive stacking"
				% Board.STRATEGIC_SHIELDS
			),
			"board.gd: STRATEGIC_SHIELDS"
		]
	)
	text += row(
		[
			"EMP Pulse",
			"+1 charge each normal player turn, including first; extra actions give 0. Ship-specific target. Disabled turns give 0 charge and prevent escape; charge is retained.",
			"ships/*.tres: ftl_turns; ftl_drive.gd"
		]
	)
	text += row(
		[
			"EMP Pulse disruption",
			(
				"Chance = clamp(min(permanent Hull damage × %s, %s) × (1 − ship resistance), 0, 1); disabled for %d full player turns. Shields/plating alone do not trigger. No new disruption while already offline."
				% [Jump.FAILURE_CHANCE_PER_DAMAGE, Jump.MAX_FAILURE_CHANCE, Jump.DISABLED_TURNS]
			),
			"ftl_drive.gd constants; ShipData.ftl_resistance"
		]
	)
	text += row(
		[
			"Interstellar FTL Drive",
			"Required = non-trading PoI count + 1. Independent Trading Outpost: zero charge, zero requirement increase, no survey or departure cost. PoIs +1 plus optional extra; enemy defeat/escape gives profile reward once. Shipping carryover is zero on normal system entry. Can leave at threshold after resolving any mandatory Boss. New expeditions start at zero.",
			"ship.interstellar_ftl_reward; outcome.extra_ftl_charge; expedition_state.gd"
		]
	)
	text += row(
		[
			"Event timing",
			(
				"First event round 1 + random integer %d–%d; next event %d–%d rounds after previous ends; active events last %d full rounds. One random modifier (0–%d, uniform; %.1f%% each) per generated enemy."
				% [
					Mod.MIN_INTERVAL,
					Mod.MAX_INTERVAL,
					Mod.MIN_INTERVAL,
					Mod.MAX_INTERVAL,
					Mod.ACTIVE_ROUNDS,
					Mod.NAMES.size()-1,
					100.0/Mod.NAMES.size()
				]
			),
			"combat_modifier.gd; expedition_state.gd"
		]
	)
	text += row(
		[
			"Asteroid belt",
			(
				"%s%% independent hit per ship, %d Shield-first damage; instant, repeats every %d–%d rounds"
				% [
					Mod.ASTEROID_CHANCE * 100,
					Mod.ASTEROID_DAMAGE,
					Mod.MIN_INTERVAL,
					Mod.MAX_INTERVAL
				]
			),
			"combat_modifier.gd: ASTEROID_*, *_INTERVAL"
		]
	)
	text += row(
		[
			"Ion storm",
			"50% ×2 / 50% ×0.5 Energy card effects for 3 rounds; half rounds down. Cost unchanged. Recursively scales numbers except pierce, shield_collapse_below, threshold, chance; legacy sabotage true counts as 1.",
			"combat_modifier.gd: begin_round, _scaled"
		]
	)
	for kind in [6,7]:
		text += row([Mod.NAMES[kind],Mod.description(kind),"combat_modifier.gd: STORMS, _scaled"])
	text += row(
		[
			"Solar flare",
			"Shields unavailable for 3 rounds; stored Shields restored afterward. Shield gains and swapping ignored during flare.",
			"combat_modifier.gd: ACTIVE_ROUNDS, play"
		]
	)
	text += row(
		[
			"Nebula",
			(
				"Initial miss %d%%; each later full round adds uniform integer −%d…+%d, clamped 0–%d%%. Miss cancels combat card effects except direct self_damage; card cost paid. Whole battle."
				% [Mod.NEBULA_START, Mod.NEBULA_STEP, Mod.NEBULA_STEP, Mod.NEBULA_MAX]
			),
			"combat_modifier.gd: NEBULA_*; is_combat"
		]
	)
	text += row(
		[
			"Temporal Rift",
			(
				"Tier 2 draw chance ×%s for entire battle (15%% → 30%%); early-round lock and hand caps remain."
				% Mod.TEMPORAL_DROP_MULTIPLIER
			),
			"combat_modifier.gd: TEMPORAL_DROP_MULTIPLIER; CardHand"
		]
	)
	text += "\nSystems Failure begins when any production system reaches zero. A ship has three of its own full turn endings after activation to restore every system above zero, or loses. Duration: `Board.systems_failure_turns`. Hull destruction takes precedence; EMP Pulse remains available. Turn income equals current production. Expedition state is in memory only; restart/ship selection/app exit ends the run. **Planned, not implemented:** persistent save/load. No other expedition currency, travel spending, undocumented rank multipliers, or persistent card-effect upgrades after an expedition ends.\n"
	write_doc("battle_modifiers", text)
	print(
		(
			"Generated card reference."
			if "--cards-only" in OS.get_cmdline_user_args()
			else "Generated four balance references from current Resources and constants."
		)
	)
	quit()


func progression_reference() -> String:
	var p: Resource = Rules.progression
	return (
		"\n## Expedition progression\n\nInspector: encounters/expedition_rules.tres -> Progression -> resources/expedition_progression.tres.\n\nCarryover = min(cap, max(0, FTL - requirement)), cap %d, hard maximum 2; new expeditions start at zero. Shipping cap is zero, so every system starts at zero charge; the editable helper retains its hard maximum of 2. Requirements remain unchanged.\n\nLevel = 1 + floor((system - 1) / %d); steps = level - 1. Per extra level: +%d Hull, +%d Shields, +%d each starting resource; each production adds floor(steps * %s). Stats are copied, never written to shared ShipData. Optional encounter count is irrelevant.\n\nElite selection retains original baseline odds in level 1, then uses min(%s, available Elite weight / total available weight + steps * %s). Each bucket retains profile weights; unavailable buckets fall back. A pool consisting only of Elites has probability 1.\n\nEvery %d systems, starting at system %d, one enemy slot becomes a mandatory existing Boss (six slots retained). Resolve by combat victory or existing EMP Pulse before normal FTL travel. Both grant profile FTL once; destruction/resource/escape Salvage remains distinct. Escape never transitions systems. Missing mandatory metadata blocks travel.\n"
		% [
			p.ftl_carryover_cap,
			p.systems_per_difficulty,
			p.hull_bonus_per_level,
			p.shields_bonus_per_level,
			p.resource_bonus_per_level,
			str(p.production_bonus_per_level),
			str(p.maximum_elite_probability),
			str(p.elite_probability_increase),
			p.boss_interval,
			p.boss_interval
		]
	)


func pool_reference() -> String:
	var text: String = "\n## Six starting pools\n\nEach pool has 28 distinct identities: its original 25 Tier 1 cards plus one targeted sabotage card per resource family. Added Tier 2 cards remain locked until round 3. Specialization comes only from membership; no extra player family/effect draw weights. The opening remains 2 Materials / 2 Energy / 2 Crew. New profiles inherit Endeavour's Hull tint and default model fallback; Model Scene remains independently editable.\n\n"
	text += "| Ship | Materials | Energy | Crew | Total |\n|---|---|---|---|---|\n"
	for ship in Ships.PLAYERS:
		var counts: Dictionary = {"materials": 0, "energy": 0, "crew": 0}
		for card in ship.starting_cards:
			counts[card.family] += 1
		text += row(
			[
				ship.ship_name,
				counts.materials,
				counts.energy,
				counts.crew,
				ship.starting_cards.size()
			]
		)
	for ship in Ships.PLAYERS:
		text += "\n### " + ship.ship_name + " starting identities\n\n"
		for family in ["materials", "energy", "crew"]:
			var names: Array[String] = []
			for card in ship.starting_cards:
				if card.family == family:
					names.append(card.card_name)
			text += "- **" + family.capitalize() + ":** " + ", ".join(names) + ".\n"
	return text + "\n"


func combat_reward_reference() -> String:
	return (
		"\n## Combat upgrade events and Chasedown\n\nNon-escape victories offer up to %d / %d / %d / %d upgrades for Chasedown / standard / elite / boss battles. Each selection must be a different card identity within that event; a later event can upgrade the identity again. Existing two-level limits remain. Finish skips unused choices; exhausted combat upgrades grant no extra Salvage. EMP Pulse escape grants no upgrades or Salvage. Quantities: `ExpeditionRules` → Combat Upgrades.\n\nSublight Chasedown: %.0f%% per valid PoI-to-PoI movement, limit %d per system. Initial entry, menus, invalid/same destinations, battle return and FTL travel never roll. Uses ordinary enemies, existing scaling and battle scene, gives exactly +1 FTL once on victory or escape, then resumes the preserved destination. See [implementation and tuning](../chasedown_rewards.md).\n"
		% [
			Rules.chasedown_upgrades,
			Rules.standard_upgrades,
			Rules.elite_upgrades,
			Rules.boss_upgrades,
			Rules.chasedown_chance * 100,
			Rules.chasedown_limit
		]
	)


func card_expansion_reference() -> String:
	var text: String = (
		"\n## Expanded library and deck capacity\n\nThe library contains 74 identities: 52 Tier 1 and 22 Tier 2. Cards 45–68 add eight per family (13 Tier 1 / 11 Tier 2). Cards 69–74 add targeted sabotage: one Tier 1 and one Tier 2 per family. Each player pool retains its original 25 identities and adds exactly three targeted sabotage identities, for 28 total. Tier 2 still unlocks in round 3 with at most one in a hand. Existing acquisition tier probabilities and acquired weight ×%.1f remain unchanged; enemies draw the full base library.\n\n`ExpeditionRules.max_deck_identities` defaults to **%d**, Inspector label **Max Deck Identities** (range 25–100). Starting and acquired identities count once; upgrades/copies do not. Capacity cannot invalidate a custom starting pool larger than its configured limit. Ordinary acquisitions grow the pool until full. Selecting a reward at capacity fixes that incoming card and opens the existing gallery as **Deck Full**. Select an owned identity, explicitly Replace Card, or Keep Current Deck. No removal happens before confirmation; declining gives no refund. Removed identities lose their private upgrade and acquired weight; retained identities keep theirs. A removed starting identity may be acquired again at base level with normal acquired weight.\n\nReplacement state is `pending_card`, `pending_choice = replace`, `removed_starting_cards`, `acquired_cards` and `upgraded_cards`. It survives screen rebuilds and normal in-memory expedition transitions. There is no disk save/load in this prototype, so application exit still ends the run. Deck Viewer shows actual owned count / capacity. Costs, six-card hands, rarity caps, Power Allocation and the weighted replacement-draw model remain unchanged.\n\n## Generic conditionals, exchanges and production\n\nCard costs are paid first. Ordinary effect keys resolve in the existing order, then `conditional` evaluates the live state and applies either `then` or `else` without another payment. Conditions may nest. `target` is `self` or `enemy`; `attribute` is a state key; comparisons are `below`, `at_most`, `equal`, `at_least`, `above`. `threshold` is a number. Use `fraction_of: hull_capacity` with threshold 0.5 for 50%% of that ship's original capacity, including difficulty scaling; current plating does not increase the denominator. Alternatively `compare_target` / `compare_attribute` replace the numeric threshold with a live stat comparison.\n\nExample: `conditional = {target: enemy, attribute: reactor, comparison: above, compare_target: self, compare_attribute: reactor, then: {reactor: 1}, else: {energy: 5}}`. In the Inspector these are ordinary nested Dictionaries in **Effects** or either **Upgrade Effects** entry; all amounts and predicates remain editable.\n\n`swap_resource: materials` exchanges the two Materials reserves from one snapshot. Only materials/energy/crew are accepted, and the card's cost family is rejected. This never swaps production. `enemy_production: {reactor: -1}` adjusts only the named enemy production, floored at 0; existing own production keys add their signed amount, also floored at 0. Targeted sabotage reductions are fixed across upgrade levels: −1 for cards 69/71/73 and −2 for cards 70/72/74. Reaching zero activates the existing Systems Failure rules.\n\nExisting `break_shields` means Shield-only damage, with no Hull spillover. New Hull attacks use existing `damage` plus `pierce: 1.0`, so Shields stay intact and existing Ablative Plating absorbs Hull damage first. Regular damage retains Shield-first spillover. No new damage system is introduced.\n\nConditions for Hull Patch, Torpedo Salvo, Tactical Assessment and Emergency Medical Team choose a complete effect branch before healing/attacking. Laser Burst checks after its primary attack; Shield Breachers and Demolition Crew check after breaking Shields. Other thresholds see the state after their main effects. Thresholds do not change with upgrades.\n\nIon Storm scales numerical outcomes, including nested branches, using the existing floor rounding; predicates, percentages, comparisons, swap identity and cost stay fixed. Production effects may scale during Ion Storm as before. Nebula classifies potential hostile branches, exchanges and targeted production changes as combat; a miss spends the cost and suppresses that card's benefits/attacks using existing rules. Solar Flare still reserves/restores Shields. The existing AI values conditional/exchange results through the same conservative state simulation; preference categories and gallery filters inspect both branches.\n\n## Revised original identities\n\nThe eight original paths/memberships remain. **Emergency Power Cell** keeps `08_energy_cell.tres`, cost 0 and turn consumption. Shield Plating remains cost 3, Hull Patch/Nanobots 7, Laser Burst/Missile Team 6, Shield Breachers 7 and Torpedo Salvo 10. Their three complete effect sets appear in the catalogue below. Other original 36 card Resources are unchanged.\n\n"
		% [Rules.acquired_card_draw_weight, Rules.max_deck_identities]
	)

	text += "## New card tiers\n\nCosts and all three effect sets are in the catalogue below. Each new identity has its own CardData Resource.\n\n| Family | Tier 1 | Tier 2 |\n|---|---|---|\n"
	for family in ["materials", "energy", "crew"]:
		var names: Array = []
		for tier in [1, 2]:
			var selected: Array[String] = []
			for card in Cards.CARDS.slice(44):
				if card.family == family and card.tier == tier:
					selected.append(card.card_name)
			names.append(", ".join(selected))
		text += row([family.capitalize(), names[0], names[1]])
	return text + "\n"
