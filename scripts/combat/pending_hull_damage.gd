extends Node
# RESPONSIBILITY: Deterministically release already-calculated Hull damage at the burst cue.
# No damage formulas, game-state copy or Tween-driven commits live here.
signal damage_applied
var pending: Array[Dictionary] = []
var elapsed: float = 0.0
var burst_time: float = 0.2
var total_time: float = 0.75
var running: bool = false
var closing: bool = false
var _commit: Callable
var _updates: Array[Callable] = []
var _skip: Callable


func arm(
	events: Array[Dictionary],
	burst: float,
	total: float,
	commit: Callable,
	updates: Array[Callable],
	skip: Callable
) -> void:
	finish_now()
	pending = events
	elapsed = 0.0
	burst_time = maxf(0.0, burst)
	total_time = maxf(burst_time + 0.01, total)
	_commit = commit
	_updates = updates.duplicate()
	_skip = skip
	running = true
	_seek(0.0)
	if burst_time == 0:
		_resolve(true)


func _process(delta: float) -> void:
	if running:
		if _skip.is_valid() and _skip.call():
			finish_now()
		else:
			advance(delta)


func advance(delta: float) -> void:
	if not running:
		return
	var next: float = minf(total_time, elapsed + maxf(0.0, delta))
	if not pending.is_empty() and next >= burst_time:
		# Fragment launch and the authoritative commit share this exact boundary.
		_seek(burst_time)
		_resolve(true)
	elapsed = next
	_seek(elapsed)
	if elapsed >= total_time:
		running = false
		_updates.clear()


func _seek(time: float) -> void:
	for update in _updates:
		if update.is_valid():
			update.call(time)


func _resolve(visuals: bool) -> void:
	if pending.is_empty():
		return
	var events: Array[Dictionary] = pending
	pending = []  # Clear before calling out: re-entrant cleanup cannot apply twice.
	if _commit.is_valid():
		_commit.call(events, visuals)
	damage_applied.emit()


func finish_now(visuals: bool = true) -> void:
	if not running and pending.is_empty():
		return
	_seek(burst_time)
	_resolve(visuals)
	_seek(total_time)
	running = false
	_updates.clear()


func _exit_tree() -> void:
	closing = true
	finish_now(false)
