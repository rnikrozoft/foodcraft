extends Control

const STAR_TEX := preload("res://assets/Icons/PictoIcon_512/Icon_PictoIcon_Star.Png")

@export var bg_color := Color(0.28, 0.56, 0.94, 1)
@export var star_spacing := Vector2(80, 76)
@export var star_size := 100
@export var star_modulate := Color(0.16, 0.38, 0.74, 0.26)
@export var scroll_speed := Vector2(9, 13)

var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_offset += scroll_speed * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)
	if STAR_TEX == null:
		return

	var y0 := -star_spacing.y + _offset.y
	var row_begin := int(ceil((-star_spacing.y - y0) / star_spacing.y))
	var row_end := int(floor((size.y + star_spacing.y - y0) / star_spacing.y))
	for row in range(row_begin, row_end + 1):
		var y := y0 + row * star_spacing.y
		var row_shift := star_spacing.x * 0.5 if row % 2 != 0 else 0.0
		var x0 := -star_spacing.x + _offset.x + row_shift
		var col_begin := int(ceil((-star_spacing.x - x0) / star_spacing.x))
		var col_end := int(floor((size.x + star_spacing.x - x0) / star_spacing.x))
		for col in range(col_begin, col_end + 1):
			var x := x0 + col * star_spacing.x
			draw_texture_rect(
				STAR_TEX,
				Rect2(x, y, star_size, star_size),
				false,
				star_modulate
			)
