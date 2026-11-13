extends RefCounted
## Defense-only approach catalogue. No state, RNG, scene references or shared resource mutation.
## The resolver owns eligibility, transaction timing and applying these declarative rewards.
const Approach = preload("res://scripts/expedition/encounter_approach.gd")
const Outcome = preload("res://scripts/expedition/encounter_outcome.gd")

static func description(id: String) -> String:
	return {
		"mining_operation":"An abandoned industrial complex holds materials, machinery and defensive equipment.",
		"research_station":"Military archives offer card schematics, experimental weapons and mothership research.",
		"spatial_anomaly":"A spacetime disturbance can alter Pressure, propulsion or reactor performance.",
		"gas_giant":"Harvest atmospheric energy for reserves or temporary production.",
		"distress_signal":"Recover supplies, rescue specialists or retrieve equipment.",
		"derelict_starship":"Recover salvage, armaments or industrial machinery from a silent wreck.",
		"radiation_nebula":"Collect useful isotopes or channel radiation into reactor reserves.",
		"pirate_debris_field":"Choose cargo, munitions or recovered card technology from pirate wreckage.",
		"raider_cache":"Recover secured supplies, weapons or EMP cells.",
		"quarantined_colony":"Help the colony and recover supplies, specialists or medical support.",
		"fuel_depot":"Recover stored fuel or recharge combat reserves.",
		"sensor_relay":"Recover navigation archives or decode tactical schematics.",
		"ancient_navigation_array":"Recover navigation archives or decode tactical schematics.",
		"unstable_wormhole":"Recover displaced cargo or channel exotic energy."
	}.get(id, "Choose a guaranteed benefit; the invasion advances during the operation.")

static func definitions(id: String) -> Array:
	match id:
		"mining_operation": return [
			row("Strip the Facility", "+12 Salvage", 2, {"salvage":12}),
			row("Recover Industrial Equipment", "+1 Materials production · 3 battles", 4, production("synthesizer",1,3)),
			row("Restore Defense Platform", "Free Kinetic Turret at this location", 5, {"turret":true}),
			row("Automated Extraction", "+18 Salvage", 6, {"salvage":18}, "synthesizer")]
		"research_station": return [
			row("Recover Card Schematics", "Two random Tier 1 cards · keep both", 4, {"cards":2}),
			row("Experimental Weapons", "+1 Energy production · 3 battles", 4, production("reactor",1,3)),
			row("Analyze Mothership Defenses", "Player card damage bypasses mothership Shields · this system", 6, {"mothership":"penetration"}),
			row("Extract Targeting Algorithms", "+50% player card damage against mothership · this system", 6, {"mothership":"damage"}, "reactor")]
		"spatial_anomaly": return [
			row("Stabilize Temporal Field", "Pause Pressure accumulation · 15 strategic seconds", 3, {"pause":15.0}),
			row("Dilate Local Time", "Half Pressure accumulation · 30 strategic seconds", 3, {"reduction":30.0}),
			row("Harvest Exotic Fuel", "+50% map travel speed · 30 distance units", 3, {"fuel":30.0}),
			row("Reactor Synchronization", "+2 Energy production · 2 battles", 5, production("reactor",2,2), "reactor")]
		"gas_giant": return [
			row("Atmospheric Sampling", "+6 Energy next battle", 2, {"next_battle":{"energy":6}}),
			row("Gas Harvesting", "+1 Energy production · 2 battles", 4, production("reactor",1,2)),
			row("Precision Skimming", "+8 Energy next battle · +4 Salvage", 4, {"next_battle":{"energy":8},"salvage":4}, "reactor")]
		"distress_signal": return [
			row("Recover Supplies", "+8 Salvage", 2, {"salvage":8}),
			row("Rescue Crew", "+1 Crew production · 2 battles", 4, production("quarters",1,2)),
			row("Salvage Equipment", "Two random Tier 1 cards · keep both", 4, {"cards":2}, "quarters")]
		"derelict_starship": return [
			row("External Salvage", "+10 Salvage", 2, {"salvage":10}),
			row("Recover Armaments", "Two random Tier 1 cards · keep both", 4, {"cards":2}),
			row("Engineering Recovery", "+1 Materials production · 2 battles", 4, production("synthesizer",1,2), "synthesizer"),
			row("Recover Tactical Decoy", "+1 Tactical Decoy Beacon", 3, {"decoy":true})]
		"radiation_nebula": return [
			row("Collect Isotopes", "+6–10 Salvage", 3, {"salvage_range":[6,10]}),
			row("Charge Capacitors", "+8 Energy next battle", 3, {"next_battle":{"energy":8}}),
			row("Shielded Sampling", "+1 Energy production · 2 battles", 4, production("reactor",1,2), "reactor")]
		"pirate_debris_field": return [
			row("Recover Cargo", "+8–12 Salvage", 3, {"salvage_range":[8,12]}),
			row("Recover Munitions", "+8 Materials next battle", 3, {"next_battle":{"materials":8}}),
			row("Sort Wreckage", "Two random Tier 1 cards · keep both", 4, {"cards":2}, "synthesizer")]
		"raider_cache": return [
			row("Open Supply Crates", "+8–12 Salvage", 3, {"salvage_range":[8,12]}),
			row("Recover Weapons", "Two random Tier 1 cards · keep both", 4, {"cards":2}),
			row("Restore EMP Cells", "+2 EMP Pulse charge next battle", 4, {"next_battle":{"emp_pulse_charge":2}}, "reactor")]
		"quarantined_colony": return [
			row("Recover Emergency Stores", "+8 Salvage", 3, {"salvage":8}),
			row("Recruit Specialists", "+1 Crew production · 2 battles", 4, production("quarters",1,2)),
			row("Medical Assistance", "Repair 8 Hull", 4, {"hull":8}, "quarters")]
		"fuel_depot": return [
			row("Recover Fuel Reserves", "+6–10 Salvage", 2, {"salvage_range":[6,10]}),
			row("Refill Capacitors", "+8 Energy next battle", 3, {"next_battle":{"energy":8}})]
		"sensor_relay", "ancient_navigation_array": return [
			row("Recover Navigation Archives", "+8 Salvage", 2, {"salvage":8}),
			row("Decode Tactical Archives", "Two random Tier 1 cards · keep both", 4, {"cards":2}, "quarters")]
		"unstable_wormhole": return [
			row("Recover Displaced Cargo", "+8–12 Salvage", 3, {"salvage_range":[8,12]}),
			row("Tap Exotic Energy", "+8 Energy next battle", 3, {"next_battle":{"energy":8}})]
	return []

static func production(category: String, amount: int, battles: int) -> Dictionary:
	return {"production":{"category":category,"amount":amount,"battles":battles}}

static func row(title: String, description: String, seconds: int, reward: Dictionary, requirement: String = "") -> Dictionary:
	var approach := Approach.new()
	approach.title = title
	approach.requirement = requirement
	approach.minimum_production = 3
	approach.success_chance = 1.0
	approach.success = Outcome.new()
	approach.success.blurb = description
	approach.success.hull = int(reward.get("hull",0))
	# A neutral failure resource preserves existing Resource consumers while the
	# Defense transaction never rolls a success/failure outcome.
	approach.failure = Outcome.new()
	approach.set_meta("strategic_reward",reward.duplicate(true))
	approach.set_meta("strategic_seconds",seconds)
	approach.set_meta("strategic_description",description)
	return {"approach":approach,"description":description,"seconds":seconds,"reward":reward}
