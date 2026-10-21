# Ships

Generated from loaded Resources by `tools/generate_balance_docs.gd`. Edit the indicated `.tres` in Godot; regenerate after balancing. M/E/C = Materials/Energy/Crew; S/R/Q = Synthesizer/Reactor/Quarters. Production identifiers: `synthesizer` / `reactor` / `quarters`.

| Ship | Type / special attribute | Hull / Shields | M/E/C | S/R/Q | EMP Pulse turns / resistance | Rank | FTL reward (defeat **or escape**) | Destruction Salvage | Generation weight | Edit |
|---|---|---|---|---|---|---|---|---|---|---|
| Endeavour | Balanced Cruiser; Balanced reserves and production; average EMP Pulse charging. | 35 / 12 | 10/10/10 | 2/2/2 | 14 / 0.0% | Player | — | — | — | `ships/player/endeavour.tres` |
| Thunderbolt | Fast and Tactical; Fast, resistant EMP Pulse; strong Shields and Energy production, weaker Hull. | 28 / 17 | 14/10/8 | 1/3/2 | 11 / 35.0% | Player | — | — | — | `ships/player/thunderbolt.tres` |
| Titania | Mobile Stronghold; Heavy reserves and Materials/Crew production; weaker Shields and slow, vulnerable EMP Pulse. | 40 / 6 | 16/17/16 | 3/2/3 | 17 / -10.0% | Player | — | — | — | `ships/player/titania.tres` |
| Ganymede | Industrial Cruiser; Materials specialist; extra Crew reserves support construction and industrial offense. | 35 / 12 | 8/12/10 | 3/1/2 | 14 / 0.0% | Player | — | — | — | `ships/player/ganymede.tres` |
| Callisto | Shield Cruiser; Energy specialist; extra Materials reserves support Shields and Reactor development. | 35 / 12 | 10/8/12 | 2/3/1 | 14 / 0.0% | Player | — | — | — | `ships/player/callisto.tres` |
| Orion | Boarding Cruiser; Crew specialist; extra Energy reserves support boarding, theft and disruption. | 35 / 12 | 8/12/10 | 1/2/3 | 14 / 0.0% | Player | — | — | — | `ships/player/orion.tres` |
| Marauder | Energy Raider; Energy-rich attacker. | 27 / 5 | 8/15/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/enemy/marauder.tres` |
| Sentinel | Shielded Defender; Heavy shields and strong Reactor. | 32 / 18 | 8/12/10 | 1/3/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/enemy/sentinel.tres` |
| Reclaimer | Armored Harvester; Strong Hull and Materials production. | 40 / 8 | 14/8/10 | 3/1/2 | Inactive (enemy has no jump mechanic) | Standard | 1 | 10 | 1.0 | `ships/enemy/reclaimer.tres` |
| Marauder Vanguard | Elite Raider | 38 / 12 | 12/18/12 | 2/4/2 | Inactive (enemy has no jump mechanic) | Elite | 2 | 40 | 0.4 | `ships/enemy/marauder_vanguard.tres` |
| Sentinel Dreadnought | Armored Dreadnought | 55 / 22 | 15/15/15 | 3/3/3 | Inactive (enemy has no jump mechanic) | Boss | 3 | 30 | 0.15 | `ships/enemy/sentinel_dreadnought.tres` |

Enemy profiles also serialize EMP Pulse defaults (14 turns, 0 resistance); these are unused. Elite Salvage rewards use the explicit `ExpeditionRules.elite_salvage_multiplier` (default 2); the table shows effective destruction rewards. Other ranks retain their profile rewards.

Escape: **0 Salvage**, full profile FTL reward once; enemy is completed and cannot be farmed. Systems Failure uses the same Salvage and FTL rewards as destruction. Elite victories additionally grant +3 Materials, Energy and Crew for the next battle, stacking with tactical rewards; escapes grant no Elite bonus. Tune `elite_salvage_multiplier` and `elite_resource_bonus` in `encounters/expedition_rules.tres`. Victory repairs: 2 Salvage per Hull, capped at capacity. Standalone combat destruction fallback: 10 Salvage. Enemy registry and reward settings: `encounters/expedition_rules.tres`; repair rate: `scripts/board.gd`.

## Card preferences

Player starting pools retain 25 original Tier 1 identities plus three targeted sabotage identities each (28 total); the library contains 52 Tier 1 and 22 Tier 2 identities. Unowned identities remain expedition rewards. All enemies draw the full base library. Multipliers are soft and strictly positive. Category multipliers use the strongest matching preference, then multiply the family weight.

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

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Hull Overhaul, Breach Charge, Salvage Strike, Overloaded Warhead.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion.

### Thunderbolt starting identities

- **Materials:** Shield Plating, Synthesizer Upgrade, Shield Disruptor, Reactor Salvage.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, System Disruption, Energy Siphon, Cargo Raid, Supply Diversion, Desperate Conversion.

