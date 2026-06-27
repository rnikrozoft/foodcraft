extends Control

signal ingredient_picked(data: Dictionary)

const CARD_SCENE := preload("res://components/ingredient_card.tscn")
const CARD_MIN_WIDTH := 108.0
const CARD_HEIGHT := 120.0
const GRID_SEP := 12
const GRID_MIN_COLUMNS := 3

const CATEGORY_TABS := [
	{"id": "", "label": "ทั้งหมด", "emoji": "🍽"},
	{"id": "thai", "label": "ไทย", "emoji": "🍜"},
	{"id": "japanese", "label": "ญี่ปุ่น", "emoji": "🍣"},
	{"id": "chinese", "label": "จีน", "emoji": "🥟"},
	{"id": "western", "label": "ตะวันตก", "emoji": "🍔"},
	{"id": "dessert", "label": "ของหวาน", "emoji": "🍰"},
	{"id": "ingredient", "label": "วัตถุดิบ", "emoji": "🧄"},
]

@onready var _discovery_badge: Control = $Margin/VBox/HeaderRow/DiscoveryBadge
@onready var _category_scroll: ScrollContainer = $Margin/VBox/CategoryScroll
@onready var _category_row: HBoxContainer = $Margin/VBox/CategoryScroll/CategoryRow
@onready var _search: LineEdit = $Margin/VBox/SearchBox/SearchInput
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _status: Label = $Margin/VBox/StatusLabel

var _all_items: Array = []
var _cards: Array = []
var _pick_mode := false
var _active_category := ""
var _category_buttons: Dictionary = {}


func _ready() -> void:
	_discovery_badge.set_title("สูตรของฉัน")
	_category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_category_buttons()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.resized.connect(_layout_grid_cards)
	_search.text_changed.connect(_on_search_changed)
	GameData.progress_changed.connect(_on_progress_changed)


func show_panel(pick_for_craft: bool = false) -> void:
	_pick_mode = pick_for_craft
	_active_category = ""
	_update_category_styles()
	visible = true
	_search.text = ""
	_refresh()


func hide_panel() -> void:
	visible = false
	_pick_mode = false


func _on_progress_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_all_items = _get_items_for_mode()
	_discovery_badge.set_progress(GameData.get_discovered_count(), GameData.get_total_discoverable())
	_apply_filter(_search.text.strip_edges())


func _get_items_for_mode() -> Array:
	if _pick_mode:
		return _merge_items(GameData.get_panel_ingredients(), GameData.get_discovered_items())
	return GameData.get_discovered_items()


func _merge_items(primary: Array, extra: Array) -> Array:
	var merged: Array = []
	var seen: Dictionary = {}
	for item in primary + extra:
		var id := String(item.get("id", ""))
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		merged.append(item)
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("title", "")) < String(b.get("title", ""))
	)
	return merged


func _on_search_changed(query: String) -> void:
	_apply_filter(query.strip_edges())


func _apply_filter(query: String) -> void:
	var items := _all_items
	if not _active_category.is_empty():
		var filtered: Array = []
		for item in items:
			if String(item.get("category", "")) == _active_category:
				filtered.append(item)
		items = filtered
	if not query.is_empty():
		var searched: Array = []
		for item in items:
			if String(item.get("title", "")).contains(query):
				searched.append(item)
		items = searched
	_show_grid(items)


func _build_category_buttons() -> void:
	for child in _category_row.get_children():
		child.queue_free()
	_category_buttons.clear()
	for tab in CATEGORY_TABS:
		var category_id := String(tab.get("id", ""))
		var btn := Button.new()
		btn.text = "%s %s" % [String(tab.get("emoji", "")), String(tab.get("label", ""))]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_category_pressed.bind(category_id))
		_apply_category_style(btn, false)
		_category_row.add_child(btn)
		_category_buttons[category_id] = btn
	_update_category_styles()


func _on_category_pressed(category_id: String) -> void:
	_active_category = category_id
	_update_category_styles()
	_apply_filter(_search.text.strip_edges())


func _update_category_styles() -> void:
	for category_id in _category_buttons:
		_apply_category_style(_category_buttons[category_id], category_id == _active_category)


func _apply_category_style(btn: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.bg_color = Color(0.4, 0.28, 0.2, 1) if active else Color(0.35, 0.24, 0.17, 1)
	if active:
		box.border_width_left = 2
		box.border_width_top = 2
		box.border_width_right = 2
		box.border_width_bottom = 2
		box.border_color = Color(1, 0.82, 0.28, 1)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.85, 1))
	btn.add_theme_font_size_override("font_size", 16)


func _show_grid(items: Array) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	if items.is_empty():
		_status.visible = true
		if _all_items.is_empty():
			_status.text = "ยังไม่มีสูตรที่ค้นพบ — ลองผสมวัตถุดิบดูสิ!"
		elif not _search.text.strip_edges().is_empty() or not _active_category.is_empty():
			_status.text = "ไม่พบรายการในหมวดนี้"
		else:
			_status.text = "ยังไม่มีสูตรที่ค้นพบ"
		return

	_status.visible = false
	for data in items:
		var card = CARD_SCENE.instantiate()
		card.title = String(data.get("title", ""))
		card.emoji = String(data.get("emoji", ""))
		if _pick_mode:
			card.pressed.connect(_on_card_pressed.bind(data))
		else:
			card.get_node("ClickArea").mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(card)
		_cards.append(card)
	call_deferred("_layout_grid_cards")


func _layout_grid_cards() -> void:
	if _cards.is_empty():
		return
	var width := _scroll.size.x
	if width < 1.0:
		return
	var columns := maxi(
		GRID_MIN_COLUMNS,
		int(floor((width + GRID_SEP) / (CARD_MIN_WIDTH + GRID_SEP)))
	)
	_grid.columns = columns
	var card_width: float = floor((width - GRID_SEP * float(columns - 1)) / float(columns))
	for card in _cards:
		card.custom_minimum_size = Vector2(card_width, CARD_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _on_card_pressed(data: Dictionary) -> void:
	if not _pick_mode:
		return
	ingredient_picked.emit(data)


func _input(event: InputEvent) -> void:
	if not visible or not _search.has_focus():
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
