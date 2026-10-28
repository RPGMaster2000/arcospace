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

Additional verification: all 13 Python runner tests passed. Updated current-balance generation and trading checks passed (100,007 trading assertions), as did the expedition regression and PoI reward simulation (186,529 assertions). Existing ObjectDB shutdown leak warnings remain in several scene tests; the new navigation and policy tests produce none. Physical-device Windows/Android validation is still outside this headless/software-rendered pass.
