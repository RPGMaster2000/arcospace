@tool
extends Resource
class_name CardPresentationSettings

# RESPONSIBILITY: Store shared compact-card and read-only inspection presentation settings.
# TUNE: One shared presentation/input configuration. No gameplay values live here.
@export_group("Compact cards")
@export_range(10, 24, 1) var compact_description_font_size: int = 14
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
