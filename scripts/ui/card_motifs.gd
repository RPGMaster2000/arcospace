@tool
extends RefCounted
## Exact supplied assignments from docs/card_icon_mapping.csv; stable identities, no name lookup.
## PNG Resources (including missing entries) are cached once, never per frame.
const ASSIGNMENTS = {
	"res://cards/01_shield_plating.tres": "shield",
	"res://cards/02_shield_array.tres": "shield",
	"res://cards/03_hull_patch.tres": "repair",
	"res://cards/04_synthesizer_upgrade.tres": "production",
	"res://cards/05_structural_reinforcement.tres": "shield",
	"res://cards/06_shield_disruptor.tres": "sabotage",
	"res://cards/07_hull_overhaul.tres": "repair",
	"res://cards/08_energy_cell.tres": "energy",
	"res://cards/09_hull_nanobots.tres": "repair",
	"res://cards/10_shield_recharge.tres": "shield",
	"res://cards/11_reactor_upgrade.tres": "production",
	"res://cards/12_laser_burst.tres": "attack",
	"res://cards/13_plasma_strike.tres": "attack",
	"res://cards/14_energy_surge.tres": "energy",
	"res://cards/15_boarding_party.tres": "attack",
	"res://cards/16_missile_team.tres": "attack",
	"res://cards/17_shield_breachers.tres": "sabotage",
	"res://cards/18_quarters_upgrade.tres": "production",
	"res://cards/19_system_disruption.tres": "sabotage",
	"res://cards/20_torpedo_salvo.tres": "attack",
	"res://cards/21_phase_lance.tres": "pierce",
	"res://cards/22_energy_siphon.tres": "energy",
	"res://cards/23_cargo_raid.tres": "attack",
	"res://cards/24_crew_capture.tres": "swap",
	"res://cards/25_emp_pulse.tres": "sabotage",
	"res://cards/26_shield_exchange.tres": "swap",
	"res://cards/27_missile_barrage.tres": "attack",
	"res://cards/28_breach_charge.tres": "pierce",
	"res://cards/29_polaron_burst.tres": "sabotage",
	"res://cards/30_siege_driver.tres": "attack",
	"res://cards/31_emergency_refit.tres": "hull",
	"res://cards/32_antimatter_lance.tres": "pierce",
	"res://cards/33_omega_overcharge.tres": "shield",
	"res://cards/34_sabotage_commandos.tres": "sabotage",
	"res://cards/35_damage_control.tres": "hull",
	"res://cards/36_salvage_strike.tres": "materials",
	"res://cards/37_pulse_repeater.tres": "attack",
	"res://cards/38_cataclysm_protocol.tres": "risk",
	"res://cards/39_reactor_salvage.tres": "production",
	"res://cards/40_supply_diversion.tres": "resource_store",
	"res://cards/41_shield_collapse.tres": "risk",
	"res://cards/42_overloaded_warhead.tres": "risk",
	"res://cards/43_emergency_reserves.tres": "resource_store",
	"res://cards/44_desperate_conversion.tres": "risk",
	"res://cards/45_emergency_bulkheads.tres": "shield",
	"res://cards/46_structural_reclamation.tres": "swap",
	"res://cards/47_siege_charges.tres": "attack",
	"res://cards/48_industrial_sabotage.tres": "sabotage",
	"res://cards/49_salvage_cannibalization.tres": "materials",
	"res://cards/50_demolition_crew.tres": "materials",
	"res://cards/51_reinforced_foundations.tres": "shield",
	"res://cards/52_resource_seizure.tres": "swap",
	"res://cards/53_capacitor_overload.tres": "sabotage",
	"res://cards/54_power_grid_reroute.tres": "resource_store",
	"res://cards/55_reactor_synchronization.tres": "production",
	"res://cards/56_phase_inverter.tres": "sabotage",
	"res://cards/57_emergency_discharge.tres": "sabotage",
	"res://cards/58_energy_equalizer.tres": "swap",
	"res://cards/59_feedback_loop.tres": "shield",
	"res://cards/60_auxiliary_power_link.tres": "production",
	"res://cards/61_tactical_assessment.tres": "pierce",
	"res://cards/62_emergency_medical_team.tres": "repair",
	"res://cards/63_boarding_specialists.tres": "pierce",
	"res://cards/64_personnel_exchange.tres": "swap",
	"res://cards/65_scientific_breakthrough.tres": "production",
	"res://cards/66_damage_control_teams.tres": "repair",
	"res://cards/67_sabotage_operation.tres": "sabotage",
	"res://cards/68_coordinated_assault.tres": "attack",
	"res://cards/69_industrial_interference.tres": "sabotage",
	"res://cards/70_fabrication_strike.tres": "sabotage",
	"res://cards/71_reactor_interference.tres": "sabotage",
	"res://cards/72_core_destabilization.tres": "sabotage",
	"res://cards/73_personnel_disruption.tres": "sabotage",
	"res://cards/74_command_infiltration.tres": "sabotage",
	"res://cards/75_adaptive_command.tres": "resource_store",
	"res://cards/76_relentless_barrage.tres": "attack",
	"res://cards/77_reactive_armor.tres": "hull",
	"res://cards/78_industrial_repurposing.tres": "resource_store",
	"res://cards/79_shield_capacitor.tres": "shield",
	"res://cards/80_boarding_operations.tres": "pierce",
	"res://cards/enemy/iron_counterbattery.tres": "pierce"
}
const ICON_KEYS = [
	"shield",
	"repair",
	"production",
	"sabotage",
	"energy",
	"attack",
	"pierce",
	"swap",
	"hull",
	"materials",
	"risk",
	"resource_store"
]
static var textures: Dictionary = {}
static var initialized := false


static func texture_for(card: Resource) -> Texture2D:
	if card == null:
		return null
	var base: Resource = card.get_meta("inspection_base", card)
	var key: String = ASSIGNMENTS.get(base.identity_key(), "")
	if key.is_empty():
		return null
	if not initialized:
		for icon in ICON_KEYS:
			var path: String = "res://assets/ui/card_effects/%s.png" % icon
			textures[icon] = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
		initialized = true
	return textures.get(key) as Texture2D
