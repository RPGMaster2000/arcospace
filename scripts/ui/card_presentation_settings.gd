@tool
extends Resource
class_name CardPresentationSettings

# RESPONSIBILITY: Store shared compact-card and read-only inspection presentation settings.
# TUNE: One shared presentation/input configuration. No gameplay values live here.
@export_group("Compact cards")
@export_range(10, 24, 1) var compact_description_font_size: int = 14
## TUNE: Keep authored descriptions at or below this length; shorten longer text.
@export_range(0, 200, 1) var description_shorthand_threshold: int = 50
@export_range(14, 24, 1) var card_title_font_size: int = 18
@export_range(40, 56, 1) var discard_button_height: float = 44.0
@export_range(12, 22, 1) var discard_button_font_size: int = 16
@export_group("Inspection input")
@export_range(0.1, 2.0, 0.05) var hold_duration: float = 0.4
@export_range(2, 64, 1) var hold_movement_cancellation: float = 12.0
@export_group("Inspection layout")
@export_range(0.0, 1.0, 0.01) var inspection_tween_duration: float = 0.2
@export_range(0.5, 3.0, 0.05) var enlarged_card_scale: float = 1.5
@export_range(260, 640, 10) var information_panel_width: float = 360.0
@export_range(0.0, 1.0, 0.05) var background_dim_opacity: float = 0.8
@export_range(14, 30, 1) var information_panel_text_size: int = 18
@export_range(8, 64, 1) var panel_card_spacing: float = 20.0

@export_group("Tactical preview")
@export var tactical_preview_enabled: bool = true
@export_range(0, 0.6) var preview_raise_fraction: float = 0.30
@export_range(0.0, 1.0) var preview_raise_duration: float = 0.18
@export_range(0.0, 1.0) var preview_lower_duration: float = 0.16
@export var preview_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export_range(0, 40) var preview_inspect_spacing: float = 8.0
@export_range(0.0, 1.0) var preview_fade_duration: float = 0.12

@export_group("Tactical target highlights")
@export_range(0.0, 1.0, 0.05) var preview_dim_opacity: float = 0.30
@export var target_glow_padding := Vector2(28, 22)
@export_range(0.2, 5.0) var target_pulse_duration: float = 1.6
@export_range(0, 1) var target_pulse_intensity: float = 0.5
@export var target_positive: Color = Color(0.2, 0.95, 0.75)
@export var target_negative: Color = Color(1.0, 0.35, 0.12)
@export var target_uncertain: Color = Color(1.0, 0.72, 0.2)
@export var target_cost: Color = Color(0.8, 0.85, 0.9)
@export var reduced_preview_animation: bool = false
