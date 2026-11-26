extends RefCounted
## Scene-free route geometry. State owners schedule leg boundaries and outcomes.
const Layout = preload("res://scripts/expedition/system_layout.gd")
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const EPSILON := 0.00001

var id: String
var kind: String
var display_name: String
var faction: String
var speed: float
var route: Array[Vector3] = []
var leg := 0
var progress := 0.0
var activity := "traveling"


func position() -> Vector3:
	if leg >= route.size() - 1: return route.back()
	return route[leg].move_toward(route[leg + 1], progress)


func destination() -> Vector3:
	return route.back()


func traveling() -> bool:
	return activity == "traveling"


func velocity() -> Vector3:
	if not traveling() or leg >= route.size() - 1: return Vector3.ZERO
	return (route[leg + 1] - route[leg]).normalized() * speed


func leg_seconds() -> float:
	if not traveling() or leg >= route.size() - 1: return INF
	return maxf(0, route[leg].distance_to(route[leg + 1]) - progress) / speed


func remaining_seconds() -> float:
	if not traveling(): return 0.0
	var distance := -progress
	for i in range(leg, route.size() - 1):
		distance += route[i].distance_to(route[i + 1])
	return maxf(0, distance) / speed


func travel_span(seconds: float) -> void:
	if traveling() and leg < route.size() - 1:
		progress = minf(route[leg].distance_to(route[leg + 1]), progress + seconds * speed)


func finish_leg() -> bool:
	if leg < route.size() - 1:
		leg += 1
		progress = 0.0
	return leg == route.size() - 1


func route_snapshot() -> Dictionary:
	return {"route":route.map(func(at): return [at.x, at.y, at.z]),
		"leg":leg, "progress":progress, "speed":speed, "activity":activity}


func restore_route(data: Dictionary, expansion: float) -> bool:
	var points: Variant = data.get("route")
	if not points is Array or points.size() < 2 or points.size() > 5: return false
	if not finite(data.get("speed"), 0.1, 10) or not whole(data.get("leg"), 0, points.size() - 1): return false
	if data.get("activity") not in ["traveling", "extracted", "destroyed"]: return false
	for wire in points:
		if not Navigation.valid_point(wire, false): return false
		var at := Vector3(wire[0], wire[1], wire[2])
		if not Layout.navigable(at, expansion) or (not route.is_empty() and route.back().distance_to(at) < 0.5):
			return false
		route.append(at)
	leg = int(data.leg)
	var limit := route[leg].distance_to(route[leg + 1]) if leg < route.size() - 1 else 0.0
	if not finite(data.get("progress"), 0, limit + EPSILON): return false
	if data.activity == "extracted" and leg != route.size() - 1: return false
	if data.activity != "extracted" and leg == route.size() - 1: return false
	progress = minf(limit, float(data.progress))
	speed = float(data.speed)
	activity = data.activity
	return true


# Earliest intercept against uniform linear motion. Include a contact radius
# by solving |relative + velocity*t| = radius + speed*t.
static func meeting_time(relative: Vector3, target_velocity: Vector3, pursue_speed: float, radius: float = 0.0) -> float:
	var c := relative.length_squared() - radius * radius
	if c <= 0.0: return 0.0
	var a := target_velocity.length_squared() - pursue_speed * pursue_speed
	var b := 2.0 * (relative.dot(target_velocity) - pursue_speed * radius)
	if absf(a) < 0.00000001: return -c / b if b < 0.0 else INF
	var d := b * b - 4.0 * a * c
	if d < 0.0: return INF
	var first := (-b - sqrt(d)) / (2.0 * a)
	var second := (-b + sqrt(d)) / (2.0 * a)
	return minf(first if first >= 0.0 else INF, second if second >= 0.0 else INF)


static func finite(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func whole(value: Variant, low: int, high: int) -> bool:
	return finite(value, low, high) and int(value) == value
