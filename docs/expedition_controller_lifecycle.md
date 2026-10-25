# Expedition controller and presentation lifecycle

## Stage A — ownership audit

Starting revision: `458d58409699ed96dd8924c0c382c747649cbb40` (main), Godot 4.7.2.
The controller is 1,332 lines. Gameplay and persistence remain in their existing owners.

| Responsibility | Before | Intended boundary |
| --- | --- | --- |
| State reference; new/resumed run; save/quit/checkpoints | Expedition | Keep in Expedition; codec validates and serializes |
| Travel legality, interception rolls, outcomes, rewards, card ledgers | State / Deck | Unchanged; presentation never duplicates these fields |
| Routing and authoritative commands | Expedition | Keep; respond to component signals |
| View reset, grid sizing, control factories, approach selection and result styling | Expedition manipulating Screen internals | Existing ExpeditionScreen owns cohesive UI operations |
| Camera, ship movement, orbit, gestures and seeded models | Existing map/camera | Preserve; move cinematic execution behind map operations |
| White curtain | Existing WhiteTransition | Preserve; explicit cancellation wakes obsolete waiters safely |
| Suspense and outcome pulse | Controller timer / OutcomeFlash | Screen owns cancellable suspense; OutcomeFlash owns its tween |
| Battle construction / typed setup / result return / release | Expedition | Keep; bind callbacks to their live battle source and reject obsolete completions |

Before: overview → map travel → visit → PoI/preview → timer/flash → rewards → overview;
preview/Chasedown → zoom/timer/white → create battle → white reveal → combat → Continue;
overview → zoom/timer/flyby/white → generate once → rebuild → white reveal.
`view_kind`, `transitioning`, `presenting_outcome`, map flags and camera state currently
coordinate these operations implicitly. Suspense guards compare only State identity;
a delayed same-run callback can survive a view replacement. Battle callbacks are not
bound to their source. `_clear()` reaches into individual screen controls, with repeated
Outpost confirmation aliases. FTL temporarily unlocks its boolean to rebuild the view.

The refactor will retain map/camera-local movement states (they protect distinct visual
operations), replace controller animation booleans with one phase, and use a revision to
invalidate stale async work and detached controls. No presentation state will be saved.

Fresh baseline and final ownership/verification details are recorded below.

## Stages B/C — clarified ownership

No new runtime component, autoload, inventory or generic state-machine/transaction framework
was introduced. `Expedition` retains the authoritative State reference, state commands,
route decisions, save/checkpoint coordination and the live battle handle.

`ExpeditionScreen` now owns view reset, grid fitting, control factories, approach highlights,
result panel/header styling and cancellable result suspense. Reward galleries now
belong to the later CardManagementScreen overlay.
The controller's existing control accessors are read-only references to Screen or the active
Outpost/replacement component; there are no second mutable control/selection stores.
Screen queries State for display but never retains or mutates it. Existing Outpost,
ApproachConfirmation, FieldRepairControls and CardGallery remain in place.
The later [card-management UI](card_management.md) replaces DeckReplacement and
reward confirmation modals with one presentation-only full-screen overlay.

A local `Expedition.Phase` enum replaces the two mutable animation booleans. Their old
`transitioning` and `presenting_outcome` names remain derived read-only accessors for callers.

| Phase / existing component state | Entry | Exit / owner |
| --- | --- | --- |
| OVERVIEW | Show/reconstruct system | Accepted travel, FTL or route request |
| TRAVELING | Map emits travel_started after State's existing begin_travel callback | Current map's arrival/interruption; cancelled map cannot emit a late arrival |
| CHASEDOWN | Current map interruption or committed resume state | State accepts response, then battle entry |
| DESTINATION + camera destination motion | PoI/Outpost/enemy preview | Confirmation, return or battle; camera owns focus timing |
| RESOLVING | State commits survey/approach once, before presentation | Cancellable Screen suspense and existing OutcomeFlash, then rewards |
| REWARD | Outcome/replacement or other non-navigation view | Valid state choice; mandatory upgrades still block overview |
| BATTLE_ENTRY | Valid battle request | Map zoom/white → checkpoint/setup → shared reveal → BATTLE |
| BATTLE | Live typed setup applied | Source-bound Continue/restart/exit |
| FTL | Accepted jump request | Map close/pause/flyby/white → generate once → rebuild under lock → shared reveal |
| OVERVIEW + camera overview motion | Return from a destination | Camera settles into the retained pan/zoom; no separate gameplay phase needed |
| EXITED | Save/quit/departure or tree exit | Terminal for this controller instance |

