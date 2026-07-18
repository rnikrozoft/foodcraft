@tool
extends Control

const STAR_TEX := preload("res://assets/icons/misc/Icon_ImageIcon_Star01_l.png")
const DEFAULT_BG_TEX := preload("res://assets/backgrounds/6164964e-5608-4c9b-b053-fb693dc8f38d.png")

@export var bg_color := Color(0.115, 0.09, 0.068, 1)
## Full-screen background image, drawn "cover" style (scaled + cropped to fill,
## no stretching). Leave empty to fall back to the flat bg_color instead.
@export var bg_texture: Texture2D = DEFAULT_BG_TEX
@export var star_spacing := Vector2(80, 76)
@export var star_size := 100
@export var star_modulate := Color(1, 0.85, 0.55, 0.08)
@export var scroll_speed := Vector2(9, 13)

var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)


func _process(delta: float) -> void:
	_offset += scroll_speed * delta
	queue_redraw()


func _draw() -> void:
	if bg_texture != null:
		_draw_bg_cover()
	else:
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


# Scales bg_texture up just enough to cover the full control rect (like CSS
# background-size: cover) and centers it, cropping any overflow via
# clip_contents. Never stretches/distorts the image.
func _draw_bg_cover() -> void:
	var tex_size := bg_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var cover_scale: float = max(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * cover_scale
	var draw_pos := (size - draw_size) * 0.5
	draw_texture_rect(bg_texture, Rect2(draw_pos, draw_size), false)
