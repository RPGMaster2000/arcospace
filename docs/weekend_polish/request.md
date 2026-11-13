# ARCOSPACE — Weekend Polish Pass
## Star-System Readability, Combat Results & Homeworld Cinematics

**Repository:** `RPGMaster2000/arcospace`  
**Engine:** Godot 4.7.x  
**Platforms:** Windows and Android  
**Starting point:** Latest `main`

### Objective

Perform a coordinated visual-polish pass focused on improving readability, feedback and presentation throughout Arcospace, especially Starfront Defense.

This is primarily a **presentation and game-feel update**, not a gameplay rebalance.

The final result should feel more like a polished commercial space-strategy game: clearer navigation, meaningful combat rewards, dramatic homeworld attacks and satisfying victory/defeat sequences.

Preserve existing rules, rewards, combat outcomes, environmental modifiers, strategic timing, encounter completion and progression.

Create a dedicated feature branch and PR.

**Do not automatically merge.**

---

# 1. Preliminary code inspection

Before implementing changes, inspect the current authoritative systems for:

- 3D star-system rendering.
- Star-map camera and navigation.
- Player ship visual representation.
- Environmental region generation.
- Homeworld and celestial-body placement.
- Solar Flare region generation.
- Starfront Defense state and strategic clock.
- Homeworld integrity and damage events.
- Enemy arrival and mothership conquest.
- Battle-result handling.
- EMP victory handling.
- Expedition progression and statistics.
- UI result screens.
- Save/load serialization.
- Desktop and Android rendering configurations.

Likely relevant locations include:

- `scripts/presentation/star_system/`
- `scripts/expedition.gd`
- `scripts/expedition_state.gd`
- `scripts/expedition/defense_state.gd`
- `scripts/expedition/system_generator.gd`
- `scripts/board.gd`
- `scripts/combat/battle_adapter.gd`
- Existing UI components and battle result scenes.

These are starting points, not assumptions about the current architecture.

Reuse established systems and avoid introducing competing sources of truth.

---

# 2. Remove persistent storm description from the star-system HUD

### Current issue

The upper-left star-system interface displays a persistent environmental message such as:

`Ion Storm - Energy`

This is redundant and adds visual clutter.

### Required change

Remove this persistent message from the main star-system HUD.

Do not remove:

- Actual storm regions.
- Storm rendering.
- Storm detection.
- Storm combat effects.
- Environmental battle previews.
- Storm information in relevant inspection panels.

The player should still be able to identify the environmental effects of a region through its existing inspection interface.

Avoid replacing the removed message with another permanent label.

### Acceptance

The upper-left star-system HUD no longer displays the persistent storm-family text, while all relevant environmental information remains accessible.

---

# 3. Prevent environmental regions from overlapping the homeworld

### Current issue

Procedurally generated storm regions can visually intersect the homeworld.

This looks unnatural and can make the defensive map difficult to interpret.

### Required change

Guarantee that all procedurally generated environmental regions maintain sufficient clearance around the homeworld.

This includes:

- Ion Storms.
- Metal Storms.
- Psionic Storms.
- Other spatial environmental regions where applicable.

### Placement requirements

Use the actual region geometry rather than checking only whether the region center is too close to the homeworld.

Account for:

- Homeworld position.
- Homeworld physical/rendered radius.
- Environmental region radius or volume.
- Non-spherical region shapes.
- A small configurable visual safety margin.

For irregular shapes, use the appropriate existing intersection or conservative containment calculations.

### Generation behavior

When placement is invalid:

1. Retry using the existing deterministic generation process.
2. Select another valid location within the configured world bounds.
3. If no valid location exists after a bounded number of attempts, omit that optional region.

Do not permit infinite generation retries.

Do not shift the homeworld to accommodate environmental placement.

### Compatibility

Preserve deterministic generation for the same seeds.

Avoid perturbing unrelated RNG streams.

Saved systems should retain their existing environmental placements unless compatibility or corruption prevention requires otherwise.

Do not silently regenerate active systems when loading a save.

---

# 4. Prevent gas giants from intersecting the Solar Flare region

### Current issue

