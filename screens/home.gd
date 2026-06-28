extends Control

const MAIN_SCENE := preload("res://screens/main.tscn")

@onready var _guest_button: Control = $VBoxContainer/GuestButton
@onready var _facebook_button: Control = $VBoxContainer/FacebookButton
@onready var _status: Label = $StatusLabel


func _ready() -> void:
	_guest_button.pressed.connect(_enter_game)
	_facebook_button.pressed.connect(_enter_game)


func _enter_game() -> void:
	_set_buttons_enabled(false)
	_status.text = "กำลังเชื่อมต่อเซิร์ฟเวอร์..."
	var ok := await NakamaService.authenticate_guest()
	if not ok:
		_status.text = "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ — ตรวจสอบเน็ตแล้วลองใหม่"
		_set_buttons_enabled(true)
		return
	_status.text = ""
	await SceneTransition.fade_to_scene(MAIN_SCENE)


func _set_buttons_enabled(enabled: bool) -> void:
	_guest_button.disabled = not enabled
	_facebook_button.disabled = not enabled