`view_kind` is Screen's current UI kind, not another cinematic lock: it remains `poi` during
RESOLVING and `system` during TRAVELING/FTL. Camera `viewing` and map gesture/travel/orbit flags
continue to protect their own distinct visual operations. Destination focus and return motion
remain concurrent with their existing UI, preserving behavior rather than adding a new wait.

One controller revision scopes each cinematic/result sequence. `_presentation_current()`
checks revision, State identity, tree membership and deletion/exit. View replacement, new run
and departure invalidate first, then cancel owned work. Screen has its own revision for
controls, so detached controls and obsolete deferred resume requests cannot route a new view.
Only the current map may deliver travel/arrival/interruption. Deferred resume validates the
current overview/model before calling the original State-backed navigation path.

Screen's suspense tween replaces the unowned timer and emits completion on cancellation so
waiters terminate. Its pause behavior matches the old timer (`TWEEN_PAUSE_PROCESS`); the
existing flash and fades retain their original pause behavior. No reward is applied by any
UI completion. OutcomeFlash owns pulse cancellation and prevents an obsolete post-frame
continuation from hiding/revealing a successor.

The existing map owns `battle_entry(curtain)` and `ftl_departure(curtain)`: the same camera
requests, durations, 0.15-second settle, acceleration, side offset and white timing moved
unchanged from the controller. WhiteTransition owns a single cancellable fade/delay and
returns false to an interrupted waiter. Camera owns its tween cancellation; map owns ship,
impact shake/overlay and gesture cleanup. The controller shares one guarded frame/fade
reveal function for battle and FTL. FTL rebuilds under the same phase/revision without the
old temporary unlock. Settings remain exclusively in `star_system_settings.tres`.

## Battle and persistence boundaries

Checkpoint ordering is retained: after battle-entry white (or immediately for the existing
direct/resume/fallback path), encode the pre-entry State and choose/preserve the battle seed;
save the checkpoint/marker before `prepare_battle()` consumes temporary modifiers or Board
initialization runs. Failure preserves the retry path and does not create a board.

BattleAdapter still configures the same typed BattleSetup before `add_child()`. Board still
records its typed BattleResult through the existing guarded State operation. Continue only
synchronizes post-battle repairs, clears active_battle, detaches the handle and routes back
to existing reward/navigation logic. The controller does not create another result ledger.
Completion/restart/exit signals are bound to their source board; another/old board cannot
finish the current battle. Removal clears the live handle before detaching, and sets the
existing checkpoint_exit flag when removing an unrecorded board. Duplicate starts are rejected.
Restart confirmation also checks its originating run/revision before replacing the run.

State, Deck, the version-1 codec, BattleSetup, BattleResult and BattleAdapter are byte-for-byte
unchanged. Existing progress notifications still drive autosave at the same logical commits.
Presentation phases, revisions, camera state and tweens are never encoded. A cancelled travel
retains State's committed destination so Continue can reconstruct it without another roll.
No state/RNG/currency/card/encounter copy was introduced by this refactor.

## Verification

Fresh baseline at 458d584: **91 headless scripts + editor import passed** on Godot 4.7.2.
The baseline was isolated in a worktree before editing. These are newly executed results,
not the preceding refactor's reported totals.

The first refactored suite exposed a missing replacement-gallery compatibility accessor;
it was corrected in the controller, with all existing assertions and fixtures unchanged.
The clean final run on the frozen implementation passed **all 92 headless scripts plus
editor import** using `tools/run_regressions.py`, with no resumed/skipped passing tests or
fixture changes in that run. Newly verified Step 1 checks remain **43 ownership checks** and
**1,044 unchanged deterministic checkpoints**. Save/resume, fresh-process quit/restart,
pending choices, typed battle boundaries, Chasedown, mandatory upgrades, PoI/Outpost,
cinematic lifecycle and all three navigation presentations pass. The original expected
fixture was not regenerated. Existing ObjectDB shutdown warnings remain separately reported;
standard discovery excludes the renderer-only enemy-model diagnostic.

