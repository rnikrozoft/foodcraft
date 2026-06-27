extends CanvasLayer

const FADE_OUT_DURATION := 0.35
const FADE_IN_DURATION := 0.45

@onready var _fade: ColorRect = $FadeOverlay

var _busy := false
var _tween: Tween


func _ready() -> void:
	layer = 120
	visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_fade.modulate.a = 0.0


func fade_to_scene(scene: PackedScene) -> void:
	if _busy:
		return
	_busy = true
	await _fade_out()
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in()
	_busy = false


func _fit_viewport() -> void:
	var rect := get_viewport().get_visible_rect()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.set_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.position = rect.position
	_fade.size = rect.size


func _fade_out() -> void:
	_kill_tween()
	_fit_viewport()
	visible = true
	_fade.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_fade, "modulate:a", 1.0, FADE_OUT_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished


func _fade_in() -> void:
	_kill_tween()
	_fit_viewport()
	visible = true
	_fade.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_fade, "modulate:a", 0.0, FADE_IN_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished
	visible = false
	_fade.modulate.a = 0.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
