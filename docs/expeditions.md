# Star systems and expedition economy

## Playing the prototype

Choose a ship and **Begin Expedition** to open the system grid. There is no mandatory opening battle: choose any encounter and charge the interstellar FTL Drive. After a non-escape battle victory, the existing result screen offers repairs and **Upgrade Cards**, followed by the system view. EMP Pulse escape returns directly to the system. Battles and PoIs can be visited in any order. Completed entries are disabled.

Each system has six progression encounters, with a separate optional Trading Outpost in scheduled systems, targeting 3–4 ordinary PoIs, 0–2 hazardous PoIs and 1–2 enemies. The FTL Drive requires **PoI count + 1** charge. Completing a PoI grants +1; defeating **or escaping** an enemy grants its profile reward (standard 1, elite 2, boss 3). Wormhole outcomes may add extra charge. Rewards are single-use, and travel charge resets in each new system. Escape grants no combat Salvage.

Once charged, jump or continue exploring. Pending card/resource/production choices must be resolved first. EMP Pulse retains the original combat charging and disruption mechanics; it is distinct from interstellar FTL Drive progress. If a PoI has no affordable, unlocked approach guaranteed to preserve at least 1 Hull, a navigation survey can complete it for its normal charge, forfeiting loot and imposing −3 Energy next battle. This covers dangerous debris fields at 1 Hull. Trading Outpost is a separate service station: zero travel charge, no requirement increase, no survey, and free entry/return without purchasing. It never replaces one of the six encounters or blocks departure.

A PoI is a single visit: tap an approach to select it, then press Confirm Approach to execute it, resolve any reward choice, and Continue. Return is available over the banner before confirming; it does not consume the encounter. Each approach shows requirements, cost, success/failure probabilities, and exact rewards/penalties.

Run state is held in memory for this prototype, not saved to disk. New Expedition, returning to ship selection and starting again, or closing the game resets it. Ship selection, permanent Hull, Salvage, acquired card weight and upgrades persist across encounters and charged system jumps. Battle resource stockpiles and combat-only production improvements reset.

## Godot Inspector tuning

| Open in FileSystem | Inspector fields |
|---|---|
| `encounters/expedition_rules.tres` | PoI library, separate Trading Outpost Resource, minimum/maximum station interval, production price increment/acceleration, encounters per system, category counts/weights, enemy registry, resource-victory Salvage, survey penalty, exhausted-research fallback, Chasedown chance/limit/responses, combat upgrade counts, debug seed |
| Any ordinary/hazardous `encounters/*.tres` | Title/description; expand **Approaches**, then any of the four approach resources |
| Approach resource | Title, required production, minimum production (default 3), Salvage cost, success chance, Success and Failure |
| Success / Failure resource | Blurb, Salvage, permanent Hull, Next Battle dictionary, card reward/minimum tier, upgrade reward, resource choice, production choice, extra interstellar FTL charge |
| `cards/*.tres` | Base cost/effects/description/rarity, two Upgrade Effects dictionaries, Max Upgrades (2); costs unchanged |
| `ships/player/*.tres` (six registered profiles) | Starting stats and production; no ship names are used in approach eligibility |
| `scenes/expedition.tscn` root | Rules resource used by the run |

Production names in code and resource dictionary keys map to the existing game:
- `synthesizer` = Synthesizer, `reactor` = Reactor, `quarters` = Quarters.
- Next Battle accepts `materials`, `energy`, `crew`, `shields`, `emp_pulse_charge`, and `emp_pulse_offline`.
- Use positive amounts for bonuses, negative for penalties. `emp_pulse_offline` is a positive number of initial player turns without charging/warp.
- Immediate `hull` repairs stop at capacity. Neutral outcomes retain purchased plating. As agreed for the single-Hull model, negative PoI Hull values reduce combined Hull and may consume plating; fatal damage still ends the expedition. The Outpost Hull service switches to plating purchases only at full Hull.
- Each outcome should have a positive reward. Card/upgrade/resource-choice/production-choice are mutually exclusive choice types per outcome; immediate Salvage/Hull and temporary modifiers can accompany any one.
- Probabilities are 0–1. Both outcomes must be authored even for guaranteed approaches (the supplied resources do this).

