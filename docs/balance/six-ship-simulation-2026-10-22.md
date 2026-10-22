# Six-ship simulated gameplay results — 22 October 2026

Source: [`8864ed8`](https://github.com/RPGMaster2000/arcospace/commit/8864ed8ee1b9ea594ddc4cca5ce257fd9a866721), including the two-disabled-system Systems Failure threshold. Engine: Godot 4.7.2 headless.

## Method

- **5,760 independent fresh encounters:** 6 player ships × 8 expedition enemy profiles × 6 modifier states × seeds 1–20. Each ship plays 960 battles; each enemy/modifier cell has 20. Enemy and modifier combinations receive equal weight, rather than expedition encounter probabilities.
- Original starting statistics, 28-identity player pools, base card levels, no acquisitions, no expedition bonuses, no post-battle carryover. Player always goes first, matching battle flow. This is encounter success, not full-expedition completion.
- Production components are reused for card draws, opening 2/2/2 hand, Tier 2 locks/chance/caps, card resolution, modifiers, AI, two-system failure countdown and EMP charge/disruption. All six modifier states are included, including None. Presentation, animation delays and reward screens are omitted; resolved damage is applied immediately.
- The current EnemyAI heuristic chooses cards for both sides. Enemies retain profile-specific card weights, tactical weights and variation. Player AI uses its default priorities/variation; no player-hand or future-draw knowledge is given to the opponent.
- Allocation policy: Balanced normally, Systems while failure is active. Matching weight 2.0, unchanged. No bespoke ship strategy or guaranteed recovery.
- **EMP policy:** Thunderbolt uses EMP immediately when ready; Titania never uses it. Endeavour, Ganymede, Callisto and Orion also use it when ready. Actual ship charge times, resistance, permanent Hull damage and five-turn disruption are respected.
- Maximum 100 rounds or 100 actions in one turn. Limit cases remain unresolved and are not silently counted as defeats. One round contains up to one full player turn and one full enemy turn, including extra actions.
- RNG streams are seeded separately for hands, AI, modifiers/combat and EMP. Identical seed sets are used for every ship. A repeated complete Endeavour batch (960 battles) produced byte-identical records.

## Overall results

**Combat wins** = enemy Hull destruction or enemy Systems Failure. **Success** = combat wins + EMP escapes. All percentages use all 960 battles, including draws/unresolved.

| Ship | Combat wins | EMP escapes | Losses | Draws | Unresolved | Combat win rate | Success rate | Mean rounds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Endeavour | 344 | 448 | 167 | 1 | 0 | 35.8% | 82.5% | 13.83 |
| Thunderbolt | 52 | 600 | 307 | 1 | 0 | 5.4% | 67.9% | 11.33 |
| Titania | 585 | 0 | 352 | 2 | 21 | 60.9% | 60.9% | 21.20 |
| Ganymede | 189 | 522 | 248 | 1 | 0 | 19.7% | 74.1% | 14.86 |
| Callisto | 110 | 595 | 255 | 0 | 0 | 11.5% | 73.4% | 15.42 |
| Orion | 242 | 404 | 312 | 2 | 0 | 25.2% | 67.3% | 13.66 |

## Victory and defeat causes

| Ship | Hull wins | Systems wins | Hull losses | Systems losses |
|---|---:|---:|---:|---:|
| Endeavour | 338 | 6 | 163 | 4 |
| Thunderbolt | 38 | 14 | 301 | 6 |
| Titania | 507 | 78 | 344 | 8 |
| Ganymede | 179 | 10 | 243 | 5 |
| Callisto | 88 | 22 | 254 | 1 |
| Orion | 217 | 25 | 310 | 2 |

## Success by enemy

Each value is success percentage over 120 battles (six modifiers × 20 seeds); the same EMP policy applies.

| Enemy | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion |
|---|---:|---:|---:|---:|---:|---:|
| Marauder | 91.7% | 52.5% | 85.8% | 80.8% | 66.7% | 61.7% |
| Sentinel | 90.8% | 85.8% | 66.7% | 90.8% | 94.2% | 80.8% |
| Reclaimer | 92.5% | 78.3% | 67.5% | 85.0% | 83.3% | 73.3% |
| Marauder Vanguard | 50.8% | 36.7% | 39.2% | 30.8% | 37.5% | 39.2% |
| Sentinel Dreadnought | 74.2% | 69.2% | 10.8% | 73.3% | 75.8% | 63.3% |
| Rustjack | 93.3% | 73.3% | 89.2% | 85.8% | 80.8% | 89.2% |
| AXIOM-7 | 85.0% | 73.3% | 62.5% | 75.8% | 76.7% | 67.5% |
| The Hollow Choir | 81.7% | 74.2% | 65.8% | 70.0% | 72.5% | 63.3% |

## Success by modifier

Each value is success percentage over 160 battles (eight enemies × 20 seeds).

| Modifier | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion |
|---|---:|---:|---:|---:|---:|---:|
| None | 81.9% | 68.1% | 62.5% | 76.2% | 73.8% | 66.2% |
| Asteroid belt | 71.9% | 47.5% | 58.1% | 57.5% | 56.9% | 58.1% |
| Ion storm | 80.6% | 73.1% | 58.1% | 78.1% | 77.5% | 68.8% |
| Solar flare | 84.4% | 66.2% | 65.0% | 66.9% | 63.1% | 63.8% |
| Nebula | 92.5% | 81.2% | 53.1% | 90.6% | 90.0% | 81.9% |
| Temporal Rift | 83.8% | 71.2% | 68.8% | 75.0% | 79.4% | 65.0% |

## Interpretation and limits

These are results of the stated automated policies, not human win-rate estimates. Titania has the highest combat-win count under this test but voluntarily forgoes escape; compare combat wins and success separately. Thunderbolt relies heavily on its fast EMP, as intended by the requested policy. Policy differences prevent treating success rates as an isolated measure of ship strength.

Titania reached the 100-round cap in 21 battles; these remain unresolved. Systems Failure defeats are uncommon under the two-system threshold in this sample; this does not establish a causal improvement versus the previous threshold because no before/after control was run. No card, ship, AI, allocation or balance setting was changed for these runs.

## Reproduction and validation

Run from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script tests/six_ship_gameplay_simulation.gd
```

This writes all per-match records to `.godot/six-ship-simulation-all.json`. For separate ship batches, append `-- 0` through `-- 5` in ShipLibrary order; outputs use the corresponding numeric suffix. The committed [aggregate JSON](../../tests/six_ship_gameplay_results.json) contains ship summaries and all 288 matchup/modifier cells. The [simulation harness](../../tests/six_ship_gameplay_simulation.gd) specifies the RNG seeds and policies.

Validation: every ship has 960 unique encounters, each enemy/modifier cell has exactly 20 seeds, all outcomes reconcile, Titania records zero EMP escapes, no action limit was reached, and the Endeavour repeat is byte-identical. The diagnostic reuses tested gameplay components; it does not exercise rendered HUD, Android performance or full expedition progression.
