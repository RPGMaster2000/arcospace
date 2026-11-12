# Strategic Defense PoIs — implementation checkpoint

Base: `c5ec25aec69c1e13b3f73d05c8565ce287618caf` (merged PR #62).
Branch: `feature/defense-strategic-pois`.

This is incomplete foundation work, not a playable implementation or merge-ready PR.
The full user specification remains authoritative. Do not merge automatically.

## Actual architecture assessment

- ExpeditionState.resolve_approach reads shared poi.approaches, consumes a success
  RNG roll, completes the encounter, applies its reward, then commits a fixed
  poi_seconds cost. Both modes currently share this path.
- ExpeditionScreen.present_poi and the controller's selection guards directly read
  poi.approaches. All three need a mode-aware accessor; replacing only the screen
  would leave server-side eligibility and resolution inconsistent.
- _complete_encounter and progress_committed participate in autosave. A Defense
  transaction must not expose an intermediate completed-but-unrewarded state or
  consume time twice. Spend strategic time before granting the new effect; handle
  terminal arrival and pending contact through the existing authoritative clock.
- ExpeditionDeck owns unique identities and draw weighting. player_pool deduplicates
  identities, choose_card rejects already-owned identities and invokes replacement
  when full. A two-card reward needs a persisted, confirmed batch/queue using those
  ownership and capacity rules; appending arbitrary cards bypasses the contract.
- prepare_battle configures a detached player ShipState. Apply temporary production
  there, not in permanent production() used by upgrade eligibility. Decrement only
  in idempotent record_battle after a real completed card battle.
- BattleEnvironment plus the existing checkpoint freezes entry values. A boss-only
  card advantage must be frozen alongside support and validated on load. CardEffects
  applies damage/pierce after conditional effects and before shield absorption;
  use this calculation site rather than post-hoc Hull compensation, which would
  mishandle non-damage effects, nested attacks and reports. Turret damage stays separate.
- Defense.advance_time is an event-split authoritative loop. Pressure effects must
  contribute expiry boundaries to this loop and change its effective pressure rate;
  never scale the whole step, enemy movement or missile time.
- Navigation reports actual distance and State charges strategic seconds per distance.
  Physical renderer travel uses a tween and physical_speed. Fuel exhaustion needs
  segmented tween travel and movement sampling at the exact boundary. Never reduce
  seconds_per_distance to implement faster physical presentation.
- Save codec version 3 restores strict state and card identifiers. Add optional typed
  records and a per-generated-system rules marker. Missing marker means legacy PoI
  behavior for that existing system; new generation opts in without new RNG draws.
- Turret deployments currently validate against construction-site IDs and have a
  purchased capacity. Free PoI turret needs its actual anchor and a dedicated stable
  source ID, independently counted/validated and rendered through the existing
  turret/missile-support components. Do not relocate to a purchased slot.

## Implemented, isolated foundations

1. `scripts/expedition/defense_poi_approaches.gd`: pure catalogue returning fresh
   EncounterApproach resources plus explicit reward metadata and time costs. Includes
   the three exact specialized PoIs and themed guaranteed choices for every ordinary
   PoI. Trading Outpost stays outside this catalogue.
2. `scripts/expedition/defense_poi_effects.gd`: small duration ledger with detached
   serialization, strict identifiers/numeric bounds, strongest/longest production
   refresh, pressure precedence, expiry boundaries and expedition/system scopes.
3. Focused headless tests for both components pass with Godot 4.7.2 after clean import.

The ledger is now owned by ExpeditionState and borrowed by DefenseState. Optional
`defense_poi_effects` save records validate and restore it; missing records give an
empty ledger. Exploration saves do not acquire the record. Battle setup adds temporary
production without changing permanent upgrade requirements, and idempotent completed
card-battle results decrement charges once. System departure clears system-scoped
entries, while production and fuel survive. The strategic event loop splits on ledger
expiry and applies the multiplier only to the effective Pressure rate. Enemy, missile,
reinforcement and mothership clocks continue normally.

The approach catalogue is still not enabled in generated systems. Live games currently
have no transaction granting these new effects. Existing PoI gameplay remains unchanged. No shared encounter resources, baseline fixtures or production combat
formulas have been changed. No screenshot or full feature/CI pass is claimed.

## Remaining implementation (required before PR delivery)

- Generated-system opt-in marker
  retained by the codec. Never reinterpret completed or pending historical PoIs.
- Mode-aware approach accessor in state, screen and controller; transactional guaranteed
  resolver with exact costs, stored randomized rewards and no success RNG rolls.
- Two-card batch confirmation and replacement queue with persisted pending ownership.
- Frozen boss card-damage advantage, including
  half-up integer damage rounding and nested card attack coverage.
- Remaining integration coverage for effects acquired in actual PoI transactions and
  continuation/retry flows; basic pressure partition and moving-fleet/missile tests pass.
- Distance-limited physical travel speed, fuel exhaustion segmentation and compact status.
- Separate free turret source/limit at the Mining Operation anchor, codec/render/support
  integration, standard purchased capacity independent of the free slot.
- Defense-only descriptions with no probabilities/failure previews, exact time and gates,
  effect inspection using an existing status view, Android readability/touch checks.
- Full gameplay, legacy/current save, RNG parity and rendered tests. Capture all three
  special interfaces/free turret; run full CI and open one focused PR for review.

Production boosts refresh each category to the maximum of incoming/existing amount
and remaining battles (caps +2 / 3 battles); categories coexist. Pressure pause wins
while both timers count down concurrently. Propulsion uses one nonmultiplying fuel
reserve. Research boss advantage is mutually exclusive per system. These policies
must be documented in the final player-facing descriptions and tested in integration.

## Integration validation

Godot 4.7.2 focused runs pass: catalogue, ledger, state integration, existing
Starfront v2 and Starfront persistence. The state integration checks actual codec
roundtrips, invalid-data rejection, borrowed ownership, effective v2 Pressure rates,
35 seconds versus 350 × 0.1 second partitions, continued attacker/mothership movement,
missile launches during Pressure pause, battle production at entry, and idempotent
completed-battle charge consumption. Full feature and rendered checks remain pending.

## Free Mining Operation turret integration

Added source-stable `mining_free_<encounter>` installations directly at the stored
PoI anchor. They share the existing turret dictionary, weapon configuration,
renderer model/range rings, battle-support selection and missile scheduler.
Purchased slots count independently (two), while the free slot is limited to one.
Legacy purchased deployments retain their existing restore validation; new free
records must match a known Mining Operation anchor and cannot exceed the total
three-installation contract. Construction previews count purchased turrets only.

State integration tests now exercise free deployment with no Salvage change,
exact anchor equality, duplicate rejection, two additional purchased turrets,
normal battle support, JSON save restoration, shifted-record rejection and a
missile destroyed by the existing scheduler while crossing the real PoI turret.
This deployment API is not yet invoked by a player-facing approach transaction.

Latest main was fetched and remains `c5ec25a`; no rebase was required. Focused
checks pass for the ledger/state, existing Starfront v2, purchased turret and
Starfront persistence suites. Full feature/renderer CI remains pending.