Bonuses and penalties stack additively and are stored separately. For each of Materials, Energy and Crew, the starting amount is `max(0, Base + TotalPositive - min(abs(TotalNegative), floor(Base * 0.5)))`. Base is the unmodified ship value; bonuses do not enlarge the negative cap. For example, base 8, +3 and −12 yields 7. Positive bonuses have no PoI cap. Shields add both signs with a floor of zero. These amounts apply before unchanged normal first-turn production income. There are no temporary production modifiers; permanent outpost production upgrades still accumulate and unlock approach requirements.

Pending modifiers survive PoIs, service visits and system jumps, then are consumed once at battle initialization. A repeated initialization call on the same board cannot reset or reapply them. EMP Pulse offline turns use the longest individual duration rather than their sum.

EMP Pulse charge is capped at the selected ship's requirement. It is granted before the existing first-turn charge tick. An offline penalty suppresses that tick for exactly the specified initial turns.

## Salvage and card progression

Default combat Salvage: standard destruction **10**, elite **20**, boss **30**, resource victory **6**, EMP Pulse **0**. Enemy profiles edit destruction Salvage and FTL independently. Existing tactical (+5 starting Materials/Energy/Crew) and strategic (+10 Shields) bonuses remain, joining the same additive pending modifiers. The victory-screen repair service costs two Salvage per Hull, with its adjustable quantity control and Hull/Salvage preview.

The first Trading Outpost appears in system 2 or 3, chosen randomly. Later stations are 2 or 3 system numbers apart. `next_outpost_system` stores the next scheduled system; an independent RNG derived from the debug seed makes this deterministic without changing six-encounter or loot rolls. `ExpeditionRules.minimum_station_interval` / `maximum_station_interval` default to 2/3 and are hard-clamped to that range.

A present station remains available until leaving its system. Buy any affordable service repeatedly, or Return to the system map freely. Purchases never complete the station or grant travel charge. Card/resource/production choices must resolve before another purchase or departure; their choice screen returns directly to the station menu. Every confirmation carries a revision that is consumed before spending, so repeated/stale confirmations cannot duplicate a purchase.

| Service | Cost | Result |
|---|---|---|
| Hull service | 1 Salvage/Hull below capacity; 2 Salvage/plating at full Hull | One tile/selector: Repair Hull → Install Ablative Plating → disabled at +10. Quantity and cost are validated before confirmation. |
| Purchase supplies | 7 Salvage | Choose +5 Materials, Energy or Crew next battle; repeated purchases add |
| Acquire card | 15 Salvage | Up to three distinct unowned offers; choose one for the player pool |
| Shipyard improvements | 25, 40, 60, 85, 115, 150, 190, … | Choose +1 permanent expedition production |

Hull services and field repairs use shared `RepairRules.max_quantity` bounds; the post-battle flow uses `max_spend` at 2 Salvage/Hull. The station previews the selected Hull gain, resulting Hull and exact cost before confirmation. For 17/35 Hull, 50 Salvage and a +12 selection, the result is 29/35 Hull and 38 Salvage.

Shipyard price for purchase `n` is `base + increment × (n−1) + acceleration × (n−1) × (n−2) / 2`, with defaults 25/15/5. The counter combines Synthesizer, Reactor and Quarters purchases; it resets at the next station, while permanent production remains. Tune supplies/card/shipyard base prices in `encounters/trading_outpost.tres` → Approaches → Salvage Cost, and increments in `ExpeditionRules`. Repair parity is fixed by the shared numerical rule. Current Salvage, prices, locks and Return remain visible in the existing station layout; a repair slider appears in the footer only when repairs are selected.

Card rewards offer **three distinct unowned cards** when available and allow one selection, including Engineering Recovery. Smaller eligible pools show fewer choices; exhaustion resolves with an explanation. Boarding teams offer Tier 2 or better only. Mixed-tier rewards favor Tier 2 at 60% per slot. Tiers display as Common/Uncommon/Rare.

