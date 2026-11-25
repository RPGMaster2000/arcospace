# Starfront Defense v2

System 1 and legacy v2 systems roll for two or three attackers with weights
40% and 60%. A dedicated seed controls the roster size and deployment
variation. Attackers start on both sides of the homeworld approach with
different travel distances. The mothership has its own encounter ID.
Starting attackers sample 75–120% of the base deployment radius, subject
to map and orbital clearance. New systems carry up to three regular
reserves. The first becomes due at 30 strategic seconds, with 30 seconds
between deployments. A due reserve waits until fewer than two ordinary
attackers remain active. This schedule runs independently of missiles.
Existing saves finish their current system with its original roster,
reveal rule and reinforcement schedule.

Starfront Defense from System 3 onward adds separate military scenario generation
and capped strategic difficulty. The campaign still uses Warzone in System 2.
See [Later Starfront Defense](balance/starfront_warfare.md) for formations,
battle tuning, and validation results. [Later Starfront geography](balance/starfront_environment.md)
describes its environmental layouts and developer controls.

New Starfront Defense sectors from System 3 onward also evacuate a civilian
convoy. Its beacon and hostile pursuers appear on the map. Inspect the convoy
to check integrity, extraction ETA and a rendezvous destination. Successful
evacuation adds 15 Salvage. Destruction adds 20 Pressure and brings a single
mandatory elite response. System 1, Warzone and already-generated saves keep
their existing objectives.
[Evacuation mechanics and balance results](balance/starfront_warfare.md#civilian-evacuation)

## Strategic clock

| Pressure | Mothership |
|---|---|
| 0–49 | Hidden |
| 50–99 | Revealed and launches missiles |
| 100 | Advances and continues launching |

Base v2 pressure is scaled by the configured pressure-rate multiplier.
Later scenarios apply their own multiplier once to that effective rate.
Player speed, strategic seconds per distance, and the 100-point
maximum retain their tuning. The mothership still uses the existing boss
battle. Neutralizing it stands down undeployed reserves. Deployed attackers and
in-flight missiles must resolve before the sector is secure.

The missile scheduler consumes the same event spans as the defense fleet.
It launches eight seconds after reveal, then every 18 seconds with at
most two live missiles. Missiles travel at twice attacker speed, start
with eight Hull, and deal 12 homeworld damage on impact. They retain
their original trajectory when the mothership starts advancing.

| Interception approach | Requirement | Strategic cost |
|---|---|---:|
| Direct Interception | Any ship | 1.0 s |
| Precision Targeting | Reactor production upgrade | 0.5 s |
| EMP Disruption | One stored EMP charge | 0.25 s |

Player contact opens a short approach-selection panel and pauses the
strategic clock until resolution. The missile grants no exploration
reward, salvage or card combat. Save/load retains the pending choice.

Kinetic Turrets deal four Hull damage to missiles every 0.8 strategic
seconds when a target is in range. The same swept motion calculation
checks entry between updates. On simultaneous events, turret fire takes
priority over player contact, then homeworld impact and launch. Multiple
turrets use stable site and missile ordering. Their existing shield-first
combat support against ships remains frozen at battle entry.

## Layout and map

Planetary PoI rings account for the visible radii of neighboring bodies
and a configurable safety margin. The packed Defense orbits reserve
space for the homeworld and use the established expanded bounds.
The visual orbits pass through the authoritative anchors. The layout
revision is saved so earlier systems retain their geometry.

Permanent Defense environments sample the fleet's approach routes.
Generation checks each sphere, ellipsoid, annulus or pocket against
those segments and avoids putting ships inside a region at deployment.
The star stays fixed. A region is omitted when no legal placement
exists. Temporary rifts continue to use active routes and remaining
lifetime. Modifier priority and Friendly Turret Support are unchanged.

The Defenses panel focuses the camera on a construction site. Large side
arrows move between sites and disable confirmation while the camera
moves. Closing the panel restores the prior view. Storm details are
available from their map control on the left, leaving the FTL panel clear.

## Captures

| View | Mobile Vulkan | GL Compatibility |
|---|---|---|
| Civilian evacuation, System 5 seed 39 | See the rendered convoy test | [Compatibility](starfront_defense_v2/convoy-gl_compatibility.webp) |
| Initial fleet, orbits and FTL HUD | [Mobile](starfront_defense_v2/fleet-and-orbits-mobile.png) | [Compatibility](starfront_defense_v2/fleet-and-orbits-gl_compatibility.png) |
| Mothership reveal at pressure 50 | [Mobile](starfront_defense_v2/reveal-mobile.png) | [Compatibility](starfront_defense_v2/reveal-gl_compatibility.png) |
| Missile on approach | [Mobile](starfront_defense_v2/missile-flight-mobile.png) | [Compatibility](starfront_defense_v2/missile-flight-gl_compatibility.png) |
| Player interception | [Mobile](starfront_defense_v2/interception-mobile.png) | [Compatibility](starfront_defense_v2/interception-gl_compatibility.png) |
| Turret interception | [Mobile](starfront_defense_v2/turret-interception-mobile.png) | [Compatibility](starfront_defense_v2/turret-interception-gl_compatibility.png) |
| First construction site | [Mobile](starfront_defense_v2/construction-first-mobile.png) | [Compatibility](starfront_defense_v2/construction-first-gl_compatibility.png) |
| Next construction site | [Mobile](starfront_defense_v2/construction-next-mobile.png) | [Compatibility](starfront_defense_v2/construction-next-gl_compatibility.png) |

The Windows captures use both rendering backends and predate the fleet
pacing adjustment. Physical Android frame times were not measured.
