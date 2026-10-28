extends Resource
@export_range(1, 30, 0.1) var player_speed: float = 12.0
@export_range(0, 5, 0.1) var enemy_speed: float = 1.2
@export_range(0.001, 1, 0.001) var seconds_per_distance: float = 0.0833333333
@export_range(0.5, 5, 0.1) var interception_radius: float = 2.5
@export_range(20, 22, 0.1) var hostile_spawn_distance: float = 20.0
@export_range(1, 100, 1) var base_attack_damage: int = 20
@export_range(1, 200, 1) var base_integrity: int = 100
@export_range(0, 10, 1) var mothership_emp_bonus: int = 2