Gas giants can appear too close to the system's central star, overlapping the Solar Flare area.

### Required change

During procedural celestial-body placement, ensure that gas giants do not intersect the Solar Flare region.

Use:

- Central star position.
- Actual Solar Flare region dimensions.
- Gas giant's rendered radius.
- A small configurable visual margin.

### Important

Do not simply compare the gas giant's center with the central star's radius.

The entire visible gas giant must remain outside the Solar Flare region.

Preserve:

- Existing gas giant sizes.
- Orbit and positioning behavior where valid.
- Existing planet distribution.
- Procedural-system variety.
- Environmental effect behavior.

If the gas giant's orbit or full movement envelope matters, validate the relevant occupied region rather than only its initial position.

Use bounded deterministic retries.

Do not introduce new gas giants or alter their gameplay significance.

---

# 5. Improve player-ship visibility in the star system

### Objective

The player-controlled ship should be immediately recognizable even when the camera is zoomed out or the background contains bright objects, debris or dense environmental effects.

### A. Pulsing player locator

Introduce a subtle, visually distinct locator around the player ship.

Suggested style:

- Cyan or blue-white glow.
- Soft circular pulse expanding outward from the ship.
- Thin locator ring beneath or surrounding the ship.
- Gentle repeating pulse.
- Limited bloom and transparency.

The effect should feel technological and restrained rather than resembling a weapon explosion.

### Behavior

- Locator remains anchored to the player's actual world position.
- Pulse continues when stationary.
- Pulse remains visible during normal navigation.
- Visibility scales appropriately with camera zoom.
- Locator must not obscure the ship model.
- Locator must not interfere with mouse/touch selection.
- Existing ship movement and orientation remain unchanged.

Use a lightweight implementation suitable for Android.

Prefer existing particles, materials or simple geometry.

Avoid expensive full-screen postprocessing.

### B. Off-screen directional arrow

When the player's ship leaves the camera viewport, display a directional indicator near the screen edge.

Requirements:

- Arrow points toward the ship's projected screen position.
- Position stays within a configurable safe margin.
- Arrow is clearly distinguishable from enemy indicators.
- Arrow disappears when the ship becomes sufficiently visible.
- No flickering when crossing the viewport boundary.
- Correct behavior during camera pan, zoom and focus transitions.
- Correct behavior at different aspect ratios.
- No collision with primary action buttons or mobile safe areas.

Optional: add a small player-ship icon at the arrow's center.

Do not display an unnecessary distance number unless it already fits the established HUD design.

### C. Camera cinematic behavior

Hide or suppress the off-screen arrow during scripted camera sequences if it would distract from the presentation.

Restore its normal behavior afterward.

---

# 6. Redesign the combat victory/result presentation

### Current issue

The result screen is too verbose and technical.

It should celebrate the outcome first, then provide access to detailed information when useful.

### Visual direction

Use polished, cinematic video-game presentation with:

- Large victory typography.
- Strong visual hierarchy.
- Ship or combat-related iconography.
- Animated rewards.
- Readable progress indicators.
- Attractive but restrained transitions.
- Clear player actions.

Avoid making the interface look like a debug report or technical summary.

### A. Combat victory

For enemy destruction or Systems Failure, use an appropriate heading such as:

**VICTORY**

Supporting text should describe the actual outcome:

- Enemy Destroyed.
- Enemy Systems Disabled.
- Other relevant existing victory causes.

Do not label a Systems Failure victory as Hull destruction.

### B. EMP victory

Successful EMP escape should have its own presentation.

Suggested heading:

**VESSEL DISABLED**

Supporting text:

`Enemy neutralized`

In Starfront Defense, EMP victories neutralize the corresponding strategic enemy and permit allied recovery.

Do not show EMP success as ship destruction.

Use appropriate EMP-related visual effects and icons rather than explosions implying the enemy has been destroyed.

Preserve the actual EMP result rules, rewards and absence of normal non-escape upgrade events.

### C. Mothership/system victory

When the mothership is successfully neutralized:

**SYSTEM SECURED**

This should be a more significant presentation than an ordinary encounter victory.

It must support both:

- Mothership destruction or Systems Failure.
- Successful EMP neutralization.

