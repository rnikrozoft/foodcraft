@tool
extends Control

signal add_coins_pressed
signal add_gems_pressed

@export_range(0.4, 1.0, 0.01) var row_scale: float = 0.65:
	set(value):
		row_scale = value
		_apply_row_scale()

@export var coins: int = 12345:
	set(value):
		coins = value
		_update_coins()

@export var gems: int = 1250:
	set(value):
		gems = value
		_update_gems()

@onready var _coin_row: Control = $HBox/CoinRow
@onready var _gem_row: Control = $HBox/GemRow


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_apply_row_scale()


func _ready() -> void:
	_apply_row_scale()
	_coin_row.add_pressed.connect(func() -> void: add_coins_pressed.emit())
	_gem_row.add_pressed.connect(func() -> void: add_gems_pressed.emit())
	_update_coins()
	_update_gems()


func set_coins(value: int) -> void:
	coins = value


func set_gems(value: int) -> void:
	gems = value


func get_coin_icon_global_center() -> Vector2:
	return _coin_row.get_icon_global_center()


func get_star_icon_global_center() -> Vector2:
	return _gem_row.get_icon_global_center()


func pulse_reward(reward_type: String) -> void:
	if reward_type == "coin":
		_coin_row.pulse_icon()
	else:
		_gem_row.pulse_icon()


func _apply_row_scale() -> void:
	var coin_row := _coin_row if is_node_ready() else get_node_or_null("HBox/CoinRow")
	var gem_row := _gem_row if is_node_ready() else get_node_or_null("HBox/GemRow")
	for row in [coin_row, gem_row]:
		if row == null:
			continue
		row.display_scale = row_scale
	if coin_row == null:
		return
	var row_size: Vector2 = coin_row.custom_minimum_size
	var gap := 6.0
	if is_node_ready():
		gap = float($HBox.get_theme_constant("separation"))
	custom_minimum_size = Vector2(row_size.x * 2.0 + gap, row_size.y)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _update_coins() -> void:
	if not is_node_ready():
		return
	_coin_row.set_amount(coins)


func _update_gems() -> void:
	if not is_node_ready():
		return
	_gem_row.set_amount(gems)
