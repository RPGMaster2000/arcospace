# Ships

Generated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; S/R/Q = Synthesizer/Reactor/Quarters. Production identifiers: `synthesizer` / `reactor` / `quarters`.

| Ship | Type / special attribute | Hull / Shields | M/E/C | S/R/Q | Emergency Jump turns / resistance | Rank | FTL reward (defeat **or escape**) | Destruction Salvage | Generation weight | Edit |
|---|---|---|---|---|---|---|---|---|---|---|
| Endeavour  | Balanced Cruiser; Balanced economy; average escape speed. | 35 / 10 | 10/10/10 | 2/2/2 | 14 / 0.0% | Player | — | — | — | `ships/endeavour.tres` |
| Thunderbolt | Balanced Cruiser; Fast, resistant Emergency Jump; fragile Hull and low Materials production. | 28 / 15 | 8/14/10 | 1/3/2 | 11 / 25.0% | Player | — | — | — | `ships/thunderbolt.tres` |
| Titiania | Balanced Cruiser; Strong Hull and industry; slow, vulnerable Emergency Jump. | 42 / 6 | 14/8/10 | 3/1/2 | 17 / -10.0% | Player | — | — | — | `ships/titania.tres` |
| Marauder | Energy Raider; Energy-rich attacker. | 27 / 5 | 8/15/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/marauder.tres` |
| Sentinel | Shielded Defender; Heavy shields and strong Reactor. | 32 / 18 | 8/12/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/sentinel.tres` |
| Reclaimer | Armored Harvester; Strong Hull and Materials production. | 40 / 8 | 14/8/10 | 3/1/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/reclaimer.tres` |
| Marauder Vanguard | Elite Raider | 38 / 12 | 12/18/12 | 2/4/2 | Inactive (enemy has no jump mechanic) | Elite | 2 | 40 | 0.4 | `ships/marauder_vanguard.tres` |
| Sentinel Dreadnought | Armored Dreadnought | 55 / 22 | 15/15/15 | 3/3/3 | Inactive (enemy has no jump mechanic) | Boss | 3 | 30 | 0.15 | `ships/sentinel_dreadnought.tres` |

Enemy profiles also serialize Emergency Jump defaults (14 turns, 0 resistance); these are unused. Elite Salvage rewards use the explicit `ExpeditionRules.elite_salvage_multiplier` (default 2); the table shows effective destruction rewards. Other ranks retain their profile rewards.

Escape: **0 Salvage**, full profile FTL reward once; enemy is completed and cannot be farmed. Resource victory: 6 Salvage (Elite: 12) and full profile FTL reward. Elite victories additionally grant +3 Materials, Energy and Crew for the next battle, stacking with tactical rewards; escapes grant no Elite bonus. Tune `elite_salvage_multiplier` and `elite_resource_bonus` in `encounters/expedition_rules.tres`. Victory repairs: 1 Hull per Salvage, capped at capacity. Standalone combat destruction fallback: 10 Salvage. Enemy registry and resource-victory Salvage: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.

## Card preferences

Player pools contain 25 of 36 Tier 1 identities (69.4%); excluded identities remain expedition rewards. All enemies draw the full base library. Multipliers are soft and strictly positive. Category multipliers use the strongest matching preference, then multiply the family weight.

| Ship | Starting identities | Family weights | Effect preferences | Tactical weights | Decision variation | Resource |
|---|---|---|---|---|---|---|
| Endeavour  | 25 | {} | {} | {} | 0.25 | `ships/endeavour.tres` |
| Thunderbolt | 25 | {} | {} | {} | 0.25 | `ships/thunderbolt.tres` |
| Titiania | 25 | {} | {} | {} | 0.25 | `ships/titania.tres` |
| Marauder | 0 | {"crew":1.15,"energy":1.7} | {"damage":1.8,"steal":1.7} | {"damage":1.8,"disruption":0.5,"hull":0.65,"play_again":1.5,"production":2.8,"resources":0.25,"shields":0.2} | 0.25 | `ships/marauder.tres` |
| Sentinel | 0 | {"energy":1.15} | {"disruption":1.6,"hull":1.8,"production":1.3,"shields":2} | {"damage":0.9,"disruption":0.8,"hull":1.5,"play_again":1,"production":4,"resources":0.3,"shields":0.95} | 0.25 | `ships/sentinel.tres` |
| Reclaimer | 0 | {"materials":1.8} | {"damage":1.2,"economy":1.8,"hull":1.6,"production":2} | {"damage":1.1,"disruption":0.4,"hull":1.05,"play_again":1,"production":10,"resources":0.8,"shields":0.4} | 0.25 | `ships/reclaimer.tres` |
| Marauder Vanguard | 0 | {"crew":1.15,"energy":1.7} | {"damage":1.8,"steal":1.7} | {"damage":1.8,"disruption":0.5,"hull":0.65,"play_again":1.5,"production":2.8,"resources":0.25,"shields":0.2} | 0.08 | `ships/marauder_vanguard.tres` |
| Sentinel Dreadnought | 0 | {"energy":1.15} | {"disruption":1.6,"hull":1.8,"production":1.3,"shields":2} | {"damage":0.9,"disruption":0.8,"hull":1.5,"play_again":1,"production":4,"resources":0.3,"shields":0.95} | 0.08 | `ships/sentinel_dreadnought.tres` |

Tactical scoring preserves affordable immediate wins and fatal-self-damage avoidance. It values public-state deltas and expected random gains; it cannot inspect player cards or sample future combat outcomes. Elites/bosses use lower score variation. Rank does not bypass costs or turn rules.
