# Enemy deck audit

Card roles overlap. An effect in a conditional branch counts toward its role.
Affordability samples cards held at turn start. Plays and discards are battle totals.

| Faction | Ship | Role | Pool | M/E/C slots | M/E/C start | S/R/Q | Hull / Shields | Mean rounds | Player wins | Off / def / recovery / econ / disrupt |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| axiom_collective | AXIOM Enforcer | Heavy Precision Vessel | 20 authored | 3/13/4 | 8/14/10 | 1/3/2 | 39 / 19 | 25.6 | 35.2% | 5 / 5 / 3 / 6 / 7 |
| axiom_collective | AXIOM Scout | Light Precision Vessel | 20 authored | 2/13/5 | 8/14/10 | 1/3/2 | 22 / 10 | 15.0 | 66.3% | 6 / 4 / 1 / 6 / 8 |
| axiom_collective | AXIOM-7 | Autonomous Interceptor | 20 authored | 2/14/4 | 8/14/10 | 1/3/2 | 29 / 16 | 24.1 | 70.7% | 5 / 4 / 2 / 7 / 8 |
| axiom_collective | AXIOM Command Nexus | Mothership Precision Vessel | 20 authored | 3/13/4 | 15/15/15 | 3/3/3 | 50 / 28 | 30.4 | 7.5% | 5 / 5 / 3 / 6 / 7 |
| hollow_choir | Choir Guardian | Heavy Living Vessel | 20 authored | 10/2/8 | 12/8/12 | 2/1/3 | 51 / 5 | 29.4 | 31.1% | 7 / 8 / 7 / 9 / 3 |
| hollow_choir | Choir Spore | Light Living Vessel | 20 authored | 9/3/8 | 12/8/12 | 2/1/3 | 27 / 2 | 25.8 | 41.8% | 7 / 8 / 7 / 10 / 3 |
| hollow_choir | The Hollow Choir | Organic Vessel | 20 authored | 8/3/9 | 12/8/12 | 2/1/3 | 42 / 2 | 27.8 | 34.4% | 7 / 7 / 5 / 10 / 4 |
| hollow_choir | Choir Leviathan | Mothership Living Vessel | 20 authored | 10/2/8 | 15/15/15 | 3/3/3 | 72 / 6 | 36.5 | 3.9% | 7 / 8 / 7 / 9 / 3 |
| iron_directorate | Bastion Frigate | Light Armored Vessel | 20 authored | 6/11/3 | 8/12/10 | 1/3/2 | 25 / 13 | 45.0 | 65.6% | 4 / 7 / 4 / 8 / 4 |
| iron_directorate | Reclaimer | Armored Harvester | 80 shared | 26/28/26 | 14/8/10 | 3/1/2 | 40 / 8 | 33.8 | 42.0% | 24 / 21 / 14 / 38 / 32 |
| iron_directorate | Sentinel | Shielded Defender | 80 shared | 26/28/26 | 8/12/10 | 1/3/2 | 32 / 18 | 38.6 | 52.1% | 24 / 21 / 14 / 38 / 32 |
| iron_directorate | Siege Monitor | Heavy Armored Vessel | 20 authored | 8/8/4 | 8/12/10 | 1/3/2 | 43 / 22 | 50.6 | 44.8% | 5 / 8 / 6 / 7 / 2 |
| iron_directorate | Sentinel Dreadnought | Armored Dreadnought | 80 shared | 26/28/26 | 15/15/15 | 3/3/3 | 55 / 22 | 37.9 | 4.0% | 24 / 21 / 14 / 38 / 32 |
| scavenger_clans | Marauder | Energy Raider | 80 shared | 26/28/26 | 8/15/10 | 1/3/2 | 27 / 5 | 12.1 | 68.8% | 24 / 21 / 14 / 38 / 32 |
| scavenger_clans | Rustjack | Scrap Raider | 20 authored | 11/2/7 | 14/8/10 | 3/1/2 | 32 / 4 | 22.7 | 75.1% | 7 / 4 / 3 / 8 / 7 |
| scavenger_clans | Scrap Skiff | Light Scrap Raider | 20 authored | 11/2/7 | 14/8/10 | 3/1/2 | 20 / 3 | 12.4 | 94.1% | 7 / 4 / 2 / 8 / 8 |
| scavenger_clans | Wreckbreaker | Heavy Scrap Raider | 20 authored | 11/2/7 | 14/8/10 | 3/1/2 | 40 / 9 | 20.0 | 35.7% | 9 / 4 / 3 / 8 / 5 |
| scavenger_clans | Marauder Vanguard | Elite Raider | 80 shared | 26/28/26 | 12/18/12 | 2/4/2 | 38 / 12 | 15.4 | 21.0% | 24 / 21 / 14 / 38 / 32 |
| scavenger_clans | Clan War Barge | Mothership Scrap Raider | 20 authored | 11/2/7 | 15/15/15 | 3/3/3 | 60 / 14 | 18.1 | 7.2% | 9 / 4 / 3 / 8 / 5 |

