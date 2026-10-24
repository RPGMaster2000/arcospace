# Persistent expedition deck and reward ownership

Baseline inventory: `a25b58a06d3cd3473d54191bff5ae9e56f4024b8` (`main`),
Godot 4.7.2. This is a behavior-preserving extraction. No Resources, balance values,
UI, audio, encounter generation, save schema or combat algorithms changed.

## Files in this change

Created `scripts/expedition/expedition_deck.gd`, `tests/deck_ownership_test.gd`,
`tests/deck_determinism_test.gd` (with their `.gd.uid` files),
`tests/deck_ownership_baseline.json` and this document.

Modified `scripts/expedition_state.gd`, `scripts/persistence/expedition_save.gd`,
`docs/DEVELOPER_GUIDE.md`, `docs/code_health_assessment.md` and seven fixture files:
`card_expansion_test.gd`, `card_progression_test.gd`, `chasedown_rewards_test.gd`,
`expedition_save_test.gd`, `expedition_test.gd`, `targeted_sabotage_test.gd`,
`ui_overhaul_test.gd`. Fixture setup now replaces copied containers explicitly and
uses the public acquisition path; existing assertions are preserved. No files removed.

## Stage A: ownership inventory

| Responsibility / mutation path | Before | After |
| --- | --- | --- |
| Acquired identities, removed starting identities, player upgrade copies | ExpeditionState fields and methods | One ExpeditionDeck instance owned by State |
| Offers, fixed incoming replacement, upgrade selections and event identity set | ExpeditionState fields and methods | ExpeditionDeck; State properties delegate without storage |
| Pending choice discriminator | ExpeditionState | One field in ExpeditionDeck; State still coordinates non-card choices through its facade |
| Starting definitions / stable identity | ShipData / CardData / CardLibrary | Unchanged; definitions are shared read-only inputs |
| Reward rarity roll, candidate filtering, capacity, replacement and upgrade rules | ExpeditionState | ExpeditionDeck, with profile/rules/RNG supplied explicitly |
| Encounter completion, battle-result deduplication, FTL, Chasedown, Hull, Salvage | ExpeditionState | Unchanged |
| Attribute choices, production, temporary modifiers, service revision/pricing, repairs | ExpeditionState / RepairRules | Unchanged |
| Battle data transfer and temporary hands | BattleSetup / BattleResult / BattleAdapter / CardHand | Unchanged |
| Single-slot encoding/validation/checkpoints and disk replacement | ExpeditionSave | Unchanged format; snapshot/restore boundary for deck fields |
| Galleries, confirmations, inspection and result navigation | Expedition controller / existing UI components | Unchanged callers and visuals |

Initial call/mutation audit:

- `start()` resets ledgers; `player_pool()` derives starting + acquired identities,
  suppressing removals and selecting upgraded definitions. It never stores another pool.
- `resolve_approach()` validates/pays, rolls, completes the encounter, then applies
  immediate rewards/modifiers and queues one choice. Precedence remains card → upgrade
  → resource → production. `_complete_encounter()` retains its charge guard.
- `purchase_service()` validates revision/eligibility/quantity, spends Salvage and
  consumes the revision before applying the outcome. Deck never spends currency.
- `choose_card()` commits acquisition or consumes offers into a fixed replacement.
  `replace_card()` removes an owned identity/upgrade and acquires the incoming identity;
  `decline_card()` consumes that pending event without refunding the service.
- `record_battle()` rejects duplicate result IDs, stale systems and already completed
  encounters before copying persistent values. Rewards and upgrade-count selection
  remain here, including Chasedown/rank/escape rules.
- `choose_upgrade()` replaces one owned definition with `with_upgrade()`, records the
  identity in the event set and spends one selection. An identity cannot be selected
  twice that event; a later event clears the set. Finish refuses eligible unspent awards.
- `progress_committed` remains the controller's autosave boundary. Pre-battle checkpoints
  continue to preserve the unconsumed setup and replay the same seeded opening on resume.

The baseline shared suite was run in an isolated worktree, independently of the extraction.
See verification below for results and the isolated fresh-process rerun.

## Stages B/C: one owner and explicit transactions

`scripts/expedition/expedition_deck.gd` extends RefCounted. Its only script dependency
is CardLibrary, which loads CardData Resources. It retains no State, scene, Board,
hand, RNG or service reference. State supplies its existing `ship()`, rules and reward
`rng` per call; no randomization, extra reward roll or independent generator was added.

These fields exist only in that instance: `acquired_cards`, `upgraded_cards`,
`removed_starting_cards`, `card_offers`, `pending_card`, `pending_choice`,
`upgrades_remaining`, `upgraded_this_event`. State's same-named properties have no
backing values. `choice_amount` and `last_outcome` remain coordinator fields.

The four choice operations return `{}` on rejection, or `{message, deck_changed}`
after one successful mutation. There are no callbacks inside the helper. State appends
the existing outcome message, emits `deck_changed` when ownership/levels changed, then
emits `progress_committed` once. Replacement deferral/decline emit only progress.
Rejected/repeated actions emit neither. Reward queuing and `start_upgrade_event()` do
not add a notification; their existing PoI/service/battle coordinator commits it.
`finish_upgrades()` notifies only when a pending event actually closes. All transaction
fields are settled before listeners are notified, including auto-completed upgrades.

