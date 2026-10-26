extends PanelContainer

# RESPONSIBILITY: Present independently replaceable PoI artwork, backing and return action.
# Image, backing and overlays remain separate so artwork can be replaced independently.
var compact := false
signal return_requested
@export var banner_texture: Texture2D
@export var maximum_height: float = 100.0
@onready var image: TextureRect = $Image
@onready var title: Label = $Overlay/Title
@onready var return_button: Button = $Overlay/Return


func _ready() -> void:
	preload("res://scripts/ui/encounter_presentation.gd").action(return_button)
	title.offset_right = -190
	return_button.pressed.connect(func(): return_requested.emit())
	resized.connect(_fit)
	_fit()


func configure(poi: Resource, category: String = "") -> void:
	var classification: String = "Hazardous location" if poi.hazardous else ("Spatial phenomenon" if poi.anomalous_presentation else "Point of interest")
	$Overlay/Caption.text = (category if not category.is_empty() else classification) if compact else "POINT OF INTEREST"
	title.text = poi.title
	var palette = preload("res://scripts/ui/encounter_presentation.gd").COLORS
	title.add_theme_color_override("font_color", palette.hazard if poi.hazardous else (palette.special if poi.anomalous_presentation else palette.ordinary))
	image.texture = poi.banner_texture if poi.banner_texture != null else banner_texture
	$Overlay/Placeholder.visible = image.texture == null
	_fit()


func _fit() -> void:
	get_node("Overlay/Placeholder").hide()
	if compact:
		custom_minimum_size.y = 44
		$Overlay/Caption.hide()
		title.add_theme_font_size_override("font_size",30)
		title.offset_left = 8
		title.offset_right = -8
		title.offset_top = -36
		$Overlay/Caption.offset_left = 8
		$Overlay/Caption.offset_top = -58
		$Overlay/Caption.add_theme_font_size_override("font_size",13)
		return
	$Overlay/Caption.show()
	title.add_theme_font_size_override("font_size",30)
	title.offset_left = 20
	title.offset_right = -190
	title.offset_top = -43
	$Overlay/Caption.offset_left = 20
	$Overlay/Caption.offset_top = -63
	$Overlay/Caption.add_theme_font_size_override("font_size",16)
	custom_minimum_size.y = clampf(
		size.x / 5.5, 88, minf(maximum_height, get_viewport_rect().size.y * .24)
	)
