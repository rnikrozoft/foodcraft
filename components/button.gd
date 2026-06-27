extends Control

signal pressed

const TEX_NORMAL := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/Green empty.png")
const TEX_HOVER := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/DARK Green empty.png")
const TEX_DISABLED := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/GREY.png")

@onready var _background: NinePatchRect = $Background
@onready var _button: Button = $ButtonBg

var disabled: bool = false:
	set(value):
		disabled = value
		if is_node_ready():
			_button.disabled = value
			_update_visual()


func _ready() -> void:
	_button.disabled = disabled
	_button.pressed.connect(func() -> void: pressed.emit())
	_button.mouse_entered.connect(_update_visual)
	_button.mouse_exited.connect(_update_visual)
	_button.button_down.connect(_update_visual)
	_button.button_up.connect(_update_visual)
	_update_visual()


func _update_visual() -> void:
	if _button.disabled:
		_background.texture = TEX_DISABLED
	elif _button.is_pressed() or _button.is_hovered():
		_background.texture = TEX_HOVER
	else:
		_background.texture = TEX_NORMAL
