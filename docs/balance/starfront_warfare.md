# Later Starfront Defense

Procedural military scenarios apply to new Starfront Defense systems from System 3 onward. System 1 keeps its v2 opening roster, pressure and reinforcements. System 2 remains Warzone. Existing active systems retain their saved behavior until the next generation.

## Deployment

Environmental layout and military doctrine use independent seeded streams. Factions receive a 10% relative weighting toward one preferred formation. An eligible alternative replaces the previous formation when there is a choice. The weights below apply before those preferences.

| Formation | System 3 | System 4 | System 5+ | Deployment |
|---|---:|---:|---:|---|
| Concentrated Assault | 40% | 20% | 15% | One front with close approach lanes and a mix of fast and heavy attackers |
| Pincer Attack | 30% | 25% | 20% | Two separated flanks with staggered arrivals and alternating reserve delays |
| Vanguard and Heavy Reserves | 30% | 25% | 25% | Fast opening attackers followed by a longer first reserve gap and heavy ships |
| Encirclement | — | 15% | 20% | Three approach directions that spread out interceptions and turret coverage |
| Mothership Spearhead | — | 15% | 20% | Heavy escorts and a quicker initial reserve share the main mothership approach |

Each scenario favors existing preparation sites near useful approaches. The rest of the PoIs and their rewards follow normal generation. Candidate deployments check map bounds, star and installation clearance, opening arrival spacing, and travel feasibility. The generator checks two sequential swept contacts with a battle cost in between. It tries other eligible formations when a candidate fails and retains the legacy layout if custom constraints preclude every military formation.

| Setting | System 3 | System 4 | System 5+ |
|---|---:|---:|---:|
| Opening attackers | 3–4 | 4 | 4–5 |
| Reserve attackers | 3 | 4 | 5 |
| Active attacker cap | 4 | 4 | 5 |
| Enemy speed and effective v2 pressure | ×1.10 | ×1.20 | ×1.30 |
| Base reserve interval | 28 s | 26 s | 24 s |
| Target elite probability | 15% | 25% | 35% |
| Elite limit, opening / total | 1 / 2 | 2 / 3 | 2 / 4 |

Pincer reserves alternate +2 s and −2 s. Vanguard reserves start at +5 s, then alternate −4 s and the base interval. Spearhead starts at −2 s. A full attacker cap defers the next reserve. It does not accrue additional deployments. The mothership is outside those counts. Destroying or disabling it stands down reserves and leaves active attackers and missiles in play.

| Role | Speed relative to system speed | Ordinary arrival damage | Combat focus |
|---|---:|---:|---|
| Raider | ×1.15 | 20 | Theft, piercing attacks and denial |
| Vanguard | ×1.10 | 20 | Shield breaking and follow-up damage |
| Siege Ship | ×0.85 | 25 | Materials production and heavy attacks |
| Disruptor | ×1.00 | 20 | Resource denial, theft and targeted sabotage |
| Heavy Escort | ×0.90 | 20 | Shield recovery, Hull repair and defensive production |

## Card battles

Roles combine with faction preferences to weight the existing card catalogue. Later pools favor cards the ship can afford over its first few rounds, while keeping the normal pool limits and any explicit custom deck. Faction editor resources include separate Defense elite rosters. Their progression and rewards use actual elite ranks.

| Rank | System 3 Tier 2 / Tier 3 | System 4 Tier 2 / Tier 3 | System 5+ Tier 2 / Tier 3 |
|---|---:|---:|---:|
| Standard | 18% / eligible 5% | 20% / eligible 5% | 22% / 5% |
| Elite | 22% / 6% | 25% / 8% | 28% / 10% |
| Mothership | 25% / 8% | 28% / 10% | 30% / 12% |

Higher tiers unlock on rounds 3 and 6 respectively. An empty bucket uses the normal fallback. Standard, elite and mothership starting reserves receive +1/+2/+2 per family at System 3, +2/+3/+4 at System 4 and +3/+4/+6 from System 5. Elites and motherships gain one point of role-preferred production from System 4. Hull and Shields use ordinary progression values. The save stores the committed military plan, reserve queue, roles, stats and card pool, and battle setup builds detached profiles from that data.

Developer Testing can select a Starfront stage, faction and eligible formation. The ordinary generator applies these settings to the selected test system. The launch log prints the seed, formation and faction.

## Generation and balance results

The pinned Godot 4.7.2 run generated 180 sectors per stage. It tested four factions, all eligible formations, multiple seeds per environment, exact seed replay, reserve clearance and persisted state.

| Stage | Assault / Pincer / Vanguard / Encirclement / Spearhead | Elites / total attackers | Earliest arrival | Shortest opening arrival gap | Worst time to first feasible interception |
|---|---|---:|---:|---:|---:|
| 3 | 70 / 57 / 53 / — / — | 164 / 1,156 | 20.02 s | 0.80 s | 5.07 s |
| 4 | 31 / 42 / 52 / 29 / 26 | 328 / 1,440 | 20.01 s | 0.84 s | 5.00 s |
| 5 | 32 / 33 / 38 / 35 / 42 | 554 / 1,712 | 20.01 s | 0.80 s | 5.08 s |

All 540 opening deployments supported two sequential swept contacts and had at least one preparation site within three seconds of starting travel. Reserve-biased weighting and composition caps yield elite rates of 14.2%, 22.8% and 32.4%. No seed needed the legacy fallback. Deployment uses a 20-second minimum opening arrival and a 0.8-second first-arrival separation because initial geometry alone did not consistently clear obstacles or provide sequential contacts.

The paired combat audit ran 864 battles across all six ships, varied environmental modifiers, ordinary draft progression and some temporary preparations. Each cell compares 48 player results for the same base enemy ship, with the existing battle setup and the later doctrine.

| Stage | Standard player wins, baseline → later | Elite player wins, baseline → later | Mothership player wins, baseline → later |
|---|---:|---:|---:|
| 3 | 17 → 26 | 21 → 16 | 5 → 5 |
| 4 | 17 → 21 | 20 → 10 | 8 → 7 |
| 5 | 14 → 14 | 3 → 1 | 2 → 0 |

The first run exposed an affordability problem with more expensive role cards. The final pass weights affordable picks and raises relevant attack or disruption evaluation by 20–45% for offensive roles. It caps tactical jitter at 0.10 for standard and 0.08 for higher ranks. These changes preserved the original Hull and Shield values and still left early ordinary fights more accessible in this sample. The later setups played 1,023 Tier 2 and 465 Tier 3 cards. System 5 motherships were severe under the audit's progression assumptions. Full expedition playthroughs are needed to gauge their acquisition and reward pacing.

Eight strategic policies ran 54 sectors each with authoritative map movement and optimistic card-battle outcomes. The nearest and most-dangerous interception policies secured every scenario with zero damage. Nearby PoI and economic policies cleared all sectors but gave up 20 and 100 total integrity respectively. Turret, decoy and early boss policies also cleared all 54, so this sample could not distinguish their benefits from timely interceptions. Detours cleared 49 of 54 and lost 3,610 total integrity. Nearest-intercept mothership reveals averaged 42.37 strategic seconds. Mothership advancing, missiles and victory persistence are exercised separately by the regression. AI card policies and deliberately favorable strategic outcomes measure different parts of the system. Their win rates are unsuitable as forecasts of campaign completion.

Reproduce with `tests/defense_warfare_test.gd`, `tests/defense_warfare_strategies.gd` or `tests/defense_warfare_balance.gd` using Godot `--headless --path . --script`.
