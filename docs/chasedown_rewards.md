# Sublight Chasedown and combat upgrade rewards

Implemented on top of `75dcbe5` after inspecting latest main, including the recent ship rebalance. Ship/card Resources, starting pools, AI, Power Allocation, combat turns, EMP Pulse failure rules, map artwork/layout and audio are unchanged.

## Trigger and state

`ExpeditionState.can_visit` validates star-map departure before `try_chasedown` rolls once. A successful roll allows 0.5 seconds of ship movement, then stops the movement and plays a one-second screen shake with two rapid red flashes before opening the response screen, without emitting arrival. `INTERCEPTION_DELAY` in `scripts/ui/star_map.gd` controls this delay; an intercepted trip lasts at least the delay plus 0.1 seconds so short travel settings cannot visually arrive first. All travel/impact tweens are cancelled and the original screen transform is restored when the map leaves the tree. `IMPACT_DURATION`, `SHAKE_PIXELS` and `FLASH_OPACITY` tune the impact in the same script. The grid retains its immediate interception via `Expedition._request_travel`. `ExpeditionState.try_chasedown` requires distinct origin and destination PoIs, an available destination, no active battle/pending choice/interception, and remaining per-system allowance. Initial arrival, service/enemy origin or destination, menus, battle return, same/invalid/completed destinations and system jumps do not roll.

The default chance is **5% per eligible movement**, maximum **one per system**. Its independent seeded RNG leaves encounter generation, station scheduling and PoI outcome rolls unchanged. Ordinary enemy profile weights are reused, with the existing ordinary library as fallback if a custom registry contains no ordinary enemies. Existing system difficulty scaling and the normal Board scene apply. Chasedown adds one hidden battle entry to the existing encounter/result pipeline; the six generated encounters, destination and travel requirement remain intact. It has no map marker or mandatory-boss flag.

State records `navigation_origin`, `pending_destination`, `chasedown_index`, `chasedowns_this_system` and the selected response. Rebuilding the UI restores the same pending narrative or starts the battle for an already chosen response, without rerolling/reapplying it. Victory or EMP escape completes that battle and grants exactly **+1 interstellar FTL** through the existing single-use completion guard. After any upgrade choices, travel resumes to the preserved destination without a second roll. Arrival does not complete the destination. A system transition resets the limit and navigation state; pending interception/rewards block departure.

There is **no disk save/load** in the prototype. State survives encounter/UI transitions in memory; closing the game or starting another expedition ends the run. No cross-process persistence is claimed.

## Responses and tuning

Tune the exported `Sublight Chasedown` and `Combat card upgrades` groups on `encounters/expedition_rules.tres` (defaults in `scripts/expedition/expedition_rules.gd`). `TUNE` comments identify the settings.

| Response | Battle-start effect |
|---|---|
| Red Alert | +4 Shields, −3 Energy |
| Evasive Maneuvers | +3 EMP Pulse charge, −4 Shields |
| Overcharge Weapons | +5 Energy, −3 permanent Hull, minimum 1 Hull |
| Hold Course | No modifiers |

Existing modifier accumulation and resource clamps apply before normal first-turn income. Shields floor at zero; resource penalties cannot exceed half the ship's unmodified starting reserve. Evasive charge, including stacked existing bonuses, is capped at `target − 2` before the first-turn tick, leaving at least one further normal charging turn before escape is available. Offline penalties still suppress charging normally. This preparation guard changes no combat EMP Pulse charging/failure rules.

## Upgrade events

| Non-escape player victory | Upgrade opportunities |
|---|---:|
| Chasedown | 1 |
| Standard | 2 |
| Elite | 3 |
| Boss | 3 |

The compact victory summary includes upgrade count alongside Salvage/FTL, retaining room for repairs and earned bonuses. The existing card gallery and inspector make sequential choices. Each **distinct identity can be selected only once per event**, even when its next upgrade level remains available. `upgraded_this_event` stores identity keys; stale/repeated selections fail. A later event can upgrade that identity again. Every identity retains its existing two-level maximum, cost, rarity, effects and acquired draw weight. Private upgraded copies replace all player copies, including held cards; enemies keep base Resources.

