# Card progression validation

Validated with Godot 4.7.2 on Windows against main `16f9a53be64841cb3c4ca79ec35d4c8229945b49`.

## Automated checks

- 33 test scripts pass, including all 44 cards at both upgrade levels, costs/rarity, held-copy replacement, reward exhaustion, acquisition weights, all three player pools and all five enemy profiles.
- The additional upgrade UI test covers all 88 variants with normal and both Ion Storm previews: descriptions retain 16 px text and do not overlap discard buttons. Long descriptions borrow decorative art space only. Titles retain upgrade suffixes.
- Existing Android layout checks: 2,435 assertions; crowded resource bars: 4,095; status/modifier checks: 10,657. Touch targets and synthetic input pass; a physical Android run, APK export and actual touch/GPU behavior were not verified.
- FTL progression: 10,000 systems, 426,069 checks; PoI overhaul: 93,950 checks; Trading Outpost: 47,176 checks. Card reward tests now account for player-only, nonduplicate acquisition and exhaustion. Authored PoI outcomes, encounter probabilities, station prices, Salvage awards and FTL code are unchanged.
- One existing test remains failing: `travel_battle_test.gd` reports the Emergency Jump label/button overlap assertion in all 15 combinations. The identical 15 failures reproduce on untouched baseline code; its other battle/profile/escape assertions pass. No unrelated FTL/layout changes were made.
- Headless editor import has no script parse/compile errors. This restricted environment cannot write Godot's normal user log/editor cache or read the system certificate store; those environment messages also occur on baseline.

Run with `godot --headless --path . --script tests/card_progression_test.gd`; substitute another test script to run it. Regenerate tables using `tools/generate_balance_docs.gd`.

## Deterministic balance diagnostic

`tests/card_progression_simulation.gd` runs seeds 1–10 against each of five enemy profiles for every player ship: 450 battles across three policies. Raw output: `tests/card_progression_simulation_results.json`. Baseline models the previous full player pool, round-six unlock and original enemy AI priorities; it uses the current RNG implementation, so it is a policy comparison rather than a bit-for-bit replay of historical draws.

This is a combat-only heuristic diagnostic: no battle modifiers, Emergency Jump, expedition production upgrades, rewards or human decisions. Forty-round unfinished matches are unresolved. The player uses the existing simple AI; these figures are not human win-rate estimates.

| Policy | Wayfarer W/L/unresolved | Specter W/L/unresolved | Bastion W/L/unresolved |
|---|---|---|---|
| Previous policies | 20/29/1 | 19/30/1 | 23/26/1 |
| New starting pools and enemy preferences | 19/27/4 | 5/40/5 | 16/31/3 |
| New policies, three acquisitions and three upgrades | 28/14/8 | 12/31/7 | 23/22/5 |

Progressed fixtures: Wayfarer acquires Siege Driver, Antimatter Lance and Cataclysm Protocol; Hull Overhaul++ and Laser Burst+. Specter acquires Antimatter Lance, Omega Overcharge and Emergency Reserves; Hull Nanobots++ and Laser Burst+. Bastion acquires Siege Driver, Emergency Refit and Cataclysm Protocol; Hull Overhaul++ and Breach Charge+. Acquisitions weigh ×3 within rarity; there are no enemy upgrades.

Among new-policy starting-pool simulations, 15 enemy Tier 2 plays occur by round five; the maximum printed damage on such a card is 20, once, from Marauder Vanguard. Earlier eligibility does not bypass resource affordability. No damage cap was added. Across ordinary-length simulations, Tier 2 cards are both drawn and played; high-cost cards remain situational rather than guaranteed plays.

With seed 1234 and 20,000 independent draws after unlocking:

| Enemy archetype | Attack identities | Hull/Shield identities |
|---|---:|---:|
| Marauder (also Vanguard) | 48.6% | 17.5% |
| Sentinel (also Dreadnought) | 28.4% | 32.5% |
| Reclaimer | 31.9% | 28.4% |

All 44 identities appear for every enemy. A fixed affordable attack/Shield/production fixture selects attack for Marauder, Shields for Sentinel and production for Reclaimer; endangered ships can still prioritize repairs. Immediate guaranteed wins and avoidance of fatal self-damage precede tactical scoring. Elite/boss score variation is 8%, versus 25% for standards.

## Remaining balance concerns

Specter and boss encounters warrant human playtesting: the scripted player performs poorly there, even after three upgrades. Defensive enemies prolong some fights. Acquisition/upgrades improve outcomes in these fixtures, but this small seed sample cannot establish final balance. Production upgrades deliberately remain +1 per play, gaining immediate resources/defense instead; enhanced restoration can still create the existing Ablative Plating. No new extra-action grants, cost discounts or action-loop mechanisms were introduced.
