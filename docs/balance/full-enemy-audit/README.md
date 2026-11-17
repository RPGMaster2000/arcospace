# Full enemy balance audit

The [results tables](tables.md) give before/after outcome and pacing rates for every enemy, split by rank, along with the six-ship win matrix and the paired experiments. [Enemy card usage](enemy-cards.csv) lists draws, start-of-turn affordability, plays and discards. `summary.json.gz` holds the exact policy configuration and both sides' combat statistics by matchup, plus the paired estimates for individual player ships.

## Retained tuning

**Choir Guardian** has a lower tactical priority for production upgrades, **3.5 → 2.8**. It retains 51 starting Hull, 5 Shields, its Crew-oriented deck, and its recovery and draw weights. The simulated player win rate rose from **29.1% to 31.1%** on seeds 1–8 and **24.8% to 26.8%** on held-out seeds. The latter paired change was **+1.95 percentage points** with an approximate 95% interval of **+0.33 to +3.39**. All six ship-level estimates rose in both runs. Callisto, its toughest baseline matchup, moved from 8.2% to 10.5% on the selection seeds.

Mean duration fell from 29.84 to 29.41 rounds on seeds 1–8 and from 33.22 to 32.85 on held-out seeds. P90 fell from 77 to 73 and from 72 to 69, respectively. The held-out interval for mean duration spans zero (−1.13 to +0.41 rounds), and the held-out share over 40 rounds moved from 24.28% to 24.41%. The repeatable result is the modest win-rate improvement. Faster fights and higher offensive pressure remain directional estimates. Held-out direct damage per round was 2.42 → 2.44 and Hull restored was 49.3 → 48.4 per fight.

## Hollow Choir investigation

| Profile | Baseline evidence | Tuning decision |
| --- | --- | --- |
| The Hollow Choir | Starts at 42 Hull and 2 Shields. It generated 46.7 Shields and restored 28.3 Hull per fight, with 10.9 recovery plays and 8.3 damage plays. The same profile averaged 41.1 rounds against Callisto and 18.9 against Titania. | Lower recovery draw weight had the largest estimated pacing gain in screening (−1.15 rounds), with an interval spanning zero and small adverse win shifts in several matchups. Lower production priority advanced, but held-out battles took 0.10 rounds longer and paired enemy damage per round fell 0.03. The tested production change was reverted. |
| Choir Spore | Starts at 27 Hull and 2 Shields but restored 41.0 Hull per fight, with Structural Reinforcement its most played card. Callisto won 13.7% while Titania won 83.6%. | Lowering the tactical repair weight improved damage slightly in the screen and gave a longer mean duration. Lowering recovery draw or production priority moved mean length by at most a tenth of a round. |
| Choir Guardian | The hardest standard on the baseline. Its 51 starting Hull, 39.5 restored Hull and 46.6 Shields gained kept it in play. It held an average 37.8 Crew after income. | Production priority had the most promising combined estimate. Lower recovery draw weight had a small aggregate pacing effect and reduced Endeavour's simulated win rate by roughly 12 percentage points in screening. |
| Choir Leviathan | Starts at 72 Hull and restored another 60.5 per fight. It averaged 100.5 held Energy, 17.3 recovery plays and 12.2 damage plays. Starter-deck wins ranged from 0.8% to 9.4%. | Lower recovery draw weight estimated −1.73 rounds with broad uncertainty and a lower pooled starter-deck win rate. The higher damage weight also reduced starter wins. Its mothership balance remains a question for progression-equipped decks. |

The Choir screens changed one variable at a time. Tactical damage went from 0.95 to 1.25, tactical Hull preference from 1.3 to 1.05, Hull-effect draw preference from 1.3 to 1.05, and tactical production preference from 3.5 to 2.8. Across the four ships, low opening Shields coexisted with substantial Shield gain during combat. The fleet's long fights were also concentrated in particular matchups. This helps explain why simply increasing the tactical damage weight produced small or mixed pacing effects.

## Other roster findings

- **Siege Monitor and Bastion Frigate** were the clearest stall outliers, averaging 50.6 and 45.0 rounds, with 20.8% and 18.0% unresolved. Siege Monitor starts at 43 Hull and 22 Shields. Bastion Frigate starts at 25 Hull and 13 Shields, then generates 120.8 Shields per fight while dealing just 1.16 direct damage per round. Shield Recharge and Shield Plating were the top plays for both. Raising their tactical damage weight from 0.9 to 1.35 gave uncertain pacing changes. Reducing their Hull-effect draw weight from 1.8 to 1.4 also gave uncertain pacing gains, with roughly 12-point and 11-point win-rate drops for Ganymede and Callisto against Siege Monitor in screening. Both profiles retain their baseline settings.
- **Sentinel and Reclaimer** were the next-slowest standards at 34.8 and 31.4 rounds. Sentinel gained about 59 Shields per fight, while Reclaimer held about 97 total resources after income and frequently used Synthesizer Upgrade and Reactor Salvage. These are descriptive patterns from the simulated decks and starting-resource model.
- **AXIOM Enforcer and Wreckbreaker** were almost as hard to beat as The Hollow Choir at 35.2% and 35.7% player wins, with different pacing. Wreckbreaker dealt 3.22 damage per round and had a 34-round P90. AXIOM Enforcer produced much less recovery than the stalling ships. **Scrap Skiff** was the easiest standard at 94.1% wins and a nine-round median.
- **Marauder Vanguard** was difficult and decisive for the lone elite (12.2% player wins, 10-round median). The bosses ranged from 3.1% to 7.5% simulated player wins. Thunderbolt and Callisto each won 0.8% against Clan War Barge, which averaged 3.94 enemy damage per round. Enemy progression classes and the results' starter-deck scope informed the decision to leave boss and elite values in place.

