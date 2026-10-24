# Card effect contract and validation

Step 3 baseline: `30a7a9bdc308f9919316d8c3c6e3e1c53f23d7d5`, Godot 4.7.2.
No card assets, wording, balance, execution order, AI decisions, visual/audio settings,
expedition ownership or save format change in this pass.

## Ownership audit

| Responsibility | Before | After |
| --- | --- | --- |
| Editable definitions, identity and upgrade copies | CardData / cards/*.tres | Unchanged |
| Registered definitions | CardLibrary.CARDS | Unchanged; no second card registry |
| Valid effect shapes and authoring diagnostics | Implicit assumptions spread across consumers | CardEffectContract, development-only RefCounted static helper |
| Resource and production identifiers | ShipCombatState | Unchanged; shared attribute list also lives here |
| Payment, ordered mutations, RNG, condition evaluation, damage report | CardEffects / CombatExecution | Unchanged |
| Modifier timing, scaling and misses | CombatModifier | Unchanged |
| Descriptions / upgrade comparison | CardData / CardEffectText / CardInspection | Unchanged |
| Possible HUD categories | CardTargets; TacticalPreview displays them | Unchanged, read-only |
| Forecast policy, scoring, priorities, ties | EnemyAI / SystemsFailureTactics | Unchanged |
| Soft draw categories | CardPreferences / CardHand | Unchanged |
| Persistent cards and rewards / exploration lifecycle | ExpeditionDeck / ExpeditionState / Expedition | Unchanged |

`combat/combat_session.gd` does not exist at this revision. CombatExecution is the shared
execution boundary; ShipCombatState owns ship values. The validator depends only on
CardData and ShipCombatState, not scenes, UI, AI, State, Deck or live Board nodes.
No runtime caller invokes validation. Dictionaries and Resources remain the data format.

## Supported vocabulary: 27 keys

Numbers mean finite int or float, excluding bool (except legacy sabotage). The resolver
converts amounts with `int()` at its existing sites; validation never rounds or normalizes.
Signed amounts remain accepted: this is a shape contract, not a new balance policy.
No arbitrary amount cap or nonnegative-amount restriction is introduced.

| Key | Value / exact meaning |
| --- | --- |
| hull | Number: add to own Hull; later damage path clamps to zero; no capacity clamp here |
| shields | Number: add to own Shields, then clamp at zero |
| materials, energy, crew | Number: add own reserve, then clamp at zero |
| synthesizer, reactor, quarters | Number: add own production, then clamp at zero |
| damage | Number: regular attack; Shields absorb nonpiercing part, Hull clamps at zero |
| pierce | Number in [0,1]: floor(damage × fraction) bypasses Shields; inert without damage in the same dictionary |
| break_shields | Number: remove enemy Shields before damage, minimum zero |
| shield_collapse_below | Number: clear enemy Shields only if strictly below threshold |
| shield_collapse | Dictionary: clear enemy Shields; at/above threshold, chance of Shield-first self_damage |
| self_damage | Number: own direct Hull loss, negative input treated as zero |
| self_damage_regular | Number: own Shield-first damage, negative input treated as zero; collapse backlash adds to it |
| drain | Dictionary of reserve → number: subtract enemy resources, minimum zero, before theft |
| steal | Dictionary of reserve → number: transfer up to enemy's post-drain reserve |
| enemy_production | Dictionary of production → signed number: adjust enemy production, minimum zero |
| production_other | Dictionary: own production and matching reserve change only when that reserve differs from card family |
| swap_resource | Reserve name: exchange post-payment reserves, unless it is the card's cost family (then no-op) |
| swap_shields | Bool: exchange both active Shield values |
| sabotage | Number or legacy bool: reduce every enemy production, minimum zero; true converts to 1 |
| random_sabotage | Number: if positive, reduce one randomly selected enemy production, minimum zero |
| random_gain | Number: choose one of all three own reserves, add amount |
| random_gain_other | Number: choose one of two non-cost reserves, add amount |
| random_gain_range_other | Dictionary: choose non-cost reserve first, then inclusive random amount |
| conditional | Dictionary: evaluate after this dictionary's ordinary effects, then recursively apply selected branch without another payment |

Resource names: `materials`, `energy`, `crew`. Corresponding production names, in the
same order: `synthesizer`, `reactor`, `quarters`. Direct attributes are Hull, Shields,
these resources and these production fields. Predicate lookup additionally accepts
`hull_capacity`, which is read-only in this vocabulary.

### Nested dictionaries

Unknown fields are errors at every validated nesting level. Empty reserve/production
maps and empty/default conditionals remain valid no-ops. Branches may nest without an
arbitrary depth limit; cyclic ancestor references are rejected. Shared acyclic branches
are valid. No condition is evaluated during validation.

| Structure | Fields |
| --- | --- |
| drain / steal | Any subset of resource names, numeric values |
| enemy_production | Any subset of production names, numeric values |
| production_other | Required `type` (production name), `production` (number), `resource` (number) |
| random_gain_range_other | Required numeric `min`, `max`; int(max) ≥ int(min), matching runtime conversion |
| shield_collapse | Required numeric `threshold`, `self_damage`, and `chance` in [0,1] |
| conditional | Optional `target`, `attribute`, `comparison`, `threshold`, `compare_target`, `compare_attribute`, `fraction_of`, `then`, `else` |

Conditional defaults: target `self`, attribute `hull`, comparison `at_most`, threshold 0,
branches `{}`. Targets are exactly `self` or `enemy`. Comparisons are `below` (<),
`at_most` (≤), `equal` (=), `at_least` (≥), `above` (>). Attributes must be known ship
fields. `compare_target` requires `compare_attribute` (otherwise ignored by runtime).
A `compare_attribute` uses the other live field, default compare_target self, and takes
precedence over fraction_of and threshold. A `fraction_of` requires an explicit numeric
threshold because descriptions read it directly: threshold multiplies the subject's
specified capacity/stat. This multiplier is not a probability: values outside [0,1]
remain valid (e.g. comparison to twice capacity). Chance and pierce ARE bounded fractions.

Required collapse/range/production_other fields reflect the description and inspection
consumers as well as execution: the resolver has defaults, but those consumers index
these fields directly. Validation does not supply defaults or alter assets.

### Card-level checks

CardData's exported types already enforce int cost/tier/upgrade counters, bool play_again,
Dictionary effects and Array[Dictionary] upgrades. Validation checks nonempty title and
identity, unique registered identities, tier 1..3, family, allocation category
`offense|defense|systems`, nonnegative cost, max_upgrades 0..2 with enough definitions,
no third upgrade definition, and upgrade_level 0..max_upgrades. Extra authored definitions
may remain while max_upgrades disables access to them; all definitions are still checked.
`with_upgrade()` must return each allowed level with the same identity. It replaces the
complete effects dictionary, never adds amounts. play_again remains a separate card bool;
CombatExecution grants an extra action only on play, never discard, without extra income.
Descriptions, costs, names, tier and allocation identity remain authored as before.

## Resolution order (unchanged)

Payment precedes effects. Within each dictionary:

1. Own Hull/Shields/reserve/production changes; non-family production_other pair.
2. Own/enemy production clamping, own reserve/Shield clamping.
3. Non-family reserve swap; random_gain, random_gain_other, random_gain_range_other in that order.
4. Shield swap, collapse/risk, strict-below clear, Shield breaking, piercing/regular damage.
5. Per-resource drain then theft; all-system sabotage then random sabotage.
6. Shield-first self-damage/backlash, direct self-damage; damage-report accumulation.
7. Evaluate conditional against resulting state; recursively execute selected branch.

Dictionary iteration order does not define combat order. Descriptions deliberately DO
iterate authored order; validation preserves it. RNG draws and modifier calls are unchanged.

## Consumer coverage matrix

The contract's COVERAGE ledger has six explicit decisions per supported key; the focused
test requires identical key sets and an executable example with a target expectation for
every key. This is a review checklist, not dispatch or proof of numerical forecast parity.
`D` = existing description handling; `G` = generic signed text/upgrade comparison.
AI simulation here means CardEffects on detached copies, not modifier-aware forecasting.

| Effect | Execution | Description | Tactical targets | Modifier decision | AI | Upgrade inspection |
| --- | --- | --- | --- | --- | --- | --- |
| hull | Add | G | Own signed | Ion scale | Simulate + Hull score | G |
| shields | Add/clamp | G | Own signed | Ion; Flare reserve | Simulate + Shield score | G |
| materials, energy, crew | Add/clamp | G | Own signed; cost distinct | Ion | Simulate + reserve score | G |
| synthesizer, reactor, quarters | Add/clamp | G | Own signed | Ion | Simulate + production score | G |
| damage | Shield-first | D | Absorption categories | Ion; Nebula combat | Simulate + attack heuristic | D |
| pierce | Damage fraction | D | Damage categories | Unscaled | Simulate | D |
| break_shields | Before damage | D | Enemy Shields | Ion; Nebula combat | Simulate | G |
| shield_collapse_below | Strict check | D | Conditional clear | Unscaled; Nebula combat | Simulate | G |
| shield_collapse | Clear/risk | D | Enemy Shield; uncertain backlash | Ion backlash; Nebula combat | Worst-case backlash | D |
| self_damage | Hull | D | Own Hull | Ion; retained top-level on miss | Simulate safety | G lower-is-better |
| self_damage_regular | Shield-first | D | Own absorption | Ion; not retained on miss | Simulate safety | G lower-is-better |
| drain | Before theft | D | Enemy reserves | Ion; Nebula combat | Simulate + reserve score | D |
| steal | Transfer | D | Both reserves | Ion; Nebula combat | Simulate + reserve score | D |
| enemy_production | Clamp | D | Enemy production | Ion; Nebula combat | Simulate + shutdown score | D |
| production_other | Non-family pair | D | Matching own pair | Ion | Simulate + upgrade heuristic | D |
| swap_resource | Exchange | D | Both differences | String unchanged; Nebula combat | Simulate | G |
| swap_shields | Exchange | D | Both differences | Bool unchanged; Flare/Nebula | Simulate | G |
| sabotage | All production | D | All enemy production | Ion incl. legacy bool; Nebula | Simulate + shutdown score | G |
| random_sabotage | One production | D | All possible, uncertain | Ion; Nebula combat | Conservative immediate check; enumerate 3 targets in tactical score | G |
| random_gain | One reserve | D | All possible, uncertain | Ion | Omit simulation; top-level expected-value score | G |
| random_gain_other | Non-family | D | Non-family, uncertain | Ion | Omit simulation; top-level expected-value score | G |
| random_gain_range_other | Non-family range | D | Non-family, uncertain | Ion bounds | Omit simulation; top-level expected-value score | D |
| conditional | Selected recursive branch | Recursive | Ordered predicate; both branches uncertain after randomness | Recursive Ion/classification | Recursive simulation | Recursive |

Ion recursively scales numeric effect fields, flooring each, except `pierce`,
`shield_collapse_below`, `threshold`, `chance`. Signed values floor too. Costs do not scale.
Solar Flare temporarily zeros both Shields, strips top-level restoration/swap, then
restores reserved values; do not generalize it to a new recursive engine.
Nebula classification uses its existing offensive-key list plus recursive conditions;
misses still pay, retaining only explicit top-level direct self_damage. A modifier play
retains its existing RNG draw even when a particular effect needs no random outcome.
Asteroids are independent third-party attacks; Temporal Rift changes draws, not effects.

CardPreferences intentionally classifies only its existing soft-draw subsets recursively;
unknown strategic value is not an execution error. play_again is handled outside the
effect vocabulary in execution, descriptions/inspection and AI extra-action scoring.

## Known limitations, not changes in this pass

- Tactical targets are categories, not a numerical forecast. Mixed exchanges/damage and
  random precursors need not mirror exact final deltas; uncertainty is intentional.
- AI simulation omits modifier context, ignores random gains and assumes collapse harm.
  Its random-gain expectation heuristic is top-level; no new policy is added for nested gains.
- Ion's recursive scaling also scales numeric range bounds/production adjustments, but
  excludes predicate thresholds. This is existing behavior, not a new uniform formula.
- Unusual signed drain/theft/damage values remain structurally accepted because runtime
  accepts them; they are not a recommendation for new card design. No such balance change
  was made. The validator cannot prove an authored description string matches execution.
- Base description strings can intentionally summarize more tersely than derived upgrade
  text. Wording and ordering are preserved; no confirmed gameplay correctness fix is
  bundled into this pass.

## Authoring and extension workflow

Edit existing CardData Resources in the Inspector: **Effects**, **Upgrade Effects**,
**Max Upgrades**, **Family**, **Cost**, **Tier**, **Allocation Category**, **Play Again**.
Register a new identity only in CardLibrary. Validate from the repository root:

```sh
godot --headless --path . --script tools/validate_cards.gd
godot --headless --path . --script tests/card_effect_contract_test.gd
godot --headless --path . --script tests/card_effect_parity_test.gd
python tools/run_regressions.py --godot godot --timeout 360 --results test-results
```

Diagnostics include resource path, title, base/Upgrade I/II, nested field, expected form,
actual type and actual value; CLI exits 1 for invalid data. No Inspector plugin, runtime
validation loop, additional service or engine dependency is required. The shared runner
already discovers the new tests, so CI needs no separate framework.

For a future effect: add a form and nested checks; review all six COVERAGE decisions;
implement execution without changing existing order/RNG; update descriptions, targets,
modifier treatment, AI treatment and inspection as appropriate; add a valid executable
sample with a target assertion and malformed cases. Review CardPreferences separately.
Use explicit no-op/uncertainty decisions where special behavior is unnecessary. Capture
any NEW parity fixture from the pre-change source; never replace existing expected hashes
to make a divergent implementation pass. Ownership and save codecs need no change.

## Verification and size

Stage A completed on unchanged runtime source: editor import passed; 91 of 92 headless
scripts passed initially. `expedition_fresh_process_test` failed its existing final
menu-button assertion and passed an isolated unchanged rerun (3.83 seconds). No fixture
or assertion was changed. All 92 scripts therefore have passing baseline executions,
with that initial intermittent failure retained in the report.

The new `card_effect_baseline.json` was captured before any runtime edits: 2,220 hashes
cover 74 identities × 3 levels × 2 seeds × 5 modifier modes (normal, Ion half, Ion double,
Solar Flare, Nebula). Each record includes direct CombatExecution results/extra action,
modifier results/damage reports/RNG, simulated states, AI decision/RNG, tactical targets,
description and upgrade-comparison text. Every card is affordable in these fixtures.
Read-only analysis is checked against the original states, definition and combat RNG.
Existing expected combat/deck fixtures remain untouched.

Final verification results follow after the shared run.
