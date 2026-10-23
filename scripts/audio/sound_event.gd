extends Resource
# RESPONSIBILITY: Inspector-editable definition of one replaceable presentation sound.
@export var event_id: StringName
@export var enabled: bool = true
@export var streams: Array[AudioStream] = []
@export_range(-40, 6, 0.5) var volume_db: float = 0.0
@export_range(0.5, 2, 0.01) var pitch_scale: float = 1.0
## Symmetric fractional variation; 0.03 means +/-3%. Keep alerts at zero.
@export_range(0, 0.15, 0.005) var pitch_variation: float = 0.0
@export_range(0, 3, 0.01) var replay_interval: float = 0.08
@export_range(1, 12, 1) var concurrency_limit: int = 2
## Higher priority can replace an older lower-priority voice when the pool is full.
@export_enum("Low:0", "Medium:1", "High:2") var priority: int = 1
## Events sharing a nonempty group share replay protection (e.g. minor resource income).
@export var replay_group: StringName
