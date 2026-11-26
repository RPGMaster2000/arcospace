# Holographic interface

Angular panels and cyan telemetry now link ship selection, card combat, the expedition map, inspections, settings, deck views and battle results. Deep navy panels preserve contrast over the 3D scene. Warm red identifies Materials, blue identifies Energy, and green identifies Crew. Hull damage, shields, faction sides, warnings and rare rewards retain their own color cues. The battle HUD also labels the three resources so color is one cue among several.

The battle HUD uses segmented Hull, Shield and EMP readouts. Shield numbers are exact. The Shield bar shows the current value relative to its peak during the battle because Shields have no capacity. Hull segments share a scale with Ablative Plating, with gold marking the excess range. Shield and Hull changes produce separate signed readouts. Resource payments, gains and production changes use the same typography and family colors. Result tiles read committed rewards through the existing result sequence.

The map keeps the 3D scene and existing interaction zones. Segmented indicators cover Homeworld, Pressure, capture, War Effort and territory. Markers use angular labels and world-aligned targeting rings. Notices use existing strategic event data. Convoy confirmations and alerts use different treatments.

## Skin and assets

[Holographic skin](../resources/presentation/holographic_skin.tres) is the default Inspector-editable Resource. It exposes palette, typography, padding, cuts, border width, glow, motion, and the optional asset layers. Cards still accept per-card illustration textures independently of the frame. Card-family colors can still be tuned through Card Presentation Settings.

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

Review on an Android device at the default and lowest supported landscape sizes. Check the card hand and result labels under bright lighting, native touch interactions, visibility over bright storm backdrops, and frame pacing while opening map inspections.
