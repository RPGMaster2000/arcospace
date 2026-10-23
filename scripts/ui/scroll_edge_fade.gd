extends TextureRect
# Stationary overlay: never participates in scroll layout, input or scrollbar geometry.
var scroll: ScrollContainer
@export_range(16.0, 96.0) var fade_height: float = 40.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.055, 0.102, 0.157, 0), Color(0.055, 0.102, 0.157, 0.98)])
	var image := GradientTexture2D.new()
	image.gradient = gradient
	image.fill_from = Vector2(0, 0)
	image.fill_to = Vector2(0, 1)
	texture = image


func _process(_delta: float) -> void:
	if not is_instance_valid(scroll):
		return
	var bar := scroll.get_v_scroll_bar()
	var remaining: float = bar.max_value - bar.page - bar.value
	visible = scroll.is_visible_in_tree() and remaining > 1.0
	var height: float = minf(fade_height, scroll.size.y)
	position = scroll.global_position - get_parent().global_position + Vector2(0, scroll.size.y - height)
	# Leave the live scrollbar completely uncovered.
	size = Vector2(maxf(0, scroll.size.x - (bar.size.x if bar.visible else 0) - 2), height)
	modulate.a = clampf(remaining / maxf(height, 1.0), 0, 1)