## Setup

- Production baseline `5591a0067d8976b24959e9791b767152ba5ceb72`. The initial audit runners were added in `b274691`. Candidate resources for the validation runs are in `ff2471fb9d292c894e26e9b883e0f433db2e162a`, and the retained production revision is `f3d60d2437c24213a30024b5bd404d949ff4e232`.
- Godot 4.7.2 stable official, headless on Windows. All six starter decks (Endeavour, Thunderbolt, Titania, Ganymede, Callisto, Orion) faced all 19 unique enemy resources, including 14 standards, one elite and four bosses/motherships. The roster uses the complete faction catalog and unions the configured and legacy enemies plus the mandatory boss, deduplicating by resource path.
- All eight modifier IDs, all five existing policies (balanced, aggressive, defensive, economic and EMP), three Systems Failure turns, a two-charge boss EMP bonus, a 100-round cap and a 100-action cap per turn. Baseline and final use seeds 1–8. The one-variable screens use 1–6. Seeds 9–16 were reserved for validation.
- Combat win rates and pacing pool the four non-EMP policies with equal weight. EMP escape is reported separately. These are simulated starting-deck outcomes. In particular, the boss runs omit the upgrades, rewards and other advantages a player can accumulate before meeting a mothership.
- The 80,640 completed runs comprise 36,480 full-roster baseline battles, 28,800 candidate battles, 7,680 held-out control battles and 7,680 battles with the candidate production profiles on the two seed ranges.

The audit uses production card effects, the shared combat execution sequence and the existing simulator’s RNG and policy setup. Resources are Materials, Energy and Crew, in that order. Income counts recurring production credited at turn start. Spend counts paid card costs. Held resources average the balance after income across observed turns. Hull dealt comes from the card resolution damage report. Hull restoration includes temporary plating and healing. Shield counts are net changes per card resolution, including transfers. Environmental Hull impacts and suspended shields are outside these flow totals. Damage per round includes damage absorbed by Shields. The card table samples affordability at the start of the turn, so plays after extra draws or changes in resource balances can occur outside that sample.

Candidate estimates use identical seeds, starter ships, policy and modifier for each pair. The table brackets give exploratory 95% intervals from 4,000 whole-seed-block bootstrap resamples. The blocks preserve shared RNG conditions. The intervals are approximate with six screening and eight validation blocks, and the screen compares several variables. Treat small or contradictory effects as inconclusive. In the activity table, damage per round weights each round equally. The paired change averages the per-battle damage rate difference so each matched condition receives equal weight.

## Reproduce

Use the baseline production resources for the baseline and screens and use the candidate revision for the validation rows. With an imported checkout, invoke the following once per ship index `0` through `5` (or use `-1` for all ships in one file). Create the output directory before the run.

```sh
godot --headless --path . --script tests/full_enemy_balance.gd -- <out>/ship-<index>.jsonl <index> <first-seed> <last-seed> <mode>
```

An optional comma-separated list of policy names after `<mode>` limits a shard to those policies. Set `ARCOSPACE_AUDIT_PRODUCTION_REF` to the full baseline commit hash when running newer audit tooling against baseline resources. The runner checks that production files match that revision before recording it.

| Directory | Production resources | Seed range | Mode |
| --- | --- | --- | --- |
| `full` | baseline | 1–8 | `full` |
| `offense` | baseline | 1–6 | `offense` |
| `repair` | baseline | 1–6 | `repair` |
| `draw` | baseline | 1–6 | `draw` |
| `economy` | baseline | 1–6 | `economy` |
| `sentinel-offense` | baseline | 1–6 | `sentinel-offense` |
| `sentinel-draw` | baseline | 1–6 | `sentinel-draw` |
| `held` | baseline | 9–16 | `choir` |
| `final` | candidate revision | 1–8 | `validation` |
| `held-final` | candidate revision | 9–16 | `validation` |

Collect all directories under the same parent and run the following from the feature branch. The report validates each grid, confirms 2,880 identical results where the scripted Choir economy candidate and production validation overlap, and overlays the retained profile onto the full baseline.

```sh
python tools/report_enemy_balance.py <parent> docs/balance/full-enemy-audit --retain "Choir Guardian" --release-revision f3d60d2437c24213a30024b5bd404d949ff4e232
```

## Regression checks

All 13 targeted Godot regressions passed on the retained tuning. They covered combat execution, modifiers, trace and audit parity, enemy roster, expedition flow, save, resume, fresh-process persistence, persistence session, star-system resume, faction generation and faction expansion. The Python tooling suite passed 21 tests, with the POSIX-only process-group test skipped on Windows.