Show relevant rewards without double-counting.

### D. Reward presentation

Display the most relevant results prominently:

- Salvage earned.
- Current Salvage balance where useful.
- Battles won.
- Remaining player Hull.
- Card upgrades available.
- Other meaningful progression rewards actually earned.

Use icons for:

- Salvage.
- Hull.
- Combat victories.
- Card upgrades.
- Systems secured, where available.

Animate earned numerical rewards counting upward.

Use a short staggered sequence:

1. Victory heading appears.
2. Reward icons appear.
3. Numbers count upward.
4. Progress summary appears.
5. Continue/Upgrade action becomes prominent.

### Reward correctness

All displayed amounts must come from committed authoritative battle results.

Do not calculate rewards separately inside presentation widgets.

Do not display speculative rewards.

If the Salvage economy overhaul has already been merged, show its actual destruction, EMP recovery and system-secured rewards.

Otherwise use the current authoritative values. Do not introduce balance changes as part of this polish pass.

### E. Details

Move technical or secondary information behind a compact optional Details section.

Potential details include:

- Victory cause.
- Battle rounds.
- Damage statistics.
- Resource bonuses.
- Temporary modifiers.
- Other existing tracked information.

Do not invent statistics that are not recorded.

### F. Layout requirements

- Suitable for 16:9 desktop.
- Suitable for 960×540 layouts.
- Suitable for Android touch input.
- No tiny reward labels.
- No overlapping action buttons.
- No forced scrolling for essential information.
- Large, obvious Continue/Upgrade controls.

### G. Animation constraints

- No long mandatory waiting periods.
- Allow the player to skip or accelerate animations.
- Reduced-effects mode where supported.
- Avoid introducing duplicate reward transactions through repeated button input.
- Keep transitions consistent with the existing visual style.

---

# 7. Homeworld damage cinematic

### Objective

Whenever the homeworld suffers damage during strategic-map gameplay, provide a short but impactful visual response.

The event should feel like an enemy attack on an important defended world, not merely a reduction in a numerical counter.

### Critical architectural requirement

**Apply damage to authoritative state immediately. Defer or animate presentation separately.**

The presentation must never determine whether damage has occurred.

Do not postpone authoritative damage, defeat detection, missile resolution or save-state updates.

### A. Damage during active star-map travel

When the homeworld receives damage while the player is traveling:

1. Commit the damage immediately.
2. Capture the relevant presentation event.
3. Interrupt or pause the current map presentation.
4. Preserve travel/navigation state.
5. Stop advancing strategic time during the cinematic.
6. Move the camera toward the homeworld.
7. Play the impact presentation.
8. Animate the displayed integrity bar.
9. Return the camera to the previous framing.
10. Resume the interrupted gameplay state safely.

### Camera behavior

Use a short smooth camera movement toward the homeworld.

Do not teleport the actual player ship to the homeworld.

Do not alter the ship's authoritative position.

Preserve:

- Navigation destination.
- Current route state.
- Camera zoom.
- Camera orientation.
- Remaining travel progress where applicable.

If the existing movement system cannot safely pause mid-tween, implement the smallest appropriate interruption mechanism rather than restarting travel.

Do not reroll Chasedown events or other travel RNG when movement resumes.

### B. Homeworld explosion effects

Play approximately two or three impact effects on the visible homeworld surface.

Use existing destruction or impact VFX resources where practical.

Suggested presentation:

- Short impact flashes.
- Localized explosion bursts.
- Brief particles.
- Subtle camera shake.
- Damage-associated sound cue.

Place impacts on or near the visible surface rather than randomly in empty space.

Avoid creating excessive particle counts on mobile.

### C. Floating damage number

Display a floating damage number above the homeworld.

Examples:

`−12`

or for consolidated events:

`−36`

The number should:

- Be large and legible.
- Use a distinct damage color.
- Rise or drift slightly.
- Fade smoothly.
- Remain readable against the planet and background.
- Avoid clipping at viewport boundaries.

### D. Integrity-bar animation

The integrity bar should decrease smoothly from the pre-damage displayed value to the newly committed authoritative value.

