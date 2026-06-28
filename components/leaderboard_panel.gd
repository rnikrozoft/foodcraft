extends Control

signal back_requested

const TIER_META := {
	1: {"title": "อันดับหลัก", "desc": "ชื่อเสียง นักสำรวจ และผู้ค้นพบคนแรก", "emoji": "🏆"},
	2: {"title": "สมรรถนะ", "desc": "ความเร็วและประสิทธิภาพการค้นพบ", "emoji": "⚡"},
	3: {"title": "หมวดอาหาร", "desc": "อันดับแยกตามสำนักอาหาร", "emoji": "🍽"},
	4: {"title": "หอเกียรติยศ", "desc": "ผู้ค้นพบเมนูก่อนใครของเซิร์ฟเวอร์", "emoji": "👑"},
	5: {"title": "ซีซัน", "desc": "อันดับรายฤดูกาล", "emoji": "🌟"},
}

const AVATAR_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/character2.png")
const AVATAR_BG_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Panel_Sprites/profile placeeholder.png")
const TROPHY_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/leaderboard.png")

const SCORE_WIDTH := 88
const TAB_FONT_SIZE := 15
const ROW_MIN_HEIGHT := 62.0
const AVATAR_SIZE := 44.0
const PODIUM_ORDER := [2, 1, 3]

@onready var _title: Label = $Margin/VBox/HeaderPanel/HeaderRow/TitleLabel
@onready var _back: Button = $Margin/VBox/HeaderPanel/HeaderRow/BackButton
@onready var _header_spacer: Control = $Margin/VBox/HeaderPanel/HeaderRow/HeaderSpacer
@onready var _tier_menu_scroll: ScrollContainer = $Margin/VBox/TierMenuScroll
@onready var _tier_menu_list: VBoxContainer = $Margin/VBox/TierMenuScroll/TierMenuList
@onready var _detail_section: VBoxContainer = $Margin/VBox/DetailSection
@onready var _board_tabs: HBoxContainer = $Margin/VBox/DetailSection/BoardTabs
@onready var _podium: HBoxContainer = $Margin/VBox/DetailSection/BoardPanel/BoardMargin/BoardVBox/Podium
@onready var _records_scroll: ScrollContainer = $Margin/VBox/DetailSection/BoardPanel/BoardMargin/BoardVBox/Scroll
@onready var _desc: Label = $Margin/VBox/DetailSection/BoardPanel/BoardMargin/BoardVBox/DescLabel
@onready var _rows: VBoxContainer = $Margin/VBox/DetailSection/BoardPanel/BoardMargin/BoardVBox/Scroll/Rows
@onready var _status: Label = $Margin/VBox/DetailSection/BoardPanel/BoardMargin/BoardVBox/StatusLabel
@onready var _owner_panel: PanelContainer = $Margin/VBox/OwnerPanel
@onready var _owner_rank: Label = $Margin/VBox/OwnerPanel/OwnerRow/OwnerRank
@onready var _owner_name: Label = $Margin/VBox/OwnerPanel/OwnerRow/OwnerInfo/OwnerName
@onready var _owner_score: Label = $Margin/VBox/OwnerPanel/OwnerRow/OwnerScoreBox/OwnerScore

var _boards: Array = []
var _active_tier := 1
var _active_board := ""
var _board_buttons: Dictionary = {}
var _showing_hall := false
var _in_tier_menu := true


func _ready() -> void:
	_records_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_records_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tier_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tier_menu_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_owner_panel_style()
	_back.pressed.connect(_back_to_tier_menu)
	NakamaService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	NakamaService.leaderboards_loaded.connect(_on_boards_loaded)
	NakamaService.hall_of_fame_loaded.connect(_on_hall_of_fame_loaded)
	_tier_menu_scroll.resized.connect(_sync_tier_menu_layout)
	_build_tier_menu()


func prepare_panel() -> void:
	_reset_to_home()


func show_panel() -> void:
	prepare_panel()
	visible = true
	if not NakamaService.is_online:
		_boards = NakamaConfig.get_fallback_boards()
	elif _boards.is_empty():
		await NakamaService.fetch_leaderboard_list()
	call_deferred("_sync_tier_menu_layout")


func hide_panel() -> void:
	visible = false
	_reset_to_home()


func _reset_to_home() -> void:
	_in_tier_menu = true
	_active_tier = 1
	_active_board = ""
	_showing_hall = false
	_apply_tier_menu_ui()
	_clear_podium()
	_clear_rows()


