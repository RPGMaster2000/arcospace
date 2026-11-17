# Enemy Balance Pass 3

The [deck audit](deck-audit.md) covers all 19 enemies, with authored and fallback pools, starting resources, production, role counts, AI weights and observed card use. [Baseline deck cards](baseline-deck-cards.csv) lists every eligible card, including costs, strategic roles, effects, affordability, use and discard rates. The [results tables](tables.md) contain the before/after matchup matrix, battle-length tails, activity, isolated experiments and held-out results. `summary.json.gz` retains the full configurations and statistics, including individual progression loadouts and their results by opponent, policy and modifier.

## Retained decks

| Enemy | Original problem | Removed → replacement | Intended behavior |
| --- | --- | --- | --- |
| Siege Monitor | Shield and Hull recovery repeatedly reset progress through a 50.6-round baseline mean. | Hull Nanobots → Iron Counterbattery (new, 8 Energy) | Preserve Shield Recharge as part of a heavy armored deck. Make those Shields enable a piercing attack that the player can weaken by breaking the armor. |
| Choir Spore | Low opening durability coexisted with 41.0 recovered Hull per baseline fight. | Hull Nanobots → Overloaded Warhead (existing, 7 Materials) | Trade passive regeneration and Materials gain for risky burst that costs the Spore four Hull. Its Crew attack suite and other recovery options support the light organic role. |
| The Hollow Choir | Structural Reinforcement was its most-used card, layering plating and Shields across prolonged matchups. | Structural Reinforcement → Siege Charges (existing, 12 Materials) | Give the living ship a conditional finishing option alongside Crew offense, while leaving its Hull Patch, Hull Nanobots and Shield recovery active. |

| Held-out outcome | Siege Monitor | Choir Spore | The Hollow Choir |
| --- | --- | --- | --- |
| Mean rounds | 54.06 → 45.02 | 29.51 → 24.21 | 29.77 → 24.12 |
| Median / P90 | 46 → 37 / 100 → 100 | 23 → 19 / 61 → 46 | 21 → 19 / 69 → 47 |
| Over 40 rounds | 57.4% → 46.2% | 19.7% → 12.8% | 21.5% → 13.5% |
| Unresolved | 24.1% → 15.0% | 3.6% → 2.0% | 4.9% → 2.3% |
| Simulated player wins | 36.4% → 41.5% | 36.2% → 42.1% | 31.4% → 27.4% |
| Enemy direct damage per round | 1.67 → 2.07 | 2.69 → 2.96 | 2.56 → 2.82 |
| Enemy Hull restored per fight | 74.8 → 37.6 | 54.4 → 36.0 | 30.5 → 22.6 |
| Enemy Shields gained per fight | 139.7 → 118.2 | 54.7 → 45.9 | 61.6 → 43.6 |
| Enemy recovery sequences per fight | 6.83 → 4.65 | 2.75 → 2.01 | 2.98 → 2.04 |

The paired 95% intervals for held-out mean duration were **−12.45 to −5.32** rounds for Siege Monitor, **−7.17 to −3.31** for Choir Spore and **−8.53 to −2.32** for The Hollow Choir. Faster pacing replicated on both seed ranges. Siege Monitor and Choir Spore were modestly easier on the held-out grid. The Hollow Choir's mean win-rate change was −4.0 points with an interval spanning zero. Its largest held-out ship-level decline was Orion at 7.4 points. Callisto, an already difficult matchup, fell 1.2 points against both Choir swaps. Siege Monitor's full-duration tail remains a pacing concern.

Iron Counterbattery was playable on 75.7% of held-out hand turns and was used 3,383 times in the 1,536 held-out combat-policy battles. Its four base damage and four conditional piercing damage fit the existing tactical AI and effect preview. It uses the built-in Energy card fallback visual, has a stable private resource path, and appears only in Siege Monitor's deck. The shipped profile and the tested prototype produce identical shared match results.