Each player ship retains its own 25 original Tier 1 identities from the expanded 68-card library. Acquisitions add new identities to the **player-only expedition pool**, at configurable ×3 draw weight within rarity, up to the default **30 distinct identities**. At capacity the selected incoming card stays fixed: select and confirm one owned identity to replace, or Keep Current Deck to decline without a refund. No card is removed before confirmation. Upgrades and drawn copies do not add to the count; retained upgrades persist and removed upgrades are discarded. Deck Viewer shows count / capacity. Tune **Max Deck Identities** in ExpeditionRules. Enemies retain the full, unmodified library. Six-card hands, maximum two identical cards and one-per-higher-tier restrictions remain. Tier 2 unlocks in round 3 for both sides.

Each identity supports two effect upgrades (+ and ++), preserving its original cost, rarity and extra-action flag. A private upgraded Resource replaces every player copy in both pool and hand; upgrades persist for this expedition. Enemy Resources remain at base level. If no card can be upgraded, research grants 4 Salvage instead (editable). Exact effects and starting memberships: `docs/balance/cards.md`.

## Chasedown and combat upgrades

Valid travel between two PoIs has a 5% Chasedown chance, at most once per system. Initial arrival, menus, battle returns and FTL jumps do not roll. Four responses feed the existing battle-start modifiers; the ordinary enemy uses existing difficulty scaling. Victory or escape grants exactly +1 FTL, then resumes the untouched destination.

Non-escape victories offer upgrades to **different identities**: Chasedown 1, standard 2, elite 3, boss 3. Choose sequentially in the existing gallery or Finish. A card selected in an event is excluded until that event ends; a later event may upgrade it again, up to the existing two-level maximum. Combat upgrade exhaustion grants no extra Salvage. Escape grants neither Salvage nor upgrades. Research keeps its existing exhausted-pool Salvage fallback.

Shipping interstellar FTL carryover is now zero, in both script defaults and configuration. Requirements, current-system charge and combat EMP Pulse rules remain unchanged. Wormhole bonus successes are 40% / 50% / 45%, each giving only +1 extra charge; the guaranteed perimeter approach gives none. See [implementation, tuning and validation](chasedown_rewards.md) for exact modifiers, old/new Wormhole outcomes and state handling.

## Restoration balance

Effects and Ablative Plating behavior are unchanged. Hull restored above capacity still absorbs damage first and is discarded between battles.

| Card | Old cost | New cost | Effect |
|---|---:|---:|---|
| Shield Plating | 3 | 3 | +4 Shields |
| Shield Array | 6 | 4 | +8 Shields |
| Shield Recharge | 5 | 3 | +6 Shields |
| Hull Patch / Hull Nanobots | 5 | 7 | +5 Hull |
| Hull Overhaul | 10 | 10 | +8 Hull |
| Structural Reinforcement | 7 | 6 | +5 Shields, +2 Hull |
| Emergency Refit | 15 | 20 | +14 Hull, +8 Shields |
| Aegis Overcharge | 15 | 16 | +20 Shields, +6 Hull |
| Damage Control | 15 | 23 | +18 Hull, +6 Shields |
| Cataclysm Protocol | 20 | 26 | 18 damage, +15 Hull |

Basic shield restoration is substantially cheaper per point than persistent Hull restoration. Mixed high-tier effects retain a modest efficiency discount; the damaging/healing Cataclysm also pays more for its persistent repair benefit.

## Verification

Run with Godot 4 (verified here with 4.5.1):
```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/trading_outpost_test.gd
godot --headless --path . --script tests/trading_outpost_ui_test.gd
godot --headless --path . --script tests/poi_reward_overhaul_test.gd -- --write-report
godot --headless --path . --script tests/ftl_progression_test.gd
godot --headless --path . --script tests/expedition_test.gd
godot --headless --path . --script tests/expedition_ui_test.gd
```

The expedition test forces both branches of every approach and checks seeded generation, non-sequential visits, jumps, costs/rewards, Hull/plating, threshold requirements, modifier consumption/clamps, FTL caps/offline duration, card choices, shared weights, isolated upgrades, upgrade limits/fallback, and live battle/victory/list transitions. UI checks include actual button selection and 1280×720, 1560×720 and 960×540 windows under the existing canvas scaling.

