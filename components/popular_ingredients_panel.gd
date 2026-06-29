extends Control

signal see_all_pressed

signal ingredient_selected(data: Dictionary)

const CARD_SCENE := preload("res://components/ingredient_card.tscn")

@onready var _title: Label = $Content/Header/Title
@onready var _see_all: TextureButton = $Content/Header/SeeAll/Arrow
@onready var _scroll: ScrollContainer = $Content/Scroll
@onready var _cards_row: HBoxContainer = $Content/Scroll/CardRow
@onready var _search: LineEdit = $Content/SearchBox/SearchInput

var _cards: Array = []
var _display_items: Array = []
var _search_pool: Array = []


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_search_pool = GameData.get_craft_pick_items()
	_search.text_changed.connect(_on_search_changed)
	_see_all.pressed.connect(func() -> void: see_all_pressed.emit())
	GameData.progress_changed.connect(_on_progress_changed)
	_refresh()


func _on_progress_changed() -> void:
	_search_pool = GameData.get_craft_pick_items()
	if _search.text.strip_edges().is_empty():
		_refresh()


func _refresh() -> void:
	var collection := GameData.get_collection_items()
	if collection.is_empty():
		_title.text = "วัตถุดิบยอดนิยม"
		_display_items = GameData.get_panel_ingredients()
	else:
		_title.text = "ค้นพบล่าสุด"
		_display_items = GameData.get_craft_bar_items()
	_show_items(_display_items)


func _input(event: InputEvent) -> void:
	if not _search.has_focus():
		return

	var press_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_pos = event.global_position
	elif event is InputEventScreenTouch and event.pressed:
		press_pos = event.position
	else:
		return

	if not _search.get_global_rect().has_point(press_pos):
		_search.release_focus()


func _on_search_changed(query: String) -> void:
	var trimmed := query.strip_edges()
	if trimmed.is_empty():
		_refresh()
		return

	var results: Array = []
	for item in _search_pool:
		if String(item.get("title", "")).contains(trimmed):
			results.append(item)
	_show_items(results)


func _show_items(items: Array) -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()

	for data in items:
		var card = CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.title = data.get("title", "")
		card.food_id = String(data.get("id", ""))
		card.pressed.connect(_on_card_pressed.bind(data))
		_cards_row.add_child(card)
		_cards.append(card)

	_scroll.scroll_horizontal = 0


func _on_card_pressed(data: Dictionary) -> void:
	ingredient_selected.emit(data)
	for i in _cards.size():
		if _cards[i].title == data.get("title"):
			return
