extends RefCounted
## A single committed span. Instant and visible resolution consume identical slices.
const STEP := 1.0 / 32.0
const EPSILON := 0.00000001

var duration: float
var elapsed := 0.0
var _steps := 0
var _advance: Callable


func _init(seconds: float, advance_span: Callable) -> void:
	duration = seconds
	_advance = advance_span


func advance_to(target: float) -> bool:
	var available := minf(duration, target)
	while elapsed < duration:
		var boundary := minf(duration, (_steps + 1) * STEP)
		if boundary > available + EPSILON:
			break
		var span := boundary - elapsed
		elapsed = boundary
		_steps += 1
		_advance.call(span)
	return elapsed >= duration
