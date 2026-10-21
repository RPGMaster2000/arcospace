extends Control
# RESPONSIBILITY: Show modifier countdown and activation feedback; never change rules.
## TUNE: Seconds for the central message to remain visible before fading.
@export var hold_seconds: float = 1.2
var flash_tween: Tween


func refresh(modifier: Node, round_number: int) -> void:
	$Meter.visible = modifier.kind != 0
	$Meter/Text.text = modifier.status_text(round_number)
	$Meter/Progress.value = modifier.meter_value(round_number)


func announce(message: String) -> void:
	if message.is_empty():
		return
	if flash_tween:
		flash_tween.kill()
	$Flash.text = message
	$Flash.modulate.a = 0.0
	flash_tween = create_tween()
	flash_tween.tween_property($Flash, "modulate:a", 1.0, 0.12)
	flash_tween.tween_interval(hold_seconds)
	flash_tween.tween_property($Flash, "modulate:a", 0.0, 0.35)


## TUNE: Disable cinematic pauses/flashes for instant presentation or automated checks.
@export var cinematic_enabled: bool = true
## TUNE: Warning lead-in and result reading time, in seconds.
@export var warning_seconds: float = 1.15
@export var result_seconds: float = 0.75
## TUNE: Screen flash strength (0–1), fade duration, and player impact shake distance.
@export var flash_opacity: float = 0.28
@export var flash_seconds: float = 0.45
@export var shake_pixels: float = 5.0
var screen_tween: Tween
var shake_tween: Tween
var original_canvas: Transform2D
var shaking: bool = false
var active_shake_pixels: float = 0.0


func warning(kind: int, card_effect: bool = false, effect_text: String = "") -> void:
	if not cinematic_enabled:
		return
	var messages = {
		1: "ASTEROID SHOWER INBOUND\nBrace for impact…",
		2: "ION STORM APPROACHING\nEnergy systems destabilizing…",
		3: "SOLAR FLARE INCOMING\n Shield emitters failing…"
	}
	announce(("ION SURGE\n" + effect_text) if card_effect else messages.get(kind, ""))
	await get_tree().create_timer(warning_seconds).timeout


func impact(kind: int, player_hit: bool = false) -> void:
	if not cinematic_enabled:
		return
	var colors = {1: Color(1.0, 0.08, 0.03), 2: Color(0.12, 0.45, 1.0), 3: Color(1.0, 0.9, 0.25)}
	if not colors.has(kind):
		return
	if screen_tween:
		screen_tween.kill()
	$ScreenFlash.color = colors[kind]
	$ScreenFlash.modulate.a = flash_opacity
	screen_tween = create_tween()
	screen_tween.tween_property($ScreenFlash, "modulate:a", 0.0, flash_seconds)
	if player_hit:
		shake_screen(shake_pixels, flash_seconds)


# Shared by modifier impacts and shield feedback; keep a single canvas-shake owner.
func shake_screen(pixels: float, seconds: float) -> void:
	if not cinematic_enabled or pixels <= 0 or (shaking and pixels < active_shake_pixels):
		return
	if shake_tween:
		shake_tween.kill()
	if not shaking:
		original_canvas = get_viewport().canvas_transform
	shaking = true
	active_shake_pixels = pixels
	shake_tween = create_tween()
	shake_tween.tween_method(_shake, 1.0, 0.0, seconds)
	shake_tween.tween_callback(_restore_screen)


func _shake(strength: float) -> void:
	var offset = (
		Vector2(sin(strength * 47.0), cos(strength * 61.0)) * active_shake_pixels * strength
	)
	var transform = original_canvas
	transform.origin += offset
	get_viewport().canvas_transform = transform


func _restore_screen() -> void:
	if shaking:
		get_viewport().canvas_transform = original_canvas
		shaking = false


func hold_result() -> void:
	if cinematic_enabled:
		await get_tree().create_timer(result_seconds).timeout


func _exit_tree() -> void:
	_restore_screen()


## TUNE: FTL transitions hold longer than modifier flashes; offline adds one second.
@export var ftl_offline_seconds: float = 1.45
@export var ftl_online_seconds: float = 0.65
var ftl_tween: Tween


func ftl_offline() -> void:
	_ftl_event("EMP PULSE OFFLINE", Color(1, 0.12, 0.04), ftl_offline_seconds, 0.32)


func ftl_online(fully_charged: bool) -> void:
	_ftl_event(
		"EMP PULSE ONLINE" if fully_charged else "EMP PULSE REPAIRED · RESUMING CHARGING",
		Color(0.25, 0.65, 1),
		ftl_online_seconds,
		0.16
	)


func _ftl_event(message: String, color: Color, seconds: float, strength: float) -> void:
	if not cinematic_enabled:
		return
	if ftl_tween:
		ftl_tween.kill()
	$FTLFlash.text = message
	$FTLFlash.modulate = Color(color, 1.0)
	$FTLTint.color = Color(color, strength)
	var label = get_parent().get_node("FTLPanel/Charge")
	label.modulate = color
	ftl_tween = create_tween().set_parallel(true)
	ftl_tween.tween_property($FTLTint, "color:a", 0.0, seconds)
	ftl_tween.tween_property($FTLFlash, "modulate:a", 0.0, 0.4).set_delay(seconds)
	ftl_tween.tween_property(label, "modulate", Color.WHITE, seconds)