Run the UI test with a rendering driver (for example `--rendering-method gl_compatibility`) to also write screen captures under `.godot/testlogs/`. It uses the game's existing Godot controls and touch-friendly scroll containers, with no platform-specific dependencies. Physical Android device verification remains necessary.

Existing combat, AI, FTL, ship, victory, card, repair, and presentation tests are retained. The combat-modifier test now uses the existing configured Nebula step instead of its stale literal, and follows the new setup→expedition→battle hierarchy. No Nebula gameplay or export workflow changes are included.

For debugging: set Rules **Debug Seed** to a nonzero integer. Systems, card offers, and PoI rolls repeat for the same sequence of choices; each approach logs seed, system, encounter, approach, roll and success. Combat retains its existing independent randomness.

## Quick balance references

- [Ships](balance/ships.md)
- [Cards](balance/cards.md)
- [Battle modifiers](balance/battle_modifiers.md)
- [PoIs and generation](balance/pois.md)

Regenerate from current Resources with `godot --headless --path . --script tools/generate_balance_docs.gd`. The progression test simulates 10,000 systems, including randomized completion orders, all-escape routes, low Hull, repeat results and remaining obtainable charge. It tests progression availability, not guaranteed combat survival.

For banner artwork, compact grids, icon fallbacks and touch validation, see [Android UI](android_ui.md).

## Reward overhaul balance checks

All ten non-trading PoIs use the authored success/failure tables in [PoIs](balance/pois.md); existing approach requirements are unchanged. Failed risky approaches give consolation loot plus a penalty. Hazardous guaranteed options retain their listed costs. Hull and Salvage apply immediately; resource and Shield changes apply next battle. Spatial Anomaly grants combat EMP Pulse charge; Unstable Wormhole grants interstellar travel charge.

`tests/poi_reward_table.json` pins every authored chance and outcome. `tests/poi_reward_overhaul_test.gd` verifies all six requested profiles (three enemies as hypothetical players), five PoI successes/failures before battle (four ordinary plus one hazardous), independent ten-PoI maximum-bonus/penalty envelopes, mixed signs, odd-base floor rounding, production preservation, actual opening-hand affordability, EMP Pulse caps/offline timing, all service prices/choices, zero-Salvage departure, survey safety and duplicate guards. Ten-PoI cases use controlled modifier injection outside the normal six-encounter generator.

See [measured opening affordability](balance/reward_verification.md) for 512 deterministic hands per ship/scenario, using actual costs, unchanged tier restrictions and production. These checks measure economy and progression availability, not win rates or guaranteed combat survival. Positive stacking is intentionally uncapped, so repeated Energy rewards can produce very strong openings; a 50% resource penalty cap also does not protect Hull or Shields.

Validation for the preceding PoI overhaul used Godot 4.5.1 headless: editor import succeeded; 26 of 27 test scripts passed, including the new reward regression, all six baseline affordability sweeps, Android geometry checks and 10,000-system progression simulation. `travel_battle_test.gd` reports 15 EMP Pulse label/button overlap assertions on both unchanged `776e391` and this implementation with the same runtime. Its escape/reward assertions pass. This existing layout failure was left untouched to keep unrelated UI work separate. Godot 4.7 and physical Android rendering were not tested here.

The station economy regression sweeps 200 debug seeds through 30 systems, verifies both first-station positions and both intervals, and compares against generation with stations disabled. It tests repeat purchases of all four services on Wayfarer, Specter and Bastion, invalid amounts/affordability, stale confirmations, pending-choice guards, shared repairs, additive supplies in a real battle, seven production prices, reset/persistence and Inspector tuning. The station UI regression exercises real controls at five existing landscape sizes (1280×720, 1560×720, 960×540, 1280×480, 686×384), including double confirmations, repeat choices, free Return/revisit, locked services and repair previews.

Station overhaul validation used Godot 4.5.1 headless: editor/Resource import succeeded; 28 of 29 test scripts passed. New economy tests passed 47,176 checks and station UI passed 1,050 checks. Existing PoI regression passed 93,953 checks, progression simulation passed 426,100 checks over 10,000 systems, and Android layout passed 2,435 assertions. `travel_battle_test.gd` retains the same 15 label/button overlap failures, independently reproduced on untouched `b0f065a` with this runtime; escape/reward assertions pass. No physical Android or Godot 4.7 rendering was performed.

