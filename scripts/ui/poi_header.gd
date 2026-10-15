extends PanelContainer
# Image, backing and overlays remain separate so artwork can be replaced independently.
signal return_requested
@export var banner_texture: Texture2D
@export var maximum_height: float = 156.0
@onready var image: TextureRect = $Image
@onready var title: Label = $Overlay/Title
@onready var return_button: Button = $Overlay/Return

func _ready() -> void:
	preload("res://scripts/ui/encounter_presentation.gd").action(return_button)
	return_button.pressed.connect(func(): return_requested.emit())
	resized.connect(_fit)
	_fit()

func configure(poi: Resource) -> void:
	title.text = poi.title
	image.texture = poi.banner_texture if poi.banner_texture != null else banner_texture
	$Overlay/Placeholder.visible = image.texture == null
	_fit()

func _fit() -> void:
	custom_minimum_size.y = clampf(size.x / 5.5, 100, minf(maximum_height, get_viewport_rect().size.y * .24))
