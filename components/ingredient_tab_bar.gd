@tool
extends Control

signal tab_selected(category: String)  # "" = show all
signal menu_pressed                     # navigate to My Recipes

const TEX_RESET_NORMAL := preload("res://assets/icons/misc/Icon_MenuIcon01_Menu_n.Png")
const TEX_RESET_ACTIVE := preload("res://assets/icons/misc/Icon_MenuIcon01_Menu_s.Png")
const TEX_SEE_ALL      := preload("res://assets/icons/misc/Icon_MenuIcon01_List_n.Png")
const TEX_SEE_ALL_ACT  := preload("res://assets/icons/misc/Icon_MenuIcon01_List_s.Png")

const CATEGORY_FLAG := {
	"thai":     preload("res://assets/icons/flags/Icon_Flag_Tha.Png"),
	"japanese": preload("res://assets/icons/flags/Icon_Flag_Jpn.Png"),
	"chinese":  preload("res://assets/icons/flags/Icon_Flag_Chn.Png"),
	"western":  preload("res://assets/icons/flags/Icon_Flag_Eng.Png"),
	"italian":  preload("res://assets/icons/flags/Icon_Flag_Ita.Png"),
	"korean":   preload("res://assets/icons/flags/Icon_Flag_Kor.Png"),
	"french":   preload("res://assets/icons/flags/Icon_Flag_Fra.Png"),
	"german":   preload("res://assets/icons/flags/Icon_Flag_Deu.Png"),
	"spanish":  preload("res://assets/icons/flags/Icon_Flag_Esp.Png"),
}

@onready var _scroll: ScrollContainer = $Layout/Scroll
@onready var _hbox: HBoxContainer = $Layout/Scroll/HBox
@onready var _see_all_slot: Control = $Layout/SeeAllSlot

var _active_tab: String = ""
var _categories: Array = []


func _ready() -> void:
	if Engine.is_editor_hint():
		build_tabs(["thai", "japanese", "chinese"])
		return
	_scroll.get_h_scroll_bar().custom_minimum_size.y = 0
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 0


func build_tabs(categories: Array) -> void:
	_categories = []
	for c in categories:
		if CATEGORY_FLAG.has(String(c)):
			_categories.append(String(c))
	_rebuild()


func reset() -> void:
	_active_tab = ""
	_rebuild()


func _rebuild() -> void:
	for child in _hbox.get_children():
		child.queue_free()
	# Reset button (show all / clear filter)
	_hbox.add_child(_make_tab("__reset__", _active_tab == ""))
	# Flag tabs per nationality
	for cat in _categories:
		_hbox.add_child(_make_tab(cat, _active_tab == cat))

	# See All button — outside scroll, pinned right in SeeAllSlot
	for child in _see_all_slot.get_children():
		child.queue_free()
	_see_all_slot.add_child(_make_tab("__see_all__", false))


func _make_tab(tab_id: String, is_active: bool) -> Control:
	var icon_tex: Texture2D
	match tab_id:
		"__reset__":
			icon_tex = TEX_RESET_ACTIVE if is_active else TEX_RESET_NORMAL
		"__see_all__":
			icon_tex = TEX_SEE_ALL_ACT if is_active else TEX_SEE_ALL
		_:
			icon_tex = CATEGORY_FLAG.get(tab_id, TEX_RESET_NORMAL)

	var container := Control.new()
	container.custom_minimum_size = Vector2(44, 44)
	# Dim inactive tabs; active tab is full brightness and slightly larger
	container.modulate = Color(1, 1, 1, 1) if is_active else Color(1, 1, 1, 0.45)
	container.scale = Vector2(1.15, 1.15) if is_active else Vector2(1.0, 1.0)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.layout_mode = 1
	icon_rect.anchors_preset = Control.PRESET_FULL_RECT
	icon_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon_rect)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.layout_mode = 1
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sbe := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", sbe)
	btn.add_theme_stylebox_override("hover", sbe)
	btn.add_theme_stylebox_override("pressed", sbe)
	btn.add_theme_stylebox_override("focus", sbe)
	btn.pressed.connect(_on_tab_pressed.bind(tab_id))
	container.add_child(btn)

	return container


func _on_tab_pressed(tab_id: String) -> void:
	match tab_id:
		"__see_all__":
			menu_pressed.emit()
		"__reset__":
			_active_tab = ""
			_rebuild()
			tab_selected.emit("")
		_:
			_active_tab = "" if _active_tab == tab_id else tab_id
			_rebuild()
			tab_selected.emit(_active_tab)