## Rejected experiments

- **Siege Monitor.** Emergency Discharge in the Shield Recharge slot reduced mean rounds in screening but moved damage pressure down and reduced player wins by 6.25 points. Counterbattery itself shortened held-out fights in that same slot, alongside a 5.6-point pooled player win drop and a 14.1-point Orion decline. The alternate Hull Nanobots slot retained the pressure and pacing benefits with better ship-level outcomes.
- **Sentinel and Reclaimer.** Curated 22-card pools distinguished the ships' energy-defense and industrial-salvage roles. Against the live fallback baseline, Sentinel's mean change was −2.90 rounds with an interval spanning zero, and unresolved fights rose by an estimated 3.39 points. Reclaimer averaged 33.85 rounds with the live fallback. Its curated deck added 10.53 rounds, added 12.37 points to unresolved fights and reduced damage pressure. Both keep their established pools.
- **Choir Guardian.** Overloaded Warhead reduced mean rounds but dropped wins by roughly eleven points for Orion and Titania in screening. Feeding Lunge reduced recovery runs with inconsistent effects on duration and individual matchups.
- **Feeding Lunge.** None of the three Choir placements cleared the combined pacing and matchup bar. The largest screening shifts on The Hollow Choir were in opposite directions for Endeavour and Titania. The prototype remains an isolated fixture for comparison.
- **Other decks.** The AXIOM authored pools already use precise energy attacks, Shield manipulation and production disruption. Wreckbreaker and Marauder Vanguard produce offensive, comparatively short engagements. The lighter Scrap Skiff remains an introductory encounter. Bastion Frigate's separate #90 experiment already evaluates the intended Breach Charge pressure.

## Baseline and measurement

The production baseline is merged `main` at `13e5f027ab6f9d9741bcc1ed5ace6285977b7480`. It includes the 2.8 tactical production preference from PR #89 for Choir Guardian. PR #90 was open when this branch started, so the merged Bastion Frigate carried Emergency Bulkheads. The earlier Breach Charge result informed the experiments. Its prospective tuning is outside this baseline comparison. The three retained production profiles were rerun at `1377170f311ad3ea471d4758a378afe9fa2f17ee`.

The existing harness exercised actual battle rules with the six starting player decks, eight modifiers, four combat policies, eight selection seeds and eight fresh held-out seeds. The baseline has 36,480 battles, including the separate EMP policy. A 912-battle replay verifies the previous audit's matching conditions. Pass 3 reruns the 9,600 battles for legacy profiles with the explicit 80-card pool passed by live expedition setup. This pool also includes the established signature identities. The old empty-pool diagnostic path excludes them. The affected enemies are Marauder, Marauder Vanguard, Sentinel, Reclaimer and Sentinel Dreadnought. Each Dreadnought boss fixture also uses the expedition pool. The audits therefore differ for those profiles. New private cards remain outside both fallback pools.

Card affordability is measured for held cards at the start of the turn. The discard share is discards divided by discards plus plays. A low play count can reflect resource competition, conditional value or rarity caps as well as affordability. Frequent cards in a 100-round fight also had more opportunities to appear. The controlled substitutions assess causation for the tested deck changes.

A recovery sequence contains at least two consecutive turns with positive Hull or Shield recovery and less than three direct damage per turn. Total damage includes damage absorbed by Shields. Environmental damage and suspended Shields are excluded from the card-flow metrics. Paired intervals use 4,000 whole-seed-block bootstrap resamples with a fixed bootstrap seed. The intervals are exploratory with eight blocks and multiple comparisons.

## Isolated experiments

