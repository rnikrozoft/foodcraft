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

@export var emoji: String = "":
	set(value):
		emoji = value
		if is_node_ready():
			_emoji.text = emoji
			_emoji.visible = not emoji.is_empty()

@onready var _highlight: NinePatchRect = $Highlight
@onready var _emoji: Label = $Emoji
@onready var _title_clip: Control = $TitleClip
@onready var _title: Label = $TitleClip/Title
@onready var _click: Button = $ClickArea

var _marquee_tween: Tween


func _ready() -> void:
	_apply_title()
	_emoji.text = emoji
	_emoji.visible = not emoji.is_empty()
	_click.pressed.connect(func() -> void: pressed.emit())
	_title_clip.resized.connect(_update_title_marquee)
	set_selected(false)
	call_deferred("_update_title_marquee")


func set_selected(selected: bool) -> void:
	_highlight.visible = selected


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
