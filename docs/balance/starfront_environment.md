# Later Starfront geography

## Environmental profiles

The following weights apply before excluding the previous committed archetype. The unusual bucket is split evenly across scattered, crowded and asymmetric. The extreme bucket is split between unstable and storm-dominated. The cap applies from System 5. System 1 uses the original generator.

| System | Conventional | Unusual | Extreme | Chaotic | Companion star |
|---|---:|---:|---:|---:|---:|
| 1 | 50% | 30% | 15% | 5% | 12% |
| 3 | 30% | 40% | 20% | 10% | 18% |
| 4 | 20% | 40% | 25% | 15% | 22% |
| 5+ | 10% | 35% | 35% | 20% | 25% |

Compact, standard and expansive scales are 0.85–0.95, 0.95–1.10 and 1.10–1.25 times the configured expansion. Actual map scale is capped by the combination of the configured range and the selected factor, giving effective bounds of 0.85–1.875. At the default expansion of 1.20 that means a map width of 57.12–84.00 units. The homeworld radius is 22 units times actual map scale and a region factor. Inner uses 0.70–0.85, Middle uses 0.85–1.05 and Outer uses 1.05–1.20. The player's starting point remains at 78% of the homeworld vector.

| Archetype | Sparse / common / dense | Main geographic preference |
|---|---:|---|
| Conventional | 15 / 70 / 15 | Standard scale and dispersed infrastructure |
| Scattered | 45 / 45 / 10 | Expansive maps, outer installations and outer orbits |
| Crowded | 5 / 35 / 60 | Compact maps, two infrastructure clusters and tightly spaced orbits |
| Asymmetric | 25 / 50 / 25 | Strongly directional infrastructure and aligned homeward support |
| Unstable | 25 / 55 / 20 | Research and anomalies, uneven infrastructure and earlier rifts |
| Storm-dominated | 30 / 50 / 20 | Up to two separated storms along selected routes |
| Chaotic | 35 / 30 / 35 | Mixed scales, uneven orbital gaps and irregular clusters |

Sparse means 3–4 PoIs, common 5–9 and dense 10–12. The Trading Outpost uses its own slot. Planetary PoIs vary from 0.85–1.20 of their existing full-size placement radii. The renderer builds them as their associated types. Every orbital ring clears the stellar envelope, other planets and Homeworld over the whole circle. Compact layouts fit eligible orbital partitions before assigning randomized gaps.

Five stellar classes span 0.75–1.35 of the base radius, with matching color, corona and lighting. Companions are cosmetic. They share the central exclusion envelope and have a separation of 3.25–4.60 world units. The primary star remains the existing source of solar influence and illumination. Unstable layouts schedule the first rift evaluation at 78% of the configured delay. Chaotic layouts use 90%. Storm-dominated sectors attempt two storms with horizontal semiaxes of 9–15 units. Existing combat effects and strategic-time rules govern exposure.

## Fair placement and debugging

The generator checks the real homeworld arrival times, the 0.8-second arrival gap and two sequential swept interceptions with the normal battle time between them. The original minimum arrival default is 20 seconds. It also leaves a nearby preparation route and an opening interception outside all permanent hazards. Capped attempts first vary geometry in the selected archetype, then try another eligible military scenario, and finally use the prior environmental generator as a safe fallback. No military composition or difficulty values were changed.

Developer Testing exposes environment, size, home region, stellar configuration and seed under **Environment & Seed**. Use System 5, seed **214**, automatic formation and select the desired archetype. Use **Asymmetric**, **Expansive** and **Binary** to reproduce the binary comparison. The log reports the committed formation and environment and explains when the generator uses its legacy fallback.

The geography test compares 360 seeds each at Systems 3, 4 and 5 with the Phase 3 generator. Run `starfront_environment_geometry_test.gd` for distributions and fairness checks. The paired policy study uses `defense_warfare_strategies.gd` with and without `-- --legacy-geography`. Its map simulation uses real movement, interceptions and PoI resolution, and assumes each reached card battle ends in victory. This isolates the effects of travel and placement. The rendered comparison script accepts `--capture-all` after the renderer argument and writes Godot screenshots under `.godot/testlogs/later-starfront`.

