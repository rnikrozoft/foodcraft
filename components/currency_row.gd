extends Control

signal add_pressed

@export var icon: Texture2D
@export var icon_tint: Color = Color(1, 1, 1, 1)
@export var add_tint: Color = Color(1, 0.88, 0.45, 1)
@export var amount: int = 0:
	set(value):
		amount = value
		_update_amount()

@onready var _icon: TextureRect = $HBox/Icon
@onready var _amount_label: Label = $HBox/Amount
@onready var _add_icon: TextureRect = $HBox/AddButton/AddIcon
@onready var _add_button: Button = $HBox/AddButton


func _ready() -> void:
	if icon:
		_icon.texture = icon
	_icon.self_modulate = icon_tint
	_add_icon.self_modulate = add_tint
	_update_amount()
	_add_button.pressed.connect(func() -> void: add_pressed.emit())


func set_amount(value: int) -> void:
	amount = value


func _update_amount() -> void:
	if not is_node_ready():
		return
	_amount_label.text = _format_amount(amount)


func _format_amount(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
