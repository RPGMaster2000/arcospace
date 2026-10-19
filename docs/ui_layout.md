# Card galleries and responsive UI

UI update based on main `c07bd0f`. No new artwork, cards, effects or balance values. Card/ship Resources, acquisition weights, upgrade eligibility, turn rules, FTL mechanics, expedition generation, Salvage and PoI outcomes are unchanged.

## Shared card components

| Component | Responsibility |
|---|---|
| `scripts/ui/card_gallery.gd` | Responsive, centered vertical gallery; All/Attack/Defense/Production/Utility filters derived from actual effect keys; Name/Cost/Rarity/Family sorting |
| `scripts/ui/card_portrait.gd` | Reuses `scenes/card.tscn`, its existing placeholder primitives, family colors, cost icons and rarity border; replaces Discard with Base/+/++ status for browsing |
| `scripts/ui/card_inspector.gd` | Dimmed centered preview, current/next comparison, lightweight fade, Confirm/Cancel, trapped keyboard focus, single-use confirmation guard |
| `scripts/ui/card_effect_text.gd` | Reads actual next-upgrade effects; green improved/new values, neutral unchanged values; handles nested production, drain, theft, random bounds and reduced self-damage/risk |
| `scripts/ui/deck_viewer.gd` | Read-only starting pool for the selected ship; updates when selection changes; reuses gallery and inspector |
| `scripts/ui/encounter_scroll.gd` | Existing native wheel/PoI scrolling and drag-release guard; opt-in explicit ScreenDrag handling for galleries with nested Buttons |

Acquisition opens a preview before invoking the existing `choose_card` method. Upgrades show only `upgrade_candidates()` and preview `with_upgrade(current_level + 1)`, then invoke the existing `choose_upgrade`. Cancel spends/grants nothing. A stale or repeated confirmation cannot apply twice. Gallery input is suspended while its inspector is open. Deck Viewer has no state-changing callbacks or visible Confirm action.

Descriptions and comparison values remain data-driven. The compact-card pass below now fixes artwork at 174×74 design pixels; descriptions never resize that rectangle. Browsing and inspection use the same renderer as combat; there is no second card library.

## Layout and navigation

- PoI and station approach grids align to the bottom of their existing expandable scroll region. Their panoramic header and Return remain fixed. Overflow still scrolls; approach confirmation stays in the existing bottom modal.
- Combat cards end 12 logical pixels above the bottom edge. Discard targets are 48 logical pixels high; the hand fits the available width. Jump is a separate 104×48 bottom action above the hand, preserving the existing signal and node path. Last-action text and the decorative hand divider follow the hand geometry.
- FTL charge track width is 154, previously 230 (33% smaller). Panel width is 248, previously 371. Charge text remains readable at 14 px, with the full EMP Pulse description in its tooltip. The charge bar retains ship-relative framing; the Jump action is positioned independently at the bottom.
- Ship selection removes general instructions, uses the existing bundled icon/legend system for resource/production values, and preserves Hull, Shields, Jump duration and resistance. Ship traits remain in tooltips. Larger existing 3D previews use aspect-aware orthographic framing. The selected panel remains highlighted. View Deck and Begin Expedition share a compact bottom row.
- Defeat/draw hides New Expedition and offers Select Ship, routing to the initial selection screen. No expedition starts until Begin Expedition is confirmed there. Victory/escape actions retain their existing flow.
- Shared focus outlines, panel borders and button styles follow the existing encounter presentation helper. No asset generation/import is part of this change.

## Validation

Godot 4.7.2 on Windows: all 35 `*_test.gd` scripts pass after relevant regression reruns. This includes the previously failing travel-battle Jump overlap check (all 15 ship/enemy combinations). Editor import reports no script parse/compile errors.

Source hashes for 73 gameplay Resource/rule files match the starting commit, ignoring trailing newlines. The new UI test also snapshots all card costs, rarity, effects and upgrade definitions before/after interaction and verifies they remain unchanged.

`tests/ui_overhaul_test.gd` covers all 88 next-upgrade comparisons, correct costs/values and neutral/green highlighting, actual rewards and eligible identities, Confirm/Cancel/double activation, read-only decks, selection changes, filtering, mouse-wheel movement, synthetic ScreenTouch/ScreenDrag movement and release protection, modal input blocking, bottom anchoring, larger ship previews, FTL width and defeat routing. It checks 1280×720, 1680×720 (21:9), 1920×1080, 960×540 and 800×450 window sizes using the project's existing canvas scaling.

