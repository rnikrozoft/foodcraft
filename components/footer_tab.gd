@tool
extends Control
class_name FooterTab

signal pressed

const TEX_INACTIVE := preload("res://assets/Components/Button/Button_Square03_White.png")
const TEX_ACTIVE   := preload("res://assets/Components/Button/Button_Square03_White.png")

# Active background tint. Defaults to gold but each tab can override it with its
# own accent color (set by footer_menu) so the nav bar reads as multi-colored.
@export var accent_active: Color = Color(1.0, 0.78, 0.25, 1.0):
	set(value):
		accent_active = value
		if is_node_ready() and _is_active:
			_bg.self_modulate = value
const BG_INACTIVE := Color(0.27, 0.21, 0.15, 1.0)   # dark brown

const COLOR_ACTIVE   := Color(1.15, 1.1, 0.98, 1.0)
const COLOR_INACTIVE := Color(0.82, 0.76, 0.64, 1.0)

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_title_label.text = value
		elif is_inside_tree():
			(%TitleLabel as Label).text = value

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_icon.texture = value
		elif is_inside_tree():
			(%Icon as TextureRect).texture = value

@export var badge_count: int = 0:
	set(value):
		badge_count = value
		if is_node_ready():
			_update_badge()

@onready var _bg: NinePatchRect = $Bg
@onready var _icon: TextureRect = $VBox/Icon
@onready var _title_label: Label = $VBox/TitleLabel
@onready var _badge: PanelContainer = $Badge
@onready var _badge_label: Label = $Badge/BadgeLabel
@onready var _click: Button = $ClickArea

var _tween: Tween
var _is_active := false


func _ready() -> void:
	_icon.texture = icon
	_title_label.text = title
	_update_badge()
	_click.pressed.connect(func() -> void:
		if not Engine.is_editor_hint():
			AudioManager.play_pop()
		pressed.emit()
	)
	if not Engine.is_editor_hint():
		set_active(false, false)
	else:
		_bg.self_modulate = BG_INACTIVE
		_icon.modulate = COLOR_INACTIVE
		_title_label.modulate.a = 0.75


func set_active(active: bool, animate: bool = true) -> void:
	if not is_node_ready():
		_is_active = active
		return

	_is_active = active
	_bg.texture = TEX_ACTIVE if active else TEX_INACTIVE
	_bg.self_modulate = accent_active if active else BG_INACTIVE

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_color := COLOR_ACTIVE if active else COLOR_INACTIVE
	var target_scale := Vector2(1.06, 1.06) if active else Vector2(1.0, 1.0)
	var target_label_alpha := 1.0 if active else 0.75

	if not animate:
		_icon.modulate = target_color
		_title_label.modulate.a = target_label_alpha
		pivot_offset = size * 0.5
		scale = target_scale
		return

	pivot_offset = size * 0.5
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", target_scale, 0.2)
	_tween.tween_property(_icon, "modulate", target_color, 0.18)
	_tween.tween_property(_title_label, "modulate:a", target_label_alpha, 0.18)


func set_badge(count: int) -> void:
	badge_count = count
	_update_badge()


func _update_badge() -> void:
	if not is_node_ready():
		return
	_badge.visible = badge_count > 0
	if badge_count > 0:
		_badge_label.text = str(badge_count) if badge_count < 100 else "99+"
