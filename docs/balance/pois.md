# Points of interest and generation

Generated from `encounters/expedition_rules.tres` and all referenced PoI Resources. Each completed PoI grants **+1 FTL Drive charge once**, in addition to rewards below. Extra FTL in a row adds to this base. All next-battle values apply once; Hull/Salvage and interstellar charge apply immediately.

| Generation category | Min / max | Weight |
|---|---|---|
| Ordinary | 3 / 4 | 1.0 |
| Hazardous | 0 / 2 | 0.8 |
| Enemy | 1 / 2 | 1.0 |

Total 6; requirement = actual PoI count + 1. Valid count combinations are sampled with weight ordinary_weight^ordinary × hazardous_weight^hazards × battle_weight^enemies. Each category samples Resources by encounter_weight without replacement until exhausted. At least 1 enemy; reward floor 1. Invalid bounds warn and fall back to one enemy plus available PoIs (all enemies if no PoIs). No hidden reduction in travel requirement. Tune counts/weights/registry in `encounters/expedition_rules.tres`; type weights in each PoI/ship Resource.

## Ordinary

### Mining Operation

Edit `encounters/mining_operation.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Surface collection | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Automated extraction | None | 0 | 75.0% | +7 Salvage | 25.0%: +3 Salvage · -3 permanent Hull |
| Industrial extraction | Fabricator ≥3 | 0 | 85.0% | +9 Salvage | 15.0%: +4 Salvage · -3 permanent Hull |
| Deep-core mining | Fabricator ≥3 | 0 | 55.0% | +14 Salvage | 45.0%: +6 Salvage · -7 permanent Hull |

### Gas Giant

Edit `encounters/gas_giant.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Atmospheric sampling | None | 0 | 100.0% | +3 Energy next battle | Not rolled |
| Gas harvesting | None | 0 | 75.0% | +1 Reactor next battle | 25.0%: +2 Energy next battle · -4 Shields next battle |
| Precision skimming | Reactor ≥3 | 0 | 90.0% | +1 Reactor next battle | 10.0%: +3 Energy next battle · -3 Shields next battle |
| Deep atmospheric dive | Hangar ≥3 | 0 | 60.0% | +2 Reactor next battle | 40.0%: +1 Reactor next battle · -5 Crew next battle |

### Derelict Starship

Edit `encounters/derelict_starship.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| External salvage | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Board the wreck | None | 0 | 70.0% | Choose 1 of 3 cards | 30.0%: +4 Salvage · -3 permanent Hull |
| Engineering recovery | Fabricator ≥3 | 0 | 85.0% | Choose 1 of 3 cards | 15.0%: +5 Salvage · -2 permanent Hull |
| Deploy boarding teams | Hangar ≥3 | 0 | 75.0% | Choose 1 of 3 uncommon-or-better cards | 25.0%: +5 Salvage · -3 Crew next battle |

### Abandoned Research Station

Edit `encounters/research_station.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Recover research data | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Access experimental database | None | 0 | 70.0% | Upgrade one player card | 30.0%: +4 Salvage · -3 Energy next battle |
| High-energy analysis | Reactor ≥3 | 0 | 85.0% | Upgrade one player card | 15.0%: +5 Salvage · -1 Reactor next battle |
| Advanced fabrication | Fabricator ≥3 | 0 | 75.0% | +3 Salvage · Upgrade one player card | 25.0%: +5 Salvage · -3 Materials next battle |

### Trading Outpost

Edit `encounters/trading_outpost.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Emergency repairs | None | 5 | 100.0% | +5 permanent Hull | Not rolled |
| Purchase supplies | None | 4 | 100.0% | +5 starting resource of choice next battle | Not rolled |
| Acquire card | None | 8 | 100.0% | Choose 1 of 3 cards | Not rolled |
| Shipyard improvements | None | 12 | 100.0% | +1 production of choice for expedition | Not rolled |

### Spatial Anomaly

Edit `encounters/spatial_anomaly.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Passive observation | None | 0 | 100.0% | +3 Salvage | Not rolled |
| Collect exotic particles | None | 0 | 70.0% | +3 Emergency Jump charge next battle | 30.0%: +4 Salvage · -3 Shields next battle |
| Stabilize anomaly | Reactor ≥3 | 0 | 85.0% | +4 Emergency Jump charge next battle | 15.0%: +5 Salvage · +1 Emergency Jump offline turns next battle |
| Reinforce Emergency Jump systems | Hangar ≥3 | 0 | 75.0% | +5 Emergency Jump charge next battle | 25.0%: +6 Salvage · +2 Emergency Jump offline turns next battle |

## Hazardous

### Radiation Nebula

