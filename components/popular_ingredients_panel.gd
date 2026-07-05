@tool
extends Control

signal see_all_pressed
signal ingredient_selected(data: Dictionary)

const CARD_SCENE := preload("res://components/ingredient_grid_card.tscn")

@onready var _tab_bar: Control = $VBox/TabBar
@onready var _scroll: ScrollContainer = $VBox/GridPanel/Scroll
@onready var _grid: HFlowContainer = $VBox/GridPanel/Scroll/Grid

var _cards: Array = []
var _display_items: Array = []
var _active_tab: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 0
	_tab_bar.tab_selected.connect(_on_tab_selected)
	_tab_bar.menu_pressed.connect(func() -> void: see_all_pressed.emit())
	GameData.progress_changed.connect(_on_progress_changed)
	_refresh()


func _on_progress_changed() -> void:
	_refresh()


func _refresh() -> void:
	var collection := GameData.get_collection_items()
	_display_items = collection if not collection.is_empty() else GameData.get_panel_ingredients()
	_rebuild_tabs()
	_show_items(_display_items)


func _rebuild_tabs() -> void:
	var cats := {}
	for item in _display_items:
		var c := String(item.get("category", ""))
		if not c.is_empty() and c != "ingredient":
			cats[c] = true
	var cat_list: Array = cats.keys()
	cat_list.sort()

	if not _active_tab.is_empty() and not cat_list.has(_active_tab):
		_active_tab = ""

	_tab_bar.build_tabs(cat_list)


func _on_tab_selected(category: String) -> void:
	_active_tab = category
	_show_items(_display_items)


func _show_items(items: Array) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()

	var filtered: Array = items
	if not _active_tab.is_empty():
		filtered = items.filter(func(d: Dictionary) -> bool:
			return String(d.get("category", "")) == _active_tab
		)

	const COLS := 5

	for data in filtered:
		var card = CARD_SCENE.instantiate()
		card.apply_display(data)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_card_pressed.bind(data))
		_grid.add_child(card)
		_cards.append(card)

	# Pad last row with invisible spacers so all cards are the same width
	var remainder := filtered.size() % COLS
	if remainder != 0:
		for _i in (COLS - remainder):
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(110, 120)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid.add_child(spacer)

	_scroll.scroll_vertical = 0


func _on_card_pressed(data: Dictionary) -> void:
	ingredient_selected.emit(data)
