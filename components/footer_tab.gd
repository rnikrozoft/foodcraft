@tool
extends Control
class_name FooterTab

signal pressed

const TEX_INACTIVE := preload("res://assets/buttons/custom/Button_Square03_White.png")
const TEX_ACTIVE   := preload("res://assets/buttons/custom/Button_Square03_White.png")

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
@onready var _icon: TextureRect = $Icon
@onready var _title_label: Label = $TitleLabel
@onready var _badge: PanelContainer = $Badge
@onready var _badge_label: Label = $Badge/BadgeLabel
@onready var _click: Button = $ClickArea

# Icon's offset_left/top/right/bottom for each state. The icon is anchored to
# the horizontal center (anchor_left = anchor_right = 0.5), so left/right must
# stay symmetric around 0 — inactive keeps the icon fully inside the button;
# active grows it and lifts it up so it pokes out past the top edge, opening
# up room below for the title label to fade in.
const ICON_OFFSETS_INACTIVE := Rect2(-22, 22, 22, 66)   # left, top, right, bottom
const ICON_OFFSETS_ACTIVE := Rect2(-30, -14, 30, 46)    # left, top, right, bottom

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
		_apply_icon_rect(ICON_OFFSETS_INACTIVE)
		_title_label.modulate.a = 0.0


## `offsets` fields are repurposed as (left, top, right, bottom) rather than the
## usual (position, size) — see the ICON_OFFSETS_* constants above.
func _apply_icon_rect(offsets: Rect2) -> void:
	_icon.offset_left = offsets.position.x
	_icon.offset_top = offsets.position.y
	_icon.offset_right = offsets.size.x
	_icon.offset_bottom = offsets.size.y
	_apply_icon_pivot(offsets)


func _apply_icon_pivot(offsets: Rect2) -> void:
	_icon.pivot_offset = Vector2(offsets.size.x - offsets.position.x, offsets.size.y - offsets.position.y) * 0.5


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
	var target_offsets := ICON_OFFSETS_ACTIVE if active else ICON_OFFSETS_INACTIVE
	var target_label_alpha := 1.0 if active else 0.0

	if not animate:
		_icon.modulate = target_color
		_apply_icon_rect(target_offsets)
		_title_label.modulate.a = target_label_alpha
		return

	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_icon, "offset_left", target_offsets.position.x, 0.22)
	_tween.tween_property(_icon, "offset_top", target_offsets.position.y, 0.22)
	_tween.tween_property(_icon, "offset_right", target_offsets.size.x, 0.22)
	_tween.tween_property(_icon, "offset_bottom", target_offsets.size.y, 0.22)
	_tween.tween_property(_icon, "modulate", target_color, 0.18)
	_tween.tween_property(_title_label, "modulate:a", target_label_alpha, 0.18).set_trans(Tween.TRANS_LINEAR)
	_tween.tween_callback(_apply_icon_pivot.bind(target_offsets)).set_delay(0.22)


func set_badge(count: int) -> void:
	badge_count = count
	_update_badge()


func _update_badge() -> void:
	if not is_node_ready():
		return
	_badge.visible = badge_count > 0
	if badge_count > 0:
		_badge_label.text = str(badge_count) if badge_count < 100 else "99+"
