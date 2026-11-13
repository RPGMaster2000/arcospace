# Weekend Polish implementation checkpoint

Branch `feature/weekend-polish`, base `59d24f3` (PR67 Salvage economy).
Original assignment is preserved in request.md. Work is incomplete; do not merge.

Implemented so far:
- Remove persistent storm legend construction while retaining storm geometry,
  mechanics and hostile inspection/Details. The existing storm regression now
  checks absence of the permanent legend and retained inspection interaction.
- Extend existing map_feedback.gd: stationary cyan locator pulse, zoom-scaled world
  ring, offscreen arrow with boundary hysteresis, HUD exclusion rectangles, Android
  safe-area handling and cinematic suppression. No input hitbox or movement changes.
- EnvironmentClearance provides full sphere/ellipsoid, annular and pocket geometry
  exclusion. New Defense system generation protects the full homeworld render
  envelope plus configurable margin. Existing clear records are retained verbatim;
  bounded private-stream retries reposition storms/regenerate intersecting asteroid
  records; impossible optional records are omitted. Temporal-rift placement uses the
  same homeworld protected radius. Saved systems are never passed through the filter.
- Focused weekend_locator, weekend_clearance, space_storm and touch regressions pass.
  Retried region records are JSON-canonicalized like existing generators before save.

Still required:
- Gas giant / actual Solar Flare clearance, including full orbital envelope and
  authoritative Defense PoI anchors. Add a new generation/render opt-in marker so
  old saved anchor layouts do not shift on load. Preserve unrelated RNG draws.
- Upgrade existing result_sequence and battle_hud using committed result values,
  actual Salvage breakdown, distinct EMP / Systems Failure / System Secured wording,
  readable animated summary and optional details, skip/reduced-effects support.
- Homeworld damage event metadata from authoritative state; transient controller
  presentation queue and documented consume-on-load policy (damage already saved).
  Consolidate per-state/per-system deltas. Phase.INTRO can gate input and strategic
  sampling, but do not call _cancel_presentation when pausing a travel Tween: that
  existing method kills movement. Pause/play the existing travel tween and restore
  its sampling baseline; animate only camera/visuals. Terminal defeat takes priority.
- Dedicated Homebase Lost overlay with preserved rendered map, cause-specific text
  and only actually tracked stats. Save terminal cleanup remains authoritative.
- Responsive/rendered validation and production screenshots, full CI and one final PR.

Architecture findings:
- Latest main already includes PR67: board.salvage_rewards and committed
  system_secured/defense_recovery result data exist. Never recalculate rewards in UI.
- Existing map_feedback already owns player ring/marker; extended rather than duplicate.
- Existing result_sequence owns result reveal and already-committed rewards; extend it.
- DefensePresentation refresh directly sets integrity_bar.value. A cinematic must override
  only displayed bar values; no repeated mutation of defense.integrity.
- State._advance_strategy synchronously applies Defense.advance_time, then emits
  defense_advanced, then progress_committed. Capture integrity before/after there.
- Controller._defense_updated currently synchronizes visuals then routes travel events;
  activity damage is deferred until show_system. It needs a coalescing presentation queue.
- _begin_presentation rebases navigation samples; _cancel_presentation invalidates revision
  then may kill map motion. Camera owns its separate motion Tween and transform fields.
- Current defeat show_system presents text after _clear; it must retain map rendering.
- Terminal save cleanup already occurs in ExpeditionPersistence.save_progress.

Local runtime: Godot 4.7.2 at /workspace/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64.
Workspace /workspace/arcospace-polish. Clean import completed using workspace config/data.
Generated untracked UIDs belong to many existing files; stage only intentional changes.
