extends Resource
@export_range(1, 30, 0.1) var player_speed: float = 7.0
@export_range(0, 5, 0.1) var enemy_speed: float = 1.2
@export_range(0.001, 1, 0.001) var seconds_per_distance: float = 0.142857142857
@export_range(0.5, 5, 0.1) var interception_radius: float = 2.5
@export_range(20, 24, 0.1) var hostile_spawn_distance: float = 22.0
@export_range(1, 100, 1) var base_attack_damage: int = 20
@export_range(1, 200, 1) var base_integrity: int = 100
@export_range(0, 10, 1) var mothership_emp_bonus: int = 2

@export_range(0, 10, 0.1) var poi_seconds: float = 1.5
@export_range(0, 10, 0.1) var battle_seconds: float = 2.5
@export_range(0.1, 30, 0.1) var first_reinforcement_seconds: float = 9.0
@export_range(0.1, 30, 0.1) var reinforcement_interval_seconds: float = 12.0
@export_range(1, 10, 1) var maximum_active_attackers: int = 3
@export_range(0, 20, 1) var maximum_reinforcements: int = 4
@export_range(0.15, 1.0, 0.05) var inspection_hold_seconds: float = 0.4

@export_range(0.15, 0.8, 0.05) var double_tap_seconds: float = 0.35

@export_range(1.0, 1000.0, 1.0) var pressure_maximum: float = 100.0
@export_range(0.0, 100.0, 0.1) var pressure_per_second: float = 2.0
@export_range(0.1, 5.0, 0.1) var mothership_speed: float = 0.65
@export_range(1, 1000, 1) var turret_salvage_cost: int = 12
@export_range(1, 8, 1) var turret_capacity: int = 2
@export_range(1.0, 28.0, 0.1) var turret_radius: float = 7.0
@export_range(1, 1000, 1) var turret_damage: int = 5
@export_range(1, 100, 1) var turret_round_interval: int = 2

@export_range(0.1, 120.0, 0.1) var rift_evaluation_interval: float = 12.0
@export_range(0.0, 1.0, 0.01) var rift_spawn_chance: float = 0.12
@export_range(0.1, 120.0, 0.1) var rift_lifetime: float = 15.0
@export_range(0.0, 120.0, 0.1) var rift_initial_delay: float = 12.0

@export_group("Starfront Defense v2")
@export var starting_fleet_weights := Vector3(0.25, 0.50, 0.25)
@export_range(0.0, 1.0, 0.01) var pressure_rate_multiplier := 0.5
@export_range(1.0, 99.0, 1.0) var mothership_reveal_pressure := 50.0
@export_range(0.1, 120.0, 0.1) var first_missile_seconds := 8.0
@export_range(0.1, 120.0, 0.1) var missile_interval := 18.0
@export_range(1, 8) var maximum_missiles := 2
@export_range(1.0, 5.0, 0.1) var missile_speed_multiplier := 2.0
@export_range(1, 100) var missile_hull := 8
@export_range(1, 100) var missile_home_damage := 12
@export_range(1, 100) var turret_missile_damage := 4
@export_range(0.1, 30.0, 0.1) var turret_missile_interval := 0.8
@export_range(0.1, 10.0, 0.1) var missile_intercept_seconds := 1.0
@export_range(0.1, 10.0, 0.1) var missile_precision_seconds := 0.5
@export_range(0.1, 10.0, 0.05) var missile_emp_seconds := 0.25
