@tool
extends Control

signal pressed

@export var tex_normal: Texture2D = preload("res://assets/Vector_UI_Pack_dobo_ui/Buttons/button_green.png"):
	set(value):
		tex_normal = value
		if is_node_ready():
			_update_visual()

@export var tex_hover: Texture2D = preload("res://assets/Vector_UI_Pack_dobo_ui/Buttons/buttonPressed.png"):
	set(value):
		tex_hover = value
		if is_node_ready():
			_update_visual()

@export var tex_disabled: Texture2D = preload("res://assets/Vector_UI_Pack_dobo_ui/Buttons/button_black.png"):
	set(value):
		tex_disabled = value
		if is_node_ready():
			_update_visual()

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
	if not Engine.is_editor_hint():
		_button.pressed.connect(func() -> void: pressed.emit())
		_button.mouse_entered.connect(_update_visual)
		_button.mouse_exited.connect(_update_visual)
		_button.button_down.connect(_update_visual)
		_button.button_up.connect(_update_visual)
	_update_visual()


func _update_visual() -> void:
	var tex: Texture2D
	if _button.disabled:
		tex = tex_disabled
	elif _button.is_pressed() or _button.is_hovered():
		tex = tex_hover
	else:
		tex = tex_normal
	_background.texture = tex
	_apply_patch_margins(tex)


func _apply_patch_margins(texture: Texture2D) -> void:
	if texture == null:
		return
	var img := texture.get_image()
	if img == null or img.is_empty():
		_apply_patch_margins_fallback(texture)
		return

	var w := img.get_width()
	var h := img.get_height()
	var max_w := 0
	var top_flat := 0
	var bottom_flat := 0

	for y in range(h):
		var left := w
		var right := -1
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				left = x
				break
		for x in range(w - 1, -1, -1):
			if img.get_pixel(x, y).a > 0.5:
				right = x
				break
		var row_w := right - left + 1 if right >= left else 0
		max_w = maxi(max_w, row_w)

	for y in range(h):
		var left := w
		var right := -1
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				left = x
				break
		for x in range(w - 1, -1, -1):
			if img.get_pixel(x, y).a > 0.5:
				right = x
				break
		var row_w := right - left + 1 if right >= left else 0
		if row_w >= max_w - 1:
			top_flat = y
			break

	for y in range(h - 1, -1, -1):
		var left := w
		var right := -1
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				left = x
				break
		for x in range(w - 1, -1, -1):
			if img.get_pixel(x, y).a > 0.5:
				right = x
				break
		var row_w := right - left + 1 if right >= left else 0
		if row_w >= max_w - 1:
			bottom_flat = y
			break

	var flat_top_y := h
	for x in range(w / 4, 3 * w / 4):
		for y in range(h):
			if img.get_pixel(x, y).a > 0.5:
				flat_top_y = mini(flat_top_y, y)
				break

	var left_cap := 0
	for x in range(w / 2):
		for y in range(h):
			if img.get_pixel(x, y).a > 0.5:
				if y == flat_top_y:
					left_cap = x
				break

	var right_cap := 0
	for x in range(w - 1, w / 2, -1):
		for y in range(h):
			if img.get_pixel(x, y).a > 0.5:
				if y == flat_top_y:
					right_cap = w - 1 - x
				break

	_background.patch_margin_left = left_cap
	_background.patch_margin_top = top_flat
	_background.patch_margin_right = right_cap
	_background.patch_margin_bottom = h - 1 - bottom_flat


func _apply_patch_margins_fallback(texture: Texture2D) -> void:
	var tex_size := texture.get_size()
	var h := int(tex_size.y)
	var cap := int(h * 0.16)
	_background.patch_margin_left = cap
	_background.patch_margin_top = int(h * 0.15)
	_background.patch_margin_right = cap
	_background.patch_margin_bottom = int(h * 0.19)