func _build_tier_menu() -> void:
	for child in _tier_menu_list.get_children():
		child.queue_free()
	for tier in [1, 2, 3, 4, 5]:
		var meta: Dictionary = TIER_META[tier]
		_tier_menu_list.add_child(_make_tier_menu_card(tier, meta))
	call_deferred("_sync_tier_menu_layout")


func _sync_tier_menu_layout() -> void:
	if not _in_tier_menu:
		return
	var area_h := _tier_menu_scroll.size.y
	if area_h <= 0.0:
		return
	_tier_menu_list.custom_minimum_size.y = area_h
	var sep := float(_tier_menu_list.get_theme_constant("separation"))
	var card_h := (area_h - sep * 4.0) / 5.0
	_apply_tier_card_scale(card_h)


func _make_tier_menu_card(tier: int, meta: Dictionary) -> Control:
	var root := Control.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_menu_card_style())
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(96, 96)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_stylebox_override("panel", _make_icon_box_style())
	row.add_child(icon_box)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_center)

	var icon := Label.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.text = String(meta.get("emoji", "🏆"))
	icon.add_theme_font_size_override("font_size", 48)
	icon_center.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = String(meta.get("title", ""))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))
	info.add_child(title)

	var desc := Label.new()
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.text = String(meta.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.48, 0.36, 0.26, 1))
	info.add_child(desc)

	var chevron := Label.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.text = "›"
	chevron.custom_minimum_size = Vector2(32, 0)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.add_theme_font_size_override("font_size", 46)
	chevron.add_theme_color_override("font_color", Color(0.62, 0.48, 0.3, 1))
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chevron)

	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_style := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty_style)
	hit.add_theme_stylebox_override("hover", empty_style)
	hit.add_theme_stylebox_override("pressed", empty_style)
	hit.add_theme_stylebox_override("disabled", empty_style)
	hit.add_theme_stylebox_override("focus", empty_style)
	hit.pressed.connect(_open_tier.bind(tier))
	root.add_child(hit)

	root.set_meta("tier_icon_box", icon_box)
	root.set_meta("tier_icon", icon)
	root.set_meta("tier_title", title)
	root.set_meta("tier_desc", desc)
	root.set_meta("tier_chevron", chevron)

	return root


func _apply_tier_card_scale(card_h: float) -> void:
	var icon_sz := clampf(card_h * 0.58, 80.0, 112.0)
	var title_sz := int(clampf(card_h * 0.2, 26, 36))
	var desc_sz := int(clampf(card_h * 0.13, 17, 24))
	var emoji_sz := int(clampf(icon_sz * 0.54, 40, 60))
	var chevron_sz := int(clampf(card_h * 0.3, 36, 56))

	for child in _tier_menu_list.get_children():
		if not child.has_meta("tier_icon_box"):
			continue
		var icon_box: PanelContainer = child.get_meta("tier_icon_box")
		icon_box.custom_minimum_size = Vector2(icon_sz, icon_sz)
		var icon: Label = child.get_meta("tier_icon")
		icon.add_theme_font_size_override("font_size", emoji_sz)
		var title: Label = child.get_meta("tier_title")
		title.add_theme_font_size_override("font_size", title_sz)
		var desc: Label = child.get_meta("tier_desc")
		desc.add_theme_font_size_override("font_size", desc_sz)
		var chevron: Label = child.get_meta("tier_chevron")
		chevron.add_theme_font_size_override("font_size", chevron_sz)


func _open_tier(tier: int) -> void:
	_active_tier = tier
	_apply_tier_detail_ui_sync()
	if NakamaService.is_online and _boards.is_empty():
		_show_status("กำลังโหลด...")
		await NakamaService.fetch_leaderboard_list()
	await _refresh_tier_view()


func _back_to_tier_menu() -> void:
	_show_tier_menu()


func _apply_tier_menu_ui() -> void:
	_in_tier_menu = true
	_title.text = "อันดับ"
	_back.visible = false
	_header_spacer.visible = false
	_tier_menu_scroll.visible = true
	_detail_section.visible = false
	_owner_panel.visible = false


func _apply_tier_detail_ui_sync() -> void:
	_in_tier_menu = false
	_tier_menu_scroll.visible = false
	_detail_section.visible = true
	_back.visible = true
	_header_spacer.visible = true
	_title.text = String(TIER_META.get(_active_tier, {}).get("title", "อันดับ"))
	_showing_hall = _active_tier == 4
	_board_tabs.visible = not _showing_hall and NakamaService.is_online
	if not _showing_hall and NakamaService.is_online and not _boards.is_empty():
		_rebuild_board_tabs()
		var board := _board_meta(_active_board)
		if not board.is_empty():
			_desc.text = String(board.get("description", ""))


