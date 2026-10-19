# Cards

Generated from `scripts/card_library.gd` and loaded CardData Resources. Edit each listed `.tres`; descriptions are presentation only, `effects` controls gameplay. Costs spend the listed family. Effects below are exact unmodified values.


## Six starting pools

Each pool has 25 distinct Tier 1 identities. Specialization comes only from membership; no extra player family/effect draw weights. The opening remains 2 Materials / 2 Energy / 2 Crew. New profiles inherit Endeavour's Hull tint and default model fallback; Model Scene remains independently editable.

| Ship | Materials | Energy | Crew | Total |
|---|---|---|---|---|
| Endeavour | 9 | 9 | 7 | 25 |
| Thunderbolt | 4 | 13 | 8 | 25 |
| Titania | 11 | 5 | 9 | 25 |
| Ganymede | 12 | 6 | 7 | 25 |
| Callisto | 7 | 13 | 5 | 25 |
| Orion | 6 | 8 | 11 | 25 |

### Endeavour starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Hull Overhaul, Breach Charge, Salvage Strike, Overloaded Warhead.
- **Energy:** Energy Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion.

### Thunderbolt starting identities

- **Materials:** Shield Plating, Synthesizer Upgrade, Shield Disruptor, Reactor Salvage.
- **Energy:** Energy Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, System Disruption, Energy Siphon, Cargo Raid, Supply Diversion, Desperate Conversion.

### Titania starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Overloaded Warhead.
- **Energy:** Energy Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.

### Ganymede starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Reactor Salvage, Overloaded Warhead.
- **Energy:** Energy Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Energy Siphon, Cargo Raid, Supply Diversion.

### Callisto starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Salvage Strike, Reactor Salvage.
- **Energy:** Energy Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Quarters Upgrade, Energy Siphon, Cargo Raid, Supply Diversion.

### Orion starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Salvage Strike, Reactor Salvage.
- **Energy:** Energy Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, System Disruption, Torpedo Salvo, Energy Siphon, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.

