extends Control
class_name FooterTab

signal pressed

@export var title: String = ""
@export var icon: Texture2D

@onready var _highlight: NinePatchRect = $Highlight
@onready var _icon: TextureRect = $VBox/Icon
@onready var _title: Label = $VBox/Title
@onready var _click: Button = $ClickArea


func _ready() -> void:
	_title.text = title
	_icon.texture = icon
	_click.pressed.connect(func() -> void: pressed.emit())
	set_active(false)


func set_active(active: bool) -> void:
	_highlight.visible = active
	if active:
		_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		_title.add_theme_color_override("font_color", Color(0.82, 0.7, 0.48, 1))
