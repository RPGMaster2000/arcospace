# Expedition UI and Android landscape

This pass changes presentation and input routing only. ExpeditionState remains responsible for requirements, outcomes, payments, completion and FTL progression.

## Layout and artwork

| File / Inspector field | Purpose |
|---|---|
| `scripts/expedition.gd` | Three-column system grid, two-column approach/service grid, three-column card choices, centered outcomes, selection followed by Confirm |
| `scenes/poi_header.tscn` | Reusable banner; separate TextureRect, dark backing, title and Return overlays |
| PoI `.tres` → Presentation → Banner Texture | Assign future PNG artwork; null keeps the dark placeholder functional |
| Header → Banner Texture | Optional shared fallback image |
| Header → Maximum Height | Default 156 logical pixels; preferred aspect 5.5:1, capped to 24% of viewport height for short landscape screens |
| `scripts/ui/encounter_presentation.gd` | Central emoji/text mappings and subdued colors; swap mappings here for future icon assets |
| PoI → Anomalous Presentation | Blue presentation classification; hazardous PoIs remain orange, enemy encounters red, other PoIs green |
| Expedition → Text Icons On Android | Default false: bundled color emoji on Android and desktop. Enable only to prefer abbreviations; missing glyphs still use text fallback |
| `scripts/ui/encounter_tile.gd` | Wrapped labels, selection outlines, content-driven height; no reward lines removed to fit |
| `scripts/ui/encounter_scroll.gd` | Native vertical touch scrolling, 12-pixel drag threshold and 180-ms release guard against swipe selection |
| `scripts/battle_setup.gd` | Responsive comparison-card placement, preserving preview nodes and ship selection |

Return and Confirm remain outside the scrolling area. A bottom hint appears when more content is available. The existing navigation survey appears as an additional selectable tile when applicable; it also requires Confirm. There is no production selector. Requirements display actual expedition production. Shared +1 travel charge appears once below the approach grid; extra outcome charge remains in its reward text.

## Verification

Run with Godot 4.7.2:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/android_layout_test.gd
godot --headless --path . --script tests/expedition_ui_test.gd
godot --headless --path . --script tests/ftl_progression_test.gd
```

`android_layout_test.gd` checks all 44 authored approaches against actual outcomes and all three ships, selection without execution, single execution on Confirm, Return, completed tiles, locked options, text containment, fixed controls, seven-option overflow, mouse wheel scrolling, Godot emulated-touch dragging, screen-touch release rejection, banner assignment/cropping and icon fallback.

Rendered tests cover 1280×720, 1560×720, 960×540, 1280×480 and 686×384 using the existing canvas scaling. To capture images under `.godot/testlogs/`, run the layout test with `--rendering-method gl_compatibility` instead of `--headless`.

All 26 Godot test scripts passed, including 2,637 layout assertions and the unchanged 10,000-system progression simulation. Native Android hardware, device-specific font rendering, display cutouts and OS gestures were not available for testing. A bundled subset of Noto Color Emoji supplies icons without depending on device fonts; see `assets/fonts/README.md`. Long or expanded approaches intentionally scroll vertically instead of truncating rewards.


## Exploration status and encounter previews

- `scripts/ui/resource_bar.gd`: seven exploration indicators: Hull, Shields, Salvage, Materials/Synthesizer, Energy/Reactor, Crew/Quarters and Emergency Jump. A resource reads `⚡ +2/t · 10 Energy +5`; production is the expedition total and the colored suffix is the effective pending reserve adjustment. Existing caps and stacking rules are unchanged. Dark red, blue and green backgrounds distinguish resource families.
- `scripts/ui/info_overlay.gd` uses compact rich text: a bold icon/title, production per turn and next-battle reserve calculation. Desktop tooltips contain plain text. The original battle HUD remains unchanged.
- Exploration menus and popups reserve 24 logical pixels at each edge. The redundant upper FTL meter is removed; charge and travel action appear only in the bottom control. PoIs place Legend beside Return in the compact header, and omit duplicated requirement explanations. Vertical scrolling remains available for additional approaches and long card lists.
- `scripts/ui/info_overlay.gd`: one reusable, dismissible modal for resource details and the Legend. It blocks underlying buttons, supports touch scrolling and Escape/Close. The Legend is available in ship selection, system, PoI and reward menus.
- Icons and explanations: `scripts/ui/encounter_presentation.gd`. The bundled font includes all mapped emoji; regenerate using `tools/subset_emoji_font.py` when adding symbols. Text-only fallbacks remain available.
- Enemy modifiers were already stored during generation. `CombatModifier.roll_encounter` preserves the original uniform 0–5 draw and RNG consumption. System tiles show the stored name; selecting an enemy opens an effects preview with Enter Combat / Return. Previewing consumes no rewards or modifiers. Event timing and in-battle rolls remain unchanged.
- Menu margins, tile padding and banner height are reduced; native vertical scrolling remains for genuinely overflowing choices. Tests cover 16:9, 21:9, 20:9 and small Android landscape dimensions.

`tests/status_bar_stress_test.gd` checks every authored PoI and the Trading Outpost at 1280×720, 1920×1080, 1680×720, 2400×1080 and 686×384. It covers all pending modifiers simultaneously, both net penalties and six-digit mixed bonuses/penalties, plus permanent production upgrades. There is no finite cap on accumulated bonuses; the flow layout wraps instead of clipping. Tests assert padded bounds, fully contained colored labels, seven combined indicators and no scrollbars for the authored four-approach menus. Extra-long custom content can still scroll.
