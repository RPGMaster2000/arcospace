# Ship profiles

The title screen defaults to Endeavour and offers Endeavour, Thunderbolt, Titania, Ganymede, Callisto and Orion with live 3D previews and compact rules. The old resource/production/FTL controls are removed. A normal title-screen start uses the selected profile at full permanent Hull capacity; the player receives ordinary first-turn production income, so displayed battle resources are starting reserves plus production. Enemy reserves receive income only when its turn begins.

Player selection is stored in setup_settings.player_ship and survives Play Again, Continue and Battle Setup until another ship is selected. An enemy profile is rolled equally from Marauder, Sentinel, Reclaimer, Rustjack, AXIOM-7 and The Hollow Choir for every new normal match, including restarts and continuations. Enemy FTL is not added. Profiles supply existing family/effect draw weights and tactical preferences to the shared AI.

Continue retains permanent player Hull up to the selected capacity and applies existing one-battle rewards. Shields and reserves/production restart from ShipData; temporary plating expires. FTL resets to the selected ship's charge duration and disruption resistance.

## Edit attributes in Godot

Select a Resource under ships/player/ or ships/enemy/. The Inspector exposes Hull Capacity, Shields, Materials/Energy/Crew, Synthesizer, Reactor, Quarters, FTL Turns, FTL Resistance, Hull Color and optional Model Scene. Edit the numbers here; the menu reads them automatically. ShipData is defined in scripts/ships/ship_data.gd; scripts/ships/ship_library.gd lists six players and six regular enemies. Expedition rules additionally register the existing elite and boss profiles.

FTL Resistance is a fraction: 0.25 multiplies the existing capped probability by 0.75; -0.10 multiplies it by 1.10. Normal remains 1.0. For four permanent Hull damage the probabilities are 20% / 15% / 22%. At the existing damage cap they become 60% / 45% / 66%. Duration, charge preservation and plating immunity remain unchanged.

## Replace a model independently

Model Scene is empty by default, retaining the existing battlefield ship and the user-authored light. To replace only one profile, duplicate scenes/ship_3d.tscn, edit its geometry/materials, then drag that scene into the corresponding ShipData Model Scene field. The title preview and battle both load it. Keep the root ship_3d.gd animation API, Body, Body/Hull, Body/Engine and Shield nodes. Replace mesh geometry under these nodes freely; these names connect existing hit/repair/shield effects. If you want the engine-light FTL effect, add Body/OmniLight3D to the replacement. An absent light is supported.

Hull Color updates only the private Hull material on each ship instance; Engine, Shield and separate effect shader materials are not tinted. Existing battlefield position/transform is applied to replacement models. No per-variant battlefield or gameplay-script copies are required.

Direct board scenes without player_ship settings retain their legacy Inspector statistics for custom experiments/tests. Normal gameplay enters through battle_setup.tscn and always uses ShipData profiles.

Verification includes all profile values, player/enemy income timing, randomized enemies, FTL multipliers/cap, selection persistence, plating transitions, per-profile colors and optional replacement models. Desktop 1280×720 and landscape 960×540 menu renders were inspected; physical phone input/performance was not measured.

## Additional regular enemies

All values and decks are editable in `ships/enemy/{rustjack,axiom_7,hollow_choir}.tres`.
Production order is Synthesizer / Reactor / Quarters; reserves are Materials / Energy / Crew.

| Profile | Hull | Shields | Reserves | Production | Variation |
| --- | ---: | ---: | --- | --- | ---: |
| Rustjack | 32 | 4 | 14 / 8 / 10 | 3 / 1 / 2 | 0.22 |
| AXIOM-7 | 29 | 16 | 8 / 14 / 10 | 1 / 3 / 2 | 0.04 |
| The Hollow Choir | 42 | 4 | 12 / 8 / 12 | 2 / 1 / 3 | 0.12 |

Each has 20 distinct base identities. No player starting pools or card effects change.
`ShipData.starting_cards` now optionally limits an enemy's draws in both standalone and
expedition battles. Empty preserves the full-library behavior of every existing enemy.
The same tier locks, copy caps and family/effect draw multipliers still apply.

### Rustjack

Family counts: materials 11, energy 2, crew 7.

Shield Plating, Hull Patch, Synthesizer Upgrade, Shield Disruptor, Hull Overhaul, Emergency Power Cell, Laser Burst, Boarding Party, Missile Team, Shield Breachers, System Disruption, Energy Siphon, Cargo Raid, Breach Charge, Salvage Strike, Reactor Salvage, Supply Diversion, Overloaded Warhead, Emergency Bulkheads, Salvage Cannibalization.

