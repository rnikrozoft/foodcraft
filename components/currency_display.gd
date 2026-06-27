extends Control

signal add_coins_pressed
signal add_gems_pressed

@export var coins: int = 12345:
	set(value):
		coins = value
		_update_coins()

@export var gems: int = 1250:
	set(value):
		gems = value
		_update_gems()

@onready var _coin_row: Control = $VBox/CoinRow
@onready var _gem_row: Control = $VBox/GemRow


func _ready() -> void:
	_coin_row.add_pressed.connect(func() -> void: add_coins_pressed.emit())
	_gem_row.add_pressed.connect(func() -> void: add_gems_pressed.emit())
	_update_coins()
	_update_gems()


func set_coins(value: int) -> void:
	coins = value


func set_gems(value: int) -> void:
	gems = value


func _update_coins() -> void:
	if not is_node_ready():
		return
	_coin_row.set_amount(coins)


func _update_gems() -> void:
	if not is_node_ready():
		return
	_gem_row.set_amount(gems)