History stores only the last committed archetype. Current Defense saves already carry it in the environmental profile, while other campaign modes carry the prior value separately. Historical sectors keep their committed geometry. Navigable planets use saved positions, sizes and types. Decorative planets are still reconstructed by the existing seeded visual layer. Companion stars have no separate illumination or combat modifier.

## Measured geometry

The paired sweep used 1,080 sectors per version, with 360 seeds at each stage. The table reports per-sector means from the new generator. Directional concentration is the length of the mean unit direction from the star to each destination. A value near one means destinations largely share a bearing.

| Archetype | Width | Homeworld radius | PoIs | Mean PoI separation, previous → new | Directional concentration | Storm coverage |
|---|---:|---:|---:|---:|---:|---:|
| Conventional | 68.93 | 25.82 | 7.38 | 27.31 → 28.19 | 0.31 | 0.76% |
| Scattered | 75.31 | 30.29 | 5.82 | 28.79 → 38.30 | 0.36 | 0.71% |
| Crowded | 65.12 | 22.37 | 9.56 | 21.31 → 18.94 | 0.69 | 0.88% |
| Asymmetric | 68.58 | 25.50 | 7.16 | 20.76 → 17.01 | 0.85 | 1.54% |
| Unstable | 71.04 | 26.63 | 6.92 | 27.62 → 27.46 | 0.32 | 1.91% |
| Storm-dominated | 72.14 | 27.38 | 6.62 | 27.52 → 30.66 | 0.32 | 13.76% |
| Chaotic | 70.18 | 25.94 | 7.48 | 30.76 → 31.37 | 0.35 | 3.84% |

Previously all sampled maps were 67.20 units wide and the homeworld was 26.40 units from the star. Compact maps now average 60.57 units across, expansive maps 78.85. Their respective average starting travel distances to destinations are 18.17 and 27.69 units. Average planetary orbit separation is 4.34 and 6.47 units. Scattered sectors average 2.13 planetary destinations and crowded ones average 3.69.

Eight sectors used legacy geometry and 34 needed an alternative military placement. Compact sectors accounted for 29 of the alternatives. Every current geometry passed sequential interception and preparation checks. Storm-dominated sectors averaged 1.84 storms against 1.38 previously. Coverage still dropped from 15.23% to 13.76% as the new placement retained clean approach routes. Coverage here is the fraction of a 9 × 9 uniform grid inside a physical storm.

## Strategic policies

The audit ran 54 paired sectors per policy across Systems 3–5 and all six ships. Travel and PoI costs were authoritative. Card battle outcomes were optimistic and the study did not estimate combat difficulty or rewards from defeating enemies.

| Policy | Clearances, previous → new | Total Homeworld damage, previous → new | Mean clear time, previous → new |
|---|---:|---:|---:|
| Nearest contact | 54 → 54 | 0 → 0 | 49.54 s → 49.46 s |
| Most dangerous | 54 → 54 | 0 → 0 | 49.57 s → 49.40 s |
| Nearby preparation | 54 → 54 | 20 → 20 | 53.07 s → 55.25 s |
| Economic preparation | 54 → 54 | 100 → 40 | 50.83 s → 51.38 s |
| Turret defense | 54 → 54 | 0 → 0 | 49.54 s → 49.46 s |
| Tactical decoys | 54 → 54 | 0 → 0 | 49.54 s → 49.37 s |
| Early mothership | 54 → 54 | 0 → 0 | 49.54 s → 49.46 s |
| Long detours | 49 → 50 | 3,610 → 3,020 | 53.50 s → 53.20 s |

Nearest-contact mothership reveal moved from 42.37 to 41.55 strategic seconds and hazardous battles fell from 45 to 40. Both preparation policies used 54 PoIs. Nearby preparation paid 339 Salvage, down from 383. Economic preparation paid 20, down from 42. These particular approaches granted no permanent production. This study samples one preparation per sector, so it does not establish the economy for a player who exhausts a dense map. PoI rewards were left at their existing values.

At the default tuning, the validated legacy fallback was below 1% of generated sectors. A stress test combined the minimum configured expansion with forced crowded, compact, inner-habitable binary layouts. Thirty of 32 such combinations used legacy geometry. At maximum expansion, all 32 forced expansive cases committed a new layout, with effective scales between 1.660 and 1.874.