Existing Android checks cover 2,435 assertions, station UI 1,050, crowded bars 4,095, and status/modifiers 10,657. Gameplay regressions include 10,000 generated systems / 426,069 progression checks, 93,950 PoI checks and 47,176 station checks.

Run `godot --headless --path . --script tests/ui_overhaul_test.gd`. Running the same test with a rendering driver also writes review PNGs to ignored `.godot/testlogs/overhaul-*.png`. Windows OpenGL rendering was exercised and screenshots inspected for ship selection, deck browsing, comparison, PoI and combat layouts. The environment cannot write Godot's usual user log/editor/shader cache or read the system certificate store; these environment diagnostics also occur on the baseline.

Physical Android touch/GPU behavior, APK export, and Vulkan/mobile renderer behavior were not tested on a device. Galleries currently use direct drag scrolling without added custom fling physics. No persistent UI settings or new save format were introduced.

## Outcome feedback and current deck

Acquisition choices hide the entire category/sort/count toolbar; upgrade galleries and read-only deck galleries retain browsing controls. The Deck button beside Legend opens the actual expedition pool, including acquisitions and current identity upgrades.

Completed rolled PoI approaches display a one-second green (success) or red (failure) overlay before revealing rewards. Input is blocked during the pulse; rewards roll and apply once. Reward headers read Mission Successful or Mission Compromised. Surveys, services and battles do not reuse stale PoI headers. Tune the pulse duration on scripts/ui/outcome_flash.gd.

Elite victories grant double Salvage and +3 of each next-battle resource, once, stacking with existing bonuses. Escape remains zero Salvage and grants no Elite bonus. See docs/balance/ships.md and ExpeditionRules Inspector fields.


Follow-up validation: all 36 automated test scripts pass on Godot 4.7.2. The new reward_feedback_test.gd makes 310 checks across every enemy profile, destruction/resource/escape/loss outcomes, stacked and once-only bonuses, next-battle consumption, current upgraded decks, toolbar visibility, both PoI branches and one-second reveal timing. Editor import has no script parse/compile errors. Windows OpenGL screenshots of the current deck, green/red pulses and both mission headers were inspected. Physical Android testing remains unverified.


Victory summaries use compact resource icons and amounts, one shared Next battle heading, and only earned Elite/tactical/strategic bonus rows. Condition explanations and repeated Star System navigation instructions are omitted. Hull changes and damage taken remain visible. Presentation only: reward qualification, values and persistence are unchanged. Verified with victory/reward, UI-overhaul, Android-layout, Salvage and travel-battle regressions plus Windows OpenGL rendering; physical Android remains unverified.


Result navigation now has one Select Ship destination for every result; a fresh expedition begins only after ship confirmation. At full combat EMP Pulse charge, the FTL label/bar are replaced in place by a 48-pixel-high Jump button. A charged offline drive keeps a red, disabled Jump offline button with remaining turns in its tooltip. Turn/input eligibility and FTL charging/disruption rules remain unchanged. Seven relevant regression scripts pass; charged online/offline rendering was inspected on Windows OpenGL. Physical Android remains unverified.


## Power Allocation

The 64-pixel-wide current-mode emoji button sits beside the projected player ship, near its engine side. Its anchor uses the ship presentation center plus a fraction of BattleView height at every aspect ratio. It does not change hand width, positions, card dimensions or existing landscape scaling.

The reusable `scripts/ui/power_allocation_popup.gd` overlays a darkened battlefield with four centered 2×2 touch targets, active-mode highlighting, short hints, static weight indicators, and Back/outside-tap dismissal. Keyboard focus stays within the popup. The battle is not paused and allocation remains free during either turn. Choosing a mode changes only future player draw weights; opening/closing/selecting never redraws held cards. Each battle starts Balanced, with two Materials-cost, two Energy-cost and two Crew-cost player cards. Enemy drawing/AI is unchanged.

Configuration and the per-card primary category table are in `docs/balance/cards.md`. The Inspector weight is copied at battle start and cannot be changed through the popup. No new artwork or mobile-specific layout branch was added.