func _show_tier_menu() -> void:
	_apply_tier_menu_ui()
	_clear_podium()
	_clear_rows()
	call_deferred("_sync_tier_menu_layout")


func _refresh_tier_view() -> void:
	_showing_hall = _active_tier == 4
	_board_tabs.visible = not _showing_hall
	_clear_podium()
	_clear_rows()
	_hide_owner()

	if not NakamaService.is_online:
		_board_tabs.visible = false
		_podium.visible = false
		_show_status("ออฟไลน์ — ไม่สามารถโหลดอันดับได้")
		return

	if _showing_hall:
		_desc.text = String(TIER_META[4].get("desc", ""))
		_podium.visible = false
		_show_status("กำลังโหลด...")
		var hall_data := await NakamaService.fetch_hall_of_fame()
		_apply_hall_of_fame(hall_data)
		return

	_rebuild_board_tabs()
	var tier_boards := _boards_for_tier(_active_tier)
	if tier_boards.is_empty():
		_desc.text = ""
		_podium.visible = false
		_show_status("ยังไม่มีกระดานในกลุ่มนี้")
		return
	if _active_board.is_empty() or not _board_in_tier(_active_board, _active_tier):
		_set_board(String(tier_boards[0].get("id", "")))


func _boards_for_tier(tier: int) -> Array:
	var out: Array = []
	for board in _boards:
		if int(board.get("tier", 0)) == tier:
			out.append(board)
	return out


func _board_in_tier(board_id: String, tier: int) -> bool:
	for board in _boards_for_tier(tier):
		if String(board.get("id", "")) == board_id:
			return true
	return false


func _rebuild_board_tabs() -> void:
	for child in _board_tabs.get_children():
		child.queue_free()
	_board_buttons.clear()
	for board in _boards_for_tier(_active_tier):
		var board_id := String(board.get("id", ""))
		var btn := _make_tab_button(String(board.get("title", board_id)))
		btn.pressed.connect(_on_board_pressed.bind(board_id))
		_board_tabs.add_child(btn)
		_board_buttons[board_id] = btn
	_update_board_buttons()


func _on_board_pressed(board_id: String) -> void:
	_set_board(board_id)


func _set_board(board_id: String) -> void:
	_active_board = board_id
	_update_board_buttons()
	var board := _board_meta(board_id)
	_desc.text = String(board.get("description", ""))
	_load_active_board()


func _board_meta(board_id: String) -> Dictionary:
	for board in _boards:
		if String(board.get("id", "")) == board_id:
			return board
	return {}


func _load_active_board() -> void:
	if not NakamaService.is_online:
		_show_status("ออฟไลน์ — ไม่สามารถโหลดอันดับได้")
		return
	_show_status("กำลังโหลด...")
	_clear_podium()
	_clear_rows()
	_hide_owner()
	var data := await NakamaService.fetch_leaderboard(_active_board)
	if data.is_empty():
		_show_status("โหลดไม่สำเร็จ — ลองใหม่อีกครั้ง")
	else:
		_apply_leaderboard(data)


func _on_boards_loaded(boards: Array) -> void:
	_boards = boards
	if visible and not _in_tier_menu:
		_refresh_tier_view()


func _on_leaderboard_loaded(data: Dictionary) -> void:
	if _in_tier_menu or _showing_hall or String(data.get("board_id", "")) != _active_board:
		return
	_apply_leaderboard(data)


func _on_hall_of_fame_loaded(data: Dictionary) -> void:
	if _in_tier_menu or not _showing_hall:
		return
	_apply_hall_of_fame(data)


func _apply_leaderboard(data: Dictionary) -> void:
	if data.is_empty():
		_show_status("โหลดไม่สำเร็จ — ลองใหม่อีกครั้ง")
		return
	_desc.text = String(data.get("description", _desc.text))
	_clear_podium()
	_clear_rows()

	var records: Array = data.get("records", [])
	if records.is_empty():
		_podium.visible = false
		_show_status("ยังไม่มีข้อมูลอันดับ")
		return

	_hide_status()
	var score_unit := String(data.get("score_unit", ""))
	var board_id := String(data.get("board_id", _active_board))
	_build_podium(records, board_id, score_unit)
	for record in records:
		if int(record.get("rank", 0)) > 3:
			_rows.add_child(_make_rank_row(record, board_id, score_unit))

	var owner_data: Dictionary = data.get("owner", {})
	if owner_data.is_empty():
		_hide_owner()
	else:
		_show_owner(
			int(owner_data.get("rank", 0)),
			String(owner_data.get("username", NakamaService.get_display_name())),
			_format_score(int(owner_data.get("score", 0)), board_id, score_unit)
		)


