extends Resource
@export_range(1, 30, 0.1) var player_speed: float = 7.0
@export_range(0, 5, 0.1) var enemy_speed: float = 1.2
@export_range(0.001, 1, 0.001) var seconds_per_distance: float = 0.142857142857
@export_range(0.5, 5, 0.1) var interception_radius: float = 2.5
@export_range(20, 22, 0.1) var hostile_spawn_distance: float = 20.0
@export_range(1, 100, 1) var base_attack_damage: int = 20
@export_range(1, 200, 1) var base_integrity: int = 100
@export_range(0, 10, 1) var mothership_emp_bonus: int = 2

@export_range(0, 10, 0.1) var poi_seconds: float = 1.5
@export_range(0, 10, 0.1) var battle_seconds: float = 2.5
@export_range(0.1, 30, 0.1) var first_reinforcement_seconds: float = 7.0
@export_range(0.1, 30, 0.1) var reinforcement_interval_seconds: float = 9.0
@export_range(1, 10, 1) var maximum_active_attackers: int = 3
@export_range(0, 20, 1) var maximum_reinforcements: int = 4
@export_range(0.15, 1.0, 0.05) var inspection_hold_seconds: float = 0.4
