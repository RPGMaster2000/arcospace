# Cards

Generated from `scripts/cards/card_library.gd` and loaded CardData Resources. Edit each listed `.tres`; descriptions are presentation only, `effects` controls gameplay. Costs spend the listed family. Effects below are exact unmodified values.


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
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion.

### Thunderbolt starting identities

- **Materials:** Shield Plating, Synthesizer Upgrade, Shield Disruptor, Reactor Salvage.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, System Disruption, Energy Siphon, Cargo Raid, Supply Diversion, Desperate Conversion.

### Titania starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Overloaded Warhead.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, Torpedo Salvo, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.

### Ganymede starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Shield Disruptor, Hull Overhaul, Crew Capture, Breach Charge, Salvage Strike, Reactor Salvage, Overloaded Warhead.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Energy Surge, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Quarters Upgrade, Torpedo Salvo, Energy Siphon, Cargo Raid, Supply Diversion.

### Callisto starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Structural Reinforcement, Salvage Strike, Reactor Salvage.
- **Energy:** Emergency Power Cell, Hull Nanobots, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Drain Beam, Shield Exchange, Polaron Burst, Pulse Repeater, Shield Collapse.
- **Crew:** Boarding Party, Quarters Upgrade, Energy Siphon, Cargo Raid, Supply Diversion.

### Orion starting identities

- **Materials:** Shield Plating, Shield Array, Hull Patch, Synthesizer Upgrade, Salvage Strike, Reactor Salvage.
- **Energy:** Emergency Power Cell, Shield Recharge, Reactor Upgrade, Laser Burst, Plasma Strike, Energy Surge, Phase Lance, Pulse Repeater.
- **Crew:** Boarding Party, Missile Team, Shield Breachers, Quarters Upgrade, System Disruption, Torpedo Salvo, Energy Siphon, Cargo Raid, Missile Barrage, Supply Diversion, Desperate Conversion.


## Expanded library and deck capacity

The library contains 68 identities: 49 Tier 1 and 19 Tier 2. Cards 45–68 add eight per family (13 Tier 1 / 11 Tier 2). None is automatically added to the six original 25-identity starting pools. Tier 2 still unlocks in round 3 with at most one in a hand. Existing acquisition tier probabilities and acquired weight ×3.0 remain unchanged; enemies draw the full base library.

`ExpeditionRules.max_deck_identities` defaults to **30**, Inspector label **Max Deck Identities** (range 25–100). Starting and acquired identities count once; upgrades/copies do not. Capacity cannot invalidate a custom starting pool larger than its configured limit. Ordinary acquisitions grow the pool until full. Selecting a reward at capacity fixes that incoming card and opens the existing gallery as **Deck Full**. Select an owned identity, explicitly Replace Card, or Keep Current Deck. No removal happens before confirmation; declining gives no refund. Removed identities lose their private upgrade and acquired weight; retained identities keep theirs. A removed starting identity may be acquired again at base level with normal acquired weight.

Replacement state is `pending_card`, `pending_choice = replace`, `removed_starting_cards`, `acquired_cards` and `upgraded_cards`. It survives screen rebuilds and normal in-memory expedition transitions. There is no disk save/load in this prototype, so application exit still ends the run. Deck Viewer shows actual owned count / capacity. Costs, six-card hands, rarity caps, Power Allocation and the weighted replacement-draw model remain unchanged.

## Generic conditionals, exchanges and production

Card costs are paid first. Ordinary effect keys resolve in the existing order, then `conditional` evaluates the live state and applies either `then` or `else` without another payment. Conditions may nest. `target` is `self` or `enemy`; `attribute` is a state key; comparisons are `below`, `at_most`, `equal`, `at_least`, `above`. `threshold` is a number. Use `fraction_of: hull_capacity` with threshold 0.5 for 50% of that ship's original capacity, including difficulty scaling; current plating does not increase the denominator. Alternatively `compare_target` / `compare_attribute` replace the numeric threshold with a live stat comparison.

