# Warzone v3 · Strategic Lattice Warfare

## Playing the sector

System 2 opens in a starless deep-space sector with a small allied foothold and two
active fleet engagements. **Lattice** emphasizes viable, contested and severed routes.
An **A** or **H** badge identifies ownership. **!** marks disruption and **/** marks
isolation. A capture ring shows progress and a pulsing ring marks combat.
Fleet markers show strength and orders. Select an allied fleet for its readout,
or hold a hostile marker to inspect it before committing to an interception.
The HUD shows War Effort, the territorial split and fleet counts. System Status
keeps the event log. The player can navigate freely behind hostile lines.

**Territorial Control** shows ownership, supplied attack routes and capture progress.
Clear defenders and hold position or let an allied fleet capture the site. The
**Facility Operation** section shows the site's signature effect, requirements,
cost and recharge. An inner ring on the map marker shows recharge progress.
Each facility has its own cooldown, which advances only on the strategic clock.

| Facility | Access | Signature operation | Recharge |
| --- | --- | --- | --- |
| Repair Dock | Supplied allied | Repair the weakest damaged fleet. One free emergency recovery is available after a rout. | 18s |
| Command station | Supplied allied | Coordinate an offensive and strengthen allied volleys near the target for 20s. | 28s |
| Outpost or junction | Supplied allied | Fortify a position against heavy hostile volleys for the recharge interval. | 16s |
| Communications Array | Infiltrate while hostile or transmit while supplied allied | Delay hostile reserves and counterattack orders for 20s. | 25s |
| Supply depot or logistics hub | Infiltrate while hostile | Sever local supply links and scatter the garrison. | 42s |
| Shipyard | Supplied allied | Dispatch a reserve when its fleet slot is vacant. | 35s |

Convoys deliver strength along supplied routes and abort when their route is cut.
The Trading Outpost retains its protected services outside the lattice.

Fleets fly a direct course to lattice-connected objectives. Cutting a route can
redirect them and immediately resets any capture that loses its last supplied
link. Restoring the link permits a new attack when an attacker enters the site.
The previous owner retains control until a fresh capture succeeds.

New sectors have one reserve formation per side. They approach from outside the
sector once their supply network can support them. Their strength depends on
connected installations, and a cutoff can delay their entry. Historical sectors
retain their existing fleet roster. The fleet marker at each engagement shows an
attrition estimate based on current strength and incoming fire. **Wait** spends
one strategic second.

War Effort credits captured territory, supply connections severed or restored,
and defeated fleets. Starting an operation grants no automatic Effort. Each
achievement is counted once, so reconnecting a severed link or recapturing a
site cannot turn it into a repeatable reward. A player intervention and 60 Effort
unlock the final offensive at Forward Command or Hostile Command. Secure that
specific objective with a supplied route and hold it uncontested through
consolidation. Direct battles can speed up the push, and logistics and fleet
support can win without them.

Victory commits campaign rewards before the aftermath. Hostiles withdraw while
allies regroup. A Pyrrhic Victory uses a subdued banner and retains more hostile
influence on the map. The Skip button and Skip Cinematics preference both
bypass the presentation. Completed saves resume with FTL available. The allied
rendezvous remains a supply foothold and all three grades unlock System 3.

## Ownership and tuning

`WarzoneLattice` derives one of six connected patterns from an independent seed.
`WarzoneSector` owns the graph, routes, supply, fleets, operational ledger and victory.
`WarzoneOperations` supplies operation quotes and applies effects after the expedition
validates proximity and available Salvage. The sector checks facility ownership, recharge and eligibility. `ExpeditionState` owns the
campaign and strategic clock. The standard card battle and allied support handoffs
remain in use. Tier 2 fights favor available faction elites or heavy faction profiles.
The hostile command fleet can use the faction mothership, which is optional to defeat.

Use `WarzoneTuning` for capture and consolidation time, Effort values, disruption
length, convoy timing and repair prices. Existing Homeworld support packages still
set initial allied strength, Salvage and Shields. Use `warzone_lattice_enabled` to
select the original operation for newly generated systems in development. The
versioned lattice payload distinguishes a v2 sector from the three-objective save
format. Optional v3 fields store recharge, active effects and the final command target. Older active saves retain their ledgers and adopt the new final offensive. Committed victories retain their campaign outcomes. The influence field and motion buffers are reconstructed from state.

Fleet movement follows the player's travel clock. Idle maps, inspections and
menus pause strategic time. Lattice movement and engagement contact use fixed
100 ms steps. Capture, volleys, supply timers and consolidation keep their
second-based timing.

**Strategic Time Overview** in Settings is on by default for timed noncombat
actions in Warzone and Starfront Defense. Confirmed actions cut to a local
cluster of hostile fleets and the player, favoring active engagements and keeping the camera
with its current group while priorities are tied. A 12% framing margin leaves room around the ships. With no hostiles, it frames
the player and a nearby objective. The progress bar displays one strategic
second per active second, and returning the camera spends none. Turning the setting off
settles the same fixed steps immediately. An orderly quit or application
suspension settles any confirmed remainder before saving.

Card battles keep their existing strategic-time commitments. Field Repairs,
which only cost Salvage, and modes without a strategic clock have no overview.
A single transparent mesh shows weighted territorial influence. Connected nodes
have stronger influence, and fleets and disruption change the field. The 3D
map reuses the existing sky and scenery and uses one non-shadowing fill light.

`warzone_lattice_test` exercises all six patterns across 64 seeds, save round trips,
zero-card-battle logistics and fleet-support wins, per-facility cooldowns, actual volley effects and final consolidation.
`warzone_lattice_presentation_test` exercises the live System 2 handoff, touch
overlay, facility layout, influence updates, withdrawal and touch skip under both renderers.

### Pacing checks

A deterministic comparison ran logistics, fleet support and three-interception
strategies on eight seeds each at standard allied strength. The scripts used the
normal travel speed and held objectives long enough to capture them. The logistics
and support runs averaged 46s and 56s before the changes, versus 166s and 176s
after retuning. The three-interception runs averaged 61s before and 110s after.
All 24 active trials won in that sample. The largest territory gains came from
logistics and fleet support, averaging about four new installations. These are
scripted strategic seconds and serve as a balance check. The regression suite also
checks that passive Effort accumulation cannot unlock the final offensive.

## Campaign foundation and original Warzone saves

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

## Playing the original three-objective operation

Two allied groups are fighting at the Communications Relay and the Shipyard
when the player arrives. Five hostile groups hold the Shipyard and Defense
Array or are moving to reinforce the front. The Relay engagement is within
intervention range at entry. Inspect the contacts to see the participants,
strengths, objectives and reward terms before committing.

Travel, finished battles and the **Wait** or **Hold position** actions advance
strategic time. Reading a report, opening a menu or standing idle consumes no
time. Both autonomous sides exchange damage every four strategic seconds.
Uncontested presence captures an opposing objective in six seconds. Two
objectives must each stay uncontested and allied for 15 seconds to unlock FTL.
The System Status button shows recent captures, engagements and losses.
Unengaged hostile groups can redirect when an allied capture succeeds. Up to
two respond at once. A lone defender can stay at its station. Active
engagements keep their assignments, and offensive groups reassess their next
objective after they finish a capture.

The protected Trading Outpost is near the entry point behind the Relay.
It uses the standard repairs, Salvage prices, card offers and shipyard
purchases. Existing Warzone saves without a service gain the outpost when
loaded, with their fleet positions and orders intact.

Entering an ongoing allied engagement snapshots the supporting fleet's
strength. It fires for 6–9 damage every two combat rounds while participating.
Supported combat awards half direct Salvage and half of numeric resource and
upgrade rewards, rounded down with at least one upgrade when normally
eligible. Solo battles keep their normal rewards. Objective rewards are
independent of combat support.
The battle result shows the immediate outcome and surviving allied strength.
Its Details panel includes contested objectives and other events from the
battle's committed strategic time. Defeat can leave an enemy fleet weakened
and grant no rewards.

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
The 3D map routes and ship formations reflect the live state. The ship models
interpolate between authoritative positions. Cosmetic beam exchanges remain
visible on an idle overview. Committed volleys drive damage flashes and
formation losses.
