extends Control

signal see_all_pressed

signal ingredient_selected(data: Dictionary)

const CARD_SCENE := preload("res://components/ingredient_card.tscn")

@onready var _see_all: Button = $Margin/VBox/Header/SeeAll
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _cards_row: HBoxContainer = $Margin/VBox/Scroll/CardRow
@onready var _search: LineEdit = $Margin/VBox/SearchBox/SearchInput

var _cards: Array = []
var _all_ingredients: Array = []


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_all_ingredients = GameData.get_panel_ingredients()
	_search.text_changed.connect(_on_search_changed)
	_see_all.pressed.connect(func() -> void: see_all_pressed.emit())
	_show_ingredients(_all_ingredients)


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
		_show_ingredients(_all_ingredients)
		return

	var results: Array = []
	for item in _all_ingredients:
		if String(item.get("title", "")).contains(trimmed):
			results.append(item)
	_show_ingredients(results)


func _show_ingredients(items: Array) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	for data in items:
		var card = CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.title = data.get("title", "")
		card.emoji = data.get("emoji", "")
		card.pressed.connect(_on_card_pressed.bind(data))
		_cards_row.add_child(card)
		_cards.append(card)

	if _cards.size() > 0:
		_select_card(0)


func _on_card_pressed(data: Dictionary) -> void:
	ingredient_selected.emit(data)
	for i in _cards.size():
		if _cards[i].title == data.get("title"):
			_select_card(i)
			return


func _select_card(index: int) -> void:
	for i in _cards.size():
		_cards[i].set_selected(i == index)
