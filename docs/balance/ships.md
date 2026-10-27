# Ships

Generated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; S/R/Q = Synthesizer/Reactor/Quarters. Production identifiers: `synthesizer` / `reactor` / `quarters`.

| Ship | Type / special attribute | Hull / Shields | M/E/C | S/R/Q | EMP Pulse turns / resistance | Rank | Destruction Salvage | Generation weight | Edit |
|---|---|---|---|---|---|---|---|---|---|
| Endeavour | Balanced Cruiser; Balanced reserves and production; average EMP Pulse charging. | 35 / 12 | 10/10/10 | 2/2/2 | 14 / 0.0% | Player | — | — | `ships/player/endeavour.tres` |
| Thunderbolt | Fast and Tactical; Fast, resistant EMP Pulse; strong Shields and Energy production, weaker Hull. | 28 / 17 | 14/10/8 | 1/3/2 | 11 / 35.0% | Player | — | — | `ships/player/thunderbolt.tres` |
| Titania | Mobile Stronghold; Heavy reserves and Materials/Crew production; weaker Shields and slow, vulnerable EMP Pulse. | 40 / 6 | 16/17/16 | 3/2/3 | 17 / -10.0% | Player | — | — | `ships/player/titania.tres` |
| Ganymede | Industrial Cruiser; Materials specialist; extra Crew reserves support construction and industrial offense. | 35 / 12 | 8/12/10 | 3/1/2 | 14 / 0.0% | Player | — | — | `ships/player/ganymede.tres` |
| Callisto | Shield Cruiser; Energy specialist; extra Materials reserves support Shields and Reactor development. | 35 / 12 | 10/8/12 | 2/3/1 | 14 / 0.0% | Player | — | — | `ships/player/callisto.tres` |
| Orion | Boarding Cruiser; Crew specialist; extra Energy reserves support boarding, theft and disruption. | 35 / 12 | 8/12/10 | 1/2/3 | 14 / 0.0% | Player | — | — | `ships/player/orion.tres` |
| Marauder | Energy Raider; Energy-rich attacker. | 27 / 5 | 8/15/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/marauder.tres` |
| Sentinel | Shielded Defender; Heavy shields and strong Reactor. | 32 / 18 | 8/12/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/sentinel.tres` |
| Reclaimer | Armored Harvester; Strong Hull and Materials production. | 40 / 8 | 14/8/10 | 3/1/2 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/reclaimer.tres` |
| Marauder Vanguard | Elite Raider | 38 / 12 | 12/18/12 | 2/4/2 | Inactive (enemy has no jump mechanic) | Elite | 40 | 0.4 | `ships/enemy/marauder_vanguard.tres` |
| Sentinel Dreadnought | Armored Dreadnought | 55 / 22 | 15/15/15 | 3/3/3 | Inactive (enemy has no jump mechanic) | Boss | 30 | 0.15 | `ships/enemy/sentinel_dreadnought.tres` |
| Rustjack | Scrap Raider; Opportunistic scrap raider: demolition, salvage and theft. | 32 / 4 | 14/8/10 | 3/1/2 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/rustjack.tres` |
| AXIOM-7 | Autonomous Interceptor; Precise energy interceptor: shield-breaking weapons and disruption. | 29 / 16 | 8/14/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/axiom_7.tres` |
| The Hollow Choir | Organic Vessel; Living vessel: restoration, defensive buildup and steady crew attacks. | 42 / 4 | 12/8/12 | 2/1/3 | Inactive (enemy has no jump mechanic) | Standard | 10 | 1.0 | `ships/enemy/hollow_choir.tres` |

Enemy profiles also serialize EMP Pulse defaults (14 turns, 0 resistance); these are unused. Elite Salvage rewards use the explicit `ExpeditionRules.elite_salvage_multiplier` (default 2); the table shows effective destruction rewards. Other ranks retain their profile rewards.

Escape: **0 Salvage**; enemy is completed and cannot be farmed. Systems Failure uses the same Salvage rewards as destruction. Regular completed encounters increase pressure once; Chasedowns do not. Combat never grants FTL Access. Elite victories additionally grant +3 Materials, Energy and Crew for the next battle, stacking with tactical rewards; escapes grant no Elite bonus. Tune `elite_salvage_multiplier` and `elite_resource_bonus` in `encounters/expedition_rules.tres`. Victory repairs: 2 Salvage per Hull, capped at capacity. Standalone combat destruction fallback: 10 Salvage. Enemy registry and reward settings: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.

## Card preferences

Player starting pools retain 25 original Tier 1 identities plus three targeted sabotage identities each (28 total); unowned identities remain expedition rewards. All enemies draw the full base library. Multipliers are soft and strictly positive. Category multipliers use the strongest matching preference, then multiply the family weight.

| Ship | Starting identities | Family weights | Effect preferences | Tactical weights | Decision variation | Resource |
|---|---|---|---|---|---|---|
| Endeavour | 28 | {} | {} | {} | 0.25 | `ships/player/endeavour.tres` |
| Thunderbolt | 28 | {} | {} | {} | 0.25 | `ships/player/thunderbolt.tres` |
| Titania | 28 | {} | {} | {} | 0.25 | `ships/player/titania.tres` |
| Ganymede | 28 | {} | {} | {} | 0.25 | `ships/player/ganymede.tres` |
| Callisto | 28 | {} | {} | {} | 0.25 | `ships/player/callisto.tres` |
| Orion | 28 | {} | {} | {} | 0.25 | `ships/player/orion.tres` |
| Marauder | 0 | {"crew":1.15,"energy":1.7} | {"damage":1.8,"steal":1.7} | {"damage":1.8,"disruption":0.5,"hull":0.65,"play_again":1.5,"production":2.8,"resources":0.25,"shields":0.2} | 0.25 | `ships/enemy/marauder.tres` |
| Sentinel | 0 | {"energy":1.15} | {"disruption":1.6,"hull":1.8,"production":1.3,"shields":2} | {"damage":0.9,"disruption":0.8,"hull":1.5,"play_again":1,"production":4,"resources":0.3,"shields":0.95} | 0.25 | `ships/enemy/sentinel.tres` |
| Reclaimer | 0 | {"materials":1.8} | {"damage":1.2,"economy":1.8,"hull":1.6,"production":2} | {"damage":1.1,"disruption":0.4,"hull":1.05,"play_again":1,"production":10,"resources":0.8,"shields":0.4} | 0.25 | `ships/enemy/reclaimer.tres` |
| Marauder Vanguard | 0 | {"crew":1.15,"energy":1.7} | {"damage":1.8,"steal":1.7} | {"damage":1.8,"disruption":0.5,"hull":0.65,"play_again":1.5,"production":2.8,"resources":0.25,"shields":0.2} | 0.08 | `ships/enemy/marauder_vanguard.tres` |
| Sentinel Dreadnought | 0 | {"energy":1.15} | {"disruption":1.6,"hull":1.8,"production":1.3,"shields":2} | {"damage":0.9,"disruption":0.8,"hull":1.5,"play_again":1,"production":4,"resources":0.3,"shields":0.95} | 0.08 | `ships/enemy/sentinel_dreadnought.tres` |
| Rustjack | 20 | {"crew":1.1,"energy":0.8,"materials":1.5} | {"damage":1.5,"disruption":1.5,"hull":1.2,"steal":1.8} | {"damage":1.6,"disruption":1.1,"hull":1,"play_again":1.2,"production":3,"resources":0.45,"shields":0.3} | 0.22 | `ships/enemy/rustjack.tres` |
| AXIOM-7 | 20 | {"crew":1,"energy":1.6,"materials":0.8} | {"damage":1.6,"disruption":1.5,"shields":1.2} | {"damage":1.5,"disruption":1,"hull":0.8,"play_again":1.1,"production":3.5,"resources":0.3,"shields":0.65} | 0.04 | `ships/enemy/axiom_7.tres` |
| The Hollow Choir | 20 | {"crew":1.4,"energy":0.8,"materials":1.25} | {"damage":0.9,"economy":1.1,"hull":1.3,"shields":1.25} | {"damage":0.95,"disruption":0.35,"hull":1.3,"play_again":1,"production":3.5,"resources":0.3,"shields":0.85} | 0.12 | `ships/enemy/hollow_choir.tres` |

Tactical scoring preserves affordable immediate wins and fatal-self-damage avoidance. It values public-state deltas and expected random gains; it cannot inspect player cards or sample future combat outcomes. Elites/bosses use lower score variation. Rank does not bypass costs or turn rules.

## Six starting pools

Each pool has 28 distinct identities: its original 25 Tier 1 cards plus one targeted sabotage card per resource family. Added Tier 2 cards remain locked until round 3. Specialization comes only from membership; no extra player family/effect draw weights. The opening remains 2 Materials / 2 Energy / 2 Crew. New profiles inherit Endeavour's Hull tint and default model fallback; Model Scene remains independently editable.

| Ship | Materials | Energy | Crew | Total |
|---|---|---|---|---|
| Endeavour | 10 | 10 | 8 | 28 |
| Thunderbolt | 5 | 14 | 9 | 28 |
| Titania | 12 | 6 | 10 | 28 |
| Ganymede | 13 | 7 | 8 | 28 |
| Callisto | 8 | 14 | 6 | 28 |
| Orion | 7 | 9 | 12 | 28 |

### Endeavour starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Hull Overhaul, Breach Charge, Salvage Strike, Overloaded Warhead, Industrial Interference.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater, Reactor Interference.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion, Personnel Disruption.

### Thunderbolt starting identities

- **Materials:** Shield Plating, Synthesizer Upgrade, Shield Disruptor, Reactor Salvage, Industrial Interference.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse, Core Destabilization.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, System Disruption, Energy Siphon, Cargo Raid, Supply Diversion, Desperate Conversion, Command Infiltration.

### Titania starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Overloaded Warhead, Fabrication Strike.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge, Reactor Interference.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion, Personnel Disruption.

### Ganymede starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Reactor Salvage, Overloaded Warhead, Fabrication Strike.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge, Pulse Repeater, Core Destabilization.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Energy Siphon, Cargo Raid, Supply Diversion, Personnel Disruption.

### Callisto starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Salvage Strike, Reactor Salvage, Industrial Interference.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse, Core Destabilization.
- **Crew:** Boarding Party, Quarters Upgrade, Energy Siphon, Cargo Raid, Supply Diversion, Command Infiltration.

### Orion starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Salvage Strike, Reactor Salvage, Fabrication Strike.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater, Reactor Interference.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, System Disruption, Torpedo Salvo, Energy Siphon, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion, Command Infiltration.


## Combat upgrade events and Chasedown

Non-escape victories offer up to 1 / 2 / 3 / 3 upgrades for Chasedown / standard / elite / boss battles. Each selection must be a different card identity within that event; a later event can upgrade the identity again. Existing two-level limits remain. Finish skips unused choices; exhausted combat upgrades grant no extra Salvage. EMP Pulse escape grants no upgrades or Salvage. Quantities: `ExpeditionRules` → Combat Upgrades.

Sublight Chasedown: base 5% before pressure/profile modifiers, limit 1 per system. Eligible PoI and free travel share one roll per uninterrupted journey and a persisted 10-second active-gameplay cooldown. Initial entry, menus, invalid/same destinations, redirects, battle return and FTL travel never roll. Chasedowns grant no pressure or FTL Access. Interruption cancels the destination and leaves the ship at the interception position until a new movement order. See [implementation and tuning](../chasedown_rewards.md).

## Expedition progression

Inspector: encounters/expedition_rules.tres -> Progression -> resources/expedition_progression.tres.

New systems start with zero pressure and locked FTL Access. Completing any access objective unlocks Jump, independently of mandatory Boss restrictions.

Level = 1 + floor((system - 1) / 3); steps = level - 1. Per extra level: +2 Hull, +1 Shields, +1 each starting resource; each production adds floor(steps * 0.25). Stats are copied, never written to shared ShipData. Optional encounter count is irrelevant.

Elite selection retains original baseline odds in level 1, then uses min(0.35, available Elite weight / total available weight + steps * 0.025). Each bucket retains profile weights; unavailable buckets fall back. A pool consisting only of Elites has probability 1.

Every 6 systems, starting at system 6, one enemy slot becomes a mandatory existing Boss (nine slots retained). Resolve by combat victory or existing EMP Pulse before normal FTL travel. Both resolve the Boss gate; FTL Access remains a separate objective. Destruction/resource/escape Salvage remains distinct. Escape never transitions systems. Missing mandatory metadata blocks travel.
