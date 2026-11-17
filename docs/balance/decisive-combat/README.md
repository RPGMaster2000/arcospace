# Enemy Balance Pass 2

The [results tables](tables.md) cover all 19 enemy profiles and all six player ships. The [enemy card table](enemy-cards.csv) records draw, affordability and use counts. `summary.json.gz` contains the full configuration, per-ship, per-policy and per-modifier results, isolated paired comparisons, independent validation and mothership loadout fixtures.

## Retained change

Bastion Frigate trades Emergency Bulkheads for Breach Charge in the same 8-Materials deck slot. The ship still fields Shield Plating, Shield Recharge and its opening armor. Breach Charge used that slot to clear Shields and deal damage. On held-out seeds it was played 2,856 times across 1,536 combat-policy fights.

| Bastion Frigate metric | Selection seeds | Held-out seeds |
| --- | --- | --- |
| Mean rounds | 45.0 → 40.5 | 49.8 → 42.8 |
| Median rounds | 32 → 28 | 42 → 33 |
| Over 40 rounds | 41.1% → 36.3% | 51.4% → 42.4% |
| Unresolved | 18.0% → 13.9% | 20.1% → 13.0% |
| Enemy direct damage per round | 1.16 → 1.36 | 1.19 → 1.34 |
| Enemy Shields gained per fight | 120.8 → 94.5 | 134.4 → 90.7 |
| Enemy Hull restored per fight | 45.4 → 42.6 | 57.5 → 50.9 |
| Enemy recovery sequences per fight | 5.65 → 4.77 | 6.11 → 4.74 |
| Simulated player wins | 65.6% → 63.0% | 58.5% → 59.2% |

The independent estimate for mean duration was **−7.00 rounds** (approximate 95% interval **−12.00 to −3.02**). The share over 40 rounds fell **8.98 percentage points** (**−17.32 to −2.86**), and unresolved fights fell **7.16 points** (**−10.74 to −3.78**). The paired direct damage rate and recovery sequence count improved on both seed sets. Thunderbolt was an exception on the selection seeds, where its simulated win rate fell about ten points from an approximately 80% baseline. Its held-out drop was 1.2 points. The held-out pooled win-rate interval spanned zero. P90 still reaches the 100-round cap and the long-fight rate remains well above the desired light-ship range.

## Rejected adjustments

- **Bastion Frigate.** Torpedo Salvo shortened fights in screening but reduced simulated player wins by roughly eleven points, with declines for all six ships. The Shield draw reduction had a smaller effect than Breach Charge. Lower production priority provided no pacing gain.
- **Siege Monitor.** Missile Team reduced unresolved fights on both seed sets, but its held-out player win-rate estimate fell 6.1 points, including drops of about 14 points for Callisto and 17 for Orion. The Breach Charge alternative reduced held-out unresolved fights and recovery sequences. Its held-out mean-length and over-40 intervals spanned zero and direct damage per round was flat. Siege Charges and reduced Shield draw each had unfavorable ship-level shifts in screening. Lower production priority had little pacing effect.
- **Choir Spore.** Removing Hull Nanobots alone reduced recovery sequences in screening with little reliable change in total duration. Cargo Raid reduced screening mean duration by 0.47 rounds, but the held-out mean was essentially flat. Shield Breachers gave up enemy damage pressure in screening.
- **The Hollow Choir.** Cargo Raid reduced Shield generation and unresolved fights, but held-out mean duration was inconclusive and enemy direct damage per round moved down. The held-out win shifts were concentrated in Endeavour and Orion. The exploratory Boarding Operations result used an Orion signature and was ineligible for production.
- **Choir Guardian.** Shield Breachers slightly shortened the screening mean, but lowered enemy direct damage per round and left the long-fight estimate uncertain. The production tuning from PR #89 remains the baseline.
- **Secondary standards.** Sentinel and Reclaimer still averaged 34.8 and 31.4 rounds on the reproduced baseline. Their Shield generation and resource retention respectively distinguish them from faster AXIOM and Scavenger encounters. This pass tested its main hypotheses on the higher-priority outliers.

