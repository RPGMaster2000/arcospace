# Combat audit tables

## Combat-Only outcomes by ship

| Ship | N | Win | Escape | Success | 95% CI | Defeat | Draws | Limits | Rounds mean / median | Net Hull lost | Gross permanent Hull damage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Endeavour | 4096 | 50.6% | 0.0% | 50.6% | 49.0%–52.1% | 44.7% | 7 | 188 | 29.3 / 21 | 21.1 | 37.8 |
| Thunderbolt | 4096 | 31.2% | 0.0% | 31.2% | 29.8%–32.7% | 68.4% | 4 | 12 | 17.9 / 14 | 22.8 | 25.2 |
| Titania | 4096 | 55.9% | 0.0% | 55.9% | 54.4%–57.4% | 40.8% | 2 | 133 | 27.5 / 20 | 25.2 | 40.4 |
| Ganymede | 4096 | 27.7% | 0.0% | 27.7% | 26.4%–29.1% | 67.8% | 1 | 182 | 28.2 / 20 | 28.6 | 41.2 |
| Callisto | 4096 | 34.4% | 0.0% | 34.4% | 32.9%–35.8% | 57.9% | 5 | 311 | 35.6 / 26 | 23.8 | 36.5 |
| Orion | 4096 | 45.2% | 0.0% | 45.2% | 43.7%–46.8% | 54.0% | 4 | 28 | 20.5 / 16 | 26.3 | 28.8 |

## Emp outcomes by ship

| Ship | N | Win | Escape | Success | 95% CI | Defeat | Draws | Limits | Rounds mean / median | Net Hull lost | Gross permanent Hull damage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Endeavour | 1024 | 12.9% | 71.2% | 84.1% | 81.7%–86.2% | 15.9% | 0 | 0 | 15.7 / 14 | 9.2 | 19.0 |
| Thunderbolt | 1024 | 10.5% | 64.0% | 74.5% | 71.8%–77.1% | 25.5% | 0 | 0 | 11.0 / 11 | 12.2 | 13.7 |
| Titania | 1024 | 17.8% | 67.5% | 85.3% | 83.0%–87.3% | 14.7% | 0 | 0 | 18.6 / 17 | 12.1 | 22.6 |
| Ganymede | 1024 | 7.4% | 68.1% | 75.5% | 72.8%–78.0% | 24.5% | 0 | 0 | 15.7 / 14 | 14.8 | 22.3 |
| Callisto | 1024 | 6.9% | 80.1% | 87.0% | 84.8%–88.9% | 12.9% | 1 | 0 | 15.7 / 14 | 9.6 | 15.4 |
| Orion | 1024 | 17.1% | 57.2% | 74.3% | 71.6%–76.9% | 25.6% | 1 | 0 | 14.7 / 14 | 16.4 | 18.0 |

## Combat wins by policy

| Ship | aggressive | balanced | defensive | economic | emp |
|---|---|---|---|---|---|
| Endeavour | 57.3% | 55.6% | 47.9% | 41.4% | 12.9% |
| Thunderbolt | 41.4% | 30.3% | 38.7% | 14.6% | 10.5% |
| Titania | 71.3% | 60.4% | 62.4% | 29.6% | 17.8% |
| Ganymede | 42.8% | 29.6% | 28.1% | 10.4% | 7.4% |
| Callisto | 41.2% | 34.6% | 36.3% | 25.4% | 6.9% |
| Orion | 60.4% | 45.6% | 47.9% | 27.1% | 17.1% |

## Paired effect of taking the first legal EMP escape

Each pair uses the same defensive policy, opponent, modifier and seed. Gains and losses count changes in the combined success outcome.

| Ship | Pairs | Success gain | Success loss | Net change (pp) |
|---|---|---|---|---|
| Callisto | 1024 | 519 | 0 | +50.7 |
| Endeavour | 1024 | 370 | 0 | +36.1 |
| Ganymede | 1024 | 485 | 0 | +47.4 |
| Orion | 1024 | 271 | 0 | +26.5 |
| Thunderbolt | 1024 | 367 | 0 | +35.8 |
| Titania | 1024 | 234 | 0 | +22.9 |

## Enemy matchup matrix

Cells show combat-only win rate. Ranks 0, 1 and 2 indicate ordinary, elite and boss.

| Enemy | Rank | N per ship | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion |
|---|---|---|---|---|---|---|---|---|
| Marauder | 0 | 512 | 66.8% | 44.1% | 74.8% | 43.0% | 44.3% | 60.9% |
| Sentinel | 0 | 512 | 57.4% | 50.8% | 62.3% | 24.4% | 48.4% | 63.1% |
| Reclaimer | 0 | 512 | 55.5% | 26.8% | 51.4% | 22.7% | 34.0% | 47.3% |
| Marauder Vanguard | 1 | 512 | 14.5% | 5.3% | 31.4% | 5.3% | 5.9% | 12.9% |
| Sentinel Dreadnought | 2 | 512 | 4.1% | 3.7% | 3.5% | 1.2% | 2.0% | 3.5% |
| Rustjack | 0 | 512 | 94.7% | 59.6% | 77.9% | 64.1% | 72.3% | 77.3% |
| AXIOM-7 | 0 | 512 | 78.7% | 43.4% | 75.0% | 46.1% | 62.3% | 68.2% |
| The Hollow Choir | 0 | 512 | 32.8% | 16.4% | 71.1% | 15.2% | 5.9% | 28.7% |

## Environmental synergies

