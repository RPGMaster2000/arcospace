# Holographic interface

Angular panels and cyan telemetry now link ship selection, card combat, the expedition map, inspections, settings, deck views and battle results. Deep navy panels preserve contrast over the 3D scene. Warm red identifies Materials, blue identifies Energy, and green identifies Crew. Hull damage, shields, faction sides, warnings and rare rewards retain their own color cues. The battle HUD also labels the three resources so color is one cue among several.

The battle header pairs the selected player ship and signature with the enemy’s name, faction and role. The centered indicator uses the current battle round and animates on a change of ownership. Tap the player identity to open Battle Systems, which includes ship information, active boons and temporary bonuses. Dark, translucent gradients fade from the left and right identities toward the middle. The round readout fades toward both sides. All three fade down into the battlefield. Salvage remains visible in progression screens and battle results.

Shield telemetry draws one electric-blue segment per five Shield points and fills the remainder proportionally. When individual segments would crowd the tile, one segment and a multiplier represent the complete segments, followed by any partial segment. The number always shows the exact protection. A depleted stack reads **Shields 0**, and a temporarily disabled stack reads **Shields OFF**. Shield changes ease the segment widths and briefly emphasize the new number. Minimal motion updates immediately. Hull keeps its actual capacity and displays Ablative Plating beyond that capacity in gold. The Hull tint shifts to amber and red as integrity falls. Materials, Energy and Crew have distinct tinted plates with production printed inside. Short layouts move the two resource groups into mirrored rows when needed to clear the hand. Unaffordable cards retain legible rules and use a warning-colored cost. Tier 2 adds a secondary frame and labeled badge, and Tier 3 adds gold trim and a short edge sweep when revealed or selected.

The violet EMP strip fills upward beside the player’s Materials, Energy and Crew column. The Battle Systems handle sits just beyond the strip and the open drawer leaves it exposed. It shows readiness, a firing cue during the cinematic, and the used or offline state. At full charge it sweeps upward once. At activation it drains on the 3D discharge cue, or immediately when the cinematic is skipped by preference. Minimal motion switches directly to the resulting state. The charging strip opens the EMP reference, and the full tile becomes the activation target when ready.

The Power Allocation button sits above the hand. Its unfolding chevron and engraved glyph show the menu state and current allocation. Tap to reveal four fixed touch targets, tap a mode to select it, or hold a mode to inspect its draw weighting without selecting it. Tap the main button again or tap outside to close.

The hand and mirrored HUD use the same safe bounds. The larger horizontal inset applies to both sides so the hand and round readout stay centered with an asymmetric cutout. The hand caps at 198×294 logical units per card. The Hull and Shield tiles sit 14 logical units above the hand. The Power Allocation flyout sits above those tiles, alongside the left HUD. Both tactical handles have their own space on the inward side of the resource rails.

In rendered trials, moving the defense tiles down with the original in-place lift covered telemetry at activation. Played player cards now slide from their actual hand slots into the open lane between the defense groups and lift by the same 20% of their on-screen height. The horizontal slide leads the lift to clear the tiles. The existing cue, linger, exit, discard and replacement timings still apply. Enemy cards keep their original position and exit.


The map keeps the 3D scene and existing interaction zones. Segmented indicators cover Homeworld, convoy integrity, fleet strength, Pressure, capture, War Effort and territory. Markers use angular labels and world-aligned targeting rings. Notices use existing strategic event data. Convoy confirmations and alerts use different treatments.

## Skin and assets

[Holographic skin](../resources/presentation/holographic_skin.tres) is the default Inspector-editable Resource. It exposes palette, typography, padding, cuts, border width, glow, motion, and the optional asset layers. Cards still accept per-card illustration textures independently of the frame. Card-family colors can still be tuned through Card Presentation Settings.

Compact padding, related-element gaps and section gaps are shared tokens. The Resource also exposes family surfaces and the battle header’s opacity, horizontal fade and downward fade. The Shield stack uses the shared meter fill texture when assigned.

Native StyleBoxes handle panels, push buttons, tabs, card frames, focus outlines and notifications. Godot manages container sizing and native controls keep their hit areas and focus. The fallback draws a short list of canvas commands per redraw. Status bars use their existing native values and ranges with a mouse-transparent segmented painter. The map ring uses bounded geometry on its existing plane and a single material per ring.

### Replace a panel or button

1. Import a PNG or an SVG as a Texture2D. A frame with a transparent middle lets a separate background show through. Source size is flexible.
2. Open [the skin Resource](../resources/presentation/holographic_skin.tres). In **Frames**, assign the panel under **dialog** and the button under **button.normal**. Add alternate button states under **button.hover**, **button.pressed**, **button.disabled** or **focus**. Toggle buttons use the same keys with **tab** in place of **button**.
3. Set **Slice Margins** in left, top, right, bottom source pixels. Make them wide enough to preserve the corners. Content padding is independent and determines where the existing controls lay out. A missing state falls back to the role texture, then to the geometric frame.
4. Use **Backgrounds** or **Ornaments** to layer other art. Role keys include **panel**, **compact**, **dialog**, **warning**, **reward**, **selection**, **marker**, **card**, **card.tier2** and **card.tier3**. Meter track, meter fill and reticle images have dedicated slots. Use a white or neutral reticle image with transparency so the existing faction tint can be applied.
5. Validate the result in the production scenes and the showcase. Dialogs, compact HUDs and Android panels use the same asset lookups.