The authoritative value must already be correct before the animation begins.

Do not animate changes by repeatedly mutating actual homeworld integrity.

If several damage events occur together, preserve the correct starting and final values.

### E. Homeworld HUD feedback

Also provide:

- Brief red flash or pulse on the integrity indicator.
- Short warning sound.
- Clear current/maximum integrity display.

Use existing HUD components wherever practical.

Avoid adding a second permanent integrity display.

---

# 8. Deferred homeworld damage presentation

### Requirement

Homeworld damage may occur while the player is inside:

- A card battle.
- A PoI interaction.
- A reward screen.
- Another modal interface.
- A strategic-time activity that does not display the normal map.

In these circumstances, the damage must still resolve immediately.

However, the cinematic should not interrupt those interfaces.

### Deferred presentation flow

1. Authoritative damage is committed.
2. A lightweight presentation event is recorded.
3. Current UI interaction continues normally.
4. Once the star-system map is safely visible, process the pending presentation.
5. Show the damage sequence before resuming normal navigation.

### Event information

Use an appropriate compact record, such as:

- System identifier.
- Event sequence identifier.
- Damage amount.
- Integrity before damage.
- Integrity after damage.
- Cause if known.
- Relevant attacker or missile identifier if available.
- Whether the event has already been presented.

Reuse existing event and save structures where possible.

Do not duplicate the authoritative integrity calculation.

### Consolidation

When multiple events accumulate before returning to the map, combine them into one coherent cinematic.

For example:

Three missile strikes of 12 damage each become:

`HOMEWORLD UNDER ATTACK`

`−36 INTEGRITY`

Use several impact effects, but only one camera interruption.

The integrity bar should animate from the last appropriately displayed value to the actual current value.

### Coalescing safeguards

- Never count the same damage event twice.
- Do not combine damage from different systems.
- Do not overwrite newer authoritative integrity values with earlier queued values.
- Do not create negative damage or fake hits.
- Preserve the original total damage.
- Record zero-damage/non-damaging events only if meaningful to presentation.

### Timing safeguards

Do not advance strategic seconds during cinematic playback.

Do not spawn additional enemies or missiles merely because the camera animation is running.

Do not advance Pressure during cinematic playback.

Do not allow repeated timer callbacks to reapply the same damage.

### Save/load safeguards

If a save occurs with pending presentation:

- The already-applied damage remains committed.
- The pending visual event is either restored exactly once or intentionally marked as consumed using a documented policy.
- The homeworld integrity never rolls back.
- No additional damage is applied when the event is replayed.
- The cinematic never becomes a source of game-state mutation.

For save schema changes, maintain compatibility with existing saves.

---

# 9. Homebase Lost cinematic

### Objective

When the homeworld is conquered, present a dedicated defeat sequence that emphasizes the loss of the defended star system.

This is especially important when the mothership reaches the homeworld.

### A. Defeat detection

Use the existing authoritative Starfront Defense defeat logic.

Distinguish internally between:

- Homeworld integrity depleted.
- Mothership arrival/conquest.
- Other supported terminal conditions.

These events may share the same result-screen component, but their descriptions should reflect their actual causes.

### B. Cinematic presentation

On conquest:

1. Commit the game-over state immediately.
2. Stop normal strategic movement and input.
3. Center the camera on the homeworld.
4. Fade in a black overlay at approximately 50% opacity.
5. Present the heading:

**HOMEBASE LOST**

6. Show a short explanatory subtitle.
7. Display relevant run statistics.
8. Provide appropriate final navigation actions.

Preserve the rendered star system behind the dark overlay.

### C. Subtitle examples

For mothership conquest:

`Enemy forces have captured the homeworld.`

For integrity depletion:

`Homeworld defenses have collapsed.`

Do not present a conquest-specific subtitle for a different defeat cause.

### D. Statistics

Display meaningful tracked statistics such as:

- Systems secured.
- Enemies defeated.
- Enemies disabled via EMP.
- Total combat victories.
- Battles survived.
- Salvage earned, if tracked.
- Salvage spent, if tracked.
- Missiles intercepted, if tracked.
- Final system reached.