Edit `encounters/radiation_nebula.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Quick scan | None | 0 | 100.0% | -2 Shields next battle | Not rolled |
| Collect isotopes | None | 0 | 100.0% | +5 Salvage · -3 permanent Hull | Not rolled |
| Harvest particles | Fabricator ≥3 | 0 | 100.0% | +1 Reactor next battle · -5 Shields next battle | Not rolled |
| Shielded expedition | Reactor ≥3 | 0 | 100.0% | +7 Salvage · -2 permanent Hull | Not rolled |

### Distress Signal

Edit `encounters/distress_signal.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Relay coordinates | None | 0 | 100.0% | +2 Salvage · -2 Crew next battle | Not rolled |
| Dispatch rescue crew | None | 0 | 70.0% | -3 Crew next battle · Choose 1 of 3 cards | 30.0%: +3 Salvage · -4 Crew next battle |
| Specialist rescue | Hangar ≥3 | 0 | 85.0% | -2 Crew next battle · Choose 1 of 3 uncommon-or-better cards | 15.0%: +5 Salvage · -3 Crew next battle |
| Fabricate relief kits | Fabricator ≥3 | 0 | 100.0% | +8 Salvage · -4 Materials next battle | Not rolled |

### Pirate Debris Field

Edit `encounters/pirate_debris_field.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Drone perimeter scan | None | 0 | 100.0% | +1 Salvage · -1 permanent Hull | Not rolled |
| Recover cargo | None | 0 | 65.0% | +10 Salvage · -3 permanent Hull | 35.0%: +4 Salvage · -5 permanent Hull |
| Disarm wreckage | Fabricator ≥3 | 0 | 80.0% | -2 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 20.0%: +5 Salvage · -3 permanent Hull |
| Board pirate flagship | Hangar ≥3 | 0 | 70.0% | +5 Salvage · -4 permanent Hull · Choose 1 of 3 uncommon-or-better cards | 30.0%: +6 Salvage · -6 permanent Hull |

### Unstable Wormhole

Edit `encounters/unstable_wormhole.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Map the perimeter | None | 0 | 100.0% | +2 Salvage · +1 Emergency Jump offline turns next battle | Not rolled |
| Probe the shortcut | None | 0 | 65.0% | +1 extra FTL Drive charge · +2 Emergency Jump offline turns next battle | 35.0%: +3 Salvage · -4 Shields next battle |
| Stabilize corridor | Reactor ≥3 | 0 | 80.0% | +2 extra FTL Drive charge · +2 Emergency Jump offline turns next battle | 20.0%: +5 Salvage · +3 Emergency Jump offline turns next battle |
| Reinforce transit probe | Fabricator ≥3 | 0 | 100.0% | -2 permanent Hull · +5 Emergency Jump charge next battle | Not rolled |

### Quarantined Colony

Edit `encounters/quarantined_colony.tres`; expand Approaches → Success / Failure. Generation weight: 1.0. All listed effects in a guaranteed row happen together; randomized rows show the complete outcome of each branch.

| Approach | Requirement | Salvage cost | Success chance | Success (guaranteed at 100%) | Failure |
|---|---|---|---|---|---|
| Remote supply exchange | None | 0 | 100.0% | +3 Salvage · -1 Fabricator next battle | Not rolled |
| Accept medical repairs | None | 0 | 100.0% | +6 permanent Hull · -1 Hangar next battle | Not rolled |
| Recover research | Reactor ≥3 | 0 | 80.0% | -1 Reactor next battle · Upgrade one player card | 20.0%: +4 Salvage · -1 Reactor next battle |
| Evacuate scientists | Hangar ≥3 | 0 | 85.0% | -1 Hangar next battle · Choose 1 of 3 uncommon-or-better cards | 15.0%: +5 Salvage · -1 Hangar next battle |

## Progression safeguard

If a PoI has no affordable, unlocked approach whose worst possible Hull outcome leaves Hull >0, **Navigation survey** becomes available. Completing the survey forfeits all normal loot and grants only that PoI's +1 charge, with guaranteed next-battle penalty `{"reactor":-1}`. Costs/requirements are not bypassed to obtain service rewards. Tune `ExpeditionRules.survey_penalty`. Full-Hull repairs are locked. Return leaves an uncompleted PoI untouched.

All escaped enemies complete normally and award their full profile charge. Repeated result/approach calls cannot award more charge. Charge resets on entering the next system; unspent charge does not carry. Pending choices must be resolved before leaving. Hull 0 ends the expedition; voluntarily lethal approaches and battle losses remain possible. The simulation guarantees charge availability for surviving players, not victory against every enemy. **Not implemented:** hostile follow-up battles from pirate debris; current pirate hazards use Hull costs.
