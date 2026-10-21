extends Resource
class_name VisualEffectSettings
# RESPONSIBILITY: Shared, Inspector-editable tuning for closed-alpha visual feedback.
@export_group("Card interaction")
## Contained artwork zoom: hand transforms and input rectangles remain unchanged.
@export_range(1.0, 1.15, 0.01) var card_hover_scale: float = 1.06
@export_range(1.0, 1.2, 0.01) var card_selected_scale: float = 1.10
@export_range(0.0, 8.0, 0.5) var card_hover_elevation: float = 2.0
@export_range(0.01, 0.5, 0.01) var card_hover_duration: float = 0.12
@export_range(0.01, 0.5, 0.01) var card_selected_duration: float = 0.10
@export_color_no_alpha var card_selection_color: Color = Color(0.55, 0.9, 1.0)
@export_range(0.0, 1.0, 0.05) var card_glow_intensity: float = 0.35
@export var interaction_transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var interaction_ease: Tween.EaseType = Tween.EASE_OUT
@export_group("Hull impact")
@export_color_no_alpha var hull_flash_color: Color = Color(1, 0.08, 0.04)
@export_range(0.0, 1.0, 0.05) var hull_flash_opacity: float = 0.85
@export_range(0.05, 1.0, 0.01) var hull_flash_duration: float = 0.18
@export_range(0.0, 0.2, 0.005) var hull_shake_strength: float = 0.08
@export_range(0.05, 1.0, 0.01) var hull_shake_duration: float = 0.22
@export_group("Shield impact")
@export_color_no_alpha var shield_impact_color: Color = Color(0.2, 0.65, 1)
@export_range(0.0, 1.0, 0.05) var shield_flash_opacity: float = 0.9
@export_range(0.05, 1.0, 0.01) var shield_flash_duration: float = 0.20
@export_range(0.0, 2.0, 0.05) var shield_ripple_strength: float = 1.0
@export_range(1.0, 64.0, 1.0) var shield_ripple_speed: float = 32.0
@export_group("Engines")
@export_range(0.0, 3.0, 0.05) var engine_glow_intensity: float = 0.7
@export_range(0.0, 0.25, 0.01) var engine_pulse_amplitude: float = 0.08
## Idle cycles per second; authored engine colors are preserved unless overridden.
@export_range(0.0, 2.0, 0.05) var engine_pulse_speed: float = 0.35
@export var override_engine_color: bool = false
@export_color_no_alpha var engine_glow_color: Color = Color(0.15, 0.75, 1)
@export_range(1.0, 4.0, 0.1) var engine_ftl_multiplier: float = 1.6
@export_range(0.01, 1.0, 0.01) var engine_ftl_transition_duration: float = 0.2
@export_group("POI and UI")
@export var poi_success_color: Color = Color(0.15, 0.85, 0.35, 0.24)
@export var poi_failure_color: Color = Color(0.95, 0.18, 0.15, 0.24)
@export_range(0.1, 1.0, 0.01) var poi_reveal_duration: float = 0.30
@export_range(0.01, 0.6, 0.01) var ui_transition_duration: float = 0.20
@export_range(0.0, 1.0, 0.05) var reward_text_emphasis: float = 0.20
@export_group("Battle results")
@export_range(0.01, 0.6, 0.01) var result_heading_duration: float = 0.20
@export_range(0.9, 1.0, 0.01) var result_heading_start_scale: float = 0.96
@export_color_no_alpha var victory_accent_color: Color = Color(0.65, 1.0, 0.75)
@export_color_no_alpha var defeat_accent_color: Color = Color(1.0, 0.55, 0.5)

@export_group("Existing combat feedback timing")
## Preserve BattleEffects' resolution envelope while tuning the visible flashes separately.
@export_range(0.02, 0.15, 0.005) var count_step_seconds: float = 0.065
@export_range(0.1, 2.0, 0.05) var hit_seconds: float = 0.6
@export_range(0.1, 2.0, 0.05) var production_seconds: float = 0.48
@export_range(0.2, 3.0, 0.05) var repair_seconds: float = 0.75
@export_range(0.2, 3.0, 0.05) var shield_seconds: float = 0.55
@export_range(0.0, 12.0, 0.5) var shake_pixels: float = 4.0
@export_range(1.0, 1.2, 0.01) var icon_peak_scale: float = 1.07
