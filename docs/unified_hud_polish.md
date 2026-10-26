# Unified star-system HUD and focus polish

Built on published `main` at `bf49c7ca1747119853a0365cdd9fc9b624518056`, using Godot 4.7.2.

## Result

The existing resource buttons now stay mounted while moving between overview, normal PoI focus, combat previews and interceptions. The upper-left horizontal economy strip combines the system identifier, Salvage and production/inventory. Hull, Shields, EMP and the Hull progress bar live at the lower-left. FTL moves to the upper-right; utilities stay at the lower-right. Focus hides the FTL/utility parents and releases their keyboard focus, retaining both essential left panels. Back sits below the economy strip and is excluded from orbit input. Existing resource modals, repair eligibility, FTL eligibility and signals remain authoritative.

Normal PoI panels retain their existing approximately 40% width. The category subtitle stays hidden, the category-colored title grows to 30px, and option padding is reduced. Locked choices contain only the option name and the actual failed gate. Their compact requirement font fits one line; `LOCK` is used when the bundled emoji font lacks the lock glyph. Long unlocked PoI descriptions still scroll and confirmation behavior is unchanged.

The tactical panel has no secondary ship viewport. It uses the existing confrontation models, with larger names, side-by-side Hull/Shields bars, colored economy values, verified profile text, a colored modifier button and a mechanical summary derived from existing constants. Tapping the modifier opens its full rules. Signed entry effects and Chasedown responses use the existing resource symbols and positive/negative colors. Enter Combat remains pinned at the panel bottom. Short screens and pursuit layouts use denser spacing while retaining every amount and qualifier, including minimum Hull.

Only the vertical sign in the two existing mouse/touch orbit-input assignments changes. Horizontal motion, smoothing, inertia, limits, distance and framing remain intact. Overview and fixed tactical/pursuit cameras use their existing paths. Noninteractive planet-name labels are hidden alongside PoI markers during focus. Travel interruption and save state are unchanged.

## Screenshots

All images use seed 1042 and true logical viewport dimensions, rather than relying on the project's 1280px stretch baseline. Captured with Compatibility/OpenGL on Mesa llvmpipe. Baseline screenshots come from a separate checkout of the published base commit.

| View | 960×540 | 1280×720 | 1680×720 |
|---|---|---|---|
| Overview | [Before](unified_hud_screenshots/before-overview-960.webp) · [After](unified_hud_screenshots/after-overview-960.webp) | [Before](unified_hud_screenshots/before-overview-1280.webp) · [After](unified_hud_screenshots/after-overview-1280.webp) | [Before](unified_hud_screenshots/before-overview-1680.webp) · [After](unified_hud_screenshots/after-overview-1680.webp) |
| Normal PoI | [Before](unified_hud_screenshots/before-poi-960.webp) · [After](unified_hud_screenshots/after-poi-960.webp) | [Before](unified_hud_screenshots/before-poi-1280.webp) · [After](unified_hud_screenshots/after-poi-1280.webp) | [Before](unified_hud_screenshots/before-poi-1680.webp) · [After](unified_hud_screenshots/after-poi-1680.webp) |
| Combat preview | [Before](unified_hud_screenshots/before-combat-960.webp) · [After](unified_hud_screenshots/after-combat-960.webp) | [Before](unified_hud_screenshots/before-combat-1280.webp) · [After](unified_hud_screenshots/after-combat-1280.webp) | [Before](unified_hud_screenshots/before-combat-1680.webp) · [After](unified_hud_screenshots/after-combat-1680.webp) |
| Sublight Chasedown | [Before](unified_hud_screenshots/before-chasedown-960.webp) · [After](unified_hud_screenshots/after-chasedown-960.webp) | [Before](unified_hud_screenshots/before-chasedown-1280.webp) · [After](unified_hud_screenshots/after-chasedown-1280.webp) | [Before](unified_hud_screenshots/before-chasedown-1680.webp) · [After](unified_hud_screenshots/after-chasedown-1680.webp) |

## Verification

See [machine-readable results](unified_hud_results.json) for full-suite status, focused reruns and the rendered result. The new test checks 960×540, 1280×720, 1680×720 and a 1560×720 Android-like aspect ratio, all registered enemy profiles plus both larger elite hulls, all eight modifiers, stacked bonuses/penalties, mandatory-contact warnings, modifier disclosure, HUD identity/restoration, hidden exploration controls, label visibility, input signs, and unchanged gameplay RNG. Chasedown checks include fixed camera mode and shared ship heading. Existing regressions cover interception position after resolution, Continue, field repair, choice confirmation, cards and combat rules.

No physical Android device was tested. The existing two-ObjectDB shutdown warning also occurs in the baseline screenshot process; it is recorded rather than treated as a passing assertion. Genuine long PoI content intentionally remains scrollable. Very long locked rows use smaller typography to keep both name and actual gate on one line. Future custom profiles or unusually large accumulated modifier lists may need additional layout calibration.

## Files changed

- `scripts/expedition.gd`
- `scripts/presentation/star_system/star_map_3d.gd`
- `scripts/ui/encounter_tile.gd`
- `scripts/ui/expedition_screen.gd`
- `scripts/ui/expedition_text.gd`
- `scripts/ui/poi_header.gd`
- `scripts/ui/resource_bar.gd`
- `scripts/ui/star_system_hud.gd`
- `scripts/ui/tactical_briefing.gd`
- `tests/compact_poi_focus_test.gd`
- `tests/star_system_hud_intro_test.gd`
- `tests/star_system_polish_ui_test.gd`
- `tests/star_system_transition_test.gd`
- `tests/status_bar_test.gd`
- `tests/tactical_focus_test.gd`
- `tests/unified_hud_test.gd`
- `tools/capture_unified_hud.gd`
- `docs/unified_hud_polish.md`
- `docs/unified_hud_results.json`
- `docs/unified_hud_screenshots/ (24 WebP captures)`
