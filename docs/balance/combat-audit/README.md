# Combat balance audit

See [Combat Balance Pass 1](pass-1.md) for the paired follow-up and selected changes.

## Executive summary

The audit completed **30,720 battles** across six playable ships, eight
enemies, eight modifiers and five player policies. It recorded 10,783
combat wins, 4,178 EMP escapes, 14,880 defeats, 25 draws and 854 unresolved
matches. All unresolved matches reached the 100-round cap.

- **Titania and Endeavour led combat-only wins.** Titania won 55.9% and
  Endeavour 50.6%. Ganymede won 27.7%, a 28.2-point gap versus Titania
  under identical opponent, modifier, policy and seed schedules
  (paired interval 26–30 points). Aggressive play raised Ganymede to
  42.8%, so policy and deck fit matter.
- **EMP changed the ranking.** Callisto won 34.4% across combat-only
  policies and reached 87.0% success under the EMP policy. First-legal
  escape added 50.7 points versus its matched Defensive policy.
  Thunderbolt's fast drive yielded 64.0% escapes, but its combined
  success was 74.5%, close to Orion and Ganymede.
- **Enemy strength varies substantially.** Every ship won fewer than 5%
  against the base Sentinel Dreadnought in combat-only trials. The
  EMP policy escaped in 496 of 768 boss trials, with zero combat wins.
  Rustjack ranged from 59.6% to 94.7% player combat wins. The Hollow
  Choir was a sharper matchup check, ranging from 5.9% for Callisto
  to 71.1% for Titania.
- **Storm specialization was weak in this sample.** Ion increased
  Callisto’s combat wins by 3.3 points and Thunderbolt’s by 0.6.
  Their paired intervals include zero. Orion lost 9.2 points in Nebula
  and 7.4 in Asteroid Belt. Endeavour gained 7.2 points in Solar Flare.
  These comparisons are exploratory across many modifier cells.

The [full tables](tables.md) cover ship policies, all enemy matchups,
modifiers, resource reserves, Systems Failure, and high/low card usage.
The [card data](card_usage.csv) breaks those observations down by ship
and policy.

## Recommendations

### High-confidence findings to investigate

- **Ganymede's starting loadout.** Compare the current 3/1/2 production
  profile with a 3/2/2 test variant under identical draws. The proposed
  variant tests whether additional reactor income improves the early
  conversion of Energy into pressure. Its average Energy reserve was
  already 55.0 after income and its unaffordable turns were only 2.5%,
  so a deck-slot swap for an earlier damaging action is an equally
  important control. The audit does not isolate production as the cause.
- **Callisto's long encounters.** It reached the cap in 311 of 4,096
  combat-only matches, the highest of any ship, yet escaped in 820 of
  1,024 EMP-policy matches. Keep the shield profile for the first human
  test and record whether players can close fights when choosing to stay.

### Potential balance changes for human or paired tests

- **Fabrication Strike and Command Infiltration.** Both cost 17. Test
  16 on one card at a time to see whether a small price change opens
  useful tactical windows without increasing Systems Failure too often.
  Only 43.7% and 40.1% of their sampled holdings were affordable,
  respectively. These cards have effects beyond direct Hull damage.
- **Sentinel Dreadnought.** The tested base boss and +2 EMP requirement
  produced a sharp distinction between destruction and escape. Retain
  those values until matched trials with intended progression and
  mothership bonuses establish whether destruction is too rare in play.
- **Boarding Operations.** Its current 7 Crew buys 4 damage with 1
  penetration and steals 4 Crew. It was played on 96.1% of draws.
  Compare the current card against a 3-Crew-steal test variant before
  considering a change. The audit does not isolate its contribution
  from the ships and policies that draw it.

### AI-policy artifacts and insufficient evidence

- Economic won less often than Aggressive on every ship. Higher
  production weights and Systems allocation deliberately favor long-term
  setup. This does not establish that economy cards are weak.
