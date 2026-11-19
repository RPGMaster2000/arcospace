# Warzone implementation

## Campaign foundation

`ExpeditionState` owns the system boundary and writes the final Homeworld record
before system generation replaces the Defense state. A secured Homeworld also
records its condition in the current checkpoint. Leaving the system refreshes
the record with the player's final Hull, Salvage, production and card upgrades.

The campaign route schedules Warzone after Homeworld. Exploration retains its
own route. The foundation leaves the current system generator active until the
Warzone simulation and player entry points are connected.

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

## Integration boundaries

- The campaign and objective model belongs to expedition state. Starfront
  Defense pressure and Exploration's mandatory Boss gate remain scoped to
  their own operations.
- Player travel and completed activities already commit strategic time.
  Fleet movement and fleet engagements will use that same boundary.
- The battle setup snapshot already persists physical modifiers and timed
  friendly support. Warzone battle entry can lock participating fleets and the
  support package into that handoff.
- Save wire data remains separate from scene state, and the star-system
  presentation can read fleet and objective snapshots.
