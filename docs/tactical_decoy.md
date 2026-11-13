# Tactical Decoy Beacon

The Defense Derelict Starship offers one guaranteed beacon for three
strategic seconds. Two unused beacons can be stored across system jumps.
One deployed beacon can be active in the current system.

The lower-right inventory action opens deployment confirmation. Pan or
zoom to position the wireframe at the center of the map. The deployment
limit is 12 world units from the ship, and the attraction radius is 15
units. Dotted lines identify the ships currently eligible for diversion.
Placement requires clearance from destinations, bodies, and installations.
Environmental regions are eligible placement locations.

Placement spends one item and no strategic time. The existing fleet
timeline sweeps ordinary attackers for range entry, redirects their
targets, and releases them on first contact with the beacon or after
15 strategic seconds. Ships keep their speeds and resume homeward movement
from their current positions. The mothership and missiles keep their
original targets. Battle entry still evaluates the actual encounter
position and freezes the existing environmental modifier.

Saves retain inventory, the active position, affected encounter IDs,
radius and remaining lifetime. Placement preview is transient. Older
saves open with empty beacon inventory.

## Windows captures

| View | Mobile Vulkan | GL Compatibility |
|---|---|---|
| Inventory | [Mobile](tactical_decoy/inventory-mobile.png) | [GL](tactical_decoy/inventory-gl_compatibility.png) |
| Placement | [Mobile](tactical_decoy/placement-mobile.png) | [GL](tactical_decoy/placement-gl_compatibility.png) |
| Active beacon | [Mobile](tactical_decoy/active-mobile.png) | [GL](tactical_decoy/active-gl_compatibility.png) |
| Routes restored | [Mobile](tactical_decoy/released-mobile.png) | [GL](tactical_decoy/released-gl_compatibility.png) |
