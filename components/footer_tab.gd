extends Control
class_name FooterTab

signal pressed

const TEX_INACTIVE := preload("res://assets/Vector_UI_Pack_dobo_ui/Buttons/buttonDefault.png")
const TEX_ACTIVE := preload("res://assets/Vector_UI_Pack_dobo_ui/Buttons/buttonPressed.png")

const INACTIVE_WIDTH := 56.0
const ACTIVE_WIDTH := 72.0
const INACTIVE_BG_TOP := -48.0
const INACTIVE_BG_BOTTOM := -8.0
const ACTIVE_BG_TOP := -60.0
const ACTIVE_BG_BOTTOM := 0.0
const ICON_SIZE_INACTIVE := 40.0
const ICON_SIZE_ACTIVE := 48.0

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_apply_tooltip()

@export var icon: Texture2D

@onready var _bg: NinePatchRect = $Bg
@onready var _icon: TextureRect = $Icon
@onready var _click: Button = $ClickArea

var _tween: Tween
var _is_active := false


func _ready() -> void:
	_icon.texture = icon
	_apply_tooltip()
	_click.pressed.connect(func() -> void: pressed.emit())
	resized.connect(_refresh_layout)
	set_active(false, false)
	call_deferred("_refresh_layout")


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	_apply_visual_state(_visual_state(_is_active))


func _apply_tooltip() -> void:
	tooltip_text = title
	if is_node_ready():
		_click.tooltip_text = title


func set_active(active: bool, animate: bool = true) -> void:
	if not is_node_ready():
		_is_active = active
		return

	var state_changed := _is_active != active
	_is_active = active

	var target := _visual_state(active)
	_bg.texture = TEX_ACTIVE if active else TEX_INACTIVE
	_icon.modulate = Color(1.05, 1.02, 0.98, 1) if active else Color(1, 1, 1, 1)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if not state_changed:
		_apply_visual_state(target)
		return

	if not animate:
		_apply_visual_state(target)
		return

	var from := _capture_visual_state()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		_apply_visual_state(_lerp_visual(from, target, t))
	, 0.0, 1.0, 0.22)


func _visual_state(active: bool) -> Dictionary:
	return {
		"width": ACTIVE_WIDTH if active else INACTIVE_WIDTH,
		"bg_top": ACTIVE_BG_TOP if active else INACTIVE_BG_TOP,
		"bg_bottom": ACTIVE_BG_BOTTOM if active else INACTIVE_BG_BOTTOM,
		"icon_size": ICON_SIZE_ACTIVE if active else ICON_SIZE_INACTIVE,
		"pop": 1.0 if active else 0.0,
	}


func _capture_visual_state() -> Dictionary:
	return {
		"width": custom_minimum_size.x,
		"bg_top": _bg.offset_top,
		"bg_bottom": _bg.offset_bottom,
		"icon_size": _icon.offset_right - _icon.offset_left,
		"pop": 1.0 if _is_active else 0.0,
	}


func _lerp_visual(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	return {
		"width": lerpf(from["width"], to["width"], t),
		"bg_top": lerpf(from["bg_top"], to["bg_top"], t),
		"bg_bottom": lerpf(from["bg_bottom"], to["bg_bottom"], t),
		"icon_size": lerpf(from["icon_size"], to["icon_size"], t),
		"pop": lerpf(from["pop"], to["pop"], t),
	}


func _apply_visual_state(state: Dictionary) -> void:
	custom_minimum_size.x = state["width"]
	_bg.offset_top = state["bg_top"]
	_bg.offset_bottom = state["bg_bottom"]
	var icon_y := _icon_y_for_state(
		state["icon_size"],
		state["bg_top"],
		state["bg_bottom"],
		state["pop"]
	)
	_apply_icon_layout(state["icon_size"], icon_y)


func _tab_height() -> float:
	return size.y if size.y > 1.0 else custom_minimum_size.y


func _icon_y_for_state(icon_size: float, bg_top: float, bg_bottom: float, pop: float) -> float:
	var tab_h := _tab_height()
	var bg_y1 := tab_h + bg_top
	var bg_y2 := tab_h + bg_bottom
	var bg_height := bg_y2 - bg_y1
	var centered_y := bg_y1 + (bg_height - icon_size) * 0.5
	var popped_y := bg_y1 + bg_height * 0.1 - icon_size * 0.25
	return lerpf(centered_y, popped_y, pop)


func _apply_icon_layout(icon_size: float, icon_y: float) -> void:
	var tab_width := size.x if size.x > 1.0 else custom_minimum_size.x
	var icon_x := (tab_width - icon_size) * 0.5
	_icon.offset_left = icon_x
	_icon.offset_right = icon_x + icon_size
	_icon.offset_top = icon_y
	_icon.offset_bottom = icon_y + icon_size
