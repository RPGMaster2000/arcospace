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

Neither component is wired into live play yet. Existing gameplay and save wire data
are unchanged. No shared encounter resources, baseline fixtures or production combat
formulas have been changed. No screenshot or full feature/CI pass is claimed.

## Remaining implementation (required before PR delivery)

- State-owned ledger and additive save validation; generated-system opt-in marker
  retained by the codec. Never reinterpret completed or pending historical PoIs.
- Mode-aware approach accessor in state, screen and controller; transactional guaranteed
  resolver with exact costs, stored randomized rewards and no success RNG rolls.
- Two-card batch confirmation and replacement queue with persisted pending ownership.
- Completed-battle production charges and frozen boss card-damage advantage, including
  half-up integer damage rounding and nested card attack coverage.
- Pressure rate and expiry splitting in the Defense event loop, including pause on an
  already advancing mother, deterministic partitions and continued missile/turret events.
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
