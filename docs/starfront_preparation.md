# Starfront preparation: dependency inventory (before refactoring)

Baseline: a3ecf6d, current main. No defense gameplay is introduced in this pass.

| Owner | Current dependencies and responsibility | Disposition |
| --- | --- | --- |
| ExpeditionState | Rules, generator, navigation, profiles, pressure transform, deck, battle setup/results | Authoritative facade; preserve reward and completion pipeline |
| NavigationState | Position/target, journey lifecycle plus random-roll guard/cooldown | Separate movement from current-mode policy; retain one position owner |
| Expedition coordinator | State, screen, map, lifecycle, persistence, battle | Report actual validated movement; preserve phase/cancellation lifecycle |
| SystemGenerator | Rules/profile weights, existing PoI and enemy registries, gameplay RNG | Static content generation retained; no moving units yet |
| StarMap3D | Cosmetic generation, markers, camera, ship animation | Presentation only; never strategic enemy authority |
| ExpeditionScreen / HUD | State facts and player intents | Keep layouts and objective facts; no new mode decisions |
| Save codec | Explicit catalog, navigation snapshot, pressure/access/encounters and RNG | Keep envelope and metagame versions unchanged; translate ownership at codec boundary |
| BattleSetup / BattleResult / Deck | Detached starting profiles, one result ledger, rewards/card ownership | Reuse unchanged for future unit encounters |

Pressure, sensitive-PoI penalties, pressure stat scaling, probability/cooldown and interception limits are current-mode-only. Chasedown cinematic/response presentation, battle handoff/results, free movement, completion records and departure eligibility are reusable. FTL access objectives remain current-mode rules behind an authoritative completion boundary.

The old station interval initialization looks obsolete but consumes the station RNG and persists next_outpost_system. Removing it changes deterministic station outcomes and historic snapshots; retain explicitly until a versioned generation migration. Weighted enemy helpers remain referenced by generation. Legacy charge fields are required only by old-save migration and must remain there.

Future hostile units must be owned by expedition state (or one state-owned collection), reference the existing encounter index and ShipData catalog, and supply positions to the renderer. Do not copy profile, rewards or defeated status into UI/map nodes. No unit fields or speculative collection are needed in Step 0.5.

## Step 1 handoff

- Subscribe once per expedition state to `state.navigation.movement_advanced(distance)`. Convert validated world-space distance using a fixed strategic rate in the future state-owned simulation. Never use the Chasedown cooldown clock, frame wall-clock gaps or destination-click counts. No elapsed strategic counter or enemy movement exists yet.
- Navigation `position`, `target` and `leg_active` remain authoritative. Its transient previous-sample baseline is measurement bookkeeping, not another saved position. Save/arrival checkpoints and rebases explicitly distinguish position restoration from movement advancement.
- `state.chasedown_roll_policy` owns current-mode cooldown and per-leg roll eligibility. State orchestrates roll policy at new-leg/interruption/arrival boundaries. The future mode selects encounter initiation at this state boundary; navigation itself has no random-encounter dependency.
- `state.system_objective_complete()` is the persistent completion predicate; `can_jump()` adds live restrictions such as pending choices, active combat and player survival. Step 1 can supply mothership completion here and retain voluntary jumping. Keep display wording centralized in `ftl_status()`.
- Represent future units once in state, referencing an existing battle encounter and profile. Feed their positions into a separate map presentation adapter. Static encounter dictionaries remain the content/result ledger. Reuse `prepare_battle`, `record_battle` and existing interruption cancellation; never infer defeat from disappearing render nodes.
- Save envelope and `metagame_version` stay at 1. The codec merges/splits movement and roll-policy snapshots into the identical existing navigation wire object. Step 1 should version its genuine unit/base/mode fields then; never infer missing enemies during this preparation.

## Cleanup and retained compatibility