| Arm | Ship | Tested card pool |
| --- | --- | --- |
| Existing cards | Siege Monitor | Shield Recharge → Emergency Discharge. Shift Shield generation toward Shield-breaking while keeping a small defensive return. |
| Existing cards | Sentinel | 22-card energy-oriented pool with Shield defense, cheap Energy pressure and targeted disruption. |
| Existing cards | Reclaimer | 22-card Materials-oriented pool with existing salvage gains, production choices and expenditure through siege and boarding cards. |
| Existing cards | Choir Spore | Hull Nanobots → Overloaded Warhead. Trade passive healing and income for affordable, risky pressure on a light attacker. |
| Existing cards | The Hollow Choir | Structural Reinforcement → Siege Charges. Trade repeated plating for conditional piercing while Crew attacks remain in the pool. |
| Existing cards | Choir Guardian | Emergency Bulkheads → Overloaded Warhead. Test a counterattack slot with a Hull cost while keeping restoration elsewhere. |
| Prototype cards | Siege Monitor | Shield Recharge → Iron Counterbattery. Its 8-Energy attack gains a piercing follow-up when the shooter has at least eight Shields. |
| Prototype cards | Choir Spore, The Hollow Choir and Choir Guardian | Use Feeding Lunge in the respective explored recovery slot. Its 8-Crew attack restores three Hull only when the shooter is at or below half Hull. |
| Alternate-slot prototype | Siege Monitor | Hull Nanobots → Iron Counterbattery. Compare the same attack in another Energy slot while preserving the Shield Recharge synergy. |

Counterbattery tests whether an opponent can weaken the Iron ship's offense by stripping its armor. Existing comparators such as Emergency Discharge pressure the target's Shields. Feeding Lunge tests a cheap attack with a recovery opportunity when damaged. Cataclysm Protocol already blends damage and healing at a substantially higher Crew cost and Tier 2 rarity. Both prototypes use the established cost, Shield, Hull, conditional, piercing and tactical scoring paths.

## Mothership evaluation

The boss study uses real acquisition offers, replacement choices, card upgrades, production rewards, temporary bonuses and battle preparation. Each of the six player ships gets four deterministic build strategies. Offensive and defensive builds prefer the matching card category. The economy build prefers Systems cards that generate resources or production. Balanced builds cycle between those roles. The offers use one deterministic reward stream per ship, with the same number of acquisition and upgrade events for each strategy. A fixed balanced combat policy makes the deck strategy the variable. EMP uses its separate policy.

Stages use systems 1, 6 and 12, with one, three and five legal acquisitions and upgrade events. The fixtures use the same progression reward sizes and pre-battle Hull assumptions as Pass 2. The late balanced comparison additionally keeps progression fixed while changing the enemy scaling to system 1, and tests a stock balanced deck against the system 12 opponent. Boss statistics change together in the scaling control. The controls help separate the scaling package from the progression package without treating changes in any single stat as established causes. All four motherships, all eight modifiers and four deterministic combat seeds run in each scenario.

| Mothership | Late stock wins | Late balanced wins | Late defense wins | Late balanced vs early enemy stats |
| --- | --- | --- | --- | --- |
| Clan War Barge | 0.5% | 11.5% | 21.9% | 30.2% |
| Sentinel Dreadnought | 1.0% | 8.3% | 10.9% | 15.6% |
| AXIOM Command Nexus | 0.0% | 5.2% | 9.4% | 32.3% |
| Choir Leviathan | 0.0% | 1.0% | 3.1% | 15.1% |

The progression package raised pooled wins against the same late opponents. At fixed player progression and AI policy, changing the enemy scaling package raised wins against all four, with particularly large shifts against Command Nexus and Choir Leviathan. Reward priorities also mattered. Defense was the strongest late-stage build across these fixtures. Late offense or economy builds scored 0.0% against the Leviathan on this small seed grid, while the separate defensive-build EMP policy escaped 96.9% of the time. The Leviathan restored 88.6 Hull and gained 98.7 Shields per late balanced fight. The more successful late defensive build also prolonged those fights to 69.6 mean rounds. Clan War Barge produced its difficulty through much higher attack pressure and considerably less recovery. Some early build choices converge because they have only one reward and upgrade event. Four seeds and one reward stream per ship make the estimates descriptive. The experiment isolates the enemy scaling and player progression packages, while the activity profiles show different sources of pressure across boss decks.