### Titania starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Overloaded Warhead.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.

### Ganymede starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Reactor Salvage, Overloaded Warhead.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Energy Siphon, Cargo Raid, Supply Diversion.

### Callisto starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Salvage Strike, Reactor Salvage.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Quarters Upgrade, Energy Siphon, Cargo Raid, Supply Diversion.

### Orion starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Salvage Strike, Reactor Salvage.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, System Disruption, Torpedo Salvo, Energy Siphon, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.


## Combat upgrade events and Chasedown

Non-escape victories offer up to 1 / 2 / 3 / 3 upgrades for Chasedown / standard / elite / boss battles. Each selection must be a different card identity within that event; a later event can upgrade the identity again. Existing two-level limits remain. Finish skips unused choices; exhausted combat upgrades grant no extra Salvage. EMP Pulse escape grants no upgrades or Salvage. Quantities: `ExpeditionRules` → Combat Upgrades.

Sublight Chasedown: 5% per valid PoI-to-PoI movement, limit 1 per system. Initial entry, menus, invalid/same destinations, battle return and FTL travel never roll. Uses ordinary enemies, existing scaling and battle scene, gives exactly +1 FTL once on victory or escape, then resumes the preserved destination. See [implementation and tuning](../chasedown_rewards.md).

## Expedition difficulty and milestones

Inspector: `encounters/expedition_rules.tres` → Progression → `resources/expedition_progression.tres` (script `scripts/expedition/expedition_progression.gd`).

| Property | Initial value |
|---|---|
| FTL carryover cap | 0 (editable 0–2) |
| Systems per difficulty increase | 3 |
| Hull bonus per extra level | +2 |
| Shields bonus per extra level | +1 |
| Each starting resource per extra level | +1 |
| Each production attribute per extra level | +0.25, accumulated then floored |
| Elite probability increase per extra level | +0.025 (2.5 percentage points) |
| Maximum Elite probability | 0.35 |
| Mandatory Boss interval | 6 systems |

`level = 1 + floor((system_number - 1) / 3)`; `steps = level - 1`. Hull/Shields/resources add `steps × bonus`; each production adds `floor(steps × 0.25)`. This makes systems 1–3 baseline; 4–6 level 2; 7–9 level 3; 10–12 level 4. The first production increase is system 13. Only system number matters: optional encounter count does not accelerate scaling. Effective enemy profiles are shallow copies; shared ship Resources, card values, AI and profile rewards are unchanged.

| Systems | Extra Hull / Shields | Each resource | Each production |
|---|---|---|---|
| 1–3 | 0 / 0 | 0 | 0 |
| 4–6 | +2 / +1 | +1 | 0 |
| 7–9 | +4 / +2 | +2 | 0 |
| 10–12 | +6 / +3 | +3 | 0 |
| 13–15 | +8 / +4 | +4 | +1 |
| 16–18 | +10 / +5 | +5 | +1 |

Systems 1–3 retain the original weighted enemy selector. Thereafter, for each enemy slot, `base = available Elite weight / total available weight` and `p = min(0.35, base + steps × 0.025)`. Choose Elite versus other profiles with p, then use the original weights within that bucket. Draws remain without replacement until a bucket registry is exhausted as before. The full shipping registry starts at 11.27%; its first-slot chance becomes 13.77% on system 4, 16.27% on system 7, 18.77% on system 10, capped at 35%. Conditional odds vary after profiles leave the available registry. An empty bucket falls back to valid profiles; an Inspector pool containing only Elites necessarily has probability 1.

Normal-system carryover still uses `min(cap, max(0, current_ftl - required_ftl))`, with the shipping Resource and script default cap both **0** (Inspector range 0–2). Every new system therefore begins at zero, regardless of surplus. The requirement remains non-trading PoI count + 1. Charge earned within a system is retained until departure; EMP Pulse is separate and unchanged.

Systems 6, 12, 18, 24, … replace one enemy slot with a mandatory Sentinel Dreadnought (or the configured existing Boss). They keep six slots, all PoI slots, their normal requirement, and the independent station schedule. Only one encounter is marked mandatory. Missing milestone metadata fails closed. Sufficient FTL never bypasses an unresolved Boss; a blocked jump consumes no charge or RNG.

Combat victory or successful existing EMP Pulse marks the encounter complete and grants the profile's 3 FTL once. Destruction and Systems Failure retain the profile’s 30 Salvage; escape grants 0 Salvage. Resolution records `defeated` versus `escaped` for future defeat-only reward checks. Escape does not perform a system transition: return to the system screen and use the ordinary FTL transition, with zero carried charge, once. Boss stats use the same level formula: system 6 has 57 Hull / 23 Shields / 16 of each resource / 3 of each production; system 12 has 61 / 25 / 18 / 3.
