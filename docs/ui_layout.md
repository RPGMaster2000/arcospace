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

Descriptions and comparison values remain data-driven. The existing primitive placeholder drawing scales within its available space instead of overlapping long descriptions. Browsing uses the same renderer as combat; it does not create a second card library.

## Layout and navigation

- PoI and station approach grids align to the bottom of their existing expandable scroll region. Their panoramic header and Return remain fixed. Overflow still scrolls; approach confirmation stays in the existing bottom modal.
- Combat cards end 12 logical pixels above the bottom edge. Discard targets are 48 logical pixels high; the hand fits the available width. Jump is a separate 104×48 bottom action above the hand, preserving the existing signal and node path. Last-action text and the decorative hand divider follow the hand geometry.
- FTL charge track width is 154, previously 230 (33% smaller). Panel width is 248, previously 371. Charge text remains readable at 14 px, with the full Emergency Jump description in its tooltip. The charge bar retains ship-relative framing; the Jump action is positioned independently at the bottom.
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

