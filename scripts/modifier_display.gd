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