The [card reference](balance/cards.md) describes the 24 added tactical identities, eight revised cards, generic conditionals/resource exchanges, replacement state and validation. These changes preserve PoIs, FTL, enemy scaling, starting pools and the combat reward upgrade event rules above.

## Card expansion validation

Based on main `2b08af7`, retaining its Chasedown, combat reward and distinct-upgrade-event behavior. Added 24 identities (eight per family; 13 Tier 1 / 11 Tier 2) and revised eight existing Resources. The [card catalogue](balance/cards.md) lists exact costs, allocation, tiers, all upgrade effects, conditional timing and Inspector tuning. Energy Cell is now Emergency Power Cell at its original path. New Hull attacks use existing 100% pierce; Shield damage uses existing break_shields without spillover. All requested base values are retained; conservative upgrades keep production changes ±1 and thresholds fixed. Hull Patch/Torpedo conditions choose their complete branch before repair/attack; Laser Burst and Shield-clearing follow-ups check afterward.

Godot **4.7.2** editor import and all **49 automated test scripts** pass after updating fixtures for the expanded registry, revised Energy Cell/Laser Burst and full-deck station rewards. Focused effects/deck coverage: **2,031 checks**; replacement UI: **80**; existing upgrade/gallery UI: **945**; repeated station UI: **2,130**; station economy: **47,512**; plating/field repairs: **222**. The unchanged progression simulation passes **433,994 checks over 10,000 systems** across all six ships. The existing deterministic economy/opening affordability, AI, modifiers, rarity, allocation, Chasedown, music and combat regressions also pass.

Rendered Compatibility/software OpenGL checks cover replacement, all card-upgrade comparisons and paid station acquisitions at capacity. Replacement was inspected at desktop/ultrawide and 960×540, 800×450, 686×384 landscape sizes. The incoming portrait opens read-only inspection; the owned gallery scrolls independently and the lower actions remain reachable by scrolling the outcome view. Physical Android has not been tested.

There is no disk save/load implementation to test or migrate. The authoritative owned pool, removed identities, retained upgrades, acquired weights and fixed incoming replacement persist through in-memory screen rebuilds and system transitions. Closing the application still ends the expedition. No persistence format or second progression system was introduced.

Balance concerns: direct Hull attacks can be strong against shield-heavy enemies; reserve exchanges can cause large economy swings and support resource victories. Tier 2 gates the production manipulation and exchanges. Acquired ×3 weighting and the existing 1/2/3/3 combat upgrades amplify newly chosen identities, while the 30-identity cap limits breadth rather than total upgrade strength. These prototype interactions need human playtesting; no additional balance changes were made.

Changed-file ownership:

- `cards/45_*.tres` through `68_*.tres`: 24 new definitions. Eight original card Resources revised: `01`, `03`, `08`, `09`, `12`, `16`, `17`, `20`; all other original card Resources remain byte-identical.
- `scripts/cards/card_data.gd`, `card_effects.gd`, `card_library.gd`, `card_preferences.gd`, `combat_modifier.gd`, `board.gd`: schema/descriptions, ordered resolution, registry, preferences, modifier integration and capacity snapshots. Existing tactical AI consumes the same simulated state deltas.
- `scripts/expedition/expedition_rules.gd`, `encounters/expedition_rules.tres`, `scripts/expedition_state.gd`, `scripts/expedition.gd`: capacity configuration, ownership/replacement validation, current deck count and existing outcome/gallery routing.
- `scripts/ui/card_gallery.gd`, `card_effect_text.gd`: conditional filter support and accurate upgrade comparisons.
- New `tests/card_expansion_test.gd`, `deck_replacement_ui_test.gd` and UID sidecars; existing card progression/tier, opening, tactical, plating and station regression fixtures updated. `.github/workflows/tests.yml` includes rendered replacement validation.
- Documentation: developer guide, card/ship balance references, battle setup, this expedition guide, historical six-ship follow-up note and `tools/generate_balance_docs.gd` (`--cards-only` option).

Ship statistics/memberships, scene files, project configuration, FTL/progression configuration, PoI definitions, enemy scaling and audio code remain unchanged.
