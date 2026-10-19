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

Existing cards default to Tier 1. The CardData Inspector offers Tier 1, Tier 2 and Tier 3. Six Tier 2 cards are added: Siege Driver / Emergency Refit (Materials), Antimatter Lance / Aegis Overcharge (Energy), Sabotage Commandos / Damage Control (Crew). Tier 3 is reserved; no Tier 3 cards exist yet.

Each hand can hold one Tier 2 card total. This applies to starting hands and replacement draws, for both ships. Tier 1 retains the two-identical-copy limit. The draw first chooses a tier (15% Tier 2 when eligible), then uniformly selects an eligible card within that tier. If a Tier 2 is already held, draws fall back to Tier 1. Using/discarding that card opens the slot for its replacement. Custom pools without an eligible fallback can produce an empty slot.

Temporal Rift is a whole-battle modifier with no periodic event. It doubles Tier 2 chance to 30% for both hands and loads `scenes/battlefield_temporal_rift.tscn`, an independent copy ready for editor changes. No other modifier is active alongside it.

TUNE: `card_hand.gd` exposes tier chances and max copies. Each new `.tres` exposes tier, cost and numerical effects. `card_view.gd` exposes commented jagged depth, spacing and pulse intensity; the Tier 2 outline pulses softly and remains visible on the played-card presentation.

Tier 2 cards are blocked for both ships during full rounds 1-2, including opening/fixed hands and Temporal Rift. Draws unlock at round 3. TUNE `card_hand.gd` → `tier_two_locked_turns` to change this delay. Emergency Power Cell retains `08_energy_cell.tres`, costs 0 and consumes a turn. It grants +3 Materials and +3 Crew, plus +3 Energy if own Energy is at most 5 after payment. Normal card summaries use 14 px text and a fixed artwork area. Hold a card or middle-click for full effects and both upgrades; tune `resources/card_presentation.tres`.