- Personnel Disruption was played on 32.6% of draws despite 82.1%
  affordability. Its −1 Quarters effect can be valuable near the Systems
  Failure threshold. Test targeted setups before changing its cost.
- The audit does not establish a causal card ranking, the strength of
  acquired-only cards, or expected human win rates. Sixteen seeds per
  ship/enemy/modifier/policy cell support screening for large effects.
  Small modifier deltas and individual rare outcomes need more evidence.

## Method

This audit compares starting loadouts at authored enemy strength. It uses
the production resolver, card hand, modifier forecasts, Systems Failure
and EMP drive. It excludes persistent expedition upgrades and bonuses,
strategic effects, and presentation delays. The boss uses the configured
Defense EMP surcharge on its base profile. This is a controlled encounter
comparison using automated policies.

## Reproduction

With Godot 4.7.2 and Python installed, run from the repository root.
Replace `godot` with the path to the Godot console executable as needed.

```text
godot --headless --path . --script tests/combat_balance_audit.gd -- audit.jsonl -1 1 16 all
python tools/aggregate_combat_audit.py docs/balance/combat-audit audit.jsonl
python tools/render_combat_audit_tables.py docs/balance/combat-audit/summary.json
```

The positional arguments are output path, zero-based ship index or `-1`,
first and last inclusive seed, and policy name or `all`. Ship, seed
range, and policy shards can run independently. Pass the complete list
of JSONL shards to the aggregator. It verifies each shard’s declared
coverage and rejects duplicates, incomplete shards and incompatible
configurations.

The comparison uses identical enemy, modifier and seed schedules for
each ship and policy. Each fine-grained cell uses 16 seeds. Full ship
summaries pool 4,096 combat-only matches or 1,024 EMP-policy matches.
The aggregate JSON includes the baseline revision and policies. The
compressed JSON Lines archive contains individual results. Card usage is
reported by identity, ship and policy. Missing card rows indicate no draws
in those groups, including cards outside the starting loadouts.

The source revision recorded in the shards is
`956cf3b9945b0b8c4df14bef7a362b38a42dc097`, the production baseline.
The audit ran from the working tree containing the harness later committed
as `4dbb822`. Reproduction from that commit records a different revision
string while using the same production rules and seeds.

Round and action caps are both 100. Unresolved rounds and action caps
remain distinct outcomes, and all attempts remain in rate denominators.
Reported 95% Wilson intervals describe binomial sampling under the stated
model. Shared seeds and policies induce dependence across cells, so the
pooled intervals are descriptive. Modifier comparisons pair each
ship/enemy/seed/policy with its unmodified result, using conservative
discordant-proportion bounds. Treat the finest cells and multiple
comparisons as exploratory.

## Parity and limitations

The board parity regression compares seeded player openings, first-turn
income and EMP charging, one legal action, resulting resources and Hull,
extra-action state, and modifier RNG in three scenarios. Existing card
effect, draw, modifier and failure regressions supplement the fixture.
The audit uses the board’s refill order, including the outgoing enemy
hand drawing at the next round. It applies Hull loss immediately and
omits presentation and rewards. The historical simulation path retains
its own seeding and replacement rules for the frozen trace regression.

Balanced uses the existing heuristic with Balanced allocation. Aggressive,
Defensive and Economic change its weights and use Offense, Defense and
Systems allocation. All policies prefer Systems allocation while in
Systems Failure. EMP uses the same Defensive weights and allocation,
and takes the first legal escape. Its paired Defensive comparison
isolates the decision to escape. Enemy AI uses its profile weights and
live modifier forecasts in every case. Opening decks and automation
exclude acquired cards, upgrades, specialized combos and human timing.

Draw metrics count opening cards and subsequent replacement draws.
Holding and affordability are sampled per player turn after income.
Contribution metrics track reported opposing Hull damage, positive
same-action Hull or Shield gains, and net change in the card’s cost
family. Gross permanent Hull damage counts reported damage below capacity
on card actions. Net Hull lost includes all effects and subsequent repair,
including asteroid strikes. Neither measure models expedition repair cost.
