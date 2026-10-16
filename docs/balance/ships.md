# Ships

Generated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; S/R/Q = Synthesizer/Reactor/Quarters. Production identifiers: `synthesizer` / `reactor` / `quarters`.

| Ship | Type / special attribute | Hull / Shields | M/E/C | S/R/Q | Emergency Jump turns / resistance | Rank | FTL reward (defeat **or escape**) | Destruction Salvage | Generation weight | Edit |
|---|---|---|---|---|---|---|---|---|---|---|
| Wayfarer | Balanced Cruiser; Balanced economy; average escape speed. | 35 / 10 | 10/10/10 | 2/2/2 | 14 / 0.0% | Player | — | — | — | `ships/wayfarer.tres` |
| Specter | Balanced Cruiser; Fast, resistant Emergency Jump; fragile Hull and low Materials production. | 28 / 15 | 8/14/10 | 1/3/2 | 11 / 25.0% | Player | — | — | — | `ships/specter.tres` |
| Bastion | Balanced Cruiser; Strong Hull and industry; slow, vulnerable Emergency Jump. | 42 / 6 | 14/8/10 | 3/1/2 | 17 / -10.0% | Player | — | — | — | `ships/bastion.tres` |
| Marauder | Energy Raider; Energy-rich attacker. | 27 / 5 | 8/15/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/marauder.tres` |
| Sentinel | Shielded Defender; Heavy shields and strong Reactor. | 32 / 18 | 8/12/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/sentinel.tres` |
| Reclaimer | Armored Harvester; Strong Hull and Materials production. | 40 / 8 | 14/8/10 | 3/1/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/reclaimer.tres` |
| Marauder Vanguard | Elite Raider | 38 / 12 | 12/18/12 | 2/4/2 | Inactive (enemy has no jump mechanic) | Elite | 2 | 20 | 0.4 | `ships/marauder_vanguard.tres` |
| Sentinel Dreadnought | Armored Dreadnought | 55 / 22 | 15/15/15 | 3/3/3 | Inactive (enemy has no jump mechanic) | Boss | 3 | 30 | 0.15 | `ships/sentinel_dreadnought.tres` |

Enemy profiles also serialize Emergency Jump defaults (14 turns, 0 resistance); these are unused. No rank-based hidden multipliers. Rank is a balancing label; stats and both rewards are independent fields.

Escape: **0 Salvage**, full profile FTL reward once; enemy is completed and cannot be farmed. Resource victory: 6 Salvage and full profile FTL reward. Victory repairs: 1 Hull per Salvage, capped at capacity. Standalone combat destruction fallback: 10 Salvage. Enemy registry and resource-victory Salvage: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.