## Method

The production baseline is `13e5f027ab6f9d9741bcc1ed5ace6285977b7480` with PR #89's Choir Guardian production weight of 2.8. The Bastion production profile was rerun at `556ef7fd0c2a56625e3009441f2d6879aacf1fee`. The audit uses the current Godot 4.7.2 battle execution, draw selection, effect resolution, Systems Failure and modifier rules with no presentation. Starter-deck combat results pool the balanced, aggressive, defensive and economic policies equally. The EMP policy has its own escape column. Each player/enemy pairing covers all eight modifiers and eight seeds in each reported phase. Simulated starter-deck outcomes describe the tested policies.

The 36,480 baseline battles reproduced Pass 1's final outcome, duration and combat-flow measurements for all 19 enemies. The seven selection experiments ran 26,112 combat-policy battles. The progressed-mothership study adds 23,040 battles across its three loadout stages.

The recovery-sequence count increments when two consecutive enemy turns each restore positive Hull or Shields and each deals less than three direct damage, including direct damage absorbed by Shields. A longer run still counts as one sequence. The machine-readable report also includes the mean number of turns in these sequences and the mean longest run. Like the existing activity measures, the metric samples resolved actions and excludes environmental Shield suspension. Recovery plays measure realized gain, including temporary Hull plating. Damage per round in the activity table weights rounds equally. Paired changes average each battle's damage rate.

Comparisons use 4,000 bootstrap resamples of whole paired seed blocks. Each bracket gives an approximate 95% interval. Eight blocks and multiple screened hypotheses limit how precisely the intervals estimate out-of-sample changes. Compare the full ship matchup matrix as well as pooled pacing and victory rates.

## Isolated scenarios

| Mode | Enemy | Change |
| --- | --- | --- |
| `decisive-deck` | Bastion Frigate | Emergency Bulkheads → Breach Charge (8 Materials, Shield damage plus direct damage) |
| `decisive-deck` | Siege Monitor | Emergency Bulkheads → Siege Charges (12 Materials, piercing damage with a follow-up against low Shields) |
| `decisive-deck` | Choir Spore and Choir Guardian | Emergency Bulkheads → Shield Breachers (7 Crew, Shield disruption) |
| `decisive-deck` | The Hollow Choir | Emergency Bulkheads → Boarding Operations (7 Crew, piercing damage and Crew theft) |
| `decisive-deck-alt` | Bastion Frigate | Emergency Bulkheads → Torpedo Salvo (10 Crew, extra damage against low Hull) |
| `decisive-deck-alt` | Siege Monitor | Emergency Bulkheads → Breach Charge |
| `decisive-shields` | Bastion Frigate and Siege Monitor | Shield-effect draw weight 2.0 → 1.5 |
| `decisive-production` | Bastion Frigate and Siege Monitor | Tactical production weight 4.0 → 2.5 |
| `decisive-spore-trim` | Choir Spore | Remove Hull Nanobots |
| `decisive-spore-hull` | Choir Spore | Hull Nanobots → Boarding Operations |
| `decisive-affordable` | Bastion Frigate | Emergency Bulkheads → Breach Charge (control repetition for the confirmed candidate) |
| `decisive-affordable` | Siege Monitor | Emergency Bulkheads → Missile Team (6 Crew) |
| `decisive-affordable` | The Hollow Choir | Emergency Bulkheads → Cargo Raid (6 Crew, direct damage and Materials theft) |
| `decisive-affordable` | Choir Spore | Hull Nanobots → Cargo Raid |

Emergency Bulkheads overlaps with Shield Plating and Shield Recharge. The one-card substitutions preserve these Shield and Hull recovery options and redirect a draw into pressure. The primary Iron replacements retain the Materials family of the card they replace. Breach Charge matches its cost. Siege Charges costs four more and the card table measures whether the Siege Monitor can play it in practice.

Boarding Operations is an Orion signature. It was included in the exploratory deck trials, then disqualified from production selection. Cargo Raid uses the same Crew family and gives the Choir an existing non-signature attack and disruption option.

