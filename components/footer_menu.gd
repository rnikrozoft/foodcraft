@tool
extends Control

signal tab_changed(index: int)

@onready var _tabs: Array = [
	$HBox/TabExperiment,
	$HBox/TabRecipes,
	$HBox/TabMissions,
	$HBox/TabRank,
	$HBox/TabMore,
]

# Distinct accent per tab so the nav bar shows a spread of color, not one gold tone.
const TAB_ACCENTS := [
	Color(1.00, 0.72, 0.22, 1.0),  # Experiment / craft — orange-gold
	Color(0.52, 0.82, 0.42, 1.0),  # Recipes — green
	Color(0.40, 0.68, 1.00, 1.0),  # Missions — blue
	Color(0.78, 0.56, 0.98, 1.0),  # Rank — purple
	Color(1.00, 0.55, 0.70, 1.0),  # More — pink
]

var _active_index: int = 0


func _ready() -> void:
	_apply_tab_accents()
	if Engine.is_editor_hint():
		call_deferred("_refresh_tabs")
		return
	for i in _tabs.size():
		_tabs[i].pressed.connect(set_active_tab.bind(i))
	set_active_tab(0)
	call_deferred("_refresh_tabs")


func _apply_tab_accents() -> void:
	for i in _tabs.size():
		if i < TAB_ACCENTS.size():
			_tabs[i].accent_active = TAB_ACCENTS[i]


func _refresh_tabs() -> void:
	for tab in _tabs:
		tab.set_active(tab == _tabs[_active_index], false)


func set_active_tab(index: int, notify: bool = true) -> void:
	_active_index = index
	for i in _tabs.size():
		_tabs[i].set_active(i == index)
	if notify and not Engine.is_editor_hint():
		tab_changed.emit(index)


func set_tab_badge(index: int, count: int) -> void:
	if index >= 0 and index < _tabs.size():
		_tabs[index].set_badge(count)
