# Battle HUD layout

The battle still uses `scenes/board.tscn`, inherited by `scenes/board_3d.tscn`.
The six cards, ship cameras/models, Hull/Shield controls and resource values keep
their existing sizing and behavior. No combat rules, modifier timers, card text,
allocation weights or expedition state were changed.

## Responsibilities

| File | Responsibility |
| --- | --- |
| `scripts/ui/battle_menu.gd` | Compact upper-left navigation; Settings, existing icon legend under Game Information, Close/outside-tap/Escape dismissal. Add future working utility entries using `_entry`. |
| `scripts/ui/settings_menu.gd` | Existing Settings, music toggle, Main Menu, Quit and pause ownership; reused unchanged. |
| `scripts/ui/battle_layout.gd` | Place navigation beside Turn/Salvage and allocation below Crew; convert supported mobile safe-area margins to logical HUD coordinates. Does not move ships/cards. |
| `scripts/ui/battle_modifier_panel.gd` | Bottom strip, compact live state and full-rule overlay. Reads `CombatModifier`; owns no clocks or combat state. |
| `scripts/modifier_display.gd` | Existing warning/impact/EMP presentation, forwarding HUD refresh/layout to the strip. |
| `scenes/modifier_display.tscn` | Existing strip converted to a tappable Button with a reusable panel script. |
| `scripts/ui/power_allocation_popup.gd` | Existing choices and selection behavior; four-column presentation in the viewscreen above the hand. |
| `scripts/board.gd`, `scripts/board_3d.gd` | Connect navigation and shared layout; remove the old ship-relative allocation placement. The legacy `settings_button` property now refers to Battle Menu, preserving existing callers. |

There is no separate implemented Expedition Status screen to link from this menu.
Game Information currently opens the existing icon legend, not a new tutorial.
Settings on ship selection and exploration keep their existing access buttons.

## Modifier presentation

Asteroids display the actual rounds until the next shower. Ion Storm and Solar
Flare distinguish waiting from active phases and show remaining full rounds only
when active. Ion text follows the already-announced doubled/halved factor. Nebula
shows the current hit probability (`100 - miss_rate`). Temporal Rift shows the
existing uncommon draw multiplier without a countdown. Deep Space explicitly
reports that there is no environmental modifier.

Tap the strip for `CombatModifier.description(kind)`, including probabilities,
durations, exclusions and rounding rules from the existing definitions. No second
modifier schedule is maintained by the UI.

## Tuning

Select `ModifierDisplay/Meter` in Godot's Inspector to edit maximum width, panel
height, font size and side padding. Text wraps to a second line in the reserved
48-pixel strip, six pixels above the existing hand. The menu exposes its width and inward offset; its open panel clears the resource column.
Resource icons/numbers, production badges, ship scale and card dimensions are
preserved. The allocation popup keeps its original choices, hints and controls;
a single horizontal row lets those controls clear the hand.

Mobile safe-area margins use `DisplayServer.get_display_safe_area()` and are
converted from device pixels to logical HUD units. Real cutouts still require a
device check; the desktop renderer cannot validate a specific phone's system bars.

## Validation

`tests/battle_layout_test.gd` exercises 1280×720 (16:9), 1560×720 (19.5:9) and
1680×720 (21:9), navigation, existing settings, outside dismissal, touch allocation,
all modifiers and their active/waiting states, countdown updates, full rules,
unchanged hands and unobstructed Hull/Shield/card geometry. It also checks a
simulated Android cutout conversion. Rendered runs capture
`.godot/testlogs/battle-layout-*.png` for inspection.

The existing Settings and Power Allocation regression tests now follow the new
navigation and below-resource placement. CI runs the new suite both headlessly
and with a rendering driver.

Validation with Godot 4.7.2: the dedicated layout suite passed 187 checks headlessly
and with OpenGL Compatibility rendering. Existing Settings (79 checks) and Power
Allocation (18,334 checks) passed; rendered versions were also exercised. Fifteen
focused headless scripts cover HUD, modifiers, effects, AI, FTL, encounter continuation
and expedition integration. The resource-counter animation test missed intermediate
frames in unrestricted runs on this shared runner and passed with `--fixed-fps 60`;
no production animation code was changed. Existing ObjectDB shutdown warnings remain.

Screenshots at all three requested aspect ratios were inspected. Actual Android
hardware, system-bar behavior and device cutouts remain unverified. The optional
2D fallback action log moves above the viewscreen strip to avoid sharing its space;
the 3D action log remains hidden as before.
