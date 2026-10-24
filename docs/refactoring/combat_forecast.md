# Combat forecast ownership and modifier-aware AI

Starting revision: `9ec97c6f3d8aca31422839830eb4e5577f358c29`, Godot 4.7.2.

## Audit and phase boundary

EnemyAI checks affordability, then conservative immediate wins and surviving self-damage.
SystemsFailureTactics handles recovery/resource preservation and discard refunds. Ordinary
fallback prioritizes attacks against low Hull, repairs at the configured build threshold,
then production, then affordable choices. Tactical scoring simulates copied states;
random sabotage averages three hypothetical targets, random gains are omitted but valued
by a top-level expectation heuristic. Weights, urgency thresholds, discard policy and
strict-greater tie order are policy. Variation and fallback picks use only AI's RNG.

All simulations use CardEffects, but lack Ion scaling, Solar Flare and Nebula context.
Board supplies detached ship state plus failure counters, not modifier information.
Board3D inherits this decision path. CardTargets is category guidance, not a forecast.

| Modifier | Live behavior | Old AI | Forecast context / treatment |
| --- | --- | --- | --- |
| None | Base effects | Conservative simulation | No adjustment |
| Ion | Active Energy ×0.5/×2, recursive floor and exceptions; cost unchanged | Base effects | Current active flag and announced factor; shared scaling |
| Solar Flare | Disabled active Shields, top-level restoration/swap stripped; stored values restored | Stored Shields treated as usable | Current active flag; shared zero/restore scope |
| Nebula | Combat classification + current miss rate; miss pays, retains top-level direct self-damage | Assumes hit | Enumerated hit/miss alternatives, no sampled roll |
| Asteroids | Separate scheduled strike | Not forecast | Explicit no-op for current card; no future strike included |
| Temporal Rift | Tier-2 draw multiplier | Current hand only | Explicit no-op for immediate card resolution |

Phase A adds infrastructure and shared rule seams only; EnemyAI and Board stay unchanged.
Phase B is separately gated on deterministic parity and audited decision comparisons.
The existing conservative three-argument AI call remains the compatibility baseline.

## Forecast contract

`CombatForecast.predict(card, actor, target, context={})` returns affordability,
`outcomes` (actor/target/damage/miss), `complete`, `uncertain`, witnessed `possible_win`
and `possible_self_destruction`, and complete-only `guaranteed_win` /
`guaranteed_self_destruction`. Winning requires actor survival and MatchRules.wins;
no countdown is advanced. The nominal current Nebula miss probability is reported.
This is not an expectation or a probability-weighted distribution of random effects.

Inputs are read-only. Every outcome owns detached dictionaries; no Resource, Node, hand,
RNG or source collection is returned. Context is four scalars from
`CombatModifier.forecast_context()` (kind, active, ion_factor, miss_rate). It must describe
a valid current modifier, not invented future schedules. No modifier Node is created by
forecasting. Terminal-action legality beyond affordability stays with CombatExecution.

Modifier's shared `resolve_effects` owns adjusted effects and the Solar Flare stored-Shield
scope. Its live caller still owns the scheduled state, existing chance draw and notice.
`_scaled` becomes static with its exact original implementation. CardEffects receives an
optional forecast draw source, default null, at the same existing draw sites. Production
calls retain their supplied RNG, draw count/order, branches and formulas. This narrow seam
lets the forecast replay explicit choices; it is not a new effect registry or resolver.

For integer resource/production/range draws, enumerate their actual discrete domains.
For Collapse's `< chance`, float endpoints cover both reachable comparison outcomes,
including native randf's inclusive 1. No probability is assigned to these alternatives.
Conditions execute normally after preceding draws, so nested branches see the right
state without the forecast interpreting their rules. Nebula gets separate hit and miss
requests; its shared miss transform preserves explicit top-level self-damage and payment.

At most 64 authoritative resolver replays run per card. An adaptive prefix branches on
the next unresolved nontrivial draw; fixed-range draws still advance that prefix. Large
or combined spaces can return a subset, flagged incomplete with a limitation. In that
case possible_* true is a witnessed outcome; false does NOT establish impossibility.
No guarantee flags are ever set for incomplete results. No Monte Carlo samples, expected
values, sampled seeds, live RNG calls or hidden fallback claims are used.

Asteroids and Temporal Rift do not change the immediate card forecast. Stored Shields
remain stored in Solar Flare outputs, while damage is calculated with zero usable
Shields. CardTargets/TacticalPreview are unchanged and remain category-only presentation.