| Card | Family / unchanged cost | Rarity | Allocation | Base effects | Upgrade I | Upgrade II | Extra action (all levels) | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion | Resource |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Shield Plating | materials / 3 | Tier 1 | Defense | `{"shields":4}` | `{"materials":1,"shields":7}` | `{"materials":2,"shields":10}` | false | true | true | true | true | true | true | `cards/01_shield_plating.tres` |
| Shield Array | materials / 4 | Tier 1 | Defense | `{"shields":8}` | `{"shields":12}` | `{"hull":2,"shields":16}` | false | true | false | true | true | true | true | `cards/02_shield_array.tres` |
| Hull Patch | materials / 7 | Tier 1 | Defense | `{"hull":5}` | `{"hull":7,"shields":2}` | `{"hull":10,"shields":3}` | false | true | false | true | true | true | true | `cards/03_hull_patch.tres` |
| Synthesizer Upgrade | materials / 8 | Tier 1 | Systems | `{"synthesizer":1}` | `{"materials":4,"synthesizer":1}` | `{"materials":7,"shields":5,"synthesizer":1}` | false | true | true | true | true | true | true | `cards/04_synthesizer_upgrade.tres` |
| Structural Reinforcement | materials / 6 | Tier 1 | Defense | `{"hull":2,"shields":5}` | `{"hull":3,"shields":8}` | `{"hull":5,"shields":11}` | false | true | false | true | true | true | false | `cards/05_structural_reinforcement.tres` |
| Shield Disruptor | materials / 6 | Tier 1 | Offense | `{"break_shields":6}` | `{"break_shields":9,"damage":2}` | `{"break_shields":12,"damage":4}` | false | false | true | true | true | false | false | `cards/06_shield_disruptor.tres` |
| Hull Overhaul | materials / 10 | Tier 1 | Defense | `{"hull":8}` | `{"hull":10,"shields":4}` | `{"hull":14,"shields":8}` | false | true | false | true | true | false | false | `cards/07_hull_overhaul.tres` |
| Energy Cell | energy / 0 | Tier 1 | Systems | `{"crew":1,"energy":1,"materials":1}` | `{"crew":2,"energy":2,"materials":2}` | `{"crew":3,"energy":3,"materials":3}` | false | true | true | true | true | true | true | `cards/08_energy_cell.tres` |
| Hull Nanobots | energy / 7 | Tier 1 | Defense | `{"hull":5}` | `{"energy":2,"hull":7}` | `{"energy":3,"hull":10}` | false | true | true | false | false | true | false | `cards/09_hull_nanobots.tres` |
| Shield Recharge | energy / 3 | Tier 1 | Defense | `{"shields":6}` | `{"energy":1,"shields":9}` | `{"energy":2,"shields":12}` | false | true | true | true | true | true | true | `cards/10_shield_recharge.tres` |
| Reactor Upgrade | energy / 8 | Tier 1 | Systems | `{"reactor":1}` | `{"energy":4,"reactor":1}` | `{"energy":7,"reactor":1,"shields":5}` | false | true | true | true | true | true | true | `cards/11_reactor_upgrade.tres` |
| Laser Burst | energy / 6 | Tier 1 | Offense | `{"damage":6}` | `{"damage":9,"energy":2}` | `{"damage":12,"energy":3}` | false | true | true | true | true | true | true | `cards/12_laser_burst.tres` |
| Plasma Strike | energy / 9 | Tier 1 | Offense | `{"damage":10}` | `{"break_shields":2,"damage":14}` | `{"break_shields":4,"damage":18}` | false | true | true | false | false | true | true | `cards/13_plasma_strike.tres` |
| Energy Surge | energy / 0 | Tier 1 | Systems | `{"energy":3}` | `{"energy":4}` | `{"energy":5}` | true | true | true | true | true | true | true | `cards/14_energy_surge.tres` |
| Boarding Party | crew / 4 | Tier 1 | Offense | `{"damage":4}` | `{"damage":6,"steal":{"materials":2}}` | `{"damage":8,"steal":{"materials":3}}` | false | true | true | true | true | true | true | `cards/15_boarding_party.tres` |
| Missile Team | crew / 6 | Tier 1 | Offense | `{"damage":6}` | `{"break_shields":2,"damage":9}` | `{"break_shields":3,"damage":12}` | false | true | true | true | true | false | true | `cards/16_missile_team.tres` |
| Shield Breachers | crew / 7 | Tier 1 | Offense | `{"break_shields":8}` | `{"break_shields":11,"damage":3}` | `{"break_shields":14,"damage":5}` | false | false | false | true | false | false | true | `cards/17_shield_breachers.tres` |
| Quarters Upgrade | crew / 8 | Tier 1 | Systems | `{"quarters":1}` | `{"crew":4,"quarters":1}` | `{"crew":7,"quarters":1,"shields":5}` | false | true | true | true | true | true | true | `cards/18_quarters_upgrade.tres` |
| System Disruption | crew / 9 | Tier 1 | Offense | `{"sabotage":true}` | `{"drain":{"energy":3},"sabotage":1}` | `{"damage":3,"drain":{"energy":6},"sabotage":1}` | false | false | true | false | false | false | true | `cards/19_system_disruption.tres` |
| Torpedo Salvo | crew / 10 | Tier 1 | Offense | `{"damage":12}` | `{"break_shields":2,"damage":16}` | `{"break_shields":4,"damage":20}` | false | true | false | true | true | false | true | `cards/20_torpedo_salvo.tres` |
| Phase Lance | energy / 9 | Tier 1 | Offense | `{"damage":10,"pierce":0.5}` | `{"damage":13,"pierce":0.6}` | `{"damage":16,"pierce":0.75}` | false | true | true | false | false | true | true | `cards/21_phase_lance.tres` |
| Energy Siphon | crew / 5 | Tier 1 | Offense | `{"steal":{"energy":5}}` | `{"shields":3,"steal":{"energy":7}}` | `{"shields":6,"steal":{"energy":9}}` | false | false | true | false | true | true | true | `cards/22_energy_siphon.tres` |
| Cargo Raid | crew / 6 | Tier 1 | Offense | `{"damage":4,"steal":{"materials":4}}` | `{"damage":6,"steal":{"materials":6}}` | `{"damage":9,"steal":{"materials":8}}` | false | true | true | true | true | true | true | `cards/23_cargo_raid.tres` |
| Crew Capture | materials / 6 | Tier 1 | Offense | `{"steal":{"crew":4}}` | `{"hull":2,"steal":{"crew":6}}` | `{"hull":4,"steal":{"crew":8}}` | false | false | false | true | true | false | false | `cards/24_crew_capture.tres` |
| Drain Beam | energy / 8 | Tier 1 | Offense | `{"drain":{"crew":7,"energy":7,"materials":7}}` | `{"drain":{"crew":9,"energy":9,"materials":9},"shields":3}` | `{"drain":{"crew":11,"energy":11,"materials":11},"shields":6}` | false | false | true | false | false | true | false | `cards/25_emp_pulse.tres` |
| Shield Exchange | energy / 8 | Tier 1 | Offense | `{"swap_shields":true}` | `{"damage":3,"swap_shields":true}` | `{"damage":6,"energy":2,"swap_shields":true}` | false | false | true | false | false | true | false | `cards/26_shield_exchange.tres` |
| Missile Barrage | crew / 13 | Tier 1 | Offense | `{"damage":16}` | `{"damage":21}` | `{"break_shields":4,"damage":26}` | false | true | false | true | false | false | true | `cards/27_missile_barrage.tres` |
| Breach Charge | materials / 8 | Tier 1 | Offense | `{"break_shields":8,"damage":4}` | `{"break_shields":11,"damage":6}` | `{"break_shields":14,"damage":9}` | false | true | false | true | true | false | false | `cards/28_breach_charge.tres` |
| Polaron Burst | energy / 10 | Tier 1 | Offense | `{"break_shields":8,"drain":{"energy":4}}` | `{"break_shields":11,"drain":{"energy":6}}` | `{"break_shields":14,"damage":3,"drain":{"energy":8}}` | false | false | true | false | false | true | false | `cards/29_polaron_burst.tres` |
| Siege Driver | materials / 18 | Tier 2 | Offense | `{"damage":24}` | `{"break_shields":3,"damage":29}` | `{"break_shields":6,"damage":34}` | false | false | false | false | false | false | false | `cards/30_siege_driver.tres` |
| Emergency Refit | materials / 20 | Tier 2 | Defense | `{"hull":14,"shields":8}` | `{"hull":18,"shields":12}` | `{"hull":22,"shields":16}` | false | false | false | false | false | false | false | `cards/31_emergency_refit.tres` |
| Antimatter Lance | energy / 20 | Tier 2 | Offense | `{"damage":20,"pierce":0.5}` | `{"damage":24,"pierce":0.6}` | `{"damage":28,"pierce":0.75}` | false | false | false | false | false | false | false | `cards/32_antimatter_lance.tres` |
| Omega Overcharge | energy / 16 | Tier 2 | Defense | `{"hull":6,"shields":20}` | `{"hull":8,"shields":26}` | `{"hull":10,"shields":32}` | false | false | false | false | false | false | false | `cards/33_omega_overcharge.tres` |
| Sabotage Commandos | crew / 18 | Tier 2 | Offense | `{"damage":18,"sabotage":2}` | `{"damage":22,"drain":{"energy":3},"sabotage":2}` | `{"damage":26,"drain":{"energy":6},"sabotage":2}` | false | false | false | false | false | false | false | `cards/34_sabotage_commandos.tres` |
| Damage Control | crew / 23 | Tier 2 | Defense | `{"hull":18,"shields":6}` | `{"hull":22,"shields":10}` | `{"hull":26,"shields":14}` | false | false | false | false | false | false | false | `cards/35_damage_control.tres` |
| Salvage Strike | materials / 5 | Tier 1 | Offense | `{"damage":4,"random_gain":2}` | `{"damage":6,"random_gain":3}` | `{"damage":9,"random_gain":4}` | false | true | false | true | true | true | true | `cards/36_salvage_strike.tres` |
| Pulse Repeater | energy / 6 | Tier 1 | Offense | `{"damage":3}` | `{"damage":5}` | `{"damage":7}` | true | true | true | false | true | true | true | `cards/37_pulse_repeater.tres` |
| Cataclysm Protocol | crew / 26 | Tier 2 | Offense | `{"damage":18,"hull":15}` | `{"damage":22,"hull":18}` | `{"damage":26,"hull":21}` | false | false | false | false | false | false | false | `cards/38_cataclysm_protocol.tres` |
| Reactor Salvage | materials / 7 | Tier 1 | Systems | `{"production_other":{"production":1,"resource":5,"type":"reactor"}}` | `{"production_other":{"production":1,"resource":8,"type":"reactor"}}` | `{"production_other":{"production":1,"resource":11,"type":"reactor"},"shields":4}` | false | false | true | false | true | true | true | `cards/39_reactor_salvage.tres` |
| Supply Diversion | crew / 4 | Tier 1 | Systems | `{"random_gain_other":2}` | `{"random_gain_other":3}` | `{"random_gain_other":4}` | true | true | true | true | true | true | true | `cards/40_supply_diversion.tres` |
| Shield Collapse | energy / 6 | Tier 1 | Offense | `{"shield_collapse":{"chance":0.5,"self_damage":10,"threshold":10}}` | `{"shield_collapse":{"chance":0.35,"self_damage":7,"threshold":10}}` | `{"shield_collapse":{"chance":0.2,"self_damage":4,"threshold":10}}` | false | false | true | false | false | true | false | `cards/41_shield_collapse.tres` |
| Overloaded Warhead | materials / 7 | Tier 1 | Offense | `{"damage":10,"self_damage":4}` | `{"damage":13,"self_damage":3}` | `{"damage":16,"self_damage":2}` | false | true | false | true | true | false | false | `cards/42_overloaded_warhead.tres` |
| Emergency Reserves | energy / 13 | Tier 2 | Systems | `{"random_gain_range_other":{"max":15,"min":12}}` | `{"random_gain_range_other":{"max":18,"min":16}}` | `{"random_gain_range_other":{"max":22,"min":19}}` | false | false | false | false | false | false | false | `cards/43_emergency_reserves.tres` |
| Desperate Conversion | crew / 9 | Tier 1 | Systems | `{"random_gain_other":20,"self_damage_regular":8}` | `{"random_gain_other":23,"self_damage_regular":6}` | `{"random_gain_other":26,"self_damage_regular":4}` | false | false | true | true | false | false | true | `cards/44_desperate_conversion.tres` |

