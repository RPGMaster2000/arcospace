# Star-system pressure and exploration v0.1

Enter a system, explore encounters, acquire FTL Access from either a direct Fuel Depot or an optional Sensor Relay → Ancient Navigation Array chain, then choose when to jump. Existing mandatory Boss restrictions remain independent. Completing one route is sufficient; pressure never locks objectives or prerequisites.

## Ownership

- `ExpeditionState`: authoritative pressure, profile, access, completion ledger and eligibility; exactly-once encounter completion. No UI state determines rewards.
- `SystemGenerator`: existing weighted category/encounter generation extracted into one deterministic generator. Profiles are data resources, not separate generators.
- `SystemPressure`: detached starting-stat transform after existing progression scaling. Shared ShipData and battles already in progress remain unchanged.
- `NavigationState`: one uninterrupted journey, saved position/target and shared probability-roll cooldown. PoI and free movement use the same ownership and presentation path.
- Expedition coordinator: validates intents, supplies actual positions and active gameplay elapsed time, orchestrates saves/transitions.
- Map: projects markers and clicks, arbitrates nearest eligible marker before empty-space movement, animates the existing ship. It never awards pressure, access or loot.
- Save codec: validates catalog references, one-step objective graph and navigation consistency. Envelope schema remains v1; payload adds `metagame_version: 1`.

## Initial tuning

Nine regular encounters (previously six). Category bounds: enemies 1–3, ordinary PoIs 4–6, hazards 0–3. The direct objective replaces one ordinary slot; the optional second route replaces two others. Additional service stations remain outside the regular count. Layout bounds increase from 48 to 56 units, with existing travel presentation duration preserved.

| Profile | Outpost chance | Chasedown multiplier | Pressure tolerance | Sensitive PoI chance |
| --- | --- | --- | --- | --- |
| Quiet Frontier | 100% | 0.65 | 8–12 | 15% |
| Industrial System | 8% | 1.0 | 5–9 | 25% |
| Hostile Territory | 4% | 1.5 | 4–7 | 35% |
| Ancient Expanse | 4% | 1.15 | 3–6 | 60% |

Composition, individual PoI weights, hue bias and nebula chance live in `resources/system_profiles/`. Gameplay and presentation RNG streams remain separate. Existing encounter rewards remain unchanged; Raider Cache reuses pirate debris rewards, and the objective PoIs are free guaranteed interactions.

Pressure starts at zero and increases once per completed regular encounter, including a resolved failure or navigation survey that actually completes it. Inspecting, rejected approaches, movement, services and Chasedowns add none. Sensitive optional PoIs above their tolerance queue a disclosed −2 Energy next battle. Objectives and prerequisites are exempt. No ordinary progression encounter expires.

Chasedown probability is `min(maximum_chasedown_chance, (chasedown_chance + pressure × pressure_chasedown_increment) × profile_multiplier)`. Initial values: base 0.05, increment 0.015, cap 0.35. Existing origin/destination eligibility and one-interception-per-system cap remain. Free destinations share eligible travel rules.

The shared cooldown is ten seconds of active exploration gameplay. Menus, pause and offline time do not reduce it. A new journey may attempt a roll only at its start. Redirects retain the leg guard; a journey skipped during cooldown does not retry later. An interception cancels its target and retains its first actual interception position until a new command. Loading restores remaining cooldown and guard, never wall-clock elapsed time.

Enemy starting Hull and Shields: pressure 0–6 unchanged; 7–9 +10%; 10+ +20%, rounded up after progression. Tactical briefing displays the actual modifier. Default nine-encounter systems normally reach at most pressure nine; the upper tier supports larger/custom/migrated systems.

Interstellar incremental charge and its reward fields are retired. Combat EMP Pulse charge remains unchanged. HUD states are FTL LOCKED, FTL OBJECTIVE AVAILABLE, FTL READY and BOSS LOCK. Objective badges use ?, !, lock and check; locked content shows only the prerequisite.

## Save migration

Old charge payloads preserve their encounter roster, deck, rewards, RNG, ship and pending choices. Completed regular encounters determine migrated pressure; profile becomes Industrial. An already-ready old drive preserves access. Otherwise a free protected Fuel Depot is appended, including exhausted systems, so migration cannot strand the run or repeat historic rewards. Legacy navigation conservatively starts with the full cooldown and marks resumed travel as already rolled. Unresolved interceptions remain stopped. Invalid graphs or catalog references are rejected using the existing safe-save error flow. Existing unfinished-battle restart checkpoints remain in force.

## Verification and checkpoints

Reconstruction is preserved on GitHub branch `checkpoint/pressure-exploration-v01`; this is a review checkpoint, not a claim that all regression tests passed. Latest checkpoint runs the repository CI with saved artifacts. Headless runner writes per-test logs, exit codes, timeout flags, diagnostics and `summary.json`.

Card progression and reward simulations can take several minutes. Bounds are 600s for card progression, PoI rewards and large repeated combat/service UI suites, 300s for card tiers and power allocation. Other suites retain 120s defaults. CI bounds are 45 minutes headless, 35 minutes per rendered job. Timeouts are failures, never silently counted as passes.

Rendered captures are produced by `tests/metagame_ui_test.gd -- --capture-dir=/absolute/path`, covering 960×540, 1280×720, 1680×720 and a wider Android landscape ratio, normal PoI, enemy preview, Chasedown and ready FTL. Headless geometric tests are not a substitute for rendered or physical-device verification.

Known limits: physical Windows/Android performance needs device validation; experimental tuning is not a reward rebalance. The fallback 2D grid may scroll with the expanded roster. Existing ObjectDB shutdown warnings are recorded separately from script failures. Screenshot and regression completion status must be read from the current checkpoint's results, not historic reconstruction notes.
