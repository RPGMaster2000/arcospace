# Points of interest and generation

Generated from `encounters/expedition_rules.tres` and all referenced PoI Resources. Each completed PoI grants **+1 FTL Drive charge once**, in addition to rewards below. Extra FTL in a row adds to this base. All next-battle values apply once; Hull/Salvage and interstellar charge apply immediately.

| Generation category | Min / max | Weight |
|---|---|---|
| Ordinary | 3 / 4 | 1.0 |
| Hazardous | 0 / 2 | 0.8 |
| Enemy | 1 / 2 | 1.0 |

Total 6 progression encounters plus an independently scheduled optional Trading Outpost; requirement = actual non-trading PoI count + 1. Service visits give zero charge and do not increase the requirement. Valid count combinations are sampled with weight ordinary_weight^ordinary × hazardous_weight^hazards × battle_weight^enemies. Each category samples Resources by encounter_weight without replacement until exhausted. At least 1 enemy; reward floor 1. Invalid bounds warn and fall back to one enemy plus available PoIs (all enemies if no PoIs). No hidden reduction in travel requirement. Tune counts/weights/registry in `encounters/expedition_rules.tres`; type weights in each PoI/ship Resource.

## Ordinary

### Mining Operation

Edit `encounters/mining_operation.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Surface collection | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Automated extraction | None | 0 | 75.0% | +6 Salvage | 25.0%: +2 Salvage · -3 Materials next battle |
| Industrial extraction | Synthesizer ≥3 | 0 | 85.0% | +9 Salvage | 15.0%: +4 Salvage · -4 Materials next battle |
| Deep-core mining | Synthesizer ≥4 | 0 | 55.0% | +14 Salvage · Choose 1 of 3 cards | 45.0%: +5 Salvage · -6 Materials next battle |

### Gas Giant

Edit `encounters/gas_giant.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Atmospheric sampling | None | 0 | 100.0% | +3 Energy next battle | Not rolled |
| Gas harvesting | None | 0 | 75.0% | +6 Energy next battle | 25.0%: +2 Energy next battle · -3 Shields next battle |
| Precision skimming | Reactor ≥3 | 0 | 90.0% | +2 Salvage · +8 Energy next battle | 10.0%: +3 Energy next battle · -4 Shields next battle |
| Deep atmospheric dive | Quarters ≥4 | 0 | 60.0% | +5 Salvage · +12 Energy next battle | 40.0%: -5 Crew next battle · +4 Energy next battle |

### Derelict Starship

Edit `encounters/derelict_starship.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| External salvage | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Board the wreck | None | 0 | 70.0% | +5 Salvage · Choose 1 of 3 cards | 30.0%: +2 Salvage · -3 Crew next battle |
| Engineering recovery | Synthesizer ≥3 | 0 | 85.0% | +7 Salvage · Choose 1 of 3 cards | 15.0%: +3 Salvage · -4 Materials next battle |
| Deploy boarding teams | Quarters ≥4 | 0 | 75.0% | +9 Salvage · Choose 1 of 3 uncommon-or-better cards | 25.0%: +4 Salvage · -5 Crew next battle |

### Abandoned Research Station

Edit `encounters/research_station.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Recover research data | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Access experimental database | None | 0 | 70.0% | +5 Salvage · Upgrade one player card | 30.0%: +2 Salvage · -3 Energy next battle |
| High-energy analysis | Reactor ≥3 | 0 | 85.0% | +7 Salvage · Upgrade one player card | 15.0%: +3 Salvage · -4 Energy next battle |
| Advanced fabrication | Synthesizer ≥4 | 0 | 75.0% | +9 Salvage · Upgrade one player card | 25.0%: +4 Salvage · -5 Materials next battle |

### Spatial Anomaly