## Draws and upgrades

Six-card hands; maximum 2 copies per identity and at most one card of each tier above Common. Tier 2 draw chance 15.0%, locked through round 2; Tier 3 chance 0.0%. Temporal Rift multiplies Tier 2 chance by 2.0. Missing eligible higher-tier bucket falls back to Common. Tune CardHand/EnemyHand in `scenes/board.tscn` or defaults in `scripts/card_hand.gd`.

Acquisitions offer up to 3 distinct unowned identities, choose 1; 60% Tier 2 / 40% Tier 1 per slot when both buckets have candidates (configurable). A missing bucket falls back to remaining eligible identities without violating the minimum tier. Fewer than three eligible identities show fewer choices; exhaustion resolves immediately with an explanation and no currency change. Acquired identities use ×3.0 draw weight within rarity, player only; rarity odds and hand caps remain unchanged. Starting identities each weigh 1. Inspector: `encounters/expedition_rules.tres` → Reward Tier Two Chance / Acquired Card Draw Weight.

Every card has two full replacement effect dictionaries on its CardData Resource. Upgrade level is independent of rarity; cost and extra-action flag stay unchanged. All player copies, including held cards, resolve to the upgraded identity; enemies always retain base Resources. Production stays +1 per play; upgraded production cards gain immediate resources/defense. Play-again cards gain no new action grants or cost refunds. Hull gains can still create existing Ablative Plating; high-cost repairs scale conservatively. Fully upgraded research retains the existing 4 Salvage fallback.

