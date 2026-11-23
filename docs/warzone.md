# Warzone v3 · Strategic Lattice Warfare

## Playing the sector

Developer Test Launch expeditions offer **DEV: One-Hit Kill** in the battle
menu. It starts off and stays set between battles in the same test session.
A player card that deals damage can end a battle even if the enemy shields
absorb the hit. Normal victory rewards and strategic time still apply.

System 2 opens in a starless deep-space sector with three allied ships and
six hostile ships, including one extra opening formation per side. Two
engagements are already active. **Lattice** starts enabled and emphasizes viable,
contested and severed routes. Fleet routes show current orders on entry and
after loading. Toggle Lattice off to clear those projections.
An **A** or **H** badge identifies ownership. **!** marks disruption and **/** marks
isolation. A capture ring shows progress and a pulsing ring marks combat.
Fleet markers show strength and orders. Select an allied fleet for its readout,
or hold a hostile marker to inspect it before committing to an interception.
The HUD shows War Effort, the territorial split and fleet counts. System Status
keeps the event log. The player can navigate freely behind hostile lines.

**Territorial Control** shows ownership, supplied attack routes and capture progress.
Solo player captures now take **12 strategic seconds** by default, versus six
with an allied fleet present. The progress ring, inspection text and Hold HUD use
the current requirement, including when an ally enters or leaves the station.
Clear defenders and choose **Hold Until Captured** at an eligible site, or let
an allied fleet capture it. The hold keeps the ship in place and runs the ordinary
war at one strategic second per real second. **Cancel Hold**, contested territory,
loss of supply, and app suspension stop the hold. Resume retains committed capture
progress and starts with the hold off. The main HUD's **Hold to Wait** advances the
normal battlefield simulation while pressed and, on release, rounds the total
strategic duration **up to the nearest 0.5 seconds** (minimum 0.5 seconds).
The button stays on the live map; it does not start a timed camera overview. The
**Facility Operation** section shows the site's signature effect, requirements,
cost and recharge. An inner ring on the map marker shows recharge progress.
Each facility has its own cooldown, which advances only on the strategic clock.

| Facility | Access | Signature operation | Recharge |
| --- | --- | --- | --- |
| Repair Dock | Supplied allied | Repair the weakest damaged fleet. One free emergency recovery is available after a rout. | 18s |
| Command station | Supplied allied | Scramble available fleets to intercept hostiles for 20s. Free, 2 strategic seconds. | 28s |
| Outpost or junction | Supplied allied | Fortify a position against heavy hostile volleys for the recharge interval. | 16s |
| Communications Array | Infiltrate while hostile or transmit while supplied allied | Delay hostile reserves and counterattack orders for 20s. | 25s |
| Supply depot or logistics hub | Infiltrate while hostile | Sever local supply links and scatter the garrison. | 42s |
| Shipyard | Supplied allied | Request an additional off-map formation for 3 Salvage and 4 strategic seconds. | 30s |

Aggressive player actions now increase **Enemy Alert**, without affecting
War Effort or causing constant enemy spawns. At critical enemy installations,
or after alert has risen, an available existing hostile patrol can respond as
soon as an uncontested solo capture begins. A patrol is never taken out of an
active engagement or from a designated command-defense role. Repeated
aggression can assign **one existing hostile ship** to a timed player pursuit;
a warned fleet displays a pursuit icon and route toward the actual player ship.
Only physical contact within the normal combat radius can trigger the standard
battle checkpoint. The pursuit warns for three strategic seconds before
contact becomes eligible, uses a 25-second cooldown, and permits at most two
player hunts per sector. The threat ends when the hunter is defeated,
engaged by allies, disconnected from supply, expires, or intercepts the
player. Autonomous allies recognize player hunters as priority threats
and intercept the hunter's real route toward the player. When the hunter
passes through fleet engagement range of an allied ship, normal fleet combat
begins and pursuit ends. The player can also escape by keeping distance. These rules and the
solo capture multiplier are tunable in `warzone_tuning.gd`; active alert
and warned stations persist in saves, while older sectors load Quiet.

Convoys deliver strength along supplied routes and abort when their route is cut.
The Trading Outpost retains its protected services outside the lattice.

Fleets fly a direct course to lattice-connected objectives. Cutting a route can
redirect them and immediately resets any capture that loses its last supplied
link. Restoring the link permits a new attack when an attacker enters the site.
The previous owner retains control until a fresh capture succeeds. Allied fleets
reserve ordinary destinations as they choose their next assignment. Undefended
frontier objectives generally need one fleet. Defended sites can draw a second,
and the existing interception policy still coordinates responses to major threats.

New sectors have one reserve formation per side. The first allied wave
becomes eligible at 18 strategic seconds and the hostile wave at 25 seconds
(previously 22 and 30). They approach from outside the sector once their
supply network can support them. Their strength depends on
connected installations, and a cutoff can delay their entry. Historical sectors retain their existing fleet roster and encounter IDs;
new opening formations have additional stable IDs after the original reserves. The fleet marker at each engagement shows an
attrition estimate based on current strength and incoming fire. **Hold to Wait**
advances the strategic clock for as long as the button is pressed.

Allied fleets reassess orders every three strategic seconds. Command stations and
junctions that supply other installations receive higher priority. Fleets
compare travel time and volley strength, prefer to finish nearly completed
captures, and converge when a threatened formation needs help. A six-second
commitment reduces target switching. Weak ships can withdraw to supplied
territory to recover using existing repair rules. Interception leads the
hostile's current leg (or the player's moving position during a pursuit)
and reevaluates if its orders change. Once allied forces begin taking the
final command station, **every active, unengaged hostile fleet** immediately
converges there using a direct route, including command defenders and any
subsequently available ships. Ships fighting an existing engagement or
withdrawing are left alone until available; no new enemies are spawned.
The final-defense order persists in saved sectors. The final offensive now prioritizes a
command station farther from Allied Command by travel distance and graph
hops; hostile command stations are placed deeper into the hostile end of
the lattice during new sector generation. Both factions' dashed
movement routes are hidden with Lattice OFF.

Scramble immediately reassesses available formations and temporarily raises the
priority of pursuing hostile fleets. The active station broadcasts a visible
pulse. Scramble uses existing engagements and damage. The Shipyard budget is
two paid requests per sector with a maximum of five active allied fleets,
including an inbound formation or the automatic reserve. A supplied Shipyard
is required to request a fleet. An incoming fleet can divert to allied command
if the Shipyard loses supply, or wait off-map if the network cannot support
it. Request costs and limits are editable in `warzone_tuning.gd`.

A 120-strategic-second simulation over 40 seeds at each of two support levels
compared the policy against the previous system. The mean number of allied
objectives at 120 seconds rose from 1.65 to 2.10 at strength 5 and from 1.65 to
2.08 at strength 9. Allied losses fell from 115 to 108 and from 103 to 101
summed across seeds. Neither version entered the final offensive without
player intervention. These unattended runs measure opening survival and
territory, alongside the lattice regression's distinct player-led victory paths.

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

## Procedural sectors and discoveries

A dedicated seed stream generates 9–12 installations with two active opening
engagements. The seven graph families vary orientation, ownership, branch lengths,
and the number and importance of connections. Bottleneck and corridor sectors
route hostile supply through their depot. Encirclement places an isolated allied
outpost inside hostile territory. Generation rejects crossing links and links
that pass too close to unrelated installations. A larger sector can have one
more discovery, and some sectors have none.

Military objectives use stable semantic roles, including the supply roots, forward
command, depot and shipyard. A role determines the installation's operation and
appearance. The saved node ID resolves its position, links and current owner.
Reserve flights start beyond the boundary on the side of their faction's command.
The normal camera centers on mission objects and keeps off-map reserves out of
its initial framing. Strategic Time continues to follow the player and local combat.

Independent derelicts, debris fields, abandoned research stations and anomalies
reuse standard PoI interactions, including their costs, rewards and Strategic
Time. Explore them through neutral markers. They have no ownership, supply
connections, or War Effort rewards. Their positions and completion state reload
with the encounter. Lattice version 3 saves roles explicitly. Version 2 and the
original three-objective saves continue using their stored layouts and IDs.

The normal map shows spacecraft, combat and ownership badges. Toggle **Lattice**
to show saturated territorial gradients, supply links, disruptions and chokepoints.
Strategic Time respects that setting. Fleet leaders and escorts reuse model
scenes with steady engine emission, no battle passes, and no ship shadows.
The normal campaign fields Scavenger Clans in System 1 and AXIOM Collective
in System 2 while `fixed_opening_factions` is enabled. Developer Test Launch
and later systems still select from the configured faction catalog.

**Warzone Tuning → Lattice Operations → Battle Modifier Chance** defaults to 54%.
Contacts draw from six existing modifiers without repeating a planned modifier
in the same sector. Logistics encounters favor asteroid or metal effects when
available. A contact without an assigned effect still uses physical hazards at
its location. One modifier applies at a time. The encounter preview identifies
it before battle. Solar Flare stays out of the starless assignment pool.

Normal expeditions and Developer Test Launch both randomize when
`ExpeditionRules.debug_seed` is zero. Set that resource field or pass a nonzero
`seed_override` to reproduce a sector. Saves preserve the chosen seed and the
committed layout, discoveries and encounter modifiers.

## Ownership and tuning

`WarzoneLattice` derives seven graph families from an independent seed.
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

`warzone_lattice_test` audits 512 networks and 128 full expeditions for graph
variety, modifier frequency and discovery placement. The audit found 163 distinct
degree signatures and a supplied victory path in every sampled network. Opening
fronts were about 8–20 world units apart. Including physical hazards, 62% of the
768 sampled contacts had a modifier, compared with 17% using physical hazards
alone on the same layouts. The suite also covers save round trips,
zero-card-battle wins, per-facility cooldowns and final consolidation.
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

## Inspection and tactical routes

Inspection owns its dismissing pointer until release, then unlocks the next
gesture. A same-sector overview return reuses the map and live markers instead
of regenerating marker labels. In a headless 25-return probe on the seeded
Warzone test scene, the median Back callback fell from about 1.63 seconds to
1.1 milliseconds. Separate timings isolated the work to the same-map marker
refresh, including relabeling and reapplying the tactical marker presentation.

Lattice connections use feathered world-space strips. The narrower animated
hostile routes connect each displayed fleet to its current movement target.
Toggling Lattice off clears both meshes together with the influence field.

The tactical shader extrudes cached connections perpendicular to their projected
direction in viewport pixels. Permanent lines are four pixels wide and fleet
routes are 2.25 pixels wide before edge feathering. Node insets keep incident
connections apart, nearby parallel routes get separate lanes, and disconnected
links use a muted patterned stroke. Width stays stable as the map zooms.