## Phase A gate

Newly verified on this source: baseline 94 headless scripts + import passed. Phase A
focused runner passed import and eight suites: forecast (1,554 combinations / 10,900
checks), 480 unchanged AI decisions AND RNG states, contract (1,011), card-effect parity
(2,220), combat traces (72), AI scene, modifier and Systems Failure suites. The first
new comparison attempt exposed JSON's float representation of integer slots; the loader
now casts that field without changing any recorded decision or established fixture.
EnemyAI and Board are byte-identical to the starting revision at this gate.

## Phase B: narrowly integrated gates

Board passes a fresh four-scalar context at the actual enemy timeout. No context field
is cached on AI or serialized. Ion forecasts apply only to Energy cards while active;
Flare while active; Nebula only to combat-classified cards at nonzero miss rate. Ordinary,
inactive Ion/Flare, Asteroid and Temporal Rift calls retain the old simulation gates.
The default three-argument call remains intentionally compatible, including the existing
72 diagnostic combat traces and 2,220 card parity records. Those traces exercise the
legacy decision policy; they are NOT a claim that modified live AI is unchanged.

Only immediate winning moves and fatal self-damage filtering use numerical forecasts.
A win requires all enumerated outcomes to win with surviving actor. Safety rejects any
possible fatal outcome. An incomplete forecast cannot claim an immediate win; safety
falls back to the old conservative policy unless a fatal witness is already present.
All current authored cards/upgrades fit the complete forecast budget in the tested contexts.
Recovery/follow-up simulations, tactical scores, random-gain expectation, sabotage scoring,
discard rules, weights, thresholds and strict tie-breaking stay byte-identical.
These remain explicit approximations and are not advertised as modifier-aware scores.

### Reviewed decision comparison

`tests/ai_forecast_baseline.json` was captured before Phase B. Cases use six six-card
hands, five situations (ordinary, immediate win, low-Hull risk, Systems Failure recovery,
unaffordable), two AI seeds and eight contexts: 480 comparisons. One hand includes
Upgrade I/II definitions. Input fingerprints, original decisions and RNG states remain
fixed. Comparisons also rerun the legacy call with an explicit identical combat seed;
both paths leave combat RNG unchanged. Old simulation does not read that RNG at all.

Results: **6 selected-card changes**, **6 same-selection RNG deltas**, **468 cases with
identical selection and RNG**. All 240 ordinary/inactive/independent-event cases match.
No discard flags change. [Complete machine-checked ledger](ai_forecast_decisions.json)
records every changed case's cards, both ship states, context, weights, AI/combat seeds,
old/new decisions, RNG states, winning sets and safety sets. The regression asserts the
entire reviewed ledger; it does not merely accept arbitrary modified-battle differences.

| Case IDs (hand/situation/AI seed/context) | Old → new | Exact reason |
| --- | --- | --- |
| 0/1/7/3, 0/1/43/3 | Laser Burst → Overloaded Warhead | Half Ion Laser gives 4 damage, not its base 9; against 6 Hull it is not an immediate win. Unscaled Warhead safely kills. |
| 0/1/7/6 | Laser Burst → Plasma Strike | Nebula removes assumed guaranteed kills; existing fallback selects Plasma. |
| 1/1/7/6 | Overloaded Warhead → Laser Burst | Same Nebula correction; existing fallback pick. |
| 2/1/43/6 | Coordinated Assault → Reactor Salvage | Same Nebula correction; existing production-priority fallback. |
| 4/1/7/6 | Laser Burst++ → Shield Exchange+ | Same Nebula correction; existing fallback. |
| 0/1/43/6, 1/1/43/6, 2/1/7/6, 4/1/43/6 | Selected card unchanged; AI RNG advances | Early certain-win return becomes ordinary fallback/scoring, using its existing RNG draws. |
| 2/2/7/5, 2/2/43/5 | Coordinated Assault unchanged; fewer variation draws | Flare removes Desperate Conversion from safe candidates: stored Shields cannot absorb its self-damage. Existing tactical variation runs on five rather than six candidates. |

These differences are accepted forecast corrections, not changed weights or new strategy.
The AI can still select a risky-to-hit attack through ordinary policy; it simply no
longer treats it as a guaranteed immediate win. No fabricated probability-weighted
expected score or new planning depth is introduced.
