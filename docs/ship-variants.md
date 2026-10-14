# Ship profiles

The title screen defaults to Wayfarer and offers Wayfarer, Specter and Bastion with live 3D previews and compact rules. The old resource/production/FTL controls are removed. A normal title-screen start uses the selected profile at full permanent Hull capacity; the player receives ordinary first-turn production income, so displayed battle resources are starting reserves plus production. Enemy reserves receive income only when its turn begins.

Player selection is stored in setup_settings.player_ship and survives Play Again, Continue and Battle Setup until another ship is selected. An enemy profile is rolled equally from Marauder, Sentinel and Reclaimer for every new normal match, including restarts and continuations. Enemy FTL is not added. Existing AI priorities are unchanged; ship economies provide variety without additional deck weighting.

Continue retains permanent player Hull up to the selected capacity and applies existing one-battle rewards. Shields and reserves/production restart from ShipData; temporary plating expires. FTL resets to the selected ship's charge duration and disruption resistance.

## Edit attributes in Godot

Select any resource in ships/ (wayfarer.tres, specter.tres, bastion.tres, marauder.tres, sentinel.tres, reclaimer.tres). The Inspector exposes Hull Capacity, Shields, Materials/Energy/Crew, Synthesizer (Fabricator), Reactor, Quarters (Hangar), FTL Turns, FTL Resistance, Hull Color and optional Model Scene. Edit the numbers here; the menu reads them automatically. ShipData is defined in scripts/ship_data.gd; scripts/ship_library.gd lists the six profiles.

FTL Resistance is a fraction: 0.25 multiplies the existing capped probability by 0.75; -0.10 multiplies it by 1.10. Normal remains 1.0. For four permanent Hull damage the probabilities are 20% / 15% / 22%. At the existing damage cap they become 60% / 45% / 66%. Duration, charge preservation and plating immunity remain unchanged.

## Replace a model independently

Model Scene is empty by default, retaining the existing battlefield ship and the user-authored light. To replace only one profile, duplicate scenes/ship_3d.tscn, edit its geometry/materials, then drag that scene into the corresponding ShipData Model Scene field. The title preview and battle both load it. Keep the root ship_3d.gd animation API, Body, Body/Hull, Body/Engine and Shield nodes. Replace mesh geometry under these nodes freely; these names connect existing hit/repair/shield effects. If you want the engine-light FTL effect, add Body/OmniLight3D to the replacement. An absent light is supported.

Hull Color updates only the private Hull material on each ship instance; Engine, Shield and separate effect shader materials are not tinted. Existing battlefield position/transform is applied to replacement models. No per-variant battlefield or gameplay-script copies are required.

Direct board scenes without player_ship settings retain their legacy Inspector statistics for custom experiments/tests. Normal gameplay enters through battle_setup.tscn and always uses ShipData profiles.

Verification includes all profile values, player/enemy income timing, randomized enemies, FTL multipliers/cap, selection persistence, plating transitions, per-profile colors and optional replacement models. Desktop 1280×720 and landscape 960×540 menu renders were inspected; physical phone input/performance was not measured.