Validation: `tests/power_allocation_test.gd` includes 48,000 sampled draws, exact legacy Balanced sequence comparisons, rarity/cap regressions, 1,200 seeded ship openings, snapshot checks for hands/resources/FTL/RNG, and real mouse/ScreenTouch input on all six ships at 1280×720, 1680×720, 960×540 and 800×450. OpenGL screenshots were inspected at desktop, ultrawide and Android landscape sizes. Synthetic touch is verified; physical Android device/GPU behavior and APK export remain unverified.

Final validation: all 37 automated Godot 4.7.2 test scripts pass after the 2/2/2 opening addition; the allocation test passes 16,948 checks. Editor import reports no script parse/compile errors. All 44 card Resource files match the starting commit exactly after excluding the added category metadata; enemy ships/AI, encounter definitions, upgrades, effects, FTL and project configuration remain unchanged.

## Expedition milestones update

Power Allocation retains its existing popup, weights and input behavior. `Board3D.allocation_presentation_offset` defaults to (-0.56, 0.02), measured in fractions of the battle presentation height from the projected player ship center. Position clamps protect the resource column, top HUD, Hull/Shields and hand. No model-specific engine coordinates, hand resizing or ultrawide-only branch is used. The 2D board has a ship-centered fallback.

The system FTL control shows carried starting charge normally and explicitly says Resolve Boss first when a milestone is unresolved. Boss tiles say Mandatory Boss; the preview explains Victory or EMP Pulse and shows effective level/Hull/Shields. Normal PoI navigation and six-slot layout remain unchanged. Full formulas and Inspector paths are in the ship/PoI balance references.

Validation is performed by the Godot regression workflow on an isolated branch before publishing main because the local execution environment is unavailable. Physical Android gameplay and device GPU rendering remain unverified.

### Minimal star-map prototype

`scenes/expedition.tscn` → Expedition Inspector: `use_star_map` defaults to **true**.
Disable it to restore the unchanged 3×2 encounter grid. `star_map_travel_duration`
controls presentation-only travel (default **1.4 seconds**).

`scripts/ui/star_map.gd` draws a static star field, central star and triangle ship;
its six touch targets consume the existing generated encounters. A separate service
marker preserves the Trading Outpost's free revisits and zero FTL. Arrival calls the
existing encounter router. Completed destinations are disabled; returning preserves
ship position, while a new system/expedition resets it. FTL/Boss rules remain in
ExpeditionState. Travel is a short, non-skippable animation; repeated taps are ignored.
No assets, combat layout or balancing values change.

Battlefield lighting, procedural backgrounds and the optional normal Planetary Orbit
scene are documented in [battlefield_environments.md](battlefield_environments.md).
Their lights/materials are scene-local; the board only adjusts background framing.