The optional audio slots accept event IDs from the existing Sfx catalog. The default reuses the quiet interface-selection cue for opening informational dialogs and the result cue for successful strategic notifications. Warnings have an assignable slot. Existing buttons, cards and combat use their established event routing and volume controls.

## Motion and performance

Settings exposes **Interface Motion** with **Minimal**, **Standard** and **Cinematic**. Minimal snaps the new gauges and summaries, skips panel fades, and suppresses decorative hover movement. Standard uses short eased button and selection states, approximately 230 ms panel activation and 320 ms gauge movement. Cinematic increases decorative reveal duration while retaining the same button timing. The existing camera cinematics, Battle VFX and combat continuation preferences remain independent.

The motion helper keeps one Tween per target and visual channel, cancels interrupted transitions and ignores repeated gauge values. It animates display state only. Card action timelines and combat pacing use their existing owners. Desktop-rendered checks exercise both renderers. Physical Android frame pacing, contrast and touch comfort still need device testing.

## Showcase and captures

Launch the independent showcase with

    godot --path . res://scenes/tools/holographic_showcase.tscn

Use **Intercept** to advance the sample gauge, **Replay entrance** to replay a panel opening and the motion chooser to try each profile without saving it. The panel and button texture examples use a Godot gradient. The cards use their production scenes.

| View | Rendered comparison |
| --- | --- |
| Battle HUD and telemetry | [Before and after](holographic_ui/battle.webp) |
| Card hand | [Before and after](holographic_ui/hand.webp) |
| Star-system HUD | [Before and after](holographic_ui/strategic.webp) |
| Enemy inspection | [Before and after](holographic_ui/inspection.webp) |
| Victory and reward selection | [Before and after](holographic_ui/result.webp) |
| Ship selection | [Before and after](holographic_ui/ship-selection.webp) |
| Independent showcase | [Showcase](holographic_ui/showcase.webp) |

The captures use the actual scenes under GL Compatibility. The map and battle use System 5, seed 39. Opening draws and the exact billboard poses may differ between captures.

    godot --path . --rendering-method gl_compatibility --script res://tests/holographic_captures.gd

The battle telemetry comparison uses the same card hand and combat values before and after the refinement.

| Battle state | GL Compatibility comparison |
| --- | --- |
| 65 Shields, zero enemy Shields, damaged Hull, production changes and all three card tiers at 960×540 | [Before and after](battle_telemetry/high-shields.webp) |
| Disabled Shields and enemy turn at 760×428 | [Before and after](battle_telemetry/shields-off.webp) |
| Critical Hull at 686×384 | [Mobile Vulkan capture](battle_telemetry/compact.webp) |

Review on an Android device at the default and lowest supported landscape sizes. Check the card hand and result labels under bright lighting, native touch interactions, visibility over bright storm backdrops, and frame pacing while opening map inspections.


The latest Shield stack and borderless header captures use the real battle scene in GL Compatibility.

| Battle scene | Screenshot |
| --- | --- |
| Dark space, 23 and 1 Shield points | [Partial segments](battle_telemetry/shield-stacks-dark.webp) |
| Bright solar arena at 760×428, 200 and 50 Shield points | [Grouped and individual segments](battle_telemetry/shield-stacks-bright.webp) |
| Same solar arena with Shields disabled | [Shields OFF](battle_telemetry/shield-stacks-disabled.webp) |


| Battle systems in Mobile Vulkan | Screenshot |
| --- | --- |
| Charging strip and folded Power Allocation button | [Collapsed controls](battle_telemetry/emp-charging-collapsed.webp) |
| Stable full-charge state | [Ready EMP](battle_telemetry/emp-ready.webp) |
| Mid-drain, synchronized with the 3D wave | [Discharge](battle_telemetry/emp-discharge.webp) |
| Four icon-only options at 760×428 | [Expanded allocation](battle_telemetry/emp-expanded.webp) |
| Draw-weight detail after a touch hold at 760×428 | [Hold to read](battle_telemetry/emp-hold-details.webp) |
| Resource rail and EMP alignment on desktop | [Desktop](battle_telemetry/emp-resource-rail-desktop.webp) |
| EMP ready with Battle Systems open at 686×384 | [Compact landscape](battle_telemetry/emp-resource-rail-compact.webp) |


## Responsive battle captures

The before-and-after sheet pairs the same render sizes on main and on the revised layout. The animation frames include a real Laser Burst during Shield loss and resource spend, its replacement, and consecutive player plays while an enemy card lingers.

- [Before and after at five landscape sizes](battle_telemetry/responsive-dock-comparison.webp)
- [Card motion and compact safe-area examples](battle_telemetry/responsive-dock-motion.webp)
