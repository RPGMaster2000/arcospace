# Ion, Metal and Psionic storm family

Starting main: `41bb441573f582681bded4ad8a706ae73aae2612` (Step 4 already merged),
Godot 4.7.2. No card assets, effect keys, scaler formulas, costs, upgrades, extra-action
rules, AI weights, music or expedition progression rules change.

| ID | Modifier | Affected family | Presentation |
| ---: | --- | --- | --- |
| 0 | None | — | Existing |
| 1 | Asteroid belt | — | Existing |
| 2 | Ion storm | Energy | Existing electric blue |
| 3 | Solar flare | — | Existing |
| 4 | Nebula | — | Existing |
| 5 | Temporal Rift | — | Existing |
| 6 | Metal storm | Materials | Amber/copper |
| 7 | Psionic storm | Crew | Violet |

Metal Storm is magnetized dust and microscopic metallic debris disrupting fabrication
and material processing. Concentrated particles amplify construction; turbulence
suppresses it. Psionic Storm is an exotic particle phenomenon disrupting neural
coordination, commands and crew communication, alternating extraordinary synchronization
with interference. Neither is a ship-triggered ability.

## One implementation

`CombatModifier.STORMS` is a small three-entry family/display mapping. All storms use
one activation branch, multiplier roll, expiration branch, `storm_applies`, `_scaled`,
`play`/shared `resolve_effects`, and `preview`. The historical public `ion_factor` remains
the ONLY stored multiplier for compatibility; it is now shared by all storms. No second
mutable multiplier, balance setting, registry, autoload or plugin framework exists.

At activation, the same existing RNG draw selects ×2 below 0.5, otherwise ×0.5. It stays
fixed for all three complete rounds and both ships. First event is round 1 + random
3..6; next event is 3..6 rounds after expiry. Active refreshes/cards/extra actions add
no storm-selection draws. Live card RNG still follows the original CardEffects path.

The `_scaled` function statements are unchanged: floor numeric amounts recursively,
exclude `pierce`, `shield_collapse_below`, `threshold`, `chance`, convert legacy sabotage
bool to its amount. Signed values retain floor behavior. Costs and play_again are outside
that dictionary transform. Inspection previews are detached copies with the existing
CardData description formatter and inspection_base metadata.

## UI and scene integration

Names/descriptions feed pre-battle details and Game Reference automatically. Metal and
Psionic status includes MATERIALS/CREW, AMPLIFIED/SUPPRESSED and the multiplier. HUD text,
existing card-outline styles, existing warning/surge and impact presentation use the
mapped colors. Ion strings and colors remain compatible, including its existing wording.
Storm tint is explicit per announcement, so unrelated alerts reset to their original color.
On expiry, the existing next-storm countdown and unscaled card presentation return.

Board reuses its existing Ion cinematic boundaries for every matching storm card,
regardless of acting ship. No new animation, particle, shader or expensive effect was
created. Metal and Psionic use inherited Ion battlefield scenes with amber and cold blue-violet
palettes and dedicated grading presets. They never enter the normal/planetary lottery. Old 0..5 arena/preset selection is unchanged. Existing encounter
icons reuse Materials/Crew icons; the developer grading selector lists all eight names.
The historical `ion_glow` / `set_ion_glow` contract stays, with an optional tint parameter.

## Step 4 forecasting and AI

Step 4 is preserved. `forecast_context()` additionally supplies `storm_family` and
`storm_factor` alongside existing `ion_factor`. Static `storm_applies` is shared by the
live transform and AI relevance filter. Forecasts continue delegating to shared modifier
execution and the authoritative effect resolver. The forecaster's executable body,
uncertainty enumeration, budget and RNG isolation are unchanged.

Legacy four-field Ion contexts remain valid through fallback to the mapping/ion_factor.
New storms require no independent AI scaling. The same two win/self-damage gates apply;
scoring, recovery, discard, thresholds, weights and decision RNG policy stay unchanged.
The Step 4 480-case compatibility/difference ledgers are not regenerated.

## Distribution, saves and historical traces

Generated encounters still call `rng.randi_range(0, NAMES.size()-1)` ONCE. With eight
entries, each is now **12.5%**, previously about 16.67% for six entries. Storms collectively
have 37.5%. Standalone next-encounter selection still excludes None and is uniform:
1/7 each (previously 1/5). There is no weighted compensation or extra selection draw.

Future expeditions from a given seed can intentionally differ from old runs because
of the changed distribution. This is NOT a claim of old encounter/reward trace identity
under the new pool. Saved records keep their existing numeric IDs and do not reroll.
Version-1 serialization and field names stay unchanged; validation's range now derives
from NAMES, accepting 6/7 while retaining old IDs. No migration or invalidation is needed.

The 1,044-checkpoint ownership fixture contains historical six-way draws. It remains
byte-identical. A small `_roll_battle_modifier()` delegation preserves one production
call and permits the test's State subclass to pin exactly `randi_range(0,5)`. All original
hash/reward/deck/save/RNG assertions remain intact. This is an explicit historical-rule
test, NOT the current distribution. The new test separately compares current eight-way
seeded generation through twelve systems and save/resume, and verifies each uniform roll
against one native 0..7 call and its RNG state. No expected fixture was regenerated.

## Files

Runtime changes: `scripts/combat_modifier.gd`, `scripts/enemy_ai.gd`,
`scripts/combat/combat_forecast.gd` (context comment only), `scripts/board.gd`,
`scripts/board_3d.gd`, `scripts/card_view.gd`, `scripts/modifier_display.gd`,
`scripts/ui/battle_hud.gd`, `scripts/ui/battle_modifier_panel.gd`,
`scripts/ui/encounter_presentation.gd`, `scripts/visual/battlefield_grading.gd`,
`scripts/tools/color_grading_preview.gd`, `scripts/persistence/expedition_save.gd`,
`scripts/expedition_state.gd` (one roll delegation).