Cells show combat-only wins, then paired percentage-point change versus None. The JSON includes paired intervals and separate EMP cells.

| Modifier | N per ship | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion |
|---|---|---|---|---|---|---|---|
| None | 512 | 50.0% (+0.0) | 32.4% (+0.0) | 55.7% (+0.0) | 28.9% (+0.0) | 34.2% (+0.0) | 47.7% (+0.0) |
| Asteroid belt | 512 | 47.5% (-2.5) | 27.9% (-4.5) | 54.9% (-0.8) | 28.9% (+0.0) | 35.5% (+1.4) | 40.2% (-7.4) |
| Ion storm | 512 | 52.5% (+2.5) | 33.0% (+0.6) | 55.5% (-0.2) | 27.5% (-1.4) | 37.5% (+3.3) | 46.5% (-1.2) |
| Solar flare | 512 | 57.2% (+7.2) | 32.6% (+0.2) | 57.6% (+2.0) | 28.7% (-0.2) | 31.1% (-3.1) | 48.8% (+1.2) |
| Nebula | 512 | 43.4% (-6.6) | 30.7% (-1.8) | 53.5% (-2.1) | 21.1% (-7.8) | 31.2% (-2.9) | 38.5% (-9.2) |
| Temporal Rift | 512 | 47.5% (-2.5) | 29.5% (-2.9) | 58.2% (+2.5) | 26.6% (-2.3) | 33.6% (-0.6) | 45.3% (-2.3) |
| Metal storm | 512 | 52.1% (+2.1) | 32.4% (+0.0) | 55.9% (+0.2) | 29.9% (+1.0) | 36.3% (+2.1) | 46.1% (-1.6) |
| Psionic storm | 512 | 54.3% (+4.3) | 31.4% (-1.0) | 56.2% (+0.6) | 30.3% (+1.4) | 35.5% (+1.4) | 48.8% (+1.2) |

## Resources and failure

Combat-only policies, sampled after income at the start of each turn. Failure entries count activations.

| Ship | Mean Materials / Energy / Crew | Unaffordable player turns | Unaffordable enemy turns | Failure entries player / enemy | Systems wins / defeats |
|---|---|---|---|---|---|
| Endeavour | 28.0 / 25.0 / 23.4 | 3.8% | 4.7% | 378 / 140 | 112 / 259 |
| Thunderbolt | 21.8 / 25.7 / 16.6 | 1.3% | 8.9% | 223 / 571 | 409 / 125 |
| Titania | 32.3 / 56.5 / 46.1 | 1.1% | 6.6% | 114 / 704 | 464 / 76 |
| Ganymede | 22.5 / 55.0 / 40.4 | 2.5% | 6.4% | 214 / 247 | 168 / 87 |
| Callisto | 40.7 / 60.6 / 24.4 | 2.0% | 9.9% | 380 / 665 | 532 / 218 |
| Orion | 10.8 / 37.4 / 21.4 | 2.1% | 7.6% | 152 / 575 | 397 / 74 |

## Starting-deck card observations

Combat-only policies. A card appears in the ranked samples after at least 200 draws. Usage includes each identity’s legal and illegal holdings and may reflect policy bias.

### Lowest play per draw

| Card | Tier | Family | Drawn | Played / drawn | Affordable holdings | Hull damage / play |
|---|---|---|---|---|---|---|
| Personnel Disruption | 1 | crew | 12472 | 32.6% | 82.1% | 0.0 |
| Fabrication Strike | 2 | materials | 12940 | 42.7% | 43.7% | 1.4 |
| Core Destabilization | 2 | energy | 9246 | 43.0% | 57.9% | 0.0 |
| Command Infiltration | 2 | crew | 8436 | 46.3% | 40.1% | 0.0 |
| Desperate Conversion | 1 | crew | 11251 | 46.5% | 83.2% | 0.0 |
| Reactor Interference | 1 | energy | 14067 | 46.6% | 82.9% | 0.0 |
| Industrial Interference | 1 | materials | 14023 | 49.0% | 83.8% | 0.0 |
| System Disruption | 1 | crew | 6419 | 50.5% | 73.3% | 0.0 |
| Shield Disruptor | 1 | materials | 14330 | 56.3% | 87.8% | 0.0 |
| Shield Collapse | 1 | energy | 8463 | 63.5% | 92.2% | 0.0 |

### Highest play per draw

| Card | Tier | Family | Drawn | Played / drawn | Affordable holdings | Hull damage / play |
|---|---|---|---|---|---|---|
| Boarding Operations | 1 | crew | 7721 | 96.1% | 90.2% | 3.8 |
| Reactive Armor | 1 | materials | 9038 | 95.6% | 93.7% | 0.0 |
| Energy Surge | 1 | energy | 32223 | 94.9% | 100.0% | 0.0 |
| Shield Capacitor | 1 | energy | 10751 | 94.8% | 89.7% | 0.0 |
| Emergency Power Cell | 1 | energy | 33487 | 94.4% | 100.0% | 0.0 |
| Shield Recharge | 1 | energy | 34451 | 92.9% | 96.8% | 0.0 |
| Cargo Raid | 1 | crew | 29066 | 92.6% | 71.0% | 1.4 |
| Shield Array | 1 | materials | 31839 | 92.5% | 85.0% | 0.0 |
| Relentless Barrage | 1 | energy | 6912 | 91.9% | 90.1% | 6.3 |
| Structural Reinforcement | 1 | materials | 27073 | 91.8% | 83.2% | 0.0 |
