# Warzone implementation

## Campaign foundation

`ExpeditionState` owns the system boundary and writes the final Homeworld record
before system generation replaces the Defense state. A secured Homeworld also
records its condition in the current checkpoint. Leaving the system refreshes
the record with the player's final Hull, Salvage, production and card upgrades.

The default campaign takes the player from Homeworld Defense into Warzone in
System 2 and back to Defense in System 3. Exploration keeps its existing route.
Set `ExpeditionRules.warzone_campaign_enabled` to false for a Defense-only run.

| Final Homeworld integrity | Support package | Strength per allied group | Salvage | Arrival Shields |
| --- | --- | ---: | ---: | ---: |
| Below 20% | Emergency | 5 | 3 | 2 |
| At least 20% | Limited | 7 | 6 | 3 |
| At least 50% | Standard | 9 | 10 | 5 |
| At least 80% | Strong | 11 | 15 | 7 |

Thresholds and amounts live in `WarzoneTuning`. Outcomes record the integrity
denominator in effect when Homeworld was secured. Support calculation consumes
no random numbers. Older saves have no historical integrity field. Their
fallback package is Standard.

## Playing Warzone

Two allied groups start near the Communications Relay. Five hostile groups
hold the Shipyard and Defense Array or are moving to reinforce or capture
objectives. Follow their routes, inspect contacts, and travel to the
engagements you want to enter.

Travel, finished battles and the **Wait** or **Hold position** actions advance
strategic time. Reading a report, opening a menu or standing idle consumes no
time. Both autonomous sides exchange damage every four strategic seconds.
Uncontested presence captures an opposing objective in six seconds. Two
objectives must each stay uncontested and allied for 15 seconds to unlock FTL.
The System Status button shows recent captures, engagements and losses.

Entering an ongoing allied engagement snapshots the supporting fleet's
strength. It fires for 6–9 damage every two combat rounds while participating.
Supported combat awards half direct Salvage and half of numeric resource and
upgrade rewards, rounded down with at least one upgrade when normally
eligible. Solo battles keep their normal rewards. Objective rewards are
independent of combat support.

## Campaign consequences

Victory depends on control and consolidation. Losing all allied forces still
allows the player to win. The outcome records held objectives, surviving
strength for both sides, player interventions and committed time.

| Surviving allied strength | Outcome | Objective victory bonus | Next-system package |
| --- | --- | ---: | --- |
| At least 65% | Decisive Victory | 15 Salvage | Strong |
| At least 30% | Hard-Fought Victory | 8 Salvage | Standard |
| Below 30% | Pyrrhic Victory | 3 Salvage | Emergency |

System 3 receives the package's Salvage and next-battle Shields. Future Warzone
openings can reuse the saved outcome and its fleet-support package. Existing
player inventory and upgrades carry over as usual.

`WarzoneState` advances at fixed strategic-second boundaries and saves partial
time, fleet and route state, capture and holding progress, and reports.
Combat commits through the existing battle checkpoint and result paths.
The 3D map draws low-cost route lines and fleet markers from the live state.
