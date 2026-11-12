# Physical Temporal Rifts

Starfront Defense evaluates a rift every 12 strategic seconds, starting at
12 seconds. Each evaluation has a 12% chance to attempt placement. A rift
lasts 15 strategic seconds and each system can have one active rift. Tune
the delay, interval, probability and lifetime in the Starfront Defense
tuning resource.

The defense simulation passes the scheduler each span of time it actually
consumes. The scheduler projects hostile positions at evaluation time
using the same movement and destinations as the fleet. A tick coinciding
with a fleet event uses the routes approaching that event. A reinforcement
or mothership that begins moving at that instant can contribute starting
with the next tick. Swept interception stops the clock at contact.
Committed activities advance it by their strategic cost. Menus, inspection,
time spent playing cards and time between sessions leave the timers paused.
Occupied evaluations consume their scheduled roll and preserve the cadence.

The generator samples points ahead on active routes to the homeworld.
It uses each route's departure point to keep placement stable across
movement samples and saves.
Reinforcements qualify after deployment and the mothership qualifies after
it starts advancing. A 2.35-unit spherical region must fit inside map bounds
with room around the star, homeworld, PoIs and construction markers. The
generator prefers centers outside asteroid fields and storms. A rift can
stay in place after its source is neutralized. Fleet routes and speeds
remain under the defense simulation.

Battle entry freezes the environment at the hostile's authoritative
position. Priority is **legacy assignment → solar interference → Temporal
Rift → asteroid field → space storm**. Friendly Turret Support can coexist.
Temporal Rift uses existing modifier ID 5 and its Tier 2 draw rules for
both sides. Expiration removes the live region immediately. A battle that
already captured it retains the frozen modifier.

The save stores the evaluation index, countdown and dedicated RNG state,
plus the live region's ID, position, source encounter, visual seed and
remaining lifetime. Loading resumes those values. Older saves start the
schedule with the configured initial delay. A system jump resets the
schedule and live region. Reserved Phase 1 records remain neutral.

The map uses two small world-space shader quads for the aperture and
engagement boundary, plus a world label for the remaining strategic
seconds. The shader uses procedural curves without texture reads,
screen effects or particles. The closing animation uses presentation
time after the region has left battle selection.

## Captures

The fixture uses a deterministic forced-success roll to capture the
feature along a naturally moving enemy route. Android device frame times
were not measured.

| View | Mobile Vulkan | GL Compatibility |
|---|---|---|
| Overview with nearby asteroid field and planets | [Mobile](physical_temporal_rifts/route-and-nearby-regions-mobile.png) | [Compatibility](physical_temporal_rifts/route-and-nearby-regions-gl_compatibility.png) |
| Oblique aperture | [Mobile](physical_temporal_rifts/oblique-aperture-mobile.png) | [Compatibility](physical_temporal_rifts/oblique-aperture-gl_compatibility.png) |
| Hostile crossing | [Mobile](physical_temporal_rifts/hostile-crossing-mobile.png) | [Compatibility](physical_temporal_rifts/hostile-crossing-gl_compatibility.png) |
| Tactical briefing | [Mobile](physical_temporal_rifts/affected-encounter-mobile.png) | [Compatibility](physical_temporal_rifts/affected-encounter-gl_compatibility.png) |
| Closing animation | [Mobile](physical_temporal_rifts/closing-mobile.png) | [Compatibility](physical_temporal_rifts/closing-gl_compatibility.png) |
| Battle with frozen modifier | [Mobile](physical_temporal_rifts/frozen-battle-mobile.png) | [Compatibility](physical_temporal_rifts/frozen-battle-gl_compatibility.png) |