func _apply_hall_of_fame(data: Dictionary) -> void:
	if not _showing_hall:
		return
	_clear_rows()
	if data.is_empty():
		_show_status("โหลดไม่สำเร็จ — รีสตาร์ทเซิร์ฟเวอร์ (make build && make run)")
		return
	var entries: Array = data.get("entries", [])
	if entries.is_empty():
		_show_status("ยังไม่มีผู้ค้นพบคนแรก")
		return
	_hide_status()
	for i in entries.size():
		_rows.add_child(_make_hall_row(entries[i], i + 1))


func _build_podium(records: Array, board_id: String, score_unit: String) -> void:
	_clear_podium()
	var top_records := _records_up_to_rank(records, 3)
	if top_records.is_empty():
		_podium.visible = false
		return
	_podium.visible = true
	for rank in PODIUM_ORDER:
		var record: Dictionary = top_records.get(rank, {})
		_podium.add_child(_make_podium_slot(rank, record, board_id, score_unit))


func _records_up_to_rank(records: Array, max_rank: int) -> Dictionary:
	var out := {}
	for record in records:
		var rank := int(record.get("rank", 0))
		if rank >= 1 and rank <= max_rank:
			out[rank] = record
	return out


func _make_podium_slot(rank: int, record: Dictionary, board_id: String, score_unit: String) -> Control:
	var slot := VBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 4)
	slot.alignment = BoxContainer.ALIGNMENT_END

	var pedestal := PanelContainer.new()
	pedestal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pedestal.add_theme_stylebox_override("panel", _make_podium_style(rank))

	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 4)
	pedestal.add_child(body)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	body.add_child(margin)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	margin.add_child(inner)

	if record.is_empty():
		inner.add_theme_constant_override("separation", 0)
		var empty := Label.new()
		empty.text = "-"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3, 0.6))
		inner.add_child(empty)
	else:
		inner.add_child(_make_avatar())
		var name := Label.new()
		name.text = String(record.get("username", "???"))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.add_theme_font_size_override("font_size", 14 if rank == 1 else 13)
		name.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06, 1))
		inner.add_child(name)
		var score := Label.new()
		score.text = _format_score(int(record.get("score", 0)), board_id, score_unit)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.add_theme_font_size_override("font_size", 15 if rank == 1 else 14)
		score.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1, 1))
		inner.add_child(score)

	slot.add_child(pedestal)

	var medal := Label.new()
	medal.text = _rank_display(rank)
	medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal.add_theme_font_size_override("font_size", 22 if rank == 1 else 18)
	slot.add_child(medal)

	pedestal.custom_minimum_size.y = 108.0 if rank == 1 else 84.0
	return slot


func _make_rank_row(record: Dictionary, board_id: String, score_unit: String) -> PanelContainer:
	var rank := int(record.get("rank", 0))
	var username := String(record.get("username", "???"))
	var score_text := _format_score(int(record.get("score", 0)), board_id, score_unit)
	return _make_list_row(rank, username, "เชฟ", score_text, false)


func _make_hall_row(entry: Dictionary, index: int) -> PanelContainer:
	var item_name := String(entry.get("item_name", entry.get("item_id", "?")))
	var title := "%s %s" % [String(entry.get("emoji", "🍽")), item_name]
	var discoverer := String(entry.get("username", "???"))
	return _make_list_row(index, title, "ค้นพบโดย %s" % discoverer, "", false)


func _make_list_row(
	rank: int,
	title_text: String,
	subtitle_text: String,
	score_text: String,
	is_owner: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_MIN_HEIGHT
	panel.add_theme_stylebox_override("panel", _make_row_style(is_owner))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(32, 0)
	rank_label.text = str(rank) if rank > 3 else _rank_display(rank)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 16)
	rank_label.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2, 1))
	row.add_child(rank_label)

	if not _showing_hall:
		row.add_child(_make_avatar())

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06, 1))
	info.add_child(title_label)

	if not subtitle_text.is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle_text
		subtitle_label.clip_text = true
		subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle_label.add_theme_font_size_override("font_size", 12)
		subtitle_label.add_theme_color_override("font_color", Color(0.48, 0.36, 0.26, 1))
		info.add_child(subtitle_label)

	if not score_text.is_empty():
		row.add_child(_make_score_box(score_text))

	return panel