Added tests: `storm_ion_parity_test.gd`, `storm_family_test.gd`,
`storm_presentation_test.gd`, their UIDs and `storm_ion_baseline.json` (captured before edits).
Adapted tests: `deck_determinism_test.gd` historical sampler;
`status_bar_test.gd` current eight-way roll bound; `encounter_continue_test.gd` appended-ID
eligibility. No unrelated assertions were weakened. Documentation: this report,
`DEVELOPER_GUIDE.md`, `card_effect_contract.md`, `refactoring/combat_forecast.md`,
`balance/battle_modifiers.md`. The existing `tools/generate_balance_docs.gd` also emits the
new storm rows/current pool size so regeneration preserves the feature. No files removed.

## Validation

Before modification, the captured Ion fixture and existing card/modifier/expedition
trace tests passed in the shared runner (import + four suites). The Ion capture records
32 seeds × 30 rounds, including activation, factor, expiry, scheduler/combat RNG state,
status text, meter and preview contents/wording.

Focused gate passed import + eleven suites. New mechanical coverage: **1,332 authored
card/upgrade/factor/storm cases**, **14,589 checks**, zero failures. It includes both
ships, both multipliers, each nonmatching/inactive family, exact numeric exclusions,
legacy bool sabotage, nested/random effects, upgrades, extra actions, actual forecast
outcomes, shared AI safety, immutable definitions, uniform calls, all eight saved IDs,
and new distribution determinism after resume. Presentation coverage: **184 checks** at
1280×720 and 960×540: names/family/factor, warning tint, unrelated-alert reset, matching
card glow/expiry, rules and explicit Ion-variant selection.

Commands from repository root:

```sh
godot --headless --path . --script tests/storm_ion_parity_test.gd
godot --headless --path . --script tests/storm_family_test.gd
godot --headless --path . --script tests/storm_presentation_test.gd
python tools/run_regressions.py --godot godot --timeout 360 --results test-results
```

## Initial feature size and limitations

| Lines including comments/blanks | Before | After |
| --- | ---: | ---: |
| CombatModifier | 264 | 285 |
| All 14 touched runtime/developer scripts | 4,354 | 4,390 |
| Three adapted existing tests | 335 | 340 |
| Three new tests | 0 | 259 |
| Balance-document generator | 478 | 482 |
| Combined affected code | 5,167 | 5,471 |

JSON, UIDs and documentation are excluded. Runtime grows by 36 lines; almost all new
code is focused regression coverage. 87 protected source/data/fixture files, including
all 74 card assets, CardEffectContract, CardEffects, tactical analysis, Deck/controller
ownership and prior baseline files, remain byte-identical. The scaler body is exact.

No new meshes, shaders or audio were added. Both storm scenes inherit Ion geometry,
camera and motion; local materials, lighting and grading supply their palettes. Device/export/performance limitations and final
shared/rendered verification results are recorded with completion below.

## Completion checks

Rendered Mobile/Vulkan on llvmpipe passed: storm presentation **184 checks** and battle
layout **208 checks**, both at 1280×720 and 960×540. Amber/violet status text and card
outlines were visually inspected. No shader/particle additions or Android-only APIs.
The ten Python regression-runner tests pass. Source/resource preload graph: 374 → 377
files, no cycles. Changed documentation links and `git diff --check` pass.

Existing card contract (74 definitions / 148 upgrades), 2,220 card-effect checkpoints,
72 old-modifier combat traces, Step 4's 480-case AI compatibility/difference ledgers and
the historical 1,044-checkpoint ownership trace were rerun without regenerating expected
fixtures. The new storm-family tests exercise forecasts and AI safety for all three
families. Historical and current-distribution tests are explicitly distinguished above.

Existing ObjectDB shutdown warnings remain separately recorded in scene tests; pure
storm mechanics and Ion trace tests exit without warnings. No physical Android/Windows
device playback/input/performance, APK export or device-specific rendering was tested.
Runtime uses only existing Godot Resources, shaders, arenas, UI styles and tweens.

Final shared run: **101 headless regression scripts + editor import passed**, zero failed
suites. All three new tests and all 98 existing suites ran through `tools/run_regressions.py`.
The balance-document generator also passes Godot `--check-only`; it was not run over
unrelated documentation. No established expected fixture was regenerated.

## Battlefield correction

The initial release incorrectly routed IDs 6/7 through the normal arena lottery. Both
now select explicit inherited Ion variants. Psionic is a cold blue-violet cloud/streak
field; Metal uses amber/copper dust colors. Separate scene-local materials/environments
and grade Resources preserve Ion and prevent cross-instance tint leakage. The regression
asserts exact scene paths, inherited camera/shader, absent planets and matching grade.

Correction files: `scenes/battlefield_metal_storm.tscn`,
`scenes/battlefield_psionic_storm.tscn`, their matching
`resources/color_grading/*_storm.tres` presets, the Board battlefield/grade arrays,
and strengthened `storm_presentation_test.gd`. Original Ion scene/preset are unchanged.
Editor import and four focused suites passed (storm presentation, environment isolation,
color grading and seeded Ion parity). Mobile/Vulkan rendered storm presentation passed
200 checks at both landscape sizes; both palette variants were visually inspected.
The full suite was not repeated for this scene-only correction; physical device testing
remains unperformed.