`start_upgrade_event` limits the count to eligible distinct identities. Finish skips remaining opportunities; no candidates ends the event immediately. Exhausted combat upgrades add **no Salvage**; existing research-PoI exhausted-upgrade Salvage remains unchanged. A latched encounter result rejects repeated reward grants before copying stale board currency. Existing repair and tactical/strategic reward behavior remains.

Design assumption: both destruction and Systems Failure victories qualify for the rank's upgrades. EMP escape grants neither upgrades nor Salvage, while retaining existing escape completion and eligible tactical/strategic bonuses.

## Interstellar FTL and Wormhole

Both `ExpeditionProgression.ftl_carryover_cap` and `resources/expedition_progression.tres` are **0**. The existing configurable helper retains its 0–2 range; the shipping setup always starts a new system at zero. Current-system earnings, PoI count + 1 requirements, mandatory bosses and combat EMP Pulse remain unchanged.

Only `encounters/unstable_wormhole.tres` changes among PoI Resources. Base completion still grants +1 FTL; extra charge is additive and never above +1.

| Approach | Requirement (unchanged) | Old → new success | Old → new extra FTL on success | Old → new failure penalty |
|---|---|---|---|---|
| Map the perimeter | None | 100% → 100% | 0 → 0 | Not rolled; guaranteed +3 Salvage and 1 EMP offline turn unchanged |
| Probe the shortcut | None | 65% → 40% | +1 → +1 | −4 → −8 Shields next battle |
| Stabilize corridor | Reactor 4 | 80% → 50% | +2 → +1 | 2 → 3 EMP offline turns next battle |
| Reinforce transit probe | Synthesizer 3 | 75% → 45% | +2 → +1 | −4 → −8 Energy next battle |

Success/failure Salvage remains 5/2, 7/3 and 9/4 respectively. Energy penalties use the existing half-base cap, so −8 is the authored penalty rather than a guaranteed eight-resource loss. No Hull damage is added. Gates, generation weights and other PoI outcomes are unchanged.

## Validation and economy recommendation

Godot **4.7.2** editor import and all **47** automated test scripts pass. New state tests cover probability boundaries, disallowed transitions, response values/clamps, ordinary enemies/scaling, preserved destinations, single-use rewards, escape exclusions, rank counts, distinct selections, later-event eligibility, exhaustion and zero carryover. Existing boss/PoI/card/AI/music/repair regressions pass. Older ship-test snapshots were corrected to the already committed main Resources; no ship data changed.

The deterministic progression simulation covers **10,000 systems across all six ships**: 433,994 checks, 18,353 escapes, 655 surveys, 21 encounter compositions and three ranks. It verifies charge availability and state transitions, not human combat win rates. Existing 512-hand-per-ship/scenario economy checks also pass.

Rendered Compatibility/software OpenGL checks pass for Chasedown choices, sequential upgrades, milestone progression, star map and existing UI regression. Both navigation modes exercise victory and escape. Choice/gallery layouts were checked from 1280×720 and 1680×720 down to 686×384 and inspected visually. Physical Android, hardware audio and cross-process save/reload are unverified; audio code is untouched.

Upgrade supply is likely generous: a starting pool has 25 identities × 2 levels = 50 possible levels, so approximately 25 standard victories or 17 three-upgrade victories can exhaust it before acquisitions/research (mixed rewards vary). Distinct choices prevent an immediate base-to-++ spike in one event but still improve several identities per win. Keep the requested values for prototype playtesting; watch time to first ++, fraction of upgraded draws and pool exhaustion before changing rewards. No additional balance adjustments were made.

## Files

- Gameplay: `scripts/expedition/expedition_rules.gd`, `expedition_progression.gd`, `expedition_state.gd`, `expedition.gd`, `board.gd`, `ui/star_map.gd`.
- Data: `resources/expedition_progression.tres`, `encounters/unstable_wormhole.tres`.
- New tests: `tests/chasedown_rewards_test.gd`, `tests/chasedown_ui_test.gd` and their Godot UID sidecars.
- Updated regressions: expedition/milestones, FTL progression, star map, six-ship snapshot, victory rewards and the PoI reward fixture; rendered CI test list.
- Documentation: this report, developer guide, expeditions, UI layout, four balance references and balance-document generator.
