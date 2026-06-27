extends Control

const MAIN_SCENE := preload("res://screens/main.tscn")

@onready var _guest_button: Control = $VBoxContainer/GuestButton
@onready var _facebook_button: Control = $VBoxContainer/FacebookButton


func _ready() -> void:
	_guest_button.pressed.connect(_enter_game)
	_facebook_button.pressed.connect(_enter_game)


func _enter_game() -> void:
	_set_buttons_enabled(false)
	await NakamaService.authenticate_guest()
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _set_buttons_enabled(enabled: bool) -> void:
	_guest_button.disabled = not enabled
	_facebook_button.disabled = not enabled