## Mothership progression fixtures

Use the normal expedition deck reward, replacement, upgrade, attribute choice, next-battle bonus and battle preparation APIs. Each ship gets a deterministic series of legal offers with a preference for direct-damage cards. Fixture state and card pools are serialized in the report. Each stage includes four motherships using normal defense-mode enemy scaling for its system number. These are illustrative snapshots with both player progression and enemy scaling, so differences between stages include both effects.

| Stage | System | Acquisitions / upgrade events | Production rewards | Opening Hull | Temporary resources |
| --- | --- | --- | --- | --- | --- |
| Early | 1 | 1 / 1 | — | 90% of capacity | +2 Materials |
| Middle | 6 | 3 / 3 | +1 Reactor | 88% of capacity | +4 Energy, +3 Shields |
| Later | 12 | 5 / 5 | +1 Reactor, +1 Quarters | 85% of capacity | +4 Energy, +4 Materials, +5 Shields |

| Mothership | Early combat wins | Middle combat wins | Later combat wins |
| --- | --- | --- | --- |
| Clan War Barge | 6.8% | 4.2% | 4.2% |
| Sentinel Dreadnought | 4.0% | 4.3% | 4.5% |
| AXIOM Command Nexus | 7.4% | 4.0% | 1.2% |
| Choir Leviathan | 3.4% | 2.3% | 2.0% |

These progressed fixtures still had low combat win rates, including a 2.0% late-stage win rate against Choir Leviathan. The corresponding EMP policy escaped 65.6% of the time. Enemy scaling and the fixed reward choices both affect the comparison across stages. In particular, the late AXIOM Command Nexus is a difficulty concern under these fixture policies. The study uses one progressed loadout per player ship and stage, so its estimates cannot establish a boss-wide balance change.

## Expedition saves

The existing save stores the enemy encounter identity. An in-progress battle checkpoint stores the pre-battle expedition, encounter index, combat seed and frozen environment. On resume, Arcospace starts that battle again with its current enemy profile. A pending or resumed encounter with an updated ship therefore uses its new card pool. A battle already running has its own prepared card pool. The resource edit requires no save migration.

## Reproduce

For each directory, create output files with one invocation per player index `0` through `5`, or run index `-1` for all six. Use an imported project with Godot 4.7.2.

```sh
godot --headless --path . --script tests/full_enemy_balance.gd -- <directory>/ship-<index>.jsonl <index> <first-seed> <last-seed> <mode> [policies] [enemy-names]
```

- On the baseline production revision, run mode `full` and each isolated mode into its own directory with seeds 1–8. Pass `balanced,aggressive,defensive,economic` for the isolated modes. Allow all five policies for the baseline.
- On the baseline, run `boss-early`, `boss-middle` and `boss-later` into equally named directories on seeds 1–8 with all policies. Run `decisive-focus` into `held` on seeds 21–28 with all policies.
- Run `decisive-affordable` into `affordable-held` on seeds 21–28 with all policies for the independent substitution comparison.
- Run `decisive-deck-alt` into `siege-breach-held` on seeds 21–28 with all policies and the enemy filter `"Siege Monitor"`.
- Run `decisive-focus` on the selected production profiles into `final` for seeds 1–8 and `held-final` for seeds 21–28. Pass `all` for policies and quote the comma-separated list of retained ship names. For baseline runs using newer audit tooling set `ARCOSPACE_AUDIT_PRODUCTION_REF` to the baseline SHA. Production content is checked against that SHA before the run.

```sh
python tools/report_decisive_balance.py <output-parent> docs/balance/decisive-combat --retain "Bastion Frigate"
```

The report validates each grid and checks that every shared selection and holdout result for the real Bastion resource exactly matches the selected scripted deck.

## Regression checks

All 13 focused Godot regressions passed with the Bastion change. They covered combat trace, audit parity, execution, modifiers and enemy roster, faction generation and expansion, expedition flow, save/resume, fresh-process resume, session persistence and star-system resume.

The Python tooling suite passed 21 tests, with its POSIX-only process-group test skipped on Windows.
