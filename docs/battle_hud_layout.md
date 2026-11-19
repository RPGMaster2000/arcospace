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
| `scripts/ui/battle_side_panel.gd` and `scripts/ui/battle_hud.gd` | Tactical drawers and resource handles, action access and read-only battle summaries. |
| `scripts/ui/battle_modifier_panel.gd` | Formats live modifier status from the combat clock. |
| `scripts/modifier_display.gd` and `scenes/modifier_display.tscn` | Transient warning, impact and EMP presentation. |
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

Open the player drawer to read the current status and the explanation from
`CombatModifier.description(kind)`. The enemy drawer also shows shared effects
when applicable.

## Tuning

The menu exposes its width and inward offset. Its open panel clears the resource column.
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
2D fallback keeps a visible action log;
the 3D action log remains hidden as before.

## Follow-up visual adjustments

The left column now uses the content-edge margins (menu 16, resources 23 logical
pixels), without adding the display's horizontal safe-area inset a second time.
Vertical safe-area handling and right-column placement are unchanged. Allocation
is reduced to 52×48 with a 22-point icon and smaller internal padding; its existing
selection behavior is unchanged. Real Android cutout placement still needs a device
check. The 187-check headless layout suite passed after these changes; rendered
captures cover 16:9, 19.5:9 and 21:9.

EMP now sits six pixels below the player Hull bar, sharing its left edge at every
aspect ratio. Its charged action starts at the same position and stays above the
hand. Long offline labels clip with an ellipsis and retain their complete tooltip.
The menu button shares the resource icons' left margin (23 logical pixels).
Camera-relative EMP placement is removed; no EMP timing or escape rules changed.

## Header and resource spacing refinement

Power Allocation now uses a 64×38 button, matching the Crew icon width while
retaining the shorter height. Resource rows start at y=90 with 78 px spacing on
both sides. Salvage starts at y=44, 29 px below Turn; the right-aligned enemy
header mirrors those rows at the 23 px right margin (plus mobile safe inset).
The old 64 px enemy-header displacement is removed. Ship/model settings are unchanged.

## Expandable tactical HUD

The player and enemy resource columns now act as tactical panel handles. Tap the column or its chevron to slide the panel inward. Only one panel can be open at a time. The card hand and resource counters remain visible. The panel body scrolls on shorter displays.

The player panel places Resource Overdrive first in expedition battles and uses the existing payment menu and availability rules. It shows current-system pressure, known hostile forces and available turret support where applicable. Active boons have an empty state until a boon source is available. The enemy panel uses the current ship profile and any signature or enemy-exclusive cards, and shows charged-beam status when applicable.

Modifier descriptions and live countdowns are inside the panels. Temporary battlefield warnings and effects still appear at their existing cues. Accepted battle actions, turn transitions and cinematic starts retract the panels.

The battle layout regression exercises mouse and simulated touch input in 16:9, 19.5:9 and 21:9. Both GL Compatibility and Mobile Vulkan runs capture the drawers under
`.godot/testlogs`. The ten-battle progression regression checks Overdrive payment and dismissal through the relocated menu.
