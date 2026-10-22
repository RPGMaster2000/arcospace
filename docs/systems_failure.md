# Systems Failure

Systems Failure replaces resource accumulation as a win condition. Resource
income, costs, reserves, drawing, Power Allocation and the existing card ecosystem
remain. Hull destruction and manual EMP Pulse escape remain valid.

## Rules and timing

- Synthesizer, Reactor and Quarters can reach zero, but never become negative.
- At least two production systems at zero activate one countdown for that ship, default **3 own turns**.
- Activation never consumes a turn immediately. If caused during that ship's own
  turn, that activation turn's ending is exempt; the following three full own-turn
  endings are its recovery opportunities.
- Opponent turns and extra `play_again` actions do not tick the countdown.
- More offline systems do not create another countdown or reset the existing one.
- Restoring enough systems so fewer than two remain at zero cancels immediately,
  including on the last available turn. Three-to-two recovery keeps the deadline.
- At the third unresolved own-turn ending, the ship loses. Production is never
  automatically restored. Player and enemy use identical, independent clocks.
- Hull destruction retains precedence, including simultaneous lethal Hull damage.
  The existing shield-overflow coordinator still resolves pending Hull damage
  before a turn can finish. Results and rewards are latched once.

Edit **Systems Failure Turns** on the Board/Board3D root in Godot's Inspector
(`scripts/board.gd`). This is the single authoritative duration value; the same
value is passed to both ships' coordinator. Fresh encounters get fresh clocks.
The activation/recovery threshold is `MatchRules.SYSTEMS_FAILURE_THRESHOLD` (2),
shared by countdown coordination, win checks and AI recovery evaluation.

## System Disruption

Identity/path, cost **9 Crew**, Tier 1, Offense allocation and two upgrade levels
are unchanged. Every version reduces **one uniformly random enemy production
system by one**, selected from all three, even when already zero.

| Version | Additional effects |
| --- | --- |
| Base | None |
| Upgrade I | Drain 3 enemy Energy |
| Upgrade II | Drain 6 enemy Energy and deal 3 ordinary damage |

`random_sabotage` is distinct from existing `sabotage`. Sabotage Commandos retains
its all-three reduction by two, damage, costs and upgrades. Other targeted Tier 2
cards retain their effects and amounts; the common production floor is now zero.
Descriptions and upgraded inspection text follow the same effect definitions.
Nebula still applies to sabotage attacks. Live resolution uses the existing combat
RNG without rerolling an already-offline target.

## Ownership

| File | Responsibility |
| --- | --- |
| `scripts/combat/systems_failure.gd` | Activation, recovery, grace and per-ship turn-end countdowns; never owns production or repairs it. |
| `scripts/match_rules.gd` | Shared offline-system predicate, terminal conditions and existing income. |
| `scripts/board.gd` | Commit production changes, coordinate full turn endings, supply snapshots, latch results and use existing progression. |
| `scripts/cards/card_effects.gd` | Zero production floor and random-target sabotage resolution, including conditional effects and simulations. |
| `scripts/combat/systems_failure_tactics.gd` | AI recovery choices and preservation of funds for useful held repair cards. |
| `scripts/enemy_ai.gd` | Existing legal-move selection, immediate Hull wins, tactical variation and production-pressure scoring. |
| `scripts/ui/systems_failure_display.gd` | Read-only compact warnings beside both resource columns; hidden when inactive. |
| `scripts/expedition_state.gd` | Existing rank reward/completion pipeline, using destruction rewards for Systems Failure. |

The AI prioritizes useful affordable restoration over upgrades to an unrelated
operational system. It considers the remaining deadline and known held play-again
recovery chains; it never assumes a guaranteed replacement draw. When restoration
is unaffordable, it preserves relevant reserves and prefers funding discards while
keeping useful repair cards. Restoring from two disabled systems to one counts
as complete recovery; restoring from three to two remains an emergency. Crossing
the second-system threshold earns an offensive bonus; additional shutdowns during
an active failure retain ordinary production-denial value without another
activation bonus. Immediate safe Hull wins still come first.

Random sabotage is valued by averaging three deterministic effect simulations on
copies. Conservative immediate-win checks assume no lucky random hit. Neither
path samples live combat RNG or observes the opponent's hand. Public countdowns
and production values are the AI's only failure information.

Resource-goal configuration and its separate Salvage setting are removed. Systems
Failure grants the same profile/rank rewards, upgrade opportunities, completion
and FTL charge as destruction; escape keeps its existing separate reward behavior.
Post-result repairs and duplicate-reward guards are unchanged.

## Validation and balance

The dedicated `tests/systems_failure_test.gd` covers both ships, all production
systems, exact-zero floors, own-turn activation grace, partial/final-turn recovery,
reactivation, simultaneous clocks, configured duration, extra actions, empty AI
hands, random targets/upgrades, Commandos, AI priorities/funds/RNG, Nebula misses,
Power Allocation, result causes, one-time standard/Elite/Boss rewards and warning
geometry at 16:9, 19.5:9 and 21:9. CI includes a rendered run.

Systems Failure makes existing production sabotage substantially more threatening,
especially all-system Sabotage Commandos. Stored-resource shortages and failing to
draw affordable recovery can cause defeat; no guaranteed recovery draw or rescue
was added. Repeated hits do not refresh a deadline, while Disruption can waste a
hit on an offline system. Human balance testing is still needed; no ship, deck,
card-price or other sabotage-amount rebalance was made.

Validated with Godot 4.7.2: all 60 headless regression scripts passed after updating
obsolete victory/minimum-production expectations. The dedicated suite passed
748 checks headlessly and with the OpenGL Compatibility renderer; screenshots at
1280×720, 1560×720 and 1680×720 were inspected. Existing repair, reward, Boss,
upgrade UI, Power Allocation, AI, Hull, EMP and shield-overflow regressions passed.
Editor import and the updated balance diagnostic's syntax check passed. The full
historical balance simulation was not rerun; no new win-rate claim is made.
Existing ObjectDB shutdown warnings remain. Native Android hardware/rendering and
real-device readability/performance were not tested here.

A stale cinematic-test assertion was updated to match the existing EMP-below-Hull
layout. The repair-selection fixture now starts after result accounting, so its
fixed starting balance tests repair spending independently of victory rewards.

## Two-system threshold validation

Godot 4.7.2 headless: all 15 relevant suites passed: systems_failure (834 checks),
targeted_sabotage (6,034), ai_turn, power_allocation (18,352), battle_hud,
battle_layout (208, covering 16:9, 19.5:9 and 21:9), victory_rewards, victory_music,
field_repairs, expedition, expedition_milestones, encounter_continue, ftl,
ftl_progression and shield_shatter. Tests cover all eight disabled-system
combinations for each ship, sufficient/insufficient recovery, reactivation,
independent clocks, final-turn recovery, warnings, AI and existing outcomes.
The older 4.6 engine reproduced 27 UI interaction failures on unchanged main;
the same suite passes on 4.7.2. No rendered or physical Android check was run.
