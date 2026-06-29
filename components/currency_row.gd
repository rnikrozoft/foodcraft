@tool
extends Control

signal add_pressed

@export var bar_texture: Texture2D:
	set(value):
		bar_texture = value
		_apply_bar_texture()
@export_range(0.4, 1.0, 0.01) var display_scale: float = 0.65:
	set(value):
		display_scale = value
		_apply_bar_texture()
@export var icon: Texture2D
@export var add_button_texture: Texture2D
@export var amount: int = 0:
	set(value):
		amount = value
		_update_amount()

const _BASE_FONT_SIZE := 20
const _BASE_OUTLINE := 5

@onready var _bar: TextureRect = $Bar
@onready var _icon: TextureRect = $Icon
@onready var _amount_label: Label = $Amount
@onready var _add_button: TextureButton = $AddButton


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_apply_bar_texture()


func _ready() -> void:
	_apply_bar_texture()
	if icon and not bar_texture:
		_icon.texture = icon
	if add_button_texture and not bar_texture:
		_add_button.texture_normal = add_button_texture
	_update_amount()
	if not Engine.is_editor_hint():
		_add_button.pressed.connect(func() -> void: add_pressed.emit())
	call_deferred("_center_icon_pivot")


func set_amount(value: int) -> void:
	amount = value


func get_icon_global_center() -> Vector2:
	if not is_node_ready():
		return Vector2.ZERO
	if bar_texture:
		return Vector2(
			_bar.global_position.x + _bar.size.x * 0.17,
			_bar.global_position.y + _bar.size.y * 0.5
		)
	return _icon.get_global_rect().get_center()


func pulse_icon() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return
	var target: CanvasItem = _bar if bar_texture else _icon
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(target, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT)


func _apply_bar_texture() -> void:
	var bar := _bar if is_node_ready() else get_node_or_null("Bar") as TextureRect
	if bar == null:
		return
	if bar_texture:
		bar.texture = bar_texture
		var tex_size := bar_texture.get_size() * display_scale
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			custom_minimum_size = tex_size
			size = tex_size
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_apply_typography()
		if is_node_ready():
			_icon.visible = false
	elif is_node_ready():
		_icon.visible = true


func _apply_typography() -> void:
	var label := _amount_label if is_node_ready() else get_node_or_null("Amount") as Label
	if label == null:
		return
	label.add_theme_font_size_override("font_size", maxi(12, int(_BASE_FONT_SIZE * display_scale)))
	label.add_theme_constant_override("outline_size", maxi(2, int(_BASE_OUTLINE * display_scale)))


func _center_icon_pivot() -> void:
	_icon.pivot_offset = _icon.size * 0.5


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
