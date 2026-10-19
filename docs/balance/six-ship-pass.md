# Six-ship balance pass

The six selectable profiles live in `ships/player/`, registered in `scripts/ship_library.gd`.
The three original resource UIDs are preserved. New profiles use Endeavour's default model
fallback and Hull color; each resource's Model Scene remains independently assignable.
The existing selection scene shows three readable ship panels per page, with two pages.
Selecting a profile updates the preview, stats, deck and expedition index, including indices 3–5.
Only visible selection viewports update. No new combat scenes or per-ship scripts exist.

## Final statistics

| Attribute | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion |
|---|---|---|---|---|---|---|
| Hull | 35 | 28 | 38 | 35 | 35 | 35 |
| Shields | 12 | 17 | 6 | 12 | 12 | 12 |
| Materials | 10 | 8 | 20 | 10 | 12 | 10 |
| Energy | 10 | 14 | 20 | 10 | 10 | 12 |
| Crew | 10 | 10 | 20 | 12 | 10 | 10 |
| Synthesizer | 2 | 1 | 3 | 3 | 2 | 1 |
| Reactor | 2 | 3 | 2 | 1 | 3 | 2 |
| Quarters | 2 | 2 | 3 | 2 | 1 | 3 |
| EMP Pulse turns (`ftl_turns`) | 14 | 11 | 17 | 14 | 14 | 14 |
| Resistance | 0% | +25% | −10% | 0% | 0% | 0% |

Resistance still multiplies existing capped disruption probability by `1 - resistance`.
No damage, repair, plating, card-effect, draw-weight, AI or progression rules changed.
Player production does not scale with system difficulty; existing enemy scaling is unchanged.

## Pool composition

All pools contain exactly 25 distinct existing Tier 1 identities. Membership establishes
the specialization; no player family/effect draw multipliers were added. The normal 2/2/2
opening, Power Allocation, acquisition, upgrades and rarity rules remain unchanged.
Endeavour and Thunderbolt retain their existing pools. Full identity lists and the six-ship
membership matrix are in [cards.md](cards.md); ship summaries are in [ships.md](ships.md).

| Ship | Materials | Energy | Crew | Total |
|---|---|---|---|---|
| Endeavour | 9 | 9 | 7 | 25 |
| Thunderbolt | 4 | 13 | 8 | 25 |
| Titania | 11 | 5 | 9 | 25 |
| Ganymede | 12 | 6 | 7 | 25 |
| Callisto | 7 | 13 | 5 | 25 |
| Orion | 6 | 8 | 11 | 25 |

Every family offers at least two cards affordable from starting reserves alone, before
first-turn income. Titania's smaller Energy selection includes Energy Cell, Shield Recharge,
Reactor Upgrade, Laser Burst and Energy Surge. Ganymede contains all 12 Tier 1 Materials
identities; Orion contains all 11 Crew identities. Callisto combines all 13 Energy identities
with more structural support and less Crew reliance than Thunderbolt.

## Production gates

Only `minimum_production` changes on the nine approaches below. Authored outcomes,
chances, costs, PoI types and encounter weights remain unchanged. These are premium
boarding, fabrication, deeper-resource, protection or stabilization options. Their sibling
approaches retain production-3 access; Distress Signal retains two intermediate options.

| PoI | Approach | Production | Old | New |
|---|---|---|---|---|
| Derelict Starship | Deploy boarding teams | Quarters | 3 | 4 |
| Mining Operation | Deep-core mining | Synthesizer | 3 | 4 |
| Abandoned Research Station | Advanced fabrication | Synthesizer | 3 | 4 |
| Spatial Anomaly | Reinforce EMP Pulse systems | Quarters | 3 | 4 |
| Gas Giant | Deep atmospheric dive | Quarters | 3 | 4 |
| Pirate Debris Field | Board pirate flagship | Quarters | 3 | 4 |
| Quarantined Colony | Evacuate scientists | Quarters | 3 | 4 |
| Radiation Nebula | Shielded expedition | Reactor | 3 | 4 |
| Unstable Wormhole | Stabilize corridor | Reactor | 3 | 4 |

The other 11 production gates remain at 3: Engineering recovery, Industrial extraction,
High-energy analysis, Stabilize anomaly, Precision skimming, Disarm wreckage,
Recover research, Harvest particles, Reinforce transit probe, Specialist rescue and
Fabricate relief kits. No gate requires 5. All ten non-service PoIs retain two approaches
without production requirements. Existing safe Navigation Survey remains available where
low Hull makes the ordinary options unsafe. Eligibility uses permanent expedition
production, including station upgrades; combat-only production does not carry over.

## Corrected resource paths