Use actual persisted values.

Do not derive false historical totals from current balances.

If a statistic is not available in the current state, either omit it or add minimal explicit bookkeeping only where justified.

Do not implement an unnecessarily broad telemetry system.

### E. Visual design

Use:

- Large, high-contrast heading.
- Subdued red accents.
- Darkened star-system background.
- Limited cinematic camera movement.
- Compact icon-based statistics.
- Clear action buttons.

The screen should communicate defeat without feeling like an error dialog.

Avoid excessive technical details.

### F. Navigation

Provide an appropriate action to return to ship selection or restart according to existing expedition rules.

Ensure the saved expedition's terminal state follows existing single-slot save policies.

Do not enable Continue for a completed/failed expedition if current rules forbid it.

### G. Priority over damage cinematics

Terminal defeat takes precedence over ordinary homeworld damage presentation.

If a pending damage event causes homeworld integrity to reach zero:

- Do not return to normal navigation.
- Avoid playing an ordinary damage cinematic and then immediately playing the same defeat sequence redundantly.
- Prefer one coherent terminal presentation.

A short final impact effect may lead into the Homebase Lost fade.

If the mothership arrives without reducing integrity to zero, the conquest must still trigger the Homebase Lost sequence.

---

# 10. Presentation state management

Because several features temporarily control the star-system camera, introduce or reuse a clear presentation-state mechanism.

Potential states:

- Normal navigation.
- Homeworld damage cinematic.
- Returning camera.
- Homebase Lost.
- Other existing cinematic transitions.

Do not create a second gameplay state machine if the current architecture already separates navigation and presentation.

### Priority rules

Terminal defeat has highest priority.

Homeworld damage presentation should not interrupt:

- Active card combat.
- PoI confirmation.
- Existing modal choice screens.
- Save/load restoration.
- Other non-interruptible cinematic sequences.

Pending damage presentations should play only when the star map can safely accept them.

### Input restrictions

During cinematic playback:

- Ignore duplicate navigation commands.
- Prevent unintended PoI selection.
- Prevent accidental turret purchases.
- Prevent repeated battle initiation.
- Prevent double-activation of Continue actions.

Restore the previous valid input state afterward.

### Cancellation and cleanup

Handle:

- Scene changes.
- New Expedition.
- Save & Quit.
- Window resize.
- Android app pause/resume.
- Returning to menu.
- Terminal defeat occurring during another presentation.

Cancel or finalize presentation objects safely.

Prevent orphaned tweens, signals, timers and particle nodes.

---

# 11. Performance and accessibility

### Android considerations

Use conservative effects for Mobile Vulkan and GL Compatibility.

Prefer:

- Existing particle systems.
- Lightweight meshes.
- Reused materials.
- Limited simultaneous VFX.
- Few transparent overlapping layers.
- Existing shaders with mobile-compatible settings.

Avoid:

- Expensive full-screen blur.
- Numerous real-time lights.
- Excessive particle emission.
- High-cost postprocessing.
- Large dynamically allocated textures.

### Responsive UI

Test:

- 1920×1080.
- 1280×720.
- 960×540.
- Narrower Android aspect ratios.
- Notches/safe areas where applicable.

Important controls and text must remain legible.

### Accessibility

Where feasible, respect existing visual-effects settings.

Support:

- Skippable cinematics.
- Reduced screen shake.
- Reduced flashes.
- Reduced motion/animation.
- Readable HUD contrast.

Do not require color alone to communicate damage, victory or failure.

---

# 12. Automated testing

Add focused regression coverage for the following.

## Environmental generation

- Storm regions cannot intersect homeworld protected geometry.
- Gas giants cannot intersect the Solar Flare region.
- Placement attempts are bounded.
- Deterministic generation remains reproducible.
- Valid systems preserve intended variety.
- Existing saves remain loadable.

## Player locator

- Player locator follows the ship.
- Off-screen arrow appears correctly.
- Arrow disappears on reentry.
- Camera zoom and resize remain correct.
- Controls remain unobstructed.

## Battle results