## Effect keys (`scripts/card_effects.gd`)

| Key | Resolution |
|---|---|
| `hull`, `shields`, resource or production key | Add to acting ship; excess Hull is Ablative Plating |
| `damage`, `pierce` | Damage; floor(damage × pierce) bypasses Shields, remaining damage consumes Shields then Hull/plating |
| `break_shields` | Remove specified enemy Shields before damage |
| `drain`, `steal` | Remove available enemy resource (floor 0); steal adds the amount actually removed to actor |
| `sabotage` | Lower every enemy production by amount; floor 1 |
| `production_other` | Add specified production/resource only if corresponding resource differs from card family |
| `random_gain` | Uniformly choose one of 3 resources and add amount |
| `random_gain_other`, `random_gain_range_other` | Uniformly choose one of 2 other families; fixed amount or inclusive uniform integer range |
| `swap_shields` | Exchange current Shield amounts |
| `shield_collapse` | Remove all enemy Shields; at or above threshold, stated chance of regular self-damage |
| `shield_collapse_below` | Remove all enemy Shields strictly below threshold |
| `self_damage` / `self_damage_regular` | Direct Hull/plating loss / Shield-first damage |

Discard gives floor(cost / 3) matching resources (`scripts/board.gd`). Extra actions grant no turn income or EMP Pulse charge. **Planned, not implemented:** Tier 3 card library, deck trimming. Pirate rewards currently use Uncommon-or-better, the highest populated tier; no empty rare selection screen.