The system Hull status reuses its existing info overlay for field repairs. Heartbeat
exports and the conditional Outpost repair/plating controls are described in
[hull-capacity.md](hull-capacity.md#field-repairs-and-outpost-plating).

## Chasedown and sequential upgrades

The compact Chasedown narrative reuses the expedition view and 2×2 response tiles. The existing gallery shows remaining upgrades and a Finish upgrades button. Selecting an identity removes it from that event's choices, including after a preview is reopened; it can be selected again in a later event. Victory summaries include the upgrade count. Interstellar FTL tooltips state that the next system starts at zero. Both map and grid resume the preserved destination after rewards.

`tests/chasedown_ui_test.gd` covers victory/escape in both navigation modes, replay guards, destination restoration and multi-card upgrade selection at 1280×720, 1680×720, 960×540, 800×450 and 686×384. Godot 4.7.2 Compatibility rendering was checked with software OpenGL; physical Android remains unverified.

## Compact cards and universal inspection

Based on main `272ec74`. Normal cards retain the original 198×294 design, family colors, icons, cost size, tier borders and discard hit target. Descriptions use **14 px** and `CardSummary` derives short text from actual effect dictionaries, factoring common conditional branches when possible. There are no per-card manual summaries or balance changes. Text stays below the fixed artwork rectangle `(12,109,174,74)`, with a line limit and ellipsis for overflow. Full values remain in tooltips and read-only inspection. Tier/upgrade markers sit beside the cost so the full name usually retains 20 px; unusually long names use 19/18 px only when needed to fit two lines. Cost remains 35 px.

`card_portrait.gd` always renders the unchanged card scene, including current upgrade/tier styling. Upgrade confirmation keeps the existing two-card workflow and green comparison, with the detailed comparison in its own scroll area below the cards instead of inside their artwork. Holding either card can open full inspection too; normal acquisition/upgrade Confirm/Cancel validation is unchanged.

Hold a card for **0.4 seconds**, or middle-click, to open the shared read-only overlay from combat, deck browsing, acquisition/upgrade galleries or replacement. It stays open after release. A short tap keeps the original action; combat right-click still discards. Dragging at least the movement threshold, or starting a gallery scroll, cancels the pending hold and release activation. Disabled/unaffordable cards remain inspectable. Inspection consumes no turn and does not pause existing battle timers; already scheduled enemy actions retain their normal timing. Empty slots and transient invisible card-motion copies do not inspect.

The overlay creates an instance of `scenes/card.tscn`, retaining the selected Resource, current temporary preview, title/summary, artwork geometry, badges, tints and tier/ion styling. It hides only combat actions and disables input on the copy. Position and uniform scale tween from the original slot; the original never moves. The right-hand panel fades in with a dimmed backdrop. The combined card/panel rectangle is centered with 16 px safe margins. Resizing clamps the card scale and panel width; detailed text stays at the configured size and scrolls vertically. The fixed Close button remains outside that scroll area. Source tooltips are temporarily suppressed to avoid covering inspection.

The panel reads base and both complete upgrade dictionaries through `CardData.describe_effects`, highlighting the selected current level. `with_upgrade()` and Ion previews retain an `inspection_base` Resource reference solely for presentation; temporary combat values appear in an additional current-preview section. No independent gameplay values are authored in the overlay.

Close, outside tap, Escape or the controller cancel action dismiss inspection smoothly. Keyboard/controller accept also activates Close; arrows/Page Up/Page Down scroll the information panel. Background shortcuts and focus navigation are blocked. Deck Viewer/CardInspector defer cancel input while this top overlay is open, so Escape preserves the parent screen. Gallery selection, replacement incoming/selected cards and scroll position remain unchanged. Scroll gesture adapters are suspended and restored; source button press attempts are cancelled before showing the overlay so releasing a hold cannot play, discard, acquire, upgrade or replace. Source changes/removal/hiding cancel pending holds and active inspection, and resize/close cancels obsolete tweens.

### Shared Inspector settings

Select `resources/card_presentation.tres` in Godot. The original card scene references this Resource; gallery portraits and inspection reuse it. No project autoload/configuration change is needed: `CardInspection` is one lazily created root CanvasLayer per SceneTree.

| Property | Default |
|---|---:|
| Compact Description Font Size | 14 |
| Hold Duration | 0.4 s |
| Hold Movement Cancellation | 12 px |
| Inspection Tween Duration | 0.2 s |
| Enlarged Card Scale | 1.5 |
| Information Panel Width | 360 px |
| Background Dim Opacity | 0.8 |
| Information Panel Text Size | 18 px |
| Panel Card Spacing | 20 px |

Ownership: `card_presentation_settings.gd` / the shared Resource own tuning; `card_summary.gd` formats short text; `card_hold.gd` owns input/timer cancellation; `card_inspection.gd` owns the read-only modal/copy/scroll/focus/tweens. The original `card_view.gd`, `card_portrait.gd`, `card_inspector.gd` and `deck_viewer.gd` retain their rendering/confirmation/viewer roles. Gameplay effect resolution, costs, hand size, acquisition probabilities, deck limits and turn sequencing are unchanged.

Validation: Godot 4.7.2 editor import and all **50 automated test scripts** pass. New `card_inspection_test.gd` checks all 68 identities at levels 0/1/2, fixed artwork, complete titles, compact text/footer geometry, genuine touch holds, unaffordable combat inspection, middle-click, tap/right-click behavior, gallery drag cancellation, source changes/removal, current-level data, Escape/outside/Close, preserved deck/replacement state, and no combat/ownership changes. Rendered Compatibility/software OpenGL checks cover inspection and confirmation workflows at 1280×720, 1680×720, 960×540, 800×450 and 686×384; captures were inspected. Existing short-tap fixtures now use distinct immediate press/release events, rather than waiting long enough to constitute a hold. CI includes the new rendered regression.

Physical Android timing, gesture feel and on-device text readability still need manual verification. No artwork was generated. Very long summaries deliberately end in an ellipsis; full effects and both upgrades remain available without reducing the detailed text size.
