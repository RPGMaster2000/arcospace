# Extreme Starfront weather

New Unstable, Storm-dominated and Chaotic Starfront Defense sectors use stronger weather from System 3 onward. The archetype rolls, celestial geometry and military formation probabilities from PR #125 still apply. System 1, Warzone and existing active sectors retain their existing weather.

## Tuning

| Environment | Storms | Planned physical storm coverage | Live rift limit | Rift evaluation rate | Spawn chance at eligible evaluation | Rift lifetime / radius |
|---|---:|---:|---:|---:|---:|---:|
| Conventional | Typically 0–1 | Existing | 1 | 1× | 12% | 15 s / 2.35 |
| Unstable | 2–4 | 16–29% | 3 | 3× | 78% | 24 s / 3.30 |
| Storm-dominated | 5–9 | 43–62% | 2 | 1.5× | 58% | 18 s / 2.55 |
| Chaotic | 3–7 | 33–52% | 4 | 4× | 88% | 26 s / 2.95 |

Rift frequency controls evaluations on the existing strategic clock. The spawn chances are higher than baseline because shortening the interval alone would still leave the default 12% roll and 15-second lifespan with fewer than one live rift on average. A full rift budget or the absence of a legal moving route can still prevent a spawn. Setting either hazard chance explicitly to zero disables that hazard. The per-system weather budget, actual fronts, active rifts and scheduler are recorded in the save.

Storm fronts use independently seeded large and satellite ellipses. A greedy placer scores additional area on a fixed grid, favors useful contact with hostile lanes, and keeps each ellipse inside the existing map bounds. Fronts can overlap each other, solar influence, the player's position, Homeworld and interception or preparation routes. These regions apply effects only in card battles. Ships pay their ordinary travel costs and Homeworld takes its existing arrival damage. Rifts still avoid stellar cores, planets, installation markers and each other's centers.

Chaotic sectors also always receive a strong physical solar influence zone. Its desired radius is 29–37% of map width, capped by Homeworld clearance. Gas-giant orbits may cross the influence boundary. Unstable sectors produce the largest rifts. Storm-dominated sectors get the highest storm coverage and the widest mix of major and satellite systems.

## Battle overlap

An explicit legacy modifier retains its precedence. Extreme-weather battles can apply one timed modifier and one passive Temporal Rift draw boost. Solar beats asteroid fields, which beat storms. When storms overlap, the strongest saved intensity wins, with stable ID as the tiebreaker. Matching storms cannot multiply card effects more than the existing ×2. One or more overlapping rifts apply the existing ×2 Tier 2 draw boost once to both hands. The established eligibility rounds, hand limits, card execution, forecast and damage rules still apply. The selected timed hazard and the contributing rift are frozen at battle entry, including on resume.

Each front renders with one animated cloud sheet with shader lightning and one exact boundary. Legacy storms retain their existing three sheets. The map reuses rift visuals by instance ID and removes expired visuals independently. Weather adds no strategic per-frame work and does not depend on the renderer or quality settings.

## Procedural comparison

Both versions used the same 540 seeds across Systems 3–5. Coverage uses 1,296 cell centers per generated map and the actual rotated ellipsoid footprints. Overlap is map area covered by at least two storms. Affected approach share measures the straight player route toward each opening interception, using the swept intercept target and existing strategic speeds.

| Archetype | Sectors | Storms, old → new | Coverage, old → new | New overlap | Affected approaches, old → new | Sectors with concurrent rifts in first 22 s |
|---|---:|---:|---:|---:|---:|---:|
| Conventional | 109 | 0.29 → 0.29 | 0.83% → 0.83% | 0.00% | 10% → 10% | 0% |
| Scattered | 75 | 0.27 → 0.27 | 0.51% → 0.51% | 0.00% | 10% → 10% | 0% |
| Crowded | 82 | 0.27 → 0.27 | 0.87% → 0.87% | 0.00% | 11% → 11% | 0% |
| Asymmetric | 50 | 0.34 → 0.34 | 1.61% → 1.61% | 0.00% | 15% → 15% | 0% |
| Unstable | 67 | 0.46 → 2.99 | 2.30% → 23.27% | 3.57% | 20% → 92% | 100% |
| Storm-dominated | 70 | 1.81 → 6.90 | 14.00% → 52.09% | 10.03% | 55% → 99% | 36% |
| Chaotic | 87 | 0.57 → 4.95 | 3.28% → 43.92% | 7.78% | 22% → 99% | 100% |

All requested fronts were placed in the default sample. The four legacy geometry fallbacks already occurred in PR #125. Fleet snapshots and the unrelated expedition RNG agreed between the two builds, preserving validated opening interception windows. Mean peak simultaneous rifts in the 22-second window were 2.87 in Unstable, 1.19 in Storm-dominated and 3.95 in Chaotic. PR #125 could generate only one at a time. Chaotic solar influence appeared in every new sample, versus 28% before.

Use Developer Testing at **System 5, seed 214**, with **Pincer**, **Standard** and **Middle Orbit**. Select Conventional, Unstable, Storm-dominated or Chaotic and advance 17 strategic seconds to see the same weather activity as the rendered comparison. The capture test writes WebP images under `.godot/testlogs/extreme-weather`.

## Strategic and combat balance

The eight existing strategic policies ran 54 paired sectors each with real travel, environmental scheduling and interception. Both versions produced the same completion rates, Homeworld damage and strategic time. The seven focused strategies cleared every sector. Long detours cleared 50 of 54 and incurred 3,020 aggregate damage in both versions.

| Policy | Hazardous battles, PR #125 → new | New overlapping timed hazard and rift |
|---|---:|---:|
| Nearest contact | 42 → 112 | 12 |
| Most dangerous | 43 → 110 | 15 |
| Nearby preparation | 52 → 129 | 17 |
| Economic preparation | 47 → 129 | 15 |
| Turret-oriented | 42 → 112 | 12 |
| Tactical decoys | 43 → 111 | 17 |
| Early mothership | 42 → 112 | 12 |
| Long detours | 18 → 64 | 13 |

Nearest-contact defense averaged 49.47 strategic seconds to completion and took no Homeworld damage in this audit. It reached 327 battles, with hazard exposure rising from 13% to 34%. The strategic audit assumes victory in each reached card battle, so its completion rates isolate map feasibility. Actual difficulty in a fight with simultaneous solar and temporal effects still needs human playtesting. The focused board test verifies simultaneous modifiers, and the full combat suite protects established execution and rarity limits.
