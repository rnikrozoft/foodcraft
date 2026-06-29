extends Control

@export var player_name: String = "Food Crafter":
	set(value):
		player_name = value
		_update_ui()

@export var level: int = 25:
	set(value):
		level = value
		_update_ui()

@export var exp_current: int = 650:
	set(value):
		exp_current = maxi(value, 0)
		_update_exp()

@export var exp_total: int = 1000:
	set(value):
		exp_total = maxi(value, 1)
		_update_exp()

@export var avatar_texture: Texture2D:
	set(value):
		avatar_texture = value
		_update_avatar()

@onready var _player_name_label: Label = $HBox/Info/PlayerName
@onready var _exp_bar: ProgressBar = $HBox/Info/ExpWrap/ExpBar
@onready var _exp_label: Label = $HBox/Info/ExpWrap/ExpLabel
@onready var _avatar_icon: TextureRect = $HBox/Avatar/AvatarIcon


func _ready() -> void:
	_update_ui()


func set_profile(new_name: String, lvl: int, current_exp: int, total_exp: int, avatar: Texture2D = null) -> void:
	player_name = new_name
	level = lvl
	exp_current = current_exp
	exp_total = total_exp
	if avatar:
		avatar_texture = avatar


func _update_ui() -> void:
	if not is_node_ready():
		return
	_player_name_label.text = player_name
	_update_avatar()
	_update_exp()


func _update_avatar() -> void:
	if not is_node_ready() or avatar_texture == null:
		return
	_avatar_icon.texture = avatar_texture


func _update_exp() -> void:
	if not is_node_ready():
		return
	var ratio := clampf(float(exp_current) / float(exp_total), 0.0, 1.0)
	_exp_bar.value = ratio * 100.0
	_exp_label.text = "%s / %s" % [_format_number(exp_current), _format_number(exp_total)]


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