The new `expedition_lifecycle_test.gd` passes **26 focused checks**: replaced/cancelled fades,
travel cancellation without arrival or state mutation, duplicate approach commits, suspense
replacement within the same run, new-run invalidation, stale controls/deferred resume,
cancelled and repeated FTL, delayed battle cancellation, duplicate battle start/completion,
source-bound completion, mandatory rewards, 2D/grid fallback navigation, interruption-impact
cleanup and scene exit while awaiting white. Test-only tuning shortens waits locally; shipping
Resources/durations are untouched.

Both the original and refactored map passed **128 checks** under Mobile/Vulkan using software
llvmpipe, at **1280×720 and 960×540**. Screenshots cover overview/connected labels, all-destination
focus framing, scrollable PoI sidebar, top bar, FTL zoom/flyby/white/new-system reveal and battle
white/reveal. The final source was rendered again after cancellation cleanup. Baseline/final
PoI and overview images were inspected; no layout or authored visual change was observed.
Additional final Mobile/Vulkan runners passed: Trading Outpost UI (**2,112 checks**),
reward feedback (**478 checks**, including the gallery and green/red result pulse), and
map zoom/scroll fade (**zero failures**). The eager preload/scene/Resource graph has the
same 236 transitive files and **zero cycles** before and after; existing lazy card-inspection
loads remain unchanged. `git diff --check` passes.

These are rendered desktop tests with Android-style touch injection, not physical Android
performance/input measurements. No physical Android/Windows device or APK export was tested.

Existing rendered/headless suite scripts remain the regression infrastructure:

```sh
godot --headless --path . --script tests/expedition_lifecycle_test.gd
python tools/run_regressions.py --godot godot --timeout 360 --results test-results
godot --path . --rendering-method mobile --rendering-driver vulkan --script tests/star_system_transition_test.gd
```

## Size, dependencies and remaining coupling

| Affected runtime file | Before | After |
| --- | ---: | ---: |
| scripts/expedition.gd | 1332 | 1217 |
| scripts/ui/expedition_screen.gd | 167 | 423 |
| scripts/ui/outcome_flash.gd | 61 | 70 |
| scripts/ui/star_map.gd | 209 | 215 |
| scripts/presentation/star_system/map_camera.gd | 82 | 91 |
| scripts/presentation/star_system/star_map_3d.gd | 381 | 439 |
| scripts/presentation/star_system/white_transition.gd | 37 | 60 |
| Combined runtime | **2269** | **2515** |

Controller decreases by 115 lines; combined runtime grows by 246 for explicit cancellation,
phase/revision guards and read-only compatibility accessors. This is an ownership/lifecycle
change, not a claim of runtime speedup or code-volume reduction. Controller camera accesses
fall from 2 to 0 and unowned timer calls from 4 to 0. Direct property assignments on the audited
shell controls fall from 28 to 5 (view/title/grid/footer/confirmation/resource/jump/scroll/header/
return/heading/gallery/mission-header properties; statement count, not a coupling score).
Tile/CardGallery/VisualEffects implementation dependencies move from controller to Screen.
Unused private `_card_text`, `_repair_selection_changed`, `_finish_upgrades` and the duplicate
Outpost selection listener are removed after a repository-wide caller search.

The controller still builds encounter/map-entry descriptions and routes specialized rewards;
its test-facing control aliases and live Board handle remain. `map_system`/`map_destination`
remain the existing presentation cache; State alone owns persistent navigation. Existing
Outpost/repair components retain read-only model references. These are deliberately retained
couplings, not another inventory or state synchronization system. No gameplay, deck, save,
card, AI, music, audio, shader, scene or tuning-Resource file changed.

Files: the seven runtime files above; new `tests/expedition_lifecycle_test.gd` and its UID;
this document; updates to DEVELOPER_GUIDE, star_system_3d and code_health_assessment. No files
removed and no runtime components created. Render/test tooling stays outside the repository.
