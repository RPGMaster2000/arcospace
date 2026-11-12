# Star-system expansion

New systems use the expedition rules' `system_expansion` setting, which
defaults to 1.20. Starfront Defense applies it to the 22-unit homeworld
and fleet deployment radii, the player start and the existing PoI radial
slots. The homeworld and fleet deploy at 26.4 units with default tuning.
The 7, 10, 13, 16 and 19 unit slot radii become 8.4, 12, 15.6, 19.2 and
22.8 units before any orbital adjustments. Exploration multiplies planet
semimajor axes and destination placement ranges by the same factor.

Existing planet and ship models retain their dimensions. Planetary PoIs
use distinct orbital rings. Exploration keeps its existing planet
assignments and gives unassigned planetary models their own circular
paths clear of existing orbits. Defense picks distinct radial slots for
its planetary destinations and adds small seeded angular and radial
variations. Its decorative planets are placed using the initial deployment,
so enemy movement and save/load leave the scenery in place.

At default tuning the navigable square grows from ±28 to ±33.6 units per
axis. Reinforcements, construction sites, asteroid pockets, storm centers
and rift positions use the available space. Asteroid thickness and storm,
rift and turret coverage sizes keep their existing tuning. Rifts use the
actual decorative planet positions for clearance in expanded systems.
The map adjusts its overview zoom and pan limits while retaining the same
maximum close-up zoom and input controls.

## Strategic pacing

Measured across six seeded Starfront Defense systems using default speeds.
The PoI value averages all direct destination pairs within each system.
The approach values assume uninterrupted movement.

| Measurement | Previous | Expanded |
|---|---:|---:|
| Mean direct PoI leg | 2.93 s | 3.54 s |
| Opening attacker to homeworld | 35.53 s | 42.64 s |
| Advancing mothership to homeworld | 53.96 s | 64.75 s |

Player, attacker and mothership speeds, pressure accumulation and
reinforcement timing retain their tuning. Each of the six test systems can
be completed by legal interceptions with homeworld integrity remaining.
Exploration uses its existing travel animation with the nominal duration
scaled by the layout factor.

## Stellar color and Solar Interference

The dedicated stellar appearance stream uses 45% yellow or warm white,
30% orange or amber, 12% blue or cyan, 8% red and 5% unusual colors. The
star, local light, dust scattering and lens effects use the selected
palette. Encounter and reward RNG streams are independent.

The new Solar Interference radius is 80% of the old sample, with a minimum
clearance from the stellar surface. The default range changes from 8–13
to 6.4–10.4 units. Its existing material renders both the boundary and a
faint orange fill that fades to zero at the edge. The boundary follows the
saved physical radius and battle entry still freezes the selected effect.

Saves without a layout factor keep their original layout, color and
environment geometry. A jump generates the next system with the current
tuning. The save records the current layout factor so future tuning
changes leave the active system intact.

## Matched captures

The two Starfront Defense layouts use the same seed and storm roll. The
Solar Interference close-up uses the same camera transform. The three
stellar examples are from exploration.

| View | Before | Expanded |
|---|---|---|
| Overview and orbital distribution | [Before](star_system_expansion/before-overview-mobile.png) | [Expanded](star_system_expansion/expanded-overview-mobile.png) |
| Normal gameplay zoom | [Before](star_system_expansion/before-normal-mobile.png) | [Expanded](star_system_expansion/expanded-normal-mobile.png) |
| Approaching enemies, asteroids, storm and turret | [Before](star_system_expansion/before-approach-mobile.png) | [Expanded](star_system_expansion/expanded-approach-mobile.png) |
| Solar Interference | [Before](star_system_expansion/before-solar-mobile.png) | [Expanded](star_system_expansion/expanded-solar-mobile.png) |

[Yellow](star_system_expansion/star-yellow-mobile.png), [orange](star_system_expansion/star-orange-mobile.png)
and [unusual](star_system_expansion/star-unusual-mobile.png) star examples.
[GL Compatibility captures](star_system_expansion/) are in the same folder.
Android gesture behavior is covered by the rendered regression suite.
Physical Android frame times were not measured.
