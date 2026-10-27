# Points of interest and generation

Generated from `encounters/expedition_rules.tres` and all referenced PoI Resources. Each completed regular PoI increases system pressure once, in addition to rewards below. FTL Access comes only from an objective. All next-battle values apply once; Hull/Salvage apply immediately.

| Generation category | Min / max | Weight |
|---|---|---|
| Ordinary | 4 / 6 | 1.0 |
| Hazardous | 0 / 3 | 0.8 |
| Enemy | 1 / 3 | 1.0 |

Total 9 progression encounters plus an independent profile-selected Trading Outpost. Composition weights multiply profile and rule category biases; Resources sample by encounter_weight and profile PoI biases without replacement until exhausted. Objective routes replace ordinary slots: guaranteed direct Fuel Depot; optionally Sensor Relay then Ancient Navigation Array. Routes and prerequisites remain pressure-safe. See [exploration prototype](../star_system_exploration.md) for tuning.

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
| Probe the shortcut | None | 0 | 40.0% | +5 Salvage | 60.0%: +2 Salvage · -8 Shields next battle |
| Stabilize corridor | Reactor ≥4 | 0 | 50.0% | +7 Salvage | 50.0%: +3 Salvage · +3 EMP Pulse offline turns next battle |
| Reinforce transit probe | Synthesizer ≥3 | 0 | 45.0% | +9 Salvage | 55.0%: +4 Salvage · -8 Energy next battle |

### Quarantined Colony

Edit `encounters/quarantined_colony.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Remote supply exchange | None | 0 | 100.0% | +3 Salvage · -2 Materials next battle | Not rolled |
| Accept medical repairs | None | 0 | 100.0% | +6 permanent Hull · -3 Crew next battle | Not rolled |
| Recover research | Reactor ≥3 | 0 | 80.0% | +6 Salvage · -3 Energy next battle · Upgrade one player card | 20.0%: +3 Salvage · -5 Energy next battle |
| Evacuate scientists | Quarters ≥4 | 0 | 85.0% | +8 Salvage · -3 Crew next battle · Choose 1 of 3 uncommon-or-better cards | 15.0%: +4 Salvage · -5 Crew next battle |

### Raider Cache

Edit `encounters/raider_cache.tres`; expand Approaches → Success / Failure. Generation weight (ignored for service stations): 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Drone perimeter scan | None | 0 | 100.0% | +3 Salvage · -1 permanent Hull | Not rolled |
| Recover cargo | None | 0 | 65.0% | +10 Salvage · -2 permanent Hull | 35.0%: +2 Salvage · -5 permanent Hull |
| Disarm wreckage | Synthesizer ≥3 | 0 | 80.0% | +10 Salvage · -2 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 20.0%: +4 Salvage · -4 permanent Hull |
| Board pirate flagship | Quarters ≥4 | 0 | 70.0% | +14 Salvage · -4 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 30.0%: +5 Salvage · -7 permanent Hull |

## Services

Trading Outpost probability: Quiet Frontier 100%, Industrial 8%, Hostile 4%, Ancient 4%. Station RNG is independent of encounter/loot RNG. Unlimited purchases and free revisits until departure, with no pressure or FTL Access reward. Pending paid choices must resolve before another purchase or departure. Each confirmation revision can spend once.

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

If a PoI has no affordable, unlocked approach whose worst possible Hull outcome leaves Hull >0, **Navigation survey** becomes available. Completing the survey forfeits all normal loot and completes the encounter with +1 pressure and guaranteed next-battle penalty `{"energy":-3}`. The independent Trading Outpost never needs or permits a survey. Entering and leaving it is free; only a confirmed purchase spends Salvage. Unlimited affordable services and free revisits while present; ignoring a station never blocks departure. Tune `ExpeditionRules.survey_penalty`. Full-Hull repairs are locked. Return leaves an uncompleted PoI untouched.

All escaped regular enemies complete normally and increase pressure once. Repeated result/approach calls cannot duplicate pressure or rewards. FTL Access unlocks by completing any access objective and persists until Jump. Mandatory Boss encounters independently gate departure. Pending choices must resolve before leaving. Hull 0 ends the expedition. At least one free, deterministic direct access route remains viable at any pressure.

## Expedition progression

Inspector: encounters/expedition_rules.tres -> Progression -> resources/expedition_progression.tres.

New systems start with zero pressure and locked FTL Access. Completing any access objective unlocks Jump, independently of mandatory Boss restrictions.

Level = 1 + floor((system - 1) / 3); steps = level - 1. Per extra level: +2 Hull, +1 Shields, +1 each starting resource; each production adds floor(steps * 0.25). Stats are copied, never written to shared ShipData. Optional encounter count is irrelevant.

Elite selection retains original baseline odds in level 1, then uses min(0.35, available Elite weight / total available weight + steps * 0.025). Each bucket retains profile weights; unavailable buckets fall back. A pool consisting only of Elites has probability 1.

Every 6 systems, starting at system 6, one enemy slot becomes a mandatory existing Boss (nine slots retained). Resolve by combat victory or existing EMP Pulse before normal FTL travel. Both resolve the Boss gate; FTL Access remains a separate objective. Destruction/resource/escape Salvage remains distinct. Escape never transitions systems. Missing mandatory metadata blocks travel.