`shared_pool()` remains on State: it is the unmodified enemy library compatibility
name, not persistent player ownership. `choose_attribute()`, `battle_upgrade_count()`,
PoI outcome rules, service operations and battle commit logic also remain on State.
There is no new subsystem for non-card rewards.

Collection facade getters and setters copy their containers. Legacy fixture writes must
assign a collection explicitly rather than mutate a getter result; existing assertions
are retained. Arrays of CardData still refer to shared definitions, as the existing UI
and BattleAdapter expect. Treat these definitions as read-only. `deck_snapshot()` is
fully detached and contains only identity strings, levels, counters and choice state;
use it for inspection/serialization that must not expose mutable CardData references.

## Persistence and battle handoff

The version remains **1**, with exactly the same field names and stable identity keys.
The codec still validates shapes, registry references, duplicate IDs, owned upgrades,
capacity and RNG states. It encodes the detached deck snapshot and calls `restore_deck()`
only after validating the payload; restore neither rolls nor emits signals. Post-restore
ownership validation remains in the codec. No migration or save invalidation is needed.

Typed BattleSetup still receives the same derived player pool and acquired weights;
BattleResult still returns Hull/currency/outcomes to State. BattleAdapter subscribes to
State's existing deck notification and updates temporary pool/held copies. Neither the
hand nor the helper becomes an independent expedition inventory. No Board-node dependency
or reverse State dependency was introduced.

## Stage D: verification

`tests/deck_ownership_test.gd` exercises the helper directly without instantiating scenes:
starting pool, tier filtering, acquisition/replay/duplicate checks, draw weights, capacity,
replacement/decline, Upgrade I/II/max, one identity per event, mandatory completion,
later events, detached snapshot/container ownership and notification order. It also loads
pre-extraction pending-replacement and partial-upgrade payloads, checks exact codec round
trips and rejects repeated claims after resume.

`tests/deck_determinism_test.gd` compares **1,044 checkpoints** against
`tests/deck_ownership_baseline.json`, captured by the old implementation. Coverage spans
six ships × three seeds × six systems, including Boss generation, actual PoI reward rolls,
Outpost card/production purchases, battle setup pools/weights, repeated battle results,
Chasedown, capped replacement and partial upgrades across codec reloads. Each state hash
includes encounter data, rewards, identity ledgers and all three expedition RNG states.
The trace comparison passes unchanged. JSON numeric types are normalized on fixture read;
state hashes themselves are captured directly from the original codec output.

To regenerate the baseline deliberately, copy the trace script into a checkout of the
recorded baseline revision and run it with `-- --write-baseline`. Never regenerate the
expected fixture from the refactored implementation to conceal a mismatch.

Focused commands (substitute the engine path):

```sh
godot --headless --path . --script tests/deck_ownership_test.gd
godot --headless --path . --script tests/deck_determinism_test.gd
python tools/run_regressions.py --godot godot --timeout 360 --results test-results
```

Godot 4.7.2 verification completed:

- Baseline: **89 headless regression scripts + editor import passed**. Its fresh-process
  fixture initially failed the menu's BEGIN EXPEDITION assertion; an isolated rerun of
  unchanged baseline code passed. This intermittent baseline check was not changed.
- Refactor: **91 headless regression scripts + editor import passed**, including both
  new tests. The shared runner's discovery, timeout/error checks and process isolation
  were reused; interrupted execution resumed from completed results after adapting fixture
  writes to copied containers and replacing a removed private-method fixture call.
  No existing assertion was weakened. Final focused ownership coverage: **43 checks,
  zero failures**; determinism: **1,044 matching checkpoints**.
- Existing card/reward/replacement/upgrade UI, outpost/repair, Chasedown, Boss/FTL,
  typed battle-boundary, save/resume/fresh-process and combat trace suites pass.
- `git diff --check` passes. Unrelated State method bodies remain unchanged; only reset,
  card outcome delegation and extracted card operations changed. The helper's dependency
  path has no reverse State/Board edge and introduces no circular script/resource path.
- Existing ObjectDB exit warnings remain reported separately by the runner. The
  renderer-only enemy-model fixture is excluded by standard headless discovery. No new
  rendered, physical Android/Windows device or export validation was performed for this
  state-only change; no platform-specific runtime dependency was added.

## Remaining coupling and size

State retains compatibility properties and forwarding methods because UI, battle adapters
and save counters use that public facade. Whole-ledger setters remain for explicit test
fixtures; runtime rewards must use validated choice methods. CardData remains a mutable
Godot Resource under a read-only definition convention, rather than introducing an
unrelated immutable card hierarchy. State's generation/services remain substantial;
extracting them is outside this change.

Original State: **1,179 lines**. Refactored State: **1,087 lines**; new deck owner:
**238 lines**, including snapshot/restore and boundary comments. Combined code grows by
146 lines to make ownership and test seams explicit. There is one rule implementation
for each card operation, one persistent inventory, no new runtime dependencies/autoloads
and no changes to project configuration, save schema, combat, maps, audio or visual assets.