- Hull destruction displays correct result type.
- Systems Failure displays correct result type.
- EMP success displays the appropriate neutralization wording.
- Mothership success displays System Secured.
- Rewards match authoritative results.
- Result animations cannot duplicate rewards.
- Upgrade and Continue controls work on desktop and touch.

## Homeworld damage

- Damage commits immediately.
- UI animation does not modify authoritative integrity.
- Damage presentation pauses strategic time.
- Travel resumes without movement duplication.
- No Chasedown reroll.
- Several damage events consolidate correctly.
- Deferred events replay after returning from battle or PoI.
- Save/load cannot reapply damage.

## Homebase Lost

- Mothership arrival triggers conquest.
- Integrity depletion triggers defeat.
- Cause-specific subtitles are correct.
- Terminal events override ordinary damage cinematics.
- Statistics reflect actual tracked values.
- No player input can resume a failed expedition improperly.

---

# 13. Manual visual validation

Automated tests alone are insufficient for a presentation-focused task.

Run the game and validate the actual visuals.

Capture screenshots or short recordings where the available environment supports them.

Review:

1. Star system without the persistent storm text.
2. Star-system generation with safe environment placement.
3. Player locator at normal zoom.
4. Player locator when zoomed out.
5. Off-screen player arrow.
6. Normal combat victory screen.
7. EMP victory screen.
8. Mothership System Secured screen.
9. Homeworld damage cinematic.
10. Deferred multi-impact presentation.
11. Homebase Lost screen.

Inspect visual alignment, animation timing, text readability, transitions and UI overlap.

If rendering validation is unavailable, clearly state which scenes remain unverified rather than claiming visual acceptance.

---

# 14. Scope control

This is a polish pass.

Do not modify:

- Card balance.
- Ship statistics.
- Enemy statistics.
- Salvage reward amounts.
- Repair pricing.
- Turret prices.
- EMP charge rules.
- Strategic Pressure values.
- Reinforcement pacing.
- Missile damage.
- Environmental combat multipliers.
- Enemy AI.
- Procedural enemy difficulty.

Only modify gameplay-adjacent logic when necessary for presentation correctness, safe generation, event persistence or result-state accuracy.

Avoid large unrelated refactors.

---

# 15. Deliverables

Provide:

### A. Implementation

All requested polish features integrated into the existing game.

### B. Visual evidence

Screenshots or recordings demonstrating important UI and cinematic changes when supported.

### C. Technical notes

Document:

- Environmental exclusion rules.
- Player locator implementation.
- Combat-result presentation.
- Homeworld damage event handling.
- Deferred cinematic behavior.
- Save/load behavior.
- Terminal defeat precedence.
- Performance considerations.

### D. Test results

Report:

- Unit/regression tests.
- Relevant CI results.
- Desktop renderer results.
- Android renderer results.
- Known limitations.

### E. Pull request

Open a dedicated PR containing the implementation, tests and concise documentation.

Do not merge automatically.

---

# 16. Acceptance criteria

This pass is complete when:

- The upper-left persistent storm text is removed.
- Environmental storms do not overlap the homeworld.
- Gas giants do not intersect the Solar Flare region.
- The player ship is more visible.
- An off-screen arrow helps locate the player ship.
- Combat victories use larger, more satisfying presentation.
- EMP success is visually distinct from destruction.
- Mothership victories receive a System Secured presentation.
- Homeworld damage triggers clear camera and impact feedback.
- Damage is committed immediately, regardless of presentation.
- Deferred impacts display safely after battles and PoI interactions.
- Homeworld defeat receives a dedicated Homebase Lost cinematic.
- Conquest and integrity-depletion causes are distinguished.
- Save/load preserves authoritative state and avoids duplicate events.
- Strategic time does not advance during cinematics.
- Desktop and Android layouts remain usable.
- No unrelated gameplay balance is altered.
- Relevant regression tests pass.
- A reviewable PR is created without automatic merging.

## Final design principle

**Make important events feel important.**

The star system should be easier to read, combat victories should feel rewarding, attacks on the homeworld should feel dangerous, and losing a system should feel like the conclusion of a meaningful expedition.

Prioritize visual clarity, satisfying feedback, reliable state handling and consistent presentation over additional gameplay complexity.