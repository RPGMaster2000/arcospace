extends RefCounted

# HUVUDANSVAR: Samla de 28 kortresurserna i originalets ordning.
# GÖR INTE: Utföra effekter eller hantera en korthand.
const CARDS = [
	preload("res://cards/01_shield_plating.tres"),
	preload("res://cards/02_shield_array.tres"),
	preload("res://cards/03_hull_patch.tres"),
	preload("res://cards/04_synthesizer_upgrade.tres"),
	preload("res://cards/05_structural_reinforcement.tres"),
	preload("res://cards/06_shield_disruptor.tres"),
	preload("res://cards/07_hull_overhaul.tres"),
	preload("res://cards/08_energy_cell.tres"),
	preload("res://cards/09_hull_nanobots.tres"),
	preload("res://cards/10_shield_recharge.tres"),
	preload("res://cards/11_reactor_upgrade.tres"),
	preload("res://cards/12_laser_burst.tres"),
	preload("res://cards/13_plasma_strike.tres"),
	preload("res://cards/14_energy_surge.tres"),
	preload("res://cards/15_boarding_party.tres"),
	preload("res://cards/16_missile_team.tres"),
	preload("res://cards/17_shield_breachers.tres"),
	preload("res://cards/18_quarters_upgrade.tres"),
	preload("res://cards/19_system_disruption.tres"),
	preload("res://cards/20_torpedo_salvo.tres"),
	preload("res://cards/21_phase_lance.tres"),
	preload("res://cards/22_energy_siphon.tres"),
	preload("res://cards/23_cargo_raid.tres"),
	preload("res://cards/24_crew_capture.tres"),
	preload("res://cards/25_emp_pulse.tres"),
	preload("res://cards/26_shield_exchange.tres"),
	preload("res://cards/27_missile_barrage.tres"),
	preload("res://cards/28_breach_charge.tres"),
]