Edit `encounters/spatial_anomaly.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Passive observation | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Collect exotic particles | None | 0 | 70.0% | +5 Salvage · +2 EMP Pulse charge next battle | 30.0%: +2 Salvage · -3 Shields next battle |
| Stabilize anomaly | Reactor ≥3 | 0 | 85.0% | +7 Salvage · +3 EMP Pulse charge next battle | 15.0%: +3 Salvage · +1 EMP Pulse offline turns next battle |
| Reinforce EMP Pulse systems | Quarters ≥4 | 0 | 75.0% | +9 Salvage · +5 EMP Pulse charge next battle | 25.0%: +4 Salvage · +2 EMP Pulse offline turns next battle |

## Hazardous

### Radiation Nebula

Edit `encounters/radiation_nebula.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Quick scan | None | 0 | 100.0% | +3 Salvage · -2 Shields next battle | Not rolled |
| Collect isotopes | None | 0 | 75.0% | +8 Salvage · -3 Shields next battle | 25.0%: +2 Salvage · -5 Shields next battle |
| Harvest particles | Synthesizer ≥3 | 0 | 70.0% | +10 Salvage · +5 Energy next battle · -4 Shields next battle | 30.0%: +3 Salvage · -6 Energy next battle |
| Shielded expedition | Reactor ≥4 | 0 | 85.0% | +12 Salvage · -2 permanent Hull · +5 Energy next battle | 15.0%: +4 Salvage · -4 permanent Hull |

### Distress Signal

Edit `encounters/distress_signal.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Relay coordinates | None | 0 | 100.0% | +3 Salvage · -2 Crew next battle | Not rolled |
| Dispatch rescue crew | None | 0 | 70.0% | +5 Salvage · -2 Crew next battle · Choose 1 of 3 cards | 30.0%: +2 Salvage · -4 Crew next battle |
| Specialist rescue | Quarters ≥3 | 0 | 85.0% | +7 Salvage · -2 Crew next battle · Choose 1 of 3 uncommon-or-better cards | 15.0%: +3 Salvage · -4 Crew next battle |
| Fabricate relief kits | Synthesizer ≥3 | 0 | 100.0% | +8 Salvage · +3 Crew next battle · -4 Materials next battle | Not rolled |

### Pirate Debris Field

Edit `encounters/pirate_debris_field.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Drone perimeter scan | None | 0 | 100.0% | +3 Salvage · -1 permanent Hull | Not rolled |
| Recover cargo | None | 0 | 65.0% | +10 Salvage · -2 permanent Hull | 35.0%: +2 Salvage · -5 permanent Hull |
| Disarm wreckage | Synthesizer ≥3 | 0 | 80.0% | +10 Salvage · -2 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 20.0%: +4 Salvage · -4 permanent Hull |
| Board pirate flagship | Quarters ≥4 | 0 | 70.0% | +14 Salvage · -4 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 30.0%: +5 Salvage · -7 permanent Hull |

### Unstable Wormhole

Edit `encounters/unstable_wormhole.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Map the perimeter | None | 0 | 100.0% | +3 Salvage · +1 EMP Pulse offline turns next battle | Not rolled |
| Probe the shortcut | None | 0 | 65.0% | +1 extra FTL Drive charge · +5 Salvage | 35.0%: +2 Salvage · -4 Shields next battle |
| Stabilize corridor | Reactor ≥4 | 0 | 80.0% | +2 extra FTL Drive charge · +7 Salvage | 20.0%: +3 Salvage · +2 EMP Pulse offline turns next battle |
| Reinforce transit probe | Synthesizer ≥3 | 0 | 75.0% | +2 extra FTL Drive charge · +9 Salvage | 25.0%: +4 Salvage · -4 Energy next battle |

### Quarantined Colony

Edit `encounters/quarantined_colony.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Remote supply exchange | None | 0 | 100.0% | +3 Salvage · -2 Materials next battle | Not rolled |
| Accept medical repairs | None | 0 | 100.0% | +6 permanent Hull · -3 Crew next battle | Not rolled |
| Recover research | Reactor ≥3 | 0 | 80.0% | +6 Salvage · -3 Energy next battle · Upgrade one player card | 20.0%: +3 Salvage · -5 Energy next battle |
| Evacuate scientists | Quarters ≥4 | 0 | 85.0% | +8 Salvage · -3 Crew next battle · Choose 1 of 3 uncommon-or-better cards | 15.0%: +4 Salvage · -5 Crew next battle |

## Services

First station: system 2–3; subsequent system-number intervals 2–3, hard cap 3. The seeded station RNG is independent of encounter/loot RNG. Unlimited purchases and free revisits until departure, with no travel charge, requirement increase, penalties or survey. Pending paid choices must resolve before another purchase or departure. Each confirmation revision can spend once.

