# Later Starfront Defense

Procedural military scenarios apply to new Starfront Defense systems from System 3 onward. System 1 keeps its v2 opening roster, pressure and reinforcements. System 2 remains Warzone. Existing active systems retain their saved behavior until the next generation.

The later [environmental geometry update](starfront_environment.md) provides a separate contemporaneous comparison of map variety and interception feasibility.

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

## Civilian evacuation

New v2 Starfront Defense sectors from System 3 onward generate one civilian evacuation convoy. System 1, Warzone and already-generated saves keep their existing objectives. The convoy uses a scene-independent moving PoI record for identity, progress and activity. DefenseState advances it with attacks, Pressure, reinforcement and missile events. The map renders the record without advancing it.

| Setting | Default |
| --- | ---: |
| Starting and maximum integrity | 40 |
| Movement speed | 0.7 units per strategic second |
| Route duration | 35–55 strategic seconds |
| Damage per hostile contact | 20 |
| Simultaneous pursuers | Up to 2 |
| Evacuation reward | 15 Salvage |
| Destruction penalty | 20 Pressure, clamped at the existing maximum |
| Punitive dispatch delay | 6 strategic seconds |

Placement uses an independent convoy seed. It tests straight routes first, then routes with one bend if necessary. Departure is 4.7–9.5 units from Homeworld and clear of the player spawn. Extraction is at least 16 units from Homeworld. Segments keep a margin from map edges, stellar and planetary bodies, installations, construction sites and other PoIs. Candidate scoring checks interception from both sides. At launch the majority of attackers still target Homeworld, and the first convoy threat leaves time for travel and a committed battle.

Raiders, Vanguards and Disruptors can pursue. Deployment, remaining route and Pressure determine whether an arriving reserve joins. Pursuers lead the convoy with a relative-motion solution and can resume their orders after a tactical decoy expires. The event solver uses swept contact, including a contact at the end of a time slice. A valid player interception wins a tie with a convoy attack. Exact extraction wins a tie with an attack. An attacker that makes contact is spent and grants no player combat reward. Outstanding pursuers return to their existing primary targets when evacuation ends.

If the convoy is destroyed, Pressure is applied immediately. A faction elite with the current stage's combat settings enters after six seconds or when the active cap permits. Its schedule is separate from the normal reserves and survives the mothership's defeat. It can strike Homeworld once, then holds nearby until defeated or disabled by EMP. Its existing elite Salvage, resource and upgrade rewards apply. Its acquisition draft uses ordinary Tier 1–2 eligibility to avoid giving an extra guaranteed Tier 3 roll for a lost evacuation. FTL requires the punitive contact to be resolved. If the battlefield is already secure and the convoy survives, extraction and its reward settle without extra travel time.

Saves include the committed route and progress, incoming and spent pursuers, outcome, reward claim and punitive identity and state. The overlay, map labels and route drawing reconstruct from this data. Developer Test Launch offers an **Evacuation Convoy** selection in **Environment & Seed** for normal or 20-integrity starts and an option to relax role restrictions for initial pursuers. The override still requires a physically feasible pursuit. System 5, seed 39 is suitable for checking the convoy and beacon. System 5, seed 142 uses the bent-route fallback.

### Procedural and strategic results

A sweep of seeds 1–180 at each of Systems 3, 4 and 5 covered all four factions and all five doctrines. All 540 generated a convoy. One used a bend and none used an unthreatened route. There were 452 openings with one pursuer and 88 with two. Routes measured 35.03–54.99 seconds. The earliest opening hostile contact was 11.29 seconds, with a feasible player intercept plus the battle time before contact for every opening pursuer. With time advancing and no player interception, 184 of 540 convoys were destroyed and the punitive forces deployed in all 184.

The policy study used 54 fixed systems per policy, drawn from seeds 31–48 at each of Systems 3, 4 and 5 across all six player ships. All policies secured 54/54 under optimistic card wins. Values below use real movement, hostile contacts, Pressure, PoIs and combat time costs.

| Policy | Evacuated | Convoy damage | Homeworld damage | Mean strategic seconds | Evacuation Salvage |
| --- | ---: | ---: | ---: | ---: | ---: |
| Nearest Homeworld threat | 54/54 | 200 | 0 | 49.6 | 810 |
| Most dangerous Homeworld threat | 54/54 | 180 | 0 | 49.4 | 810 |
| Convoy first | 54/54 | 0 | 80 | 49.5 | 810 |
| Alternate objectives | 54/54 | 20 | 40 | 49.4 | 810 |
| Tactical decoys | 54/54 | 100 | 0 | 49.4 | 810 |
| Turrets | 54/54 | 100 | 0 | 49.4 | 810 |
| Nearby preparation | 54/54 | 220 | 40 | 55.2 | 810 |
| Economic preparation | 54/54 | 240 | 40 | 51.3 | 810 |
| Ignore convoy | 43/54 | 1,140 | 0 | 49.0 | 645 |
| Deliberate sacrifice | 43/54 | 1,140 | 0 | 49.0 | 645 |
| Rush mothership | 54/54 | 100 | 0 | 49.4 | 810 |

Without convoys the convoy-first policy reduced to normal threat selection and averaged 49.5 seconds, 0 Homeworld damage and 6.06 battles. With convoys it averaged 5.98 battles and incurred four Homeworld strikes across the sample. Deliberate sacrifice saved less than one strategic second on average and ended with 495 less total Salvage than convoy-first across 54 matched systems. The 11 extra elite encounters initially offered every sacrificed convoy another rare draft. Removing Tier 3 eligibility from that encounter preserves its combat challenge and other rewards. Damage to the convoy is often strategically acceptable. These policies assume every card fight won and scripted preparation choices. They do not estimate human win rates, card difficulty, or physical-device performance.

Reproduce with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/starfront_convoy_test.gd
godot --headless --path . --script res://tests/starfront_convoy_balance.gd
godot --headless --path . --script res://tests/starfront_convoy_balance.gd -- --no-convoy
```

The rendered convoy test captures the same seed in both renderers at 960×540 and checks map input at 686×384. Real-device Android input and full card battles remain manual playtests.
