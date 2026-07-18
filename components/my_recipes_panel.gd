@tool
extends Control

signal ingredient_picked(data: Dictionary)

const CARD_SCENE := preload("res://components/ingredient_card.tscn")
const CARD_MIN_WIDTH := 108.0
const CARD_HEIGHT := 120.0
const GRID_SEP := 12
const GRID_MIN_COLUMNS := 3
const EDITOR_PREVIEW_SIZE := Vector2(688, 1088)
const EDITOR_PREVIEW_POS := Vector2(16, 96)
const CARD_TEX := preload("res://assets/labels/Label_Round01_White.png")

# ── FoodCraft warm palette (shared with leaderboard/shop) ──
const COL_CREAM     := Color(0.96, 0.92, 0.84)
const COL_GREEN     := Color(0.45, 0.68, 0.24)
const COL_TEXT_SUB  := Color(0.55, 0.48, 0.37)

const CATEGORY_TABS := [
	{"id": "", "label": "ทั้งหมด", "emoji": "🍽"},
	{"id": "thai", "label": "ไทย", "emoji": "🍜"},
	{"id": "japanese", "label": "ญี่ปุ่น", "emoji": "🍣"},
	{"id": "chinese", "label": "จีน", "emoji": "🥟"},
	{"id": "western", "label": "ตะวันตก", "emoji": "🍔"},
	{"id": "dessert", "label": "ของหวาน", "emoji": "🍰"},
	{"id": "ingredient", "label": "วัตถุดิบ", "emoji": "🧄"},
]

const SORT_TABS := [
	{"id": "tier", "label": "ความหายาก"},
	{"id": "newest", "label": "ล่าสุด"},
	{"id": "oldest", "label": "เก่าสุด"},
]

@onready var _discovery_badge: Control = $Margin/VBox/HeaderRow/DiscoveryBadge
@onready var _sort_button: MenuButton = $Margin/VBox/SearchRow/SortButton
@onready var _category_scroll: ScrollContainer = $Margin/VBox/CategoryScroll
@onready var _category_row: HBoxContainer = $Margin/VBox/CategoryScroll/CategoryRow
@onready var _search: LineEdit = $Margin/VBox/SearchRow/SearchBox/SearchInput
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _status: Label = $Margin/VBox/StatusLabel

var _all_items: Array = []
var _cards: Array = []
var _pick_mode := false
var _active_category := ""
var _category_buttons: Dictionary = {}
var _sort_mode := "tier"


func _enter_tree() -> void:
	_apply_editor_preview()


func _ready() -> void:
	_category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_category_buttons()
	_build_sort_menu()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.resized.connect(_layout_grid_cards)
	_search.text_changed.connect(_on_search_changed)
	if Engine.is_editor_hint():
		return
	GameData.progress_changed.connect(_on_progress_changed)


func prepare_panel(pick_for_craft: bool = false) -> void:
	_pick_mode = pick_for_craft
	_active_category = ""
	_update_category_styles()
	_search.text = ""
	visible = true
	_refresh()


func show_panel(pick_for_craft: bool = false) -> void:
	if _pick_mode != pick_for_craft or not visible:
		prepare_panel(pick_for_craft)
	else:
		visible = true


func hide_panel() -> void:
	visible = false
	_pick_mode = false


func _on_progress_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_all_items = _get_items_for_mode()
	_apply_filter(_search.text.strip_edges())


func _get_items_for_mode() -> Array:
	if _pick_mode:
		return _merge_items(GameData.get_panel_ingredients(), GameData.get_discovered_items())
	return GameData.get_collection_items()


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
	_show_grid(_sort_items(items))


func _sort_items(items: Array) -> Array:
	var sorted := items.duplicate()
	match _sort_mode:
		"newest":
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var at := int(a.get("discovered_at", 0))
				var bt := int(b.get("discovered_at", 0))
				if at != bt:
					return at > bt
				return String(a.get("title", "")) < String(b.get("title", ""))
			)
		"oldest":
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var at := int(a.get("discovered_at", 0))
				var bt := int(b.get("discovered_at", 0))
				if at != bt:
					return at < bt
				return String(a.get("title", "")) < String(b.get("title", ""))
			)
		_:  # "tier" — most rare first
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var tier_a := int(a.get("tier", 0))
				var tier_b := int(b.get("tier", 0))
				if tier_a != tier_b:
					return tier_a > tier_b
				return String(a.get("title", "")) < String(b.get("title", ""))
			)
	return sorted


func _build_category_buttons() -> void:
	for child in _category_row.get_children():
		child.queue_free()
	_category_buttons.clear()
	for tab in CATEGORY_TABS:
		var category_id := String(tab.get("id", ""))
		var btn := Button.new()
		btn.text = String(tab.get("label", ""))
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size.y = 46.0
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
	var normal_style := _make_category_button_style(active)
	var pressed_style := _make_category_button_style(true)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var font_col := Color(1, 1, 1, 1) if active else COL_TEXT_SUB
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_font_size_override("font_size", 16)


func _make_category_button_style(active: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CARD_TEX
	style.texture_margin_left = 20
	style.texture_margin_top = 20
	style.texture_margin_right = 20
	style.texture_margin_bottom = 24
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	style.modulate_color = COL_GREEN if active else COL_CREAM
	return style


func _build_sort_menu() -> void:
	_apply_category_style(_sort_button, false)
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.custom_minimum_size = Vector2(0, 46)
	_sort_button.text = "เรียง: " + _sort_label_for_mode(_sort_mode)
	var popup := _sort_button.get_popup()
	popup.clear()
	for i in range(SORT_TABS.size()):
		popup.add_item(String(SORT_TABS[i].get("label", "")), i)
	if not popup.id_pressed.is_connected(_on_sort_selected):
		popup.id_pressed.connect(_on_sort_selected)


func _on_sort_selected(id: int) -> void:
	if id < 0 or id >= SORT_TABS.size():
		return
	_sort_mode = String(SORT_TABS[id].get("id", "tier"))
	_sort_button.text = "เรียง: " + _sort_label_for_mode(_sort_mode)
	_apply_filter(_search.text.strip_edges())


func _sort_label_for_mode(mode: String) -> String:
	for tab in SORT_TABS:
		if String(tab.get("id", "")) == mode:
			return String(tab.get("label", ""))
	return ""


func _show_grid(items: Array) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()

	if items.is_empty():
		_status.visible = true
		if _all_items.is_empty():
			_status.text = "ยังไม่มีสูตรหรือวัตถุดิบ — ลองผสมวัตถุดิบดูสิ!"
		elif not _search.text.strip_edges().is_empty() or not _active_category.is_empty():
			_status.text = "ไม่พบรายการในหมวดนี้"
		else:
			_status.text = "ยังไม่มีสูตรที่ค้นพบ"
		return

	_status.visible = false
	for data in items:
		var card = CARD_SCENE.instantiate()
		card.title = String(data.get("title", ""))
		card.food_id = String(data.get("id", ""))
		if _pick_mode:
			card.pressed.connect(_on_card_pressed.bind(data))
		else:
			card.get_node("ClickArea").mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(card)
		_cards.append(card)
	_layout_grid_cards()


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


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if get_tree().edited_scene_root == self:
		custom_minimum_size = EDITOR_PREVIEW_SIZE
		position = EDITOR_PREVIEW_POS
		size = EDITOR_PREVIEW_SIZE
	else:
		custom_minimum_size = Vector2.ZERO
		position = Vector2.ZERO
