@tool
extends Control
class_name IngredientCard

signal pressed

const MARQUEE_SPEED := 24.0
const MARQUEE_PAUSE := 1.4

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_apply_title()

@export var food_id: String = "":
	set(value):
		food_id = value
		if is_node_ready():
			_apply_icon()

@onready var _background: NinePatchRect = $Background
@onready var _icon: TextureRect = $Icon
@onready var _title_clip: Control = $TitleClip
@onready var _title: Label = $TitleClip/Title
@onready var _click: Button = $ClickArea
@onready var _craftable_badge: PanelContainer = $CraftableBadge
@onready var _craftable_badge_label: Label = $CraftableBadge/CraftableBadgeLabel

var _marquee_tween: Tween


func _ready() -> void:
	_apply_title()
	_apply_icon()
	if Engine.is_editor_hint():
		return
	_click.pressed.connect(func() -> void: pressed.emit())
	_title_clip.resized.connect(_update_title_marquee)
	call_deferred("_update_title_marquee")


func apply_display(data: Dictionary) -> void:
	title = String(data.get("title", ""))
	food_id = String(data.get("id", ""))


func _apply_icon() -> void:
	if Engine.is_editor_hint():
		return
	FoodIcons.apply_to(_icon, food_id)
	_apply_rarity()
	_apply_craftable_badge()


# Top-right badge: how many more distinct recipes this item can still lead
# to that aren't discovered yet (server-computed; see RarityStyle usage above
# for the general "read state, skip in editor" pattern this mirrors).
func _apply_craftable_badge() -> void:
	if not is_node_ready() or Engine.is_editor_hint() or food_id.is_empty():
		return
	var count := GameData.get_craftable_count(food_id)
	_craftable_badge.visible = count > 0
	if count > 0:
		_craftable_badge_label.text = str(count) if count < 100 else "99+"


# Tints the card by rarity tier: same constant translucent white wash + per-
# tier hue used everywhere else (see RarityStyle), so cards aren't all one
# cream tone.
func _apply_rarity() -> void:
	if not is_node_ready() or Engine.is_editor_hint() or food_id.is_empty():
		return
	var tier := RarityStyle.tier_for_id(food_id)
	_background.self_modulate = RarityStyle.bg_self_modulate()
	_background.modulate = RarityStyle.bg_modulate_for_tier(tier)
	var accent := RarityStyle.color_for_tier(tier)
	_title.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.15))


func _apply_title() -> void:
	_title.text = title
	call_deferred("_update_title_marquee")


func _update_title_marquee() -> void:
	_stop_marquee()
	if _title.text.is_empty():
		return

	var clip_width := _title_clip.size.x
	if clip_width < 1.0:
		return

	var text_width := _measure_title_width()
	_title.custom_minimum_size.x = text_width
	_title.size.x = text_width

	if text_width <= clip_width:
		_title.position.x = (clip_width - text_width) * 0.5
		return

	_title.position.x = 0.0
	var scroll_distance := text_width - clip_width
	var duration := scroll_distance / MARQUEE_SPEED
	_marquee_tween = create_tween().set_loops()
	_marquee_tween.tween_interval(MARQUEE_PAUSE)
	_marquee_tween.tween_property(_title, "position:x", -scroll_distance, duration).set_trans(Tween.TRANS_LINEAR)
	_marquee_tween.tween_interval(MARQUEE_PAUSE)
	_marquee_tween.tween_property(_title, "position:x", 0.0, duration).set_trans(Tween.TRANS_LINEAR)


func _measure_title_width() -> float:
	var font: Font = _title.get_theme_font("font")
	var font_size := _title.get_theme_font_size("font_size")
	if font == null:
		return _title.get_minimum_size().x
	return font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _stop_marquee() -> void:
	if _marquee_tween != null and _marquee_tween.is_valid():
		_marquee_tween.kill()
	_marquee_tween = null