- `card_family_weights`: `{"materials": 1.5, "energy": 0.8, "crew": 1.1}`
- `card_effect_weights`: `{"damage": 1.5, "steal": 1.8, "disruption": 1.5, "hull": 1.2}`
- `tactical_weights`: `{"damage": 1.6, "hull": 1, "shields": 0.3, "production": 3, "resources": 0.45, "disruption": 1.1, "play_again": 1.2}`

### AXIOM-7

Family counts: materials 2, energy 14, crew 4.

Shield Plating, Hull Patch, Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Missile Team, Shield Breachers, System Disruption, Phase Lance, Energy Siphon, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Capacitor Overload, Power Grid Reroute.

- `card_family_weights`: `{"materials": 0.8, "energy": 1.6, "crew": 1}`
- `card_effect_weights`: `{"damage": 1.6, "disruption": 1.5, "shields": 1.2}`
- `tactical_weights`: `{"damage": 1.5, "hull": 0.8, "shields": 0.65, "production": 3.5, "resources": 0.3, "disruption": 1, "play_again": 1.1}`

### The Hollow Choir

Family counts: materials 8, energy 3, crew 9.

Shield Plating, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Emergency Power Cell, Hull Nanobots, Shield Recharge, Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, Torpedo Salvo, Crew Capture, Missile Barrage, Salvage Strike, Emergency Bulkheads, Structural Reclamation, Tactical Assessment, Damage Control Teams, Coordinated Assault.

- `card_family_weights`: `{"materials": 1.25, "energy": 0.8, "crew": 1.4}`
- `card_effect_weights`: `{"hull": 1.3, "shields": 1.25, "damage": 0.9, "economy": 1.1}`
- `tactical_weights`: `{"damage": 0.95, "hull": 1.3, "shields": 0.85, "production": 3.5, "resources": 0.3, "disruption": 0.35, "play_again": 1}`


Rustjack uses asymmetric boxes, armor plates and exposed ribs; AXIOM-7 uses a closed
procedural triangular wedge with swept wings; Hollow Choir uses spheres and torus
extensions. Their independent scenes are `scenes/ships/`. The compact shared
`enemy_ship_model.gd` extends the existing animation script, constructs the optional
interceptor wedge and attaches the existing damage/repair passes to nested colored
accents. Body/Hull, Body/Engine and Shield remain present. No default model changes.

Both registries include all six regular enemies. New encounter weights are 1.0, matching
the original regular profiles. Expedition elite weighting, scaling, mandatory Boss
selection and combat reward rules are unchanged; adding regular entries naturally changes
the registry's total weight. Standalone matches choose uniformly among the six regulars.

### Verification and balance diagnostic

`enemy_roster_test.gd` exercises all 36 player/enemy setups, actual expedition deck
assignment, model contracts/effect tweens and victory bookkeeping. The companion
`enemy_models_visual_test.gd` captures actual 1280×720 and 960×540 combat renders to `/tmp` (requires
a renderer). `enemy_roster_simulation.gd` runs 10 deterministic seeds per pairing with
real card draws, income, resolver and AI; no modifiers, player acquisitions or escape,
and a 40-round diagnostic bound. It is not a prediction of human win rates.

| Opponent | Player wins / losses / unresolved (60 each) | Mean rounds |
| --- | --- | ---: |
| Marauder | 27 / 33 / 0 | 11.5 |
| Sentinel | 14 / 33 / 13 | 25.8 |
| Reclaimer | 14 / 37 / 9 | 25.1 |
| Rustjack | 43 / 15 / 2 | 14.4 |
| AXIOM-7 | 19 / 39 / 2 | 18.7 |
| The Hollow Choir | 10 / 46 / 4 | 23.8 |

Rustjack is the easier early raider. Hollow Choir remains the most durable new opponent; its repair selection was reduced during prototyping to avoid excessive stalemates. Physical Android input/performance and human difficulty remain manual checks.

Validation: Godot 4.7.2 import completed without parsing/resource errors; all 52 automated test scripts passed (the updated progression fixture was rerun after adapting its full-enemy-library assertion), plus the 360-match diagnostic and rendered roster checks. Existing AudioStreamMP3/AudioStreamPlaybackMP3 shutdown warnings persist in test runs; no audio code changed.