Example: `conditional = {target: enemy, attribute: reactor, comparison: above, compare_target: self, compare_attribute: reactor, then: {reactor: 1}, else: {energy: 5}}`. In the Inspector these are ordinary nested Dictionaries in **Effects** or either **Upgrade Effects** entry; all amounts and predicates remain editable.

`swap_resource: materials` exchanges the two Materials reserves from one snapshot. Only materials/energy/crew are accepted, and the card's cost family is rejected. This never swaps production. `enemy_production: {reactor: -1}` adjusts only the named enemy production, floored at 1; existing own production keys add their signed amount, also floored at 1. New production adjustments remain ±1 at all three authored levels.

Existing `break_shields` means Shield-only damage, with no Hull spillover. New Hull attacks use existing `damage` plus `pierce: 1.0`, so Shields stay intact and existing Ablative Plating absorbs Hull damage first. Regular damage retains Shield-first spillover. No new damage system is introduced.

Conditions for Hull Patch, Torpedo Salvo, Tactical Assessment and Emergency Medical Team choose a complete effect branch before healing/attacking. Laser Burst checks after its primary attack; Shield Breachers and Demolition Crew check after breaking Shields. Other thresholds see the state after their main effects. Thresholds do not change with upgrades.

Ion Storm scales numerical outcomes, including nested branches, using the existing floor rounding; predicates, percentages, comparisons, swap identity and cost stay fixed. Production effects may scale during Ion Storm as before. Nebula classifies potential hostile branches, exchanges and targeted production changes as combat; a miss spends the cost and suppresses that card's benefits/attacks using existing rules. Solar Flare still reserves/restores Shields. The existing AI values conditional/exchange results through the same conservative state simulation; preference categories and gallery filters inspect both branches.

## Revised original identities

The eight original paths/memberships remain. **Emergency Power Cell** keeps `08_energy_cell.tres`, cost 0 and turn consumption. Shield Plating remains cost 3, Hull Patch/Nanobots 7, Laser Burst/Missile Team 6, Shield Breachers 7 and Torpedo Salvo 10. Their three complete effect sets appear in the catalogue below. Other original 36 card Resources are unchanged.

## New card tiers

Costs and all three effect sets are in the catalogue below. Each new identity has its own CardData Resource.

| Family | Tier 1 | Tier 2 |
|---|---|---|
| Materials | Emergency Bulkheads, Structural Reclamation, Siege Charges, Salvage Cannibalization, Demolition Crew | Industrial Sabotage, Reinforced Foundations, Resource Seizure |
| Energy | Capacitor Overload, Power Grid Reroute, Emergency Discharge, Feedback Loop | Reactor Synchronization, Phase Inverter, Energy Equalizer, Auxiliary Power Link |
| Crew | Tactical Assessment, Emergency Medical Team, Damage Control Teams, Coordinated Assault | Boarding Specialists, Personnel Exchange, Scientific Breakthrough, Sabotage Operation |

