# Battle setup and modifiers

The normal launch scene is `scenes/battle_setup.tscn`. Both setup and modifier HUD nodes are editable in Godot's viewport.

- Configure Materials, Energy, Crew and their three production rates separately for player and enemy. These are starting values before the normal first-turn income.
- FTL turns default to 14. The first player turn contributes the first charge.
- Pick exactly one modifier, or None. Play Again reuses the setup; Battle Setup on the result screen returns to the controls.
- A displayed turn is a full round: player actions, then enemy actions. Extra-action cards do not advance it. Income still occurs at the start of each side's turn.

## Modifiers

| Modifier | Behavior |
|---|---|
| Asteroid belt | After a displayed 6–10-round countdown, the battlefield independently rolls a 20% chance to hit each ship for 5 normal damage. Shields absorb it first. The attack happens once, before the player acts, and immediately schedules the next shower. |
| Ion storm | After a 6–10-round countdown, blue cards have a 50/50 chance of double or half numeric effects for one full round, including both sides. Halves round down; costs, piercing fraction and extra actions stay unchanged. Shield swaps remain swaps. |
| Solar flare | Both shields are offline for one full round. Attacks hit hull; shield gain has no effect. Existing shield points are preserved and return after the flare. Shield swapping/breaking cannot alter stored shields during the flare. |
| Nebula | Starts at 35% miss rate and drifts by up to 5 percentage points each new full round, clamped to 0–70%. Combat cards (damage, shield attacks, drain, theft, sabotage, swaps) pay their cost but cancel their effects on a miss. Non-combat cards are unaffected. The requested “Targeting Sensor Efficiency” number explicitly also displays the miss rate. |

Ion and solar events schedule a new 6–10-round countdown after their active round ends. Countdown text predicts the activation round; a central message announces activation. Asteroid outcomes and ion multipliers/misses also have central feedback. Simultaneous hull destruction is a draw.

## Values to tune

- `scripts/combat_modifier.gd`: intervals, duration, asteroid damage/chance, nebula starting rate/step/cap; each is marked `TUNE`.
- `scripts/modifier_display.gd`: activation message hold duration.
- `scenes/battle_setup.tscn`: SpinBox defaults and ranges.
- `scripts/ftl_drive.gd`: default charge target and disruption settings. Setup overrides only the per-match charge target.
- `scripts/board.gd`: applies settings and coordinates round boundaries; `combat_modifier.gd` owns modifier rules.