## AXIOM Enforcer

AXIOM Enforcer: energy disruption and precision strikes.

Tactics `{"damage": 1.5, "disruption": 1, "hull": 0.8, "play_again": 1.1, "production": 3.5, "resources": 0.3, "shields": 0.65}`, variation 0.04.
Family draw weights `{"crew": 1, "energy": 1.6, "materials": 0.8}`.
Effect draw weights `{"damage": 1.6, "disruption": 1.5, "shields": 1.2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 1.81, Hull Nanobots 0.76, Shield Plating 0.70, Hull Patch 0.67.

**Recovery and Shield slots sharing a resource family**  energy 3, materials 3.

**Frequently played multi-role attacks**  none observed.

**Low-affordability, low-play examples**  Emergency Reserves (12% affordable, 95% discarded among removals).

## AXIOM Scout

AXIOM Scout: energy disruption and precision strikes.

Tactics `{"damage": 1.5, "disruption": 1, "hull": 0.8, "play_again": 1.1, "production": 3.5, "resources": 0.3, "shields": 0.65}`, variation 0.04.
Family draw weights `{"crew": 1, "energy": 1.6, "materials": 0.8}`.
Effect draw weights `{"damage": 1.6, "disruption": 1.5, "shields": 1.2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 0.94, Shield Plating 0.63, Hull Patch 0.31, Power Grid Reroute 0.30.

**Recovery and Shield slots sharing a resource family**  energy 2, materials 2.

**Frequently played multi-role attacks**  Missile Team (disruption).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## AXIOM-7

Precise energy interceptor: shield-breaking weapons and disruption.

Tactics `{"damage": 1.5, "disruption": 1, "hull": 0.8, "play_again": 1.1, "production": 3.5, "resources": 0.3, "shields": 0.65}`, variation 0.04.
Family draw weights `{"crew": 1, "energy": 1.6, "materials": 0.8}`.
Effect draw weights `{"damage": 1.6, "disruption": 1.5, "shields": 1.2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 1.64, Hull Nanobots 1.04, Power Grid Reroute 1.00, Shield Plating 0.98.

**Recovery and Shield slots sharing a resource family**  energy 3, materials 2.

**Frequently played multi-role attacks**  Missile Team (disruption).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## AXIOM Command Nexus

AXIOM Command Nexus: energy disruption and precision strikes.

Tactics `{"damage": 1.5, "disruption": 1, "hull": 0.8, "play_again": 1.1, "production": 3.5, "resources": 0.3, "shields": 0.65}`, variation 0.04.
Family draw weights `{"crew": 1, "energy": 1.6, "materials": 0.8}`.
Effect draw weights `{"damage": 1.6, "disruption": 1.5, "shields": 1.2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 2.02, Emergency Refit 1.09, Shield Plating 0.90, Hull Patch 0.84.

**Recovery and Shield slots sharing a resource family**  energy 3, materials 3.

**Frequently played multi-role attacks**  none observed.

**Low-affordability, low-play examples**  Emergency Reserves (13% affordable, 94% discarded among removals).

## Choir Guardian

Choir Guardian: regeneration and sustained crew attacks.

Tactics `{"damage": 0.95, "disruption": 0.35, "hull": 1.3, "play_again": 1, "production": 2.8, "resources": 0.3, "shields": 0.85}`, variation 0.12.
Family draw weights `{"crew": 1.4, "energy": 0.8, "materials": 1.25}`.
Effect draw weights `{"damage": 0.9, "economy": 1.1, "hull": 1.3, "shields": 1.25}`.

**Most-used recovery or Shield cards per combat**  Structural Reinforcement 2.27, Shield Plating 2.06, Damage Control Teams 1.64, Hull Patch 1.55.

**Recovery and Shield slots sharing a resource family**  crew 1, energy 2, materials 7.

**Frequently played multi-role attacks**  Coordinated Assault (economy/disruption), Salvage Strike (economy), Missile Team (disruption).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Choir Spore

Choir Spore: regeneration and sustained crew attacks.

Tactics `{"damage": 0.95, "disruption": 0.35, "hull": 1.3, "play_again": 1, "production": 3.5, "resources": 0.3, "shields": 0.85}`, variation 0.12.
Family draw weights `{"crew": 1.4, "energy": 0.8, "materials": 1.25}`.
Effect draw weights `{"damage": 0.9, "economy": 1.1, "hull": 1.3, "shields": 1.25}`.

**Most-used recovery or Shield cards per combat**  Structural Reinforcement 2.36, Shield Plating 1.67, Damage Control Teams 1.46, Emergency Bulkheads 1.26.

**Recovery and Shield slots sharing a resource family**  crew 2, energy 2, materials 6.

**Frequently played multi-role attacks**  Coordinated Assault (economy/disruption), Missile Team (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## The Hollow Choir

Living vessel: restoration, defensive buildup and steady crew attacks.

Tactics `{"damage": 0.95, "disruption": 0.35, "hull": 1.3, "play_again": 1, "production": 3.5, "resources": 0.3, "shields": 0.85}`, variation 0.12.
Family draw weights `{"crew": 1.4, "energy": 0.8, "materials": 1.25}`.
Effect draw weights `{"damage": 0.9, "economy": 1.1, "hull": 1.3, "shields": 1.25}`.

**Most-used recovery or Shield cards per combat**  Structural Reinforcement 2.16, Shield Plating 1.98, Hull Patch 1.65, Damage Control Teams 1.47.

**Recovery and Shield slots sharing a resource family**  crew 1, energy 2, materials 5.

**Frequently played multi-role attacks**  Coordinated Assault (economy/disruption), Missile Team (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Choir Leviathan

Choir Leviathan: regeneration and sustained crew attacks.

Tactics `{"damage": 0.95, "disruption": 0.35, "hull": 1.3, "play_again": 1, "production": 3.5, "resources": 0.3, "shields": 0.85}`, variation 0.12.
Family draw weights `{"crew": 1.4, "energy": 0.8, "materials": 1.25}`.
Effect draw weights `{"damage": 0.9, "economy": 1.1, "hull": 1.3, "shields": 1.25}`.

**Most-used recovery or Shield cards per combat**  Structural Reinforcement 2.90, Shield Plating 2.60, Hull Patch 2.22, Damage Control Teams 2.18.

**Recovery and Shield slots sharing a resource family**  crew 1, energy 2, materials 7.

**Frequently played multi-role attacks**  Coordinated Assault (economy/disruption), Salvage Strike (economy), Missile Team (disruption).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Bastion Frigate

Bastion Frigate: layered defenses and attrition.

Tactics `{"damage": 0.9, "disruption": 0.8, "hull": 1.5, "play_again": 1, "production": 4, "resources": 0.3, "shields": 0.95}`, variation 0.25.
Family draw weights `{"energy": 1.15}`.
Effect draw weights `{"disruption": 1.6, "hull": 1.8, "production": 1.3, "shields": 2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 3.81, Shield Plating 3.72, Structural Reinforcement 3.25, Power Grid Reroute 3.25.

**Recovery and Shield slots sharing a resource family**  crew 1, energy 3, materials 4.

**Frequently played multi-role attacks**  Missile Team (disruption).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Reclaimer

Strong Hull and Materials production.

Tactics `{"damage": 1.1, "disruption": 0.4, "hull": 1.05, "play_again": 1, "production": 10, "resources": 0.8, "shields": 0.4}`, variation 0.25.
Family draw weights `{"materials": 1.8}`.
Effect draw weights `{"damage": 1.2, "economy": 1.8, "hull": 1.6, "production": 2}`.

**Most-used recovery or Shield cards per combat**  Hull Patch 1.29, Salvage Cannibalization 1.20, Shield Plating 1.07, Structural Reclamation 1.01.

**Recovery and Shield slots sharing a resource family**  crew 5, energy 9, materials 11.

**Frequently played multi-role attacks**  Salvage Strike (economy), Cargo Raid (disruption), Coordinated Assault (economy/disruption).

**Low-affordability, low-play examples**  Antimatter Lance (3% affordable, 29% discarded among removals), Sabotage Commandos (6% affordable, 20% discarded among removals), Auxiliary Power Link (7% affordable, 18% discarded among removals), Sabotage Operation (7% affordable, 62% discarded among removals), Personnel Exchange (12% affordable, 35% discarded among removals).

## Sentinel

Heavy shields and strong Reactor.

Tactics `{"damage": 0.9, "disruption": 0.8, "hull": 1.5, "play_again": 1, "production": 4, "resources": 0.3, "shields": 0.95}`, variation 0.25.
Family draw weights `{"energy": 1.15}`.
Effect draw weights `{"disruption": 1.6, "hull": 1.8, "production": 1.3, "shields": 2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 1.49, Shield Plating 1.07, Shield Capacitor 1.01, Hull Nanobots 1.00.

**Recovery and Shield slots sharing a resource family**  crew 5, energy 9, materials 11.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Coordinated Assault (economy/disruption), Breach Charge (disruption).

**Low-affordability, low-play examples**  Industrial Sabotage (1% affordable, 88% discarded among removals), Siege Driver (1% affordable, 73% discarded among removals), Emergency Refit (2% affordable, 85% discarded among removals), Resource Seizure (2% affordable, 79% discarded among removals), Fabrication Strike (5% affordable, 70% discarded among removals).

## Siege Monitor

Siege Monitor: layered defenses and attrition.

Tactics `{"damage": 0.9, "disruption": 0.8, "hull": 1.5, "play_again": 1, "production": 4, "resources": 0.3, "shields": 0.95}`, variation 0.25.
Family draw weights `{"energy": 1.15}`.
Effect draw weights `{"disruption": 1.6, "hull": 1.8, "production": 1.3, "shields": 2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 4.07, Shield Plating 3.91, Structural Reinforcement 3.86, Power Grid Reroute 3.65.

**Recovery and Shield slots sharing a resource family**  crew 1, energy 3, materials 6.

**Frequently played multi-role attacks**  none observed.

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Sentinel Dreadnought

Armored Dreadnought

Tactics `{"damage": 0.9, "disruption": 0.8, "hull": 1.5, "play_again": 1, "production": 4, "resources": 0.3, "shields": 0.95}`, variation 0.08.
Family draw weights `{"energy": 1.15}`.
Effect draw weights `{"disruption": 1.6, "hull": 1.8, "production": 1.3, "shields": 2}`.

**Most-used recovery or Shield cards per combat**  Shield Recharge 1.38, Hull Patch 1.12, Shield Plating 1.07, Shield Capacitor 1.07.

**Recovery and Shield slots sharing a resource family**  crew 5, energy 9, materials 11.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Coordinated Assault (economy/disruption), Breach Charge (disruption).

**Low-affordability, low-play examples**  Core Destabilization (15% affordable, 12% discarded among removals).

## Marauder

Energy-rich attacker.

Tactics `{"damage": 1.8, "disruption": 0.5, "hull": 0.65, "play_again": 1.5, "production": 2.8, "resources": 0.25, "shields": 0.2}`, variation 0.25.
Family draw weights `{"crew": 1.15, "energy": 1.7}`.
Effect draw weights `{"damage": 1.8, "steal": 1.7}`.

**Most-used recovery or Shield cards per combat**  Hull Nanobots 0.39, Damage Control Teams 0.23, Shield Capacitor 0.21, Adaptive Command 0.17.

**Recovery and Shield slots sharing a resource family**  crew 5, energy 9, materials 11.

**Frequently played multi-role attacks**  Breach Charge (disruption), Cargo Raid (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  Resource Seizure (0% affordable, 100% discarded among removals), Siege Driver (0% affordable, 97% discarded among removals), Fabrication Strike (0% affordable, 100% discarded among removals), Reinforced Foundations (1% affordable, 86% discarded among removals), Emergency Refit (1% affordable, 100% discarded among removals).

## Rustjack

Opportunistic scrap raider: demolition, salvage and theft.

Tactics `{"damage": 1.6, "disruption": 1.1, "hull": 1, "play_again": 1.2, "production": 3, "resources": 0.45, "shields": 0.3}`, variation 0.22.
Family draw weights `{"crew": 1.1, "energy": 0.8, "materials": 1.5}`.
Effect draw weights `{"damage": 1.5, "disruption": 1.5, "hull": 1.2, "steal": 1.8}`.

**Most-used recovery or Shield cards per combat**  Hull Patch 1.58, Salvage Cannibalization 1.39, Hull Overhaul 1.20, Shield Plating 0.90.

**Recovery and Shield slots sharing a resource family**  materials 5.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Breach Charge (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Scrap Skiff

Scrap Skiff: raiding and recovered weapons.

Tactics `{"damage": 1.6, "disruption": 1.1, "hull": 1, "play_again": 1.2, "production": 3, "resources": 0.45, "shields": 0.3}`, variation 0.22.
Family draw weights `{"crew": 1.1, "energy": 0.8, "materials": 1.5}`.
Effect draw weights `{"damage": 1.5, "disruption": 1.5, "hull": 1.2, "steal": 1.8}`.

**Most-used recovery or Shield cards per combat**  Hull Patch 0.89, Salvage Cannibalization 0.84, Shield Plating 0.22, Emergency Bulkheads 0.07.

**Recovery and Shield slots sharing a resource family**  materials 4.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Breach Charge (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Wreckbreaker

Wreckbreaker: raiding and recovered weapons.

Tactics `{"damage": 1.6, "disruption": 1.1, "hull": 1, "play_again": 1.2, "production": 3, "resources": 0.45, "shields": 0.3}`, variation 0.22.
Family draw weights `{"crew": 1.1, "energy": 0.8, "materials": 1.5}`.
Effect draw weights `{"damage": 1.5, "disruption": 1.5, "hull": 1.2, "steal": 1.8}`.

**Most-used recovery or Shield cards per combat**  Hull Patch 1.27, Salvage Cannibalization 1.22, Hull Overhaul 1.01, Shield Plating 0.63.

**Recovery and Shield slots sharing a resource family**  materials 5.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Breach Charge (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.

## Marauder Vanguard

Elite Raider

Tactics `{"damage": 1.8, "disruption": 0.5, "hull": 0.65, "play_again": 1.5, "production": 2.8, "resources": 0.25, "shields": 0.2}`, variation 0.08.
Family draw weights `{"crew": 1.15, "energy": 1.7}`.
Effect draw weights `{"damage": 1.8, "steal": 1.7}`.

**Most-used recovery or Shield cards per combat**  Hull Nanobots 0.50, Damage Control Teams 0.24, Hull Overhaul 0.22, Shield Capacitor 0.21.

**Recovery and Shield slots sharing a resource family**  crew 5, energy 9, materials 11.

**Frequently played multi-role attacks**  Breach Charge (disruption), Cargo Raid (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  Cataclysm Protocol (1% affordable, 79% discarded among removals), Sabotage Commandos (2% affordable, 0% discarded among removals), Siege Driver (3% affordable, 0% discarded among removals), Boarding Specialists (3% affordable, 69% discarded among removals), Fabrication Strike (6% affordable, 13% discarded among removals).

## Clan War Barge

Clan War Barge: raiding and recovered weapons.

Tactics `{"damage": 1.6, "disruption": 1.1, "hull": 1, "play_again": 1.2, "production": 3, "resources": 0.45, "shields": 0.3}`, variation 0.22.
Family draw weights `{"crew": 1.1, "energy": 0.8, "materials": 1.5}`.
Effect draw weights `{"damage": 1.5, "disruption": 1.5, "hull": 1.2, "steal": 1.8}`.

**Most-used recovery or Shield cards per combat**  Salvage Cannibalization 1.11, Hull Overhaul 0.83, Hull Patch 0.82, Shield Plating 0.46.

**Recovery and Shield slots sharing a resource family**  materials 5.

**Frequently played multi-role attacks**  Cargo Raid (disruption), Breach Charge (disruption), Salvage Strike (economy).

**Low-affordability, low-play examples**  none at the reporting cutoff.