| Card | Family / unchanged cost | Rarity | Allocation | Base effects | Upgrade I | Upgrade II | Extra action (all levels) | Endeavour | Thunderbolt | Titania | Ganymede | Callisto | Orion | Resource |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Shield Plating | materials / 3 | Tier 1 | Defense | `{"crew":2,"shields":4}` | `{"crew":3,"shields":6}` | `{"crew":4,"shields":8}` | false | true | true | true | true | true | true | `cards/01_shield_plating.tres` |
| Shield Array | materials / 4 | Tier 1 | Defense | `{"shields":8}` | `{"shields":12}` | `{"hull":2,"shields":16}` | false | true | false | true | true | true | true | `cards/02_shield_array.tres` |
| Hull Patch | materials / 7 | Tier 1 | Defense | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"hull":5},"target":"self","then":{"hull":5,"shields":5},"threshold":20}}` | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"hull":7},"target":"self","then":{"hull":7,"shields":6},"threshold":20}}` | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"hull":9},"target":"self","then":{"hull":9,"shields":7},"threshold":20}}` | false | true | false | true | true | true | true | `cards/03_hull_patch.tres` |
| Synthesizer Upgrade | materials / 8 | Tier 1 | Systems | `{"synthesizer":1}` | `{"materials":4,"synthesizer":1}` | `{"materials":7,"shields":5,"synthesizer":1}` | false | true | true | true | true | true | true | `cards/04_synthesizer_upgrade.tres` |
| Structural Reinforcement | materials / 6 | Tier 1 | Defense | `{"hull":2,"shields":5}` | `{"hull":3,"shields":8}` | `{"hull":5,"shields":11}` | false | true | false | true | true | true | false | `cards/05_structural_reinforcement.tres` |
| Shield Disruptor | materials / 6 | Tier 1 | Offense | `{"break_shields":6}` | `{"break_shields":9,"damage":2}` | `{"break_shields":12,"damage":4}` | false | false | true | true | true | false | false | `cards/06_shield_disruptor.tres` |
| Hull Overhaul | materials / 10 | Tier 1 | Defense | `{"hull":8}` | `{"hull":10,"shields":4}` | `{"hull":14,"shields":8}` | false | true | false | true | true | false | false | `cards/07_hull_overhaul.tres` |
| Emergency Power Cell | energy / 0 | Tier 1 | Systems | `{"conditional":{"attribute":"energy","comparison":"at_most","target":"self","then":{"energy":3},"threshold":5},"crew":3,"materials":3}` | `{"conditional":{"attribute":"energy","comparison":"at_most","target":"self","then":{"energy":4},"threshold":5},"crew":3,"materials":4}` | `{"conditional":{"attribute":"energy","comparison":"at_most","target":"self","then":{"energy":5},"threshold":5},"crew":4,"materials":4}` | false | true | true | true | true | true | true | `cards/08_energy_cell.tres` |
| Hull Nanobots | energy / 7 | Tier 1 | Defense | `{"hull":5,"materials":3}` | `{"hull":7,"materials":4}` | `{"hull":9,"materials":5}` | false | true | true | false | false | true | false | `cards/09_hull_nanobots.tres` |
| Shield Recharge | energy / 3 | Tier 1 | Defense | `{"shields":6}` | `{"energy":1,"shields":9}` | `{"energy":2,"shields":12}` | false | true | true | true | true | true | true | `cards/10_shield_recharge.tres` |
| Reactor Upgrade | energy / 8 | Tier 1 | Systems | `{"reactor":1}` | `{"energy":4,"reactor":1}` | `{"energy":7,"reactor":1,"shields":5}` | false | true | true | true | true | true | true | `cards/11_reactor_upgrade.tres` |
| Laser Burst | energy / 6 | Tier 1 | Offense | `{"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"damage":3},"threshold":0},"damage":6}` | `{"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"damage":4},"threshold":0},"damage":8}` | `{"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"damage":5},"threshold":0},"damage":10}` | false | true | true | true | true | true | true | `cards/12_laser_burst.tres` |
| Plasma Strike | energy / 9 | Tier 1 | Offense | `{"damage":10}` | `{"break_shields":2,"damage":14}` | `{"break_shields":4,"damage":18}` | false | true | true | false | false | true | true | `cards/13_plasma_strike.tres` |
| Energy Surge | energy / 0 | Tier 1 | Systems | `{"energy":3}` | `{"energy":4}` | `{"energy":5}` | true | true | true | true | true | true | true | `cards/14_energy_surge.tres` |
| Boarding Party | crew / 4 | Tier 1 | Offense | `{"damage":4}` | `{"damage":6,"steal":{"materials":2}}` | `{"damage":8,"steal":{"materials":3}}` | false | true | true | true | true | true | true | `cards/15_boarding_party.tres` |
| Missile Team | crew / 6 | Tier 1 | Offense | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"damage":6},"target":"enemy","then":{"break_shields":4,"damage":6},"threshold":10}}` | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"damage":8},"target":"enemy","then":{"break_shields":5,"damage":8},"threshold":10}}` | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"damage":10},"target":"enemy","then":{"break_shields":6,"damage":10},"threshold":10}}` | false | true | true | true | true | false | true | `cards/16_missile_team.tres` |
| Shield Breachers | crew / 7 | Tier 1 | Offense | `{"break_shields":8,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"materials":4},"threshold":0}}` | `{"break_shields":11,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"materials":5},"threshold":0}}` | `{"break_shields":14,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"materials":6},"threshold":0}}` | false | false | false | true | false | false | true | `cards/17_shield_breachers.tres` |
| Quarters Upgrade | crew / 8 | Tier 1 | Systems | `{"quarters":1}` | `{"crew":4,"quarters":1}` | `{"crew":7,"quarters":1,"shields":5}` | false | true | true | true | true | true | true | `cards/18_quarters_upgrade.tres` |
| System Disruption | crew / 9 | Tier 1 | Offense | `{"random_sabotage":1}` | `{"drain":{"energy":3},"random_sabotage":1}` | `{"damage":3,"drain":{"energy":6},"random_sabotage":1}` | false | false | true | false | false | false | true | `cards/19_system_disruption.tres` |
| Torpedo Salvo | crew / 10 | Tier 1 | Offense | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"damage":12},"target":"enemy","then":{"damage":16},"threshold":15}}` | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"damage":15},"target":"enemy","then":{"damage":20},"threshold":15}}` | `{"conditional":{"attribute":"hull","comparison":"at_most","else":{"damage":18},"target":"enemy","then":{"damage":24},"threshold":15}}` | false | true | false | true | true | false | true | `cards/20_torpedo_salvo.tres` |
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
| Emergency Bulkheads | materials / 8 | Tier 1 | Defense | `{"conditional":{"attribute":"hull","comparison":"at_most","target":"self","then":{"shields":5},"threshold":20},"shields":9}` | `{"conditional":{"attribute":"hull","comparison":"at_most","target":"self","then":{"shields":6},"threshold":20},"shields":11}` | `{"conditional":{"attribute":"hull","comparison":"at_most","target":"self","then":{"shields":7},"threshold":20},"shields":13}` | false | false | false | false | false | false | false | `cards/45_emergency_bulkheads.tres` |
| Structural Reclamation | materials / 10 | Tier 1 | Defense | `{"crew":3,"energy":4,"hull":5,"shields":-3}` | `{"crew":3,"energy":5,"hull":6,"shields":-3}` | `{"crew":4,"energy":5,"hull":7,"shields":-3}` | false | false | false | false | false | false | false | `cards/46_structural_reclamation.tres` |
| Siege Charges | materials / 12 | Tier 1 | Offense | `{"conditional":{"attribute":"shields","comparison":"at_most","target":"enemy","then":{"damage":7,"pierce":1.0},"threshold":5},"damage":9,"pierce":1.0}` | `{"conditional":{"attribute":"shields","comparison":"at_most","target":"enemy","then":{"damage":8,"pierce":1.0},"threshold":5},"damage":11,"pierce":1.0}` | `{"conditional":{"attribute":"shields","comparison":"at_most","target":"enemy","then":{"damage":9,"pierce":1.0},"threshold":5},"damage":13,"pierce":1.0}` | false | false | false | false | false | false | false | `cards/47_siege_charges.tres` |
| Industrial Sabotage | materials / 14 | Tier 2 | Offense | `{"conditional":{"attribute":"materials","comparison":"at_least","target":"enemy","then":{"energy":6},"threshold":15},"enemy_production":{"synthesizer":-1}}` | `{"conditional":{"attribute":"materials","comparison":"at_least","target":"enemy","then":{"energy":8},"threshold":15},"enemy_production":{"synthesizer":-1}}` | `{"conditional":{"attribute":"materials","comparison":"at_least","target":"enemy","then":{"energy":10},"threshold":15},"enemy_production":{"synthesizer":-1}}` | false | false | false | false | false | false | false | `cards/48_industrial_sabotage.tres` |
| Salvage Cannibalization | materials / 9 | Tier 1 | Defense | `{"energy":5,"hull":7,"shields":-5}` | `{"energy":6,"hull":9,"shields":-5}` | `{"energy":7,"hull":11,"shields":-5}` | false | false | false | false | false | false | false | `cards/49_salvage_cannibalization.tres` |
| Demolition Crew | materials / 11 | Tier 1 | Offense | `{"break_shields":8,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"drain":{"crew":5}},"threshold":0}}` | `{"break_shields":10,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"drain":{"crew":6}},"threshold":0}}` | `{"break_shields":12,"conditional":{"attribute":"shields","comparison":"equal","target":"enemy","then":{"drain":{"crew":7}},"threshold":0}}` | false | false | false | false | false | false | false | `cards/50_demolition_crew.tres` |
| Reinforced Foundations | materials / 13 | Tier 2 | Systems | `{"hull":4,"shields":6,"synthesizer":1}` | `{"hull":5,"shields":8,"synthesizer":1}` | `{"hull":6,"shields":10,"synthesizer":1}` | false | false | false | false | false | false | false | `cards/51_reinforced_foundations.tres` |
| Resource Seizure | materials / 15 | Tier 2 | Offense | `{"crew":4,"damage":4,"pierce":1.0,"swap_resource":"energy"}` | `{"crew":5,"damage":5,"pierce":1.0,"swap_resource":"energy"}` | `{"crew":6,"damage":6,"pierce":1.0,"swap_resource":"energy"}` | false | false | false | false | false | false | false | `cards/52_resource_seizure.tres` |
| Capacitor Overload | energy / 11 | Tier 1 | Offense | `{"break_shields":8,"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"break_shields":7},"threshold":10}}` | `{"break_shields":10,"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"break_shields":8},"threshold":10}}` | `{"break_shields":12,"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"break_shields":9},"threshold":10}}` | false | false | false | false | false | false | false | `cards/53_capacitor_overload.tres` |
| Power Grid Reroute | energy / 9 | Tier 1 | Systems | `{"crew":3,"materials":5,"shields":6}` | `{"crew":3,"materials":6,"shields":8}` | `{"crew":4,"materials":6,"shields":10}` | false | false | false | false | false | false | false | `cards/54_power_grid_reroute.tres` |
| Reactor Synchronization | energy / 15 | Tier 2 | Systems | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"materials":7},"target":"enemy","then":{"reactor":1},"threshold":0}}` | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"materials":9},"target":"enemy","then":{"reactor":1,"shields":2},"threshold":0}}` | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"materials":11},"target":"enemy","then":{"reactor":1,"shields":4},"threshold":0}}` | false | false | false | false | false | false | false | `cards/55_reactor_synchronization.tres` |
| Phase Inverter | energy / 17 | Tier 2 | Offense | `{"break_shields":5,"crew":5,"enemy_production":{"reactor":-1}}` | `{"break_shields":7,"crew":6,"enemy_production":{"reactor":-1}}` | `{"break_shields":9,"crew":7,"enemy_production":{"reactor":-1}}` | false | false | false | false | false | false | false | `cards/56_phase_inverter.tres` |
| Emergency Discharge | energy / 10 | Tier 1 | Offense | `{"break_shields":12,"materials":3,"shields":4}` | `{"break_shields":15,"materials":3,"shields":5}` | `{"break_shields":18,"materials":4,"shields":6}` | false | false | false | false | false | false | false | `cards/57_emergency_discharge.tres` |
| Energy Equalizer | energy / 14 | Tier 2 | Systems | `{"shields":4,"swap_resource":"materials"}` | `{"shields":6,"swap_resource":"materials"}` | `{"shields":8,"swap_resource":"materials"}` | false | false | false | false | false | false | false | `cards/58_energy_equalizer.tres` |
| Feedback Loop | energy / 12 | Tier 1 | Offense | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"materials":5,"shields":4},"target":"enemy","then":{"break_shields":14},"threshold":12}}` | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"materials":6,"shields":5},"target":"enemy","then":{"break_shields":17},"threshold":12}}` | `{"conditional":{"attribute":"shields","comparison":"at_least","else":{"materials":7,"shields":6},"target":"enemy","then":{"break_shields":20},"threshold":12}}` | false | false | false | false | false | false | false | `cards/59_feedback_loop.tres` |
| Auxiliary Power Link | energy / 13 | Tier 2 | Systems | `{"crew":3,"materials":4,"reactor":1,"shields":-4}` | `{"crew":4,"materials":5,"reactor":1,"shields":-4}` | `{"crew":5,"materials":6,"reactor":1,"shields":-4}` | false | false | false | false | false | false | false | `cards/60_auxiliary_power_link.tres` |
| Tactical Assessment | crew / 9 | Tier 1 | Offense | `{"conditional":{"attribute":"hull","comparison":"below","else":{"damage":7,"pierce":1.0},"fraction_of":"hull_capacity","target":"enemy","then":{"damage":13,"pierce":1.0},"threshold":0.5}}` | `{"conditional":{"attribute":"hull","comparison":"below","else":{"damage":9,"pierce":1.0},"fraction_of":"hull_capacity","target":"enemy","then":{"damage":16,"pierce":1.0},"threshold":0.5}}` | `{"conditional":{"attribute":"hull","comparison":"below","else":{"damage":11,"pierce":1.0},"fraction_of":"hull_capacity","target":"enemy","then":{"damage":19,"pierce":1.0},"threshold":0.5}}` | false | false | false | false | false | false | false | `cards/61_tactical_assessment.tres` |
| Emergency Medical Team | crew / 10 | Tier 1 | Defense | `{"conditional":{"attribute":"hull","comparison":"below","else":{"hull":6},"fraction_of":"hull_capacity","target":"self","then":{"hull":12},"threshold":0.5}}` | `{"conditional":{"attribute":"hull","comparison":"below","else":{"hull":8},"fraction_of":"hull_capacity","target":"self","then":{"hull":15},"threshold":0.5}}` | `{"conditional":{"attribute":"hull","comparison":"below","else":{"hull":10},"fraction_of":"hull_capacity","target":"self","then":{"hull":18},"threshold":0.5}}` | false | false | false | false | false | false | false | `cards/62_emergency_medical_team.tres` |
| Boarding Specialists | crew / 14 | Tier 2 | Offense | `{"damage":5,"pierce":1.0,"swap_resource":"materials"}` | `{"damage":7,"pierce":1.0,"swap_resource":"materials"}` | `{"damage":9,"pierce":1.0,"swap_resource":"materials"}` | false | false | false | false | false | false | false | `cards/63_boarding_specialists.tres` |
| Personnel Exchange | crew / 17 | Tier 2 | Systems | `{"enemy_production":{"quarters":-1},"quarters":1}` | `{"enemy_production":{"quarters":-1},"materials":2,"quarters":1}` | `{"enemy_production":{"quarters":-1},"materials":4,"quarters":1}` | false | false | false | false | false | false | false | `cards/64_personnel_exchange.tres` |
| Scientific Breakthrough | crew / 12 | Tier 2 | Systems | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"energy":5},"target":"enemy","then":{"reactor":1},"threshold":0}}` | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"energy":7},"target":"enemy","then":{"materials":2,"reactor":1},"threshold":0}}` | `{"conditional":{"attribute":"reactor","compare_attribute":"reactor","compare_target":"self","comparison":"above","else":{"energy":9},"target":"enemy","then":{"materials":4,"reactor":1},"threshold":0}}` | false | false | false | false | false | false | false | `cards/65_scientific_breakthrough.tres` |
| Damage Control Teams | crew / 9 | Tier 1 | Defense | `{"hull":5,"materials":3,"shields":5}` | `{"hull":6,"materials":3,"shields":7}` | `{"hull":7,"materials":4,"shields":9}` | false | false | false | false | false | false | false | `cards/66_damage_control_teams.tres` |
| Sabotage Operation | crew / 13 | Tier 2 | Offense | `{"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"drain":{"energy":7},"materials":4},"threshold":15},"enemy_production":{"reactor":-1}}` | `{"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"drain":{"energy":9},"materials":5},"threshold":15},"enemy_production":{"reactor":-1}}` | `{"conditional":{"attribute":"energy","comparison":"at_least","target":"enemy","then":{"drain":{"energy":11},"materials":6},"threshold":15},"enemy_production":{"reactor":-1}}` | false | false | false | false | false | false | false | `cards/67_sabotage_operation.tres` |
| Coordinated Assault | crew / 12 | Tier 1 | Offense | `{"break_shields":6,"damage":6,"energy":4,"pierce":1.0}` | `{"break_shields":8,"damage":8,"energy":5,"pierce":1.0}` | `{"break_shields":10,"damage":10,"energy":6,"pierce":1.0}` | false | false | false | false | false | false | false | `cards/68_coordinated_assault.tres` |

## Draws and upgrades

Six-card hands; maximum 2 copies per identity and at most one card of each tier above Common. Tier 2 draw chance 15.0%, locked through round 2; Tier 3 chance 0.0%. Temporal Rift multiplies Tier 2 chance by 2.0. Missing eligible higher-tier bucket falls back to Common. Tune CardHand/EnemyHand in `scenes/board.tscn` or defaults in `scripts/cards/card_hand.gd`.

Acquisitions offer up to 3 distinct unowned identities, choose 1; 60% Tier 2 / 40% Tier 1 per slot when both buckets have candidates (configurable). A missing bucket falls back to remaining eligible identities without violating the minimum tier. Fewer than three eligible identities show fewer choices; exhaustion resolves immediately with an explanation and no currency change. Acquired identities use ×3.0 draw weight within rarity, player only; rarity odds and hand caps remain unchanged. Starting identities each weigh 1. Inspector: `encounters/expedition_rules.tres` → Reward Tier Two Chance / Acquired Card Draw Weight.

Every card has two full replacement effect dictionaries on its CardData Resource. Upgrade level is independent of rarity; cost and extra-action flag stay unchanged. All player copies, including held cards, resolve to the upgraded identity; enemies always retain base Resources. Production stays +1 per play; upgraded production cards gain immediate resources/defense. Play-again cards gain no new action grants or cost refunds. Hull gains can still create existing Ablative Plating; high-cost repairs scale conservatively. Fully upgraded research retains the existing 4 Salvage fallback.


## Combat upgrade events and Chasedown

Non-escape victories offer up to 1 / 2 / 3 / 3 upgrades for Chasedown / standard / elite / boss battles. Each selection must be a different card identity within that event; a later event can upgrade the identity again. Existing two-level limits remain. Finish skips unused choices; exhausted combat upgrades grant no extra Salvage. EMP Pulse escape grants no upgrades or Salvage. Quantities: `ExpeditionRules` → Combat Upgrades.

Sublight Chasedown: 5% per valid PoI-to-PoI movement, limit 1 per system. Initial entry, menus, invalid/same destinations, battle return and FTL travel never roll. Uses ordinary enemies, existing scaling and battle scene, gives exactly +1 FTL once on victory or escape, then resumes the preserved destination. See [implementation and tuning](../chasedown_rewards.md).
## Effect keys (`scripts/cards/card_effects.gd`)

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

## Card presentation

Normal cards use 14 px data-derived summaries and a fixed artwork rectangle. Hold or middle-click any card to inspect the original-scene copy beside full base/upgrade effects. Tuning: `resources/card_presentation.tres`; implementation and gesture/confirmation rules: [UI layout](../ui_layout.md#compact-cards-and-universal-inspection). No gameplay values are duplicated in presentation.
