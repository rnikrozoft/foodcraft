extends Control
class_name IngredientCard

signal pressed

@export var title: String = ""
@export var emoji: String = ""

@onready var _highlight: NinePatchRect = $Highlight
@onready var _emoji: Label = $Emoji
@onready var _title: Label = $Title
@onready var _click: Button = $ClickArea


func _ready() -> void:
	_title.text = title
	_emoji.text = emoji
	_emoji.visible = not emoji.is_empty()
	_click.pressed.connect(func() -> void: pressed.emit())
	set_selected(false)


func set_selected(selected: bool) -> void:
	_highlight.visible = selected
