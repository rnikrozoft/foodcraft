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
@export var amount: int = 0:
	set(value):
		amount = value
		_update_amount()

const _BASE_FONT_SIZE := 20
const _BASE_OUTLINE := 5
# Pixel insets for the Amount label at display_scale = 1.0, tuned for the
# single-image "*_label.png" art (coin_label.png / gem_label.png): the icon
# + baked-in plus button occupy roughly the left 40% of the image, with a
# black pill filling the rest for the number. Scaled by display_scale like
# the font size so it stays correct at any row_scale.
const _BAR_AMOUNT_LEFT_BASE := 78.0
const _BAR_AMOUNT_RIGHT_BASE := 14.0

@onready var _bar: TextureRect = $Bar
@onready var _amount_label: Label = $Amount
@onready var _add_button: TextureButton = $AddButton


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_apply_bar_texture()


func _ready() -> void:
	_apply_bar_texture()
	_update_amount()
	if not Engine.is_editor_hint():
		_add_button.pressed.connect(func() -> void: add_pressed.emit())


func set_amount(value: int) -> void:
	amount = value


func get_icon_global_center() -> Vector2:
	if not is_node_ready():
		return Vector2.ZERO
	return Vector2(
		_bar.global_position.x + _bar.size.x * 0.17,
		_bar.global_position.y + _bar.size.y * 0.5
	)


func pulse_icon() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return
	_bar.pivot_offset = _bar.size * 0.5
	var tween := create_tween()
	tween.tween_property(_bar, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_bar, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT)


# This component only supports the single pre-baked label image (bar_texture)
# now — coin_label.png / gem_label.png already contain the icon and a green
# "+" button drawn into the art, so there's nothing to render without it.
func _apply_bar_texture() -> void:
	var bar := _bar if is_node_ready() else get_node_or_null("Bar") as TextureRect
	if bar == null or bar_texture == null:
		return
	bar.texture = bar_texture
	var tex_size := bar_texture.get_size() * display_scale
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		custom_minimum_size = tex_size
		size = tex_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_typography()
	if is_node_ready():
		# Keep AddButton as the click target (its `pressed` signal is already
		# wired to add_pressed), but stretch it to cover the whole bar
		# instead of just a corner, so tapping anywhere on the label — not
		# just the tiny baked "+" — triggers it. No texture of its own since
		# the "+" is already part of bar_texture.
		_add_button.texture_normal = null
		_add_button.anchor_left = 0.0
		_add_button.anchor_top = 0.0
		_add_button.anchor_right = 1.0
		_add_button.anchor_bottom = 1.0
		_add_button.offset_left = 0.0
		_add_button.offset_top = 0.0
		_add_button.offset_right = 0.0
		_add_button.offset_bottom = 0.0
		_add_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_add_button.grow_vertical = Control.GROW_DIRECTION_BOTH


func _apply_typography() -> void:
	var label := _amount_label if is_node_ready() else get_node_or_null("Amount") as Label
	if label == null:
		return
	label.add_theme_font_size_override("font_size", maxi(12, int(_BASE_FONT_SIZE * display_scale)))
	label.offset_left = _BAR_AMOUNT_LEFT_BASE * display_scale
	label.offset_right = -_BAR_AMOUNT_RIGHT_BASE * display_scale
	label.add_theme_constant_override("outline_size", maxi(2, int(_BASE_OUTLINE * display_scale)))


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
