# Targeted production sabotage

Six Inspector-editable CardData resources (`cards/69_*.tres` through `74_*.tres`) extend the shared library to **74 identities: 52 Tier 1 and 22 Tier 2**. All six use **Offense** allocation. No existing card definition or ship statistic changes.

## Definitions

Every level keeps its original cost, family, tier and production reduction. Upgrades replace the complete effect dictionary, including the same targeted reduction.

| Card | Cost / tier | Target, all levels | Base secondary | Upgrade I secondary | Upgrade II secondary |
|---|---|---|---|---|---|
| Industrial Interference | 9 Materials / 1 | Enemy Synthesizer −1 | None | Gain 3 Materials | Gain 6 Materials |
| Fabrication Strike | 17 Materials / 2 | Enemy Synthesizer −2 | Deal 3 damage | Deal 5 damage | Deal 7 damage; gain 3 Shields |
| Reactor Interference | 9 Energy / 1 | Enemy Reactor −1 | None | Gain 3 Energy | Gain 6 Energy |
| Core Destabilization | 17 Energy / 2 | Enemy Reactor −2 | Drain 4 Energy | Drain 6 Energy | Drain 8 Energy; gain 3 Shields |
| Personnel Disruption | 9 Crew / 1 | Enemy Quarters −1 | None | Gain 3 Crew | Gain 6 Crew |
| Command Infiltration | 17 Crew / 2 | Enemy Quarters −2 | Steal 4 Crew | Steal 6 Crew | Steal 8 Crew; gain 3 Shields |

Production floors at zero. Drain and steal are limited by the target's available reserve. Fabrication Strike uses ordinary Shield-first damage and overflow, including the existing shield-shatter damage coordinator. Existing Ion Storm scaling and Nebula misses still apply; the table gives unmodified authored effects.

## Starting pools

The original 25 identities remain in their original order; three new references are appended to each ship Resource. Each new identity occurs in exactly three player pools.

| Ship | Materials | Energy | Crew |
|---|---|---|---|
| Endeavour | Industrial Interference | Reactor Interference | Personnel Disruption |
| Thunderbolt | Industrial Interference | Core Destabilization | Command Infiltration |
| Titania | Fabrication Strike | Reactor Interference | Personnel Disruption |
| Ganymede | Fabrication Strike | Core Destabilization | Personnel Disruption |
| Callisto | Industrial Interference | Core Destabilization | Command Infiltration |
| Orion | Fabrication Strike | Reactor Interference | Command Infiltration |

Each pool now has **28 identities**. Default capacity in `scripts/expedition/expedition_rules.gd` and `encounters/expedition_rules.tres` is **36**, leaving eight acquisitions. Hand size remains six, opening hands remain two of each family, duplicate limit remains two, and Tier 2 remains locked through round 2 with at most one Tier 2 in hand. Its 15% draw probability and acquired-card weight ×3 are unchanged.

## Integration and ownership

- `scripts/cards/card_library.gd`: appends six resources; existing indices and identities remain stable. Enemy fallback pools automatically include all 74 base cards.
- `ships/player/*.tres`: assigns the specified three cards per ship; all numeric and visual properties remain unchanged.
- Existing `CardEffects.enemy_production`, damage, drain, steal, reserve gain and Shield effects resolve all levels. No new effect parser or combat formula is needed.
- Existing Board/SystemsFailure coordination observes zero production and handles recovery/countdowns. No duplicate countdown state is introduced.
- Existing AI simulates these effects, values newly offline systems, and includes damage, drain, stolen resources and Shields in tactical scores. Affordability, recovery priorities, Hull-win precedence and tactical variation remain intact; no AI algorithm change is needed.
- Existing acquisition, upgrades, replacement, Deck Viewer, gallery filters, card descriptions and procedural art consume CardData directly. Full upgrade comparisons name the targeted system; compact portraits retain the existing automatic shorthand rules.
- `tools/generate_balance_docs.gd`, `docs/balance/cards.md`, `docs/balance/ships.md` and `docs/expeditions.md`: update catalogue, pool and capacity references.
- `tests/targeted_sabotage_test.gd`: dedicated specification/integration/UI coverage. Existing expansion, progression, inspection, replacement, roster, ship-profile and station test fixtures now reflect 28/36/74 counts and starting Tier 2 ownership.

## Validation

Godot 4.7.2 editor import and **all 61 headless regression scripts pass**, after updating obsolete registry, pool-size and reward-ownership fixtures. This includes combat, Systems Failure, AI, rarity/drop rates, allocation, expedition progression, rewards, acquisition, upgrades, replacement and UI regressions. Existing ObjectDB shutdown warnings remain in some suites; no script errors or failed checks remain. The unrelated `enemy_models_visual_test.gd` render-only diagnostic was not run. The dedicated suite runs **6,034 checks**, including all 18 authored levels, zero/near-zero production, empty/limited reserves, isolated target selection, ordinary damage spillover, Systems Failure activation, exact distribution, opening restrictions, allocation/acquired weights, AI affordability/preview safety, acquisition/upgrades, gallery filters and upgrade presentation.

Rendered Compatibility/software OpenGL validation also passes all 6,034 checks at **1280×720, 1560×720 and 1680×720** (16:9, 19.5:9 and 21:9). Screenshots are generated under `.godot/testlogs/sabotage-*.png` by the same test. Physical Android and the Mobile renderer require separate device validation.

## Balance to evaluate

Every ship can now attack all three production systems. Starting access differs intentionally: Endeavour receives three Tier 1 additions; other profiles receive one or two Tier 2 additions that unlock in round 3. Existing starting production of 1 can be disabled by a single Tier 1 hit. Frequent targeted sabotage, Offense weighting and upgraded secondary economy may accelerate Systems Failure; human playtesting should assess recovery access and battle length before changing any existing card or ship values.
