extends CanvasLayer

const HOLD_SECONDS := 3.0
const FADE_SECONDS := 0.8
const SKIP_FADE_SECONDS := 0.25
const DIM_ALPHA := 0.78
const BACK_ROTATION_SECONDS := 20.0
const DEFAULT_HEADER_TEXT := "พบสูตรอาหารใหม่"

signal celebration_finished

@onready var _celebration_stack: Control = $CelebrationStack
@onready var _dim: ColorRect = $CelebrationStack/Dim
@onready var _content: Control = $CelebrationStack/Content
@onready var _back_effect: TextureRect = $CelebrationStack/Content/BackEffect
@onready var _header_label: Label = $CelebrationStack/Content/Header/HeaderLabel
@onready var _food_icon: TextureRect = $CelebrationStack/Content/Body/FoodIcon
@onready var _title: Label = $CelebrationStack/Content/Body/Title

var _playing := false
var _skip_requested := false
var _active_tween: Tween
var _rotate_tween: Tween


func _ready() -> void:
	visible = false
	_reset_visual_state()
	_dim.gui_input.connect(_on_dismiss_input)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if _is_dismiss_input(event):
		_request_skip()
		get_viewport().set_input_as_handled()


func play_celebration(display: Dictionary, _burst_origin: Vector2, header_text: String = DEFAULT_HEADER_TEXT) -> void:
	if _playing:
		return

	_playing = true
	_skip_requested = false
	_kill_tween()
	_reset_visual_state()
	set_process_unhandled_input(true)

	_header_label.text = header_text
	FoodIcons.apply_to(_food_icon, String(display.get("id", "")))
	_title.text = display.get("title", "")

	visible = true
	AudioManager.play_discover()
	_start_back_rotation()

	await _play_intro_phase()
	if not _skip_requested:
		await _play_hold_phase()
	await _play_fade_phase(_skip_requested)
	_finish_celebration()


func _finish_celebration() -> void:
	_kill_tween()
	_stop_back_rotation()
	_snap_fade_out()
	set_process_unhandled_input(false)
	_reset_visual_state()
	visible = false
	_playing = false
	_skip_requested = false
	_active_tween = null
	celebration_finished.emit()


func _request_skip() -> void:
	if not _playing or _skip_requested:
		return
	_skip_requested = true
	_stop_back_rotation()


func _on_dismiss_input(event: InputEvent) -> void:
	if _is_dismiss_input(event):
		_request_skip()


func _is_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _play_intro_phase() -> void:
	_content.pivot_offset = _content.size * 0.5
	var intro := create_tween()
	_active_tween = intro
	intro.set_parallel(true)
	intro.tween_property(_dim, "modulate:a", DIM_ALPHA, 0.28).set_ease(Tween.EASE_OUT)
	intro.tween_property(_content, "modulate:a", 1.0, 0.24).set_ease(Tween.EASE_OUT)
	intro.tween_property(_content, "scale", Vector2.ONE, 0.34).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	while intro.is_valid() and intro.is_running():
		if _skip_requested:
			_kill_tween()
			return
		await get_tree().process_frame


func _play_hold_phase() -> void:
	var remaining := HOLD_SECONDS
	while remaining > 0.0 and not _skip_requested:
		var step := minf(0.05, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step


func _play_fade_phase(fast: bool = false) -> void:
	if _skip_requested:
		_snap_fade_out()
		return

	var duration := SKIP_FADE_SECONDS if fast else FADE_SECONDS
	_kill_tween()
	var fade := create_tween()
	_active_tween = fade
	fade.set_parallel(true)
	fade.tween_property(_dim, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	fade.tween_property(_content, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	fade.tween_property(_celebration_stack, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	while fade.is_valid() and fade.is_running():
		if _skip_requested:
			_snap_fade_out()
			_kill_tween()
			return
		await get_tree().process_frame


func _snap_fade_out() -> void:
	_dim.modulate.a = 0.0
	_content.modulate.a = 0.0
	_celebration_stack.modulate.a = 0.0


func _reset_visual_state() -> void:
	_content.modulate = Color(1, 1, 1, 0)
	_content.scale = Vector2(0.88, 0.88)
	_celebration_stack.modulate = Color(1, 1, 1, 1)
	_dim.modulate = Color(1, 1, 1, 0)
	_back_effect.rotation = 0.0
	_stop_back_rotation()


func _start_back_rotation() -> void:
	_stop_back_rotation()
	# pivot ต้องอยู่กึ่งกลาง rect เสมอ ไม่งั้นหมุนแล้วจะวิ่งออกจากจุดกลาง
	_back_effect.pivot_offset = _back_effect.size * 0.5
	_rotate_tween = create_tween().set_loops()
	_rotate_tween.tween_property(
		_back_effect,
		"rotation",
		TAU,
		BACK_ROTATION_SECONDS
	).from(0.0).set_trans(Tween.TRANS_LINEAR)


func _stop_back_rotation() -> void:
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()
	_rotate_tween = null


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
