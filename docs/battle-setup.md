# Battle setup and modifiers

The normal launch scene is `scenes/battle_setup.tscn`. Both setup and modifier HUD nodes are editable in Godot's viewport.

- Configure Materials, Energy, Crew and their three production rates separately for player and enemy. These are starting values before the normal first-turn income.
- FTL turns default to 14. The first player turn contributes the first charge.
- Pick exactly one modifier, or None. Play Again reuses the setup; Battle Setup on the result screen returns to the controls.
- A displayed turn is a full round: player actions, then enemy actions. Extra-action cards do not advance it. Income still occurs at the start of each side's turn.

## Modifiers

| Modifier | Behavior |
|---|---|
| Asteroid belt | After a displayed 3–6-round countdown, the battlefield independently rolls a 50% chance to hit each ship for 10 normal damage. Shields absorb it first. The attack happens once, before the player acts, and immediately schedules the next shower. |
| Ion storm | After a 3–6-round countdown, one announced multiplier (50/50 double or half) applies to all blue cards for three full rounds, including resource gains, drain, theft, production increases and sabotage, for both sides. Halves round down; costs, piercing fraction and extra actions stay unchanged. Shield swaps remain swaps. |
| Solar flare | Both shields are offline for three full rounds. Attacks hit hull; shield gain has no effect. Existing shield points are preserved and return after the flare. Shield swapping/breaking cannot alter stored shields during the flare. |
| Nebula | Displays 70% starting hit rate (sensor efficiency), ranging from 30–100%. Internally starts at 30% miss rate and drifts by up to 5 percentage points each new full round, clamped to 0–70%. Combat cards (damage, shield attacks, drain, theft, sabotage, swaps) pay their cost but cancel their effects on a miss. Non-combat cards are unaffected. The bar shows the actual hit percentage. |

Ion and solar events schedule a new 3–6-round countdown after their three active rounds end. Countdown text predicts the activation round; a central message announces activation. Asteroid outcomes and ion multipliers/misses also have central feedback. Simultaneous hull destruction is a draw.

## Values to tune

- `scripts/combat_modifier.gd`: intervals, duration, asteroid damage/chance, nebula starting rate/step/cap; each is marked `TUNE`.
- `scripts/modifier_display.gd`: activation message hold duration.
- `scenes/battle_setup.tscn`: SpinBox defaults and ranges.
- `scripts/ftl_drive.gd`: default charge target and disruption settings. Setup overrides only the per-match charge target.
- `scripts/board.gd`: applies settings and coordinates round boundaries; `combat_modifier.gd` owns modifier rules.

## Editable battlefields

None uses `scenes/battlefield_3d.tscn`. Each other setup selection loads its own full copy:
- `scenes/battlefield_asteroid_belt.tscn`
- `scenes/battlefield_ion_storm.tscn`
- `scenes/battlefield_solar_flare.tscn`
- `scenes/battlefield_nebula.tscn`

These start with the same visuals. Edit their backgrounds, lighting and layouts independently in Godot. Keep `Camera3D`, `MeshInstance3D` (backdrop), `PlayerShip` and `EnemyShip` node names for board wiring. Ship instances still share `ship_3d.tscn`; make ship resources unique before changing them for only one battlefield. Setup descriptions use modifier constants automatically.

Ion card previews and glow use the same storm multiplier as resolution. FTL status sits below player hull/shields and flashes when disrupted and at each offline player turn.

## Card tiers

The CardData Inspector exposes three rarities. Rarity stays fixed through both upgrade levels. The [card catalogue](balance/cards.md) lists the 115 shared identities and the full effects of each variant.

Each six-card hand allows at most one Tier 2 and one Tier 3 at the same time, with at most two copies of an identity. Tier 2 unlocks in round 3 and Tier 3 in round 6. The normal eligible rates are 80% Tier 1, 15% Tier 2 and 5% Tier 3. A locked, missing or occupied rarity falls back to Tier 1. Once rarity is rolled, identity selection uses the hand's existing weights. Custom pools without a valid fallback can leave a slot empty.

Temporal Rift doubles the Tier 2 rate to 30%. Tier 3 stays at 5%, and both round gates and caps still apply. The modifier uses `scenes/battlefield_temporal_rift.tscn`.

Tune chances, rounds and duplicate limits in `scripts/cards/card_hand.gd`. Card resources expose effect dictionaries and rarity in the Inspector. The card face shows compact effect timing and highlights Tier 3 with a gold badge. Hold or middle-click for the full effects and upgrades.