The same Hull service tile repairs damaged Hull for 1 Salvage/Hull up to capacity, then switches to Install Ablative Plating for 2 Salvage/point up to capacity +10. It selects an affordable quantity, previews total cost/result and rejects zero confirmation; at +10 it remains in place disabled. Shared quantity bounds live in `scripts/repair_rules.gd`; post-battle repairs cost 2 Salvage/Hull. Field repairs are separate, accessed through the system Hull popup at 2 Salvage/Hull and cannot create plating. Supply/card base prices and shipyard base price are editable in `encounters/trading_outpost.tres` approach Salvage Cost; supply amount/production amount remain editable outcome Resources. Shipyard cost for purchase n: base + increment × (n−1) + acceleration × (n−1) × (n−2) / 2. Current increment 15, acceleration 5; prices 25, 40, 60, 85, 115, 150, 190. Counter combines all production categories and resets only when a later station appears; permanent upgrades persist. Intervals and escalation parameters: `ExpeditionRules` Inspector. The table shows initial prices; repair amount is variable.

### Trading Outpost

Edit `encounters/trading_outpost.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Hull repairs | None | 1 | 100.0% | +1 permanent Hull | Not rolled |
| Purchase supplies | None | 7 | 100.0% | +5 starting resource of choice next battle | Not rolled |
| Acquire card | None | 15 | 100.0% | Choose 1 of 3 cards | Not rolled |
| Shipyard improvements | None | 25 | 100.0% | +1 production of choice for expedition | Not rolled |

## Progression safeguard

If a PoI has no affordable, unlocked approach whose worst possible Hull outcome leaves Hull >0, **Navigation survey** becomes available. Completing the survey forfeits all normal loot and grants only that PoI's +1 charge, with guaranteed next-battle penalty `{"energy":-3}`. The independent Trading Outpost never needs or permits a survey. Entering and leaving it is free; only a confirmed purchase spends Salvage. Unlimited affordable services and free revisits while present; ignoring a station never blocks departure. Tune `ExpeditionRules.survey_penalty`. Full-Hull repairs are locked. Return leaves an uncompleted PoI untouched.

All escaped enemies complete normally and award their full profile charge. Repeated result/approach calls cannot award more charge. A normal transition starts the next system with `min(2, max(0, current_ftl - required_ftl))` charge (Inspector cap may be reduced). New expeditions start at 0. Mandatory Boss encounters must resolve before any transition. Pending choices must be resolved before leaving. Hull 0 ends the expedition; voluntarily lethal approaches and battle losses remain possible. The simulation guarantees charge availability for surviving players, not victory against every enemy. **Not implemented:** hostile follow-up battles from pirate debris; current pirate hazards use Hull costs.

## Expedition difficulty and milestones

Inspector: `encounters/expedition_rules.tres` → Progression → `resources/expedition_progression.tres` (script `scripts/expedition_progression.gd`).

| Property | Initial value |
|---|---|
| FTL carryover cap | 2 (editable 0–2) |
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

Normal-system carryover is `min(cap, max(0, current_ftl - required_ftl))`, cap default and hard maximum 2. Surpluses 0/1/2/4 therefore yield 0/1/2/2. The old requirement remains non-trading PoI count + 1; rewards and charge generation are unchanged. There is no additional counter or currency. New expeditions reset to 0. In the shipping six-slot compositions, the next requirement exceeds carried charge.

Systems 6, 12, 18, 24, … replace one enemy slot with a mandatory Sentinel Dreadnought (or the configured existing Boss). They keep six slots, all PoI slots, their normal requirement, and the independent station schedule. Only one encounter is marked mandatory. Missing milestone metadata fails closed. Sufficient FTL never bypasses an unresolved Boss; a blocked jump consumes no charge or RNG.

Combat victory or successful existing EMP Pulse marks the encounter complete and grants the profile's 3 FTL once. Destruction retains 30 Salvage; resource victory retains 6; escape grants 0 Salvage. Resolution records `defeated` versus `escaped` for future defeat-only reward checks. Escape does not perform a system transition: return to the system screen and use the ordinary FTL transition, including carryover, once. Boss stats use the same level formula: system 6 has 57 Hull / 23 Shields / 16 of each resource / 3 of each production; system 12 has 61 / 25 / 18 / 3.
