@tool
extends Resource
## Shared palette, geometry, motion and optional authored assets for the UI.

@export_group("Palette")
@export var surface := Color("102338ed")
@export var surface_depth := Color("071220f5")
@export var edge := Color("62cbe9")
@export var text := Color("e8f4ff")
@export var muted := Color("a6b8ce")
@export var materials := Color("fa937f")
@export var energy := Color("68cbff")
@export var crew := Color("73e2ac")
@export var materials_surface := Color("38232bfa")
@export var energy_surface := Color("142f46fa")
@export var crew_surface := Color("1b392efa")
@export var hull := Color("fa817b")
@export var shield := Color("6cbdff")
@export var friendly := Color("65dee9")
@export var hostile := Color("ff817c")
@export var warning := Color("ffbd69")
@export var reward := Color("ffdb87")
@export var rarity_two := Color("a9e9ff")
@export var rarity_three := Color("ffcf72")

@export_group("Geometry and typography")
@export_range(2.0, 25.0, 1.0) var corner_cut := 11.0
@export_range(0.0, 1.0, 0.01) var glow := 0.22
@export var line_width := 1.0
@export var compact_padding := 7
@export var related_gap := 5
@export var spacing := 8
@export var section_gap := 20
@export var padding := Vector2(16, 12)
@export var touch_height := 48
@export var label_size := 14
@export var heading_size := 24
@export var font: Font = preload("res://assets/fonts/emoji_ui.tres")
@export_range(4, 24) var segments := 12
## Visual reference only. Ships may have any number of Shields.
@export_range(1, 200) var shield_reference := 50

@export_group("Motion")
@export var hover_seconds := 0.12
@export var press_seconds := 0.09
@export var selection_seconds := 0.16
@export var panel_seconds := 0.23
@export var meter_seconds := 0.32
@export var transition_seconds := 0.42
@export var transition := Tween.TRANS_CUBIC
@export var easing := Tween.EASE_OUT

@export_group("Graphical replacements")
## Keys include panel, compact, dialog, warning, reward, selection, card,
## card.tier2, card.tier3, button.normal, button.pressed, tab.pressed and focus.
## State-specific keys take priority over a role-wide entry.
@export var frames: Dictionary[String, Texture2D] = {}
@export var backgrounds: Dictionary[String, Texture2D] = {}
@export var ornaments: Dictionary[String, Texture2D] = {}
@export var slice_margins := Vector4(16, 16, 16, 16)
@export var meter_track: Texture2D
@export var meter_fill: Texture2D
@export var reticle: Texture2D

@export_group("Interface audio")
@export var panel_sound: StringName
@export var warning_sound: StringName
@export var reward_sound: StringName
