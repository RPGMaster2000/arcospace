# Combat Balance Pass 1

[Generated tables](pass-1-tables.md) include before/after ship rates, the enemy matchup matrix, storm comparisons, and every isolated trial. [Machine-readable results](pass-1-summary.json) include exact counts and paired intervals. The original audit is in [PR #65](https://github.com/RPGMaster2000/arcospace/pull/65).

Across 30,720 matched battles, direct-combat wins rose from 40.8% to 43.0%
and EMP escapes fell from 68.0% to 64.3%. Ganymede had the largest
combat gain (+10.0 percentage points), followed by Thunderbolt (+3.7).
Titania still led at 54.7%, down from 55.9%, without a ship-stat change.

## Changes retained

1. **Guaranteed storm amplification.** Ion doubles Energy effects, Metal doubles Materials effects and Psionic doubles Crew effects for both ships. The event duration stays at three rounds. The scheduler consumes the historical random draw to preserve activation timing, and the resolver still uses the existing scaling rules and costs. In the storm-only run, Ion and Psionic EMP escapes dropped by 8.6 and 12.2 points respectively. Combat-win changes were smaller and their intervals spanned zero.
2. **Ganymede gets Siege Charges in place of Shield Disruptor.** The existing 12-Materials Tier 1 card converts production into Hull damage, with a follow-up against low Shields. The isolated swap gained 10.0 percentage points of combat wins. Reactor 1 → 2 on its own gained 0.1 points and lowered player Systems Failure activations from 210 to 131. The combined trial gained 10.6 points. The single swap captures most of that improvement.
3. **Thunderbolt gets Capacitor Overload in place of Desperate Conversion.** The outgoing Crew card was played on about 15% of audit draws. The existing 11-Energy Tier 1 card breaks Shields. The isolated swap gained 3.1 points of combat wins. EMP escapes moved by −1.9 points with an interval spanning zero. Drive timing and resistance are unchanged.
4. **The Hollow Choir starts with 2 Shields, down from 4.** The isolated trial gained 3.3 points across all ships, including 3.5 for Callisto, 3.1 for Ganymede and 5.5 for Endeavour. Titania gained 1.2 points with an interval spanning zero. Titania's EMP escapes declined in this isolated matchup, a trade-off to check in play.

New Ganymede and Thunderbolt expeditions use the revised pools. Existing expeditions keep their original identities, upgrades, removals and pending rewards. The checkpoint stores the starting-pool revision for affected ships. Combat modifier IDs and environmental snapshots use the existing format.

## The Hollow Choir matchup

The Choir starts with 42 Hull and reserves of 12 Materials, 8 Energy and 12 Crew. It produces 2 Materials, 1 Energy and 3 Crew per round. Its authored draws favor Crew, Materials, repair and shields. Its tactical weights emphasize production and Hull repair, with low disruption weighting. The pool contains theft and Crew attacks as well.

In PR #65, Callisto won 5.9% of combat-policy encounters and lasted 41.9 rounds on average. It had zero player Systems Failure activations and averaged 58 Materials and 80 Energy at sampled start-of-turn checkpoints. Its Aggressive policy won 18.8% versus 0% for Balanced. Titania won 71.1% in 23.2 rounds on average and triggered 451 enemy Systems Failure activations across 512 battles. Its reserves and offensive cards let it pressure the Choir earlier. These observations favor testing defenses first. They leave the relative contribution of recovery, card families and policy choice uncertain.

## Other candidates

| Candidate | Values tested | Decision |
|---|---|---|
| Ganymede Reactor | 1 → 2, alone and with the deck swap | Omit. Fewer Systems Failures, with little additional direct-combat benefit. |
| Fabrication Strike | 17 → 16 Materials | Inconclusive. Affordability and play rate rose slightly. The win estimate was small and favored Titania more than Ganymede. |
| Command Infiltration | 17 → 16 Crew | Inconclusive. Affordability and plays per draw improved. Combat-win intervals spanned zero for all three ships. Enemy Systems Failure activations increased from 509 to 565. |
| Boarding Operations | Crew steal 4 → 3, same cost, Hull damage and penetration | Reject. It removed about 0.88 net Crew per play and reduced Orion's EMP escape rate. High usage alone does not establish excessive value. |
| Rustjack | 4 → 6 starting Shields | Reject. Thunderbolt and Callisto each lost about 5.5 points while Endeavour stayed near its reference rate. Preserve the easier encounter for pacing. |
| Sentinel Dreadnought progression | Three Tier 1 acquisitions and one level-1 upgrade per family | Supplemental. Combat wins moved from 4.0% to 3.6% and EMP escapes from 60.4% to 65.1%, with both intervals spanning zero. The loadouts omit station purchases, PoI bonuses, hull recovery and route choices. Leave the boss unchanged pending Starfront playtesting. |

Titania keeps its authored reserves. If manual play confirms a large lead, the next small test is one offensive starting identity swap.

On held-out seeds, Ganymede gained 4.8 combat-win points [2.3, 7.5].
Thunderbolt gained 2.1 points [−1.2, 5.5], so the direction replicated but
the size of the benefit is uncertain. Both held-out comparisons include the
Choir adjustment and neither shows a clear change in EMP escape rates.

## Reproduce the comparison

Use Godot 4.7.2 and create the output directories before running. For each ship index 0–5, repeat the two commands below with the corresponding index and filename.

The published control and candidate runs began from the PR #65 checkout
with guaranteed amplification applied locally. The combined run used
commit `6c93556` for gameplay. The current driver reconstructs both arms
directly from this branch.

```sh
godot --headless --path . --script tests/combat_balance_audit.gd -- storm-only/ship-0.jsonl 0 1 16 all storm-only
godot --headless --path . --script tests/combat_balance_audit.gd -- final/ship-0.jsonl 0 1 16 all
godot --headless --path . --script tests/combat_balance_candidates.gd -- candidates/ganymede_deck.jsonl ganymede_deck 1 16
```

- Use seeds 1–16 for ganymede_deck, ganymede_reactor, ganymede_both and thunderbolt. These trials cover all eight modifiers.
- Use seeds 1–16 for choir, rustjack and progressed_boss. These trials cover no modifier and the three storms.
- Use seeds 1–8 for fabrication, infiltration and boarding. These trials cover no modifier and the three storms and include encounters that can draw the tested card. The candidate driver measures card usage on both loadouts with identical coverage.
- For held-out confirmation, use ship indices 1 and 3 and seeds 17–24. Save the two arms in holdout/control and holdout/combined.

```sh
python tools/compare_combat_balance.py docs/balance/combat-audit/matches.jsonl.gz storm-only candidates docs/balance/combat-audit/pass-1-summary.json --final-shards final --holdout-shards holdout
python tools/render_combat_balance_pass.py docs/balance/combat-audit/pass-1-summary.json docs/balance/combat-audit/pass-1-tables.md
```

The full comparison pairs ship, enemy, modifier, policy and seed. It uses 24,576 non-EMP-policy pairs for combat and 6,144 EMP-policy pairs for escapes. Paired 95% intervals resample entire seed blocks (4,000 replicates, Python RNG seed 1) to preserve correlations across conditions that share a seed. These intervals are descriptive and do not correct for multiple comparisons. The original 16 seeds also informed candidate selection. The eight held-out seeds give a separate check for the two affected player ships. The automated policies are a fixed mix and cannot estimate win rates for experienced players or full expeditions.
