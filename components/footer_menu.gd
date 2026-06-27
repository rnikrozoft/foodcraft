extends Control

signal tab_changed(index: int)

@onready var _tabs: Array = [
	$HBox/TabExperiment,
	$HBox/TabRecipes,
	$HBox/TabMissions,
	$HBox/TabRank,
	$HBox/TabMore,
]

var _active_index: int = 0


func _ready() -> void:
	for i in _tabs.size():
		_tabs[i].pressed.connect(set_active_tab.bind(i))
	set_active_tab(0)


func set_active_tab(index: int) -> void:
	_active_index = index
	for i in _tabs.size():
		_tabs[i].set_active(i == index)
	tab_changed.emit(index)