Player preloads now use `res://ships/player/`; standalone enemy fallbacks and the default
boss use `res://ships/enemy/`. Updated old enemy loads in expedition, reward-feedback
and victory tests, and player links in the developer guide. ExpeditionRules already used
the relocated enemy paths and required no edits. Removed obsolete historical ship names
from the expedition edit reference. No files were moved and existing UIDs were retained.
`project.godot`, enemy resources, cards and battle scenes are unchanged.

## Deterministic diagnostic

Run `godot --headless --path . --script tests/six_ship_economy.gd`.
Ten fixed seeds against each of five authored enemy profiles: 50 matches per player,
300 total, maximum 40 rounds. Both sides use the existing AI; player pools and 2/2/2
openings are real. No modifiers, EMP escape, expedition upgrades/rewards, or human
strategy. Unfinished matches are unresolved. These are heuristic outcomes, not human
win-rate estimates. The shared older diagnostic now also uses the actual opening guarantee
in its updated/progressed modes; its historical baseline still uses unrestricted openings.

| Ship | Wins | Losses | Unresolved | Mean rounds |
|---|---|---|---|---|
| Endeavour | 26 | 21 | 3 | 19.9 |
| Thunderbolt | 2 | 46 | 2 | 18.2 |
| Titania | 11 | 34 | 5 | 18.4 |
| Ganymede | 8 | 38 | 4 | 20.2 |
| Callisto | 3 | 37 | 10 | 22.6 |
| Orion | 14 | 34 | 2 | 16.9 |

Endeavour performs strongest under this generic policy. Thunderbolt's fast escape advantage
is absent from the diagnostic, while both Energy-heavy profiles struggle with this AI.
Callisto has the most stalled games. Titania's large reserves do not dominate these samples.
No further balance changes were made in response; human/escape-inclusive playtesting is
needed before treating these differences as balance conclusions.

## Validation

`tests/six_ship_profiles_test.gd` covers exact statistics and pool membership, 600 seeded
2/2/2 openings, no extra family weights, production gate boundaries for every ship,
zero-Salvage/one-Hull completion safeguards, enemy/boss paths and both selection pages at
1280×720, 1680×720, 960×540, 800×450 and 686×384. It saves actual rendered screenshots
when run with a display. Other existing player-profile regressions now enumerate all six
ships, including acquisition/upgrades, allocation, battle initialization/continuation,
repairs, Outpost services and travel.

Desktop rendering is checked with Godot 4.7.2 Compatibility/OpenGL via software Mesa.
Physical Android appearance/performance and Mobile/Vulkan rendering are not verified.

Validation result: Godot import passed; all **44 regression scripts** passed after updating
the two outdated fixtures. The focused profile test passed **1,851 checks** headless and
rendered. Five rendered suites passed: six-ship profiles, UI/deck overhaul, Android-layout
geometry with synthetic input, Power Allocation and travel/battle integration.
All **81** relative developer-guide links resolve. No physical Android testing was performed.

## File manifest

### Added

- `docs/balance/six-ship-pass.md`
- `ships/player/callisto.tres`
- `ships/player/ganymede.tres`
- `ships/player/orion.tres`
- `tests/six_ship_economy.gd`
- `tests/six_ship_economy.gd.uid`
- `tests/six_ship_profiles_test.gd`
- `tests/six_ship_profiles_test.gd.uid`

### Modified

- `.github/workflows/tests.yml`
- `docs/DEVELOPER_GUIDE.md`
- `docs/android_ui.md`
- `docs/balance/cards.md`
- `docs/balance/pois.md`
- `docs/balance/ships.md`
- `docs/expeditions.md`
- `docs/hull-capacity.md`
- `docs/ui_layout.md`
- `encounters/derelict_starship.tres`
- `encounters/gas_giant.tres`
- `encounters/mining_operation.tres`
- `encounters/pirate_debris_field.tres`
- `encounters/quarantined_colony.tres`
- `encounters/radiation_nebula.tres`
- `encounters/research_station.tres`
- `encounters/spatial_anomaly.tres`
- `encounters/unstable_wormhole.tres`
- `scripts/battle_setup.gd`
- `scripts/expedition_progression.gd`
- `scripts/ship_library.gd`
- `ships/player/endeavour.tres`
- `ships/player/thunderbolt.tres`
- `ships/player/titania.tres`
- `tests/android_layout_test.gd`
- `tests/card_progression_simulation.gd`
- `tests/card_progression_test.gd`
- `tests/combat_modifier_test.gd`
- `tests/expedition_test.gd`
- `tests/field_repairs_test.gd`
- `tests/power_allocation_test.gd`
- `tests/reward_feedback_test.gd`
- `tests/ship_variants_test.gd`
- `tests/trading_outpost_test.gd`
- `tests/trading_outpost_ui_test.gd`
- `tests/travel_battle_test.gd`
- `tests/ui_overhaul_test.gd`
- `tests/victory_rewards_test.gd`
- `tools/generate_balance_docs.gd`