func _make_avatar() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)

	var bg := TextureRect.new()
	bg.texture = AVATAR_BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wrap.add_child(bg)

	var face := TextureRect.new()
	face.texture = AVATAR_TEX
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 4.0
	face.offset_top = 4.0
	face.offset_right = -4.0
	face.offset_bottom = -4.0
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wrap.add_child(face)
	return wrap


func _make_score_box(score_text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = SCORE_WIDTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var trophy := TextureRect.new()
	trophy.custom_minimum_size = Vector2(20, 20)
	trophy.texture = TROPHY_TEX
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(trophy)

	var label := Label.new()
	label.text = score_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))
	box.add_child(label)
	return box


func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_stretch_ratio = 1.0
	btn.custom_minimum_size.y = 42
	btn.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	_apply_tab_style(btn, false)
	return btn


func _apply_tab_style(btn: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	if active:
		box.bg_color = Color(0.98, 0.86, 0.42, 1)
		box.border_width_left = 2
		box.border_width_top = 2
		box.border_width_right = 2
		box.border_width_bottom = 2
		box.border_color = Color(0.82, 0.62, 0.18, 1)
	else:
		box.bg_color = Color(0.88, 0.8, 0.68, 1)
		box.border_width_left = 2
		box.border_width_top = 2
		box.border_width_right = 2
		box.border_width_bottom = 2
		box.border_color = Color(0.68, 0.54, 0.34, 0.55)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_color_override(
		"font_color",
		Color(0.24, 0.14, 0.08, 1) if active else Color(0.45, 0.34, 0.24, 1)
	)


func _update_board_buttons() -> void:
	for board_id in _board_buttons:
		_apply_tab_style(_board_buttons[board_id], board_id == _active_board)


func _make_menu_card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.94, 0.88, 0.76, 1)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.68, 0.52, 0.32, 0.65)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	return box


func _make_icon_box_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.98, 0.92, 0.8, 1)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.72, 0.55, 0.3, 0.5)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	return box


func _make_podium_style(rank: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	match rank:
		1:
			box.bg_color = Color(1, 0.88, 0.45, 0.55)
		2:
			box.bg_color = Color(0.82, 0.86, 0.92, 0.65)
		_:
			box.bg_color = Color(0.92, 0.72, 0.52, 0.55)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.62, 0.48, 0.28, 0.45)
	return box


func _make_row_style(is_owner: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.border_width_bottom = 1
	box.border_color = Color(0.62, 0.5, 0.36, 0.22)
	box.bg_color = Color(1, 0.78, 0.35, 0.18) if is_owner else Color(0, 0, 0, 0)
	return box


func _apply_owner_panel_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.28, 0.52, 0.82, 1)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.18, 0.38, 0.62, 1)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_owner_panel.add_theme_stylebox_override("panel", box)


func _rank_display(rank: int) -> String:
	match rank:
		1:
			return "🥇"
		2:
			return "🥈"
		3:
			return "🥉"
		_:
			return "#%d" % rank


func _format_score(score: int, board_id: String, score_unit: String) -> String:
	if score <= 0 and board_id.begins_with("speed_runner"):
		return "ยังไม่ถึง"
	if board_id == "efficiency" or board_id == "season_efficiency":
		return "%.1f%%" % (float(score) / 100.0)
	if board_id.begins_with("speed_runner") and score > 0:
		var reached: int = NakamaConfig.SPEED_SCORE_BASE - score
		return Time.get_datetime_string_from_unix_time(reached, true)
	if not score_unit.is_empty():
		return "%d %s" % [score, score_unit]
	return str(score)


func _show_owner(rank: int, username: String, score_text: String) -> void:
	_owner_rank.text = str(rank) if rank > 0 else "-"
	_owner_name.text = username if not username.is_empty() else NakamaService.get_display_name()
	_owner_score.text = score_text
	_owner_panel.visible = true


func _hide_owner() -> void:
	_owner_panel.visible = false


func _show_status(message: String) -> void:
	_desc.visible = false
	_status.text = message
	_status.visible = true
	_records_scroll.visible = false
	_podium.visible = false


func _hide_status() -> void:
	_status.visible = false
	_records_scroll.visible = true
	_desc.visible = not _desc.text.is_empty()


func _clear_podium() -> void:
	for child in _podium.get_children():
		child.queue_free()


func _clear_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