## Player card boundary and saves

Private card resources stay outside `CardLibrary.CARDS`, which supplies normal rewards, outpost offers, shared pools, fallback draws and saved deck identity lookup. The test covers that boundary, actual player pools and offers, and deterministic cost, condition, damage, recovery and AI fixtures. Existing player identities keep their original paths.

Expedition saves store the enemy encounter identity. An in-progress battle checkpoint stores its pre-battle state, combat seed, encounter index and frozen environment. A pending or restored battle prepares the current enemy profile's card pool. Already running battles use the pool prepared at entry.

## Reproduce

Import the project with Godot 4.7.2. Run the baseline and all experiments with the merged production profiles. On the feature branch, restore the baseline enemy resources in an audit checkout and set `ARCOSPACE_AUDIT_PRODUCTION_REF` to the full merged SHA. The runner checks production files against the audited revision. If using the prior raw baseline, pass its `full` directory to the reporter.

```sh
godot --headless --path . --script tests/enemy_deck_inventory.gd -- <shards>/inventory-before.json
godot --headless --path . --script tests/full_enemy_balance.gd -- <out>/ship-<index>.jsonl <index> <first> <last> <mode> [policies] [enemy-names]
```

- For `full`, use seeds 1–8 and all policies. For the `replay` directory, use mode `full`, seed 1 and `balanced`.
- For `expedition-fallback`, set `ARCOSPACE_AUDIT_EXPEDITION_POOL=1` and run `full` on all policies and seeds 1–8 with the five legacy enemy names above as the filter. Clear the variable for the other ordinary trial directories.
- Use seeds 1–8 and `balanced,aggressive,defensive,economic` for `faction-existing`, `faction-prototypes` and `faction-siege-hull`.
- For `held`, use mode `full`, all policies, seeds 21–28 and the enemy filter `"Siege Monitor,Sentinel,Reclaimer,Choir Spore,The Hollow Choir,Choir Guardian"`.
- On seeds 21–28 with all policies, run `faction-existing` into `faction-existing-held` for Choir Spore and The Hollow Choir. Run `faction-prototypes` and `faction-siege-hull` into their corresponding `-held` directories for Siege Monitor.
- Run one directory per boss mode with seeds 1–4 and policies `balanced,emp`. Use `boss-{early,middle,later}-{offense,defense,economy,balanced}` and the controls `boss-later-balanced-fixed` and `boss-later-balanced-starter`.
- Repeat each boss mode into its `expedition-` directory with `ARCOSPACE_AUDIT_EXPEDITION_POOL=1` and the enemy filter `"Sentinel Dreadnought"`.
- With the retained production profiles and the production-reference environment variable cleared, use mode `full`, all policies and the retained enemy filter. Run seeds 1–8 for `final` and 21–28 for `held-final`. The reporter verifies paired candidate and resource parity.

```sh
python tools/report_faction_decks.py <baseline-full-directory> <shards> docs/balance/faction-decks --retain "Siege Monitor=faction-siege-hull" --retain "Choir Spore=faction-existing" --retain "The Hollow Choir=faction-existing"
```

## Verification

All 18 targeted Godot regressions passed across combat execution, modifier and trace parity, card effects, progression, faction generation and expansion, expedition persistence and exclusivity. The Trading Outpost stress test hit the default time limit during concurrent simulations. Its isolated rerun passed 100,008 checks in 84.9 seconds. The Python tooling suite passed 21 tests, with its POSIX-only process-group test skipped on Windows.

The report verifies the baseline replay, the five replacement legacy grids, all 14 mothership scenarios and 5,760 held-out production-profile pairs. The deck audit covers 680 baseline card slots. The generated before/after data differs for exactly the three retained enemy profiles.