## Power Allocation

Player opening hands contain two Materials-cost, two Energy-cost and two Crew-cost cards, chosen within the actual ship pool with existing rarity and duplicate eligibility. Slot families are seed-shuffled. Eligible fixed Inspector cards keep their slots only within those quotas. Incomplete custom pools fall back to other valid cards rather than blocking a draw. This opening-only guarantee does not constrain replacement families or enemy hands.

Balanced is the default at each battle start. Offense, Defense and Systems multiply matching player cards by the fixed Inspector weight (default 2). Switching is free, unrestricted by turns, and affects future replacement draws only: no hand mutation or RNG consumption on selection. No upgrades, resource costs or cooldowns.

Every CardData identity has exactly one `allocation_category`, editable in its `cards/*.tres` Resource and retained through both upgrades. Offense covers damage, shield breaking, theft, sabotage and disruption (including Shield Exchange). Defense covers Hull/Shields and protection. Systems covers resource generation and production. Mixed-purpose Salvage Strike and Cataclysm Protocol remain Offense; production cards remain Systems despite upgraded secondary defenses. The table lists every identity's primary purpose. These categories are independent of the gallery's overlapping effect filters and enemy preference categories.

The existing rarity roll and eligible bucket are chosen first, with the same round lock and duplicate caps. Within that bucket: `weight = identity_weight × existing_preference_weight × allocation_factor`; `P(card) = weight / sum(eligible weights)`. `allocation_factor = matching_draw_weight` only for the selected primary category, otherwise 1. Balanced and a bucket without matching cards therefore use the original probabilities. No cards are removed and every existing positive weight stays positive; cost/affordability never filters draws. Enemy hands do not enable allocation and retain their existing weights and AI.

Inspector: `resources/power_allocation.tres` → Matching Draw Weight (default 2.0); Board → Allocation Settings can reference an alternate configuration. The player hand snapshots the value once at battle start; modes never change it during battle. `scripts/ui/power_allocation_popup.gd` owns the reusable centered 2×2 modal. The current-mode emoji sits in the existing combat action strip above the hand, anchored identically at 16:9 and 21:9. Cards, hand timing and dimensions are unchanged.