Navigation's random-roll fields and `claim_roll`/`advance` methods were removed from its API and moved to the dedicated current-mode policy. `advance_navigation_time` was renamed to `advance_chasedown_cooldown`; no forwarding alias remains. Obsolete six-encounter, carryover and in-memory-only comments were corrected. Existing save migration, the legacy station RNG initialization and its serialized counter remain for deterministic compatibility. No live pressure, Chasedown, reward, profile, objective or presentation feature was removed on the basis of its name.

Remaining debt: expedition retains its existing navigation destination indices and encounter ledger, while Navigation owns world position/target and journey lifecycle. Moving units will need stable identities distinct from those indices in Step 1; no empty framework was introduced now. The coordinator still owns UI phase checks because it alone knows modal/presentation state. These checks gate reporting, not strategic rules.

## Validation

Focused movement (48 checks), risk policy (39), navigation (25), save (33), FTL (103,655), milestone (3,185), Chasedown reward (82), UI (74), legacy save correctness, save/resume, native map input and transition regressions were exercised. Current main had stale balance expectations; tests were aligned to its already-authored tuning without changing gameplay resources. Full headless and rendered registries remain the CI acceptance check; Mobile navigation-specific engine teardown is already excluded by the existing main workflow, while Mobile metagame/HUD/tactical coverage remains active.

Additional verification: all 13 Python runner tests passed. Updated current-balance generation and trading checks passed (100,007 trading assertions), as did the expedition regression and PoI reward simulation (186,529 assertions). ObjectDB shutdown leak warnings remain in several scene tests, including the coordinator movement fixture during the full suite. The isolated policy test is clean; leak cleanup remains separate technical debt. Physical-device Windows/Android validation is still outside this headless/software-rendered pass.

## Normal-chat handoff (2026-10-28)

Implementation is complete and checkpointed; do not reimplement it. `main` has NOT been advanced for Step 0.5. Baseline main is `a3ecf6d1ab0e71cca69539ea0aab6829840f89a5`.

Code commits, in order:
- `52eaa6abf2c8cf3ac46d32bbe2372c2f54694a78`: navigation/policy separation, movement reporting, objective boundary, save compatibility, focused tests.
- `012c7921d6117e41f2d2e9605a250d190049a731`: tests aligned to existing main balance, historical tuning documentation.
- `249d8720bbc8bd19c1f240c00b11bf92d24d14f9`: validated interruption position checkpoint and verification notes.

The final handoff commit on `checkpoint/starfront-step05-ready` only changes this documentation. Its executable code is identical to `249d872` on `refactor/starfront-preparation`.

CI for that exact code: https://github.com/RPGMaster2000/arcospace/actions/runs/40633853989 . It was still running at handoff. The previous code checkpoint's Mobile and exported-startup jobs passed. Full headless/OpenGL completion must still be checked; do not report them as passed before reading results. Local broad run had completed 80 tests without failures and was running power allocation. The focused tests and four current-balance reruns passed; all 13 Python tests passed. Existing shutdown warnings are documented above.

Local checkout, if retained: `/workspace/scratch/45c62988ff1a/starfront`. Full-run results: sibling `starfront-remaining/summary.json`; focused results: sibling `starfront-checks/summary.json`; current-balance results: sibling `starfront-balance-checks/` (the first expedition run failed its stale reward expectation; `expedition-rerun.log` records the corrected passing run). GitHub CI artifacts are the durable fallback if the local workspace disappears. Do not use the older sibling `arcospace` pressure reconstruction tree.

To finish: inspect all four jobs and artifacts for the exact code CI run above, address genuine failures with bounded reruns, fetch latest main, and fast-forward main to the ready checkpoint if it still descends from current main. If main advanced independently, integrate those changes and validate conflicts before publishing; never force overwrite it. User has authorized publishing verified changes to main. Do not repeat long passing simulations solely because this handoff is a documentation-only descendant. There are no unsaved implementation changes or defense-mode gameplay hidden outside this checkpoint.
