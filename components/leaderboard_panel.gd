@tool
extends Control

signal back_requested

const TIER_META := {
	1: {"title": "อันดับหลัก", "desc": "ชื่อเสียง นักสำรวจ และผู้ค้นพบคนแรก"},
	2: {"title": "สมรรถนะ", "desc": "ความเร็วและประสิทธิภาพการค้นพบ"},
	3: {"title": "หมวดอาหาร", "desc": "อันดับแยกตามสำนักอาหาร"},
	4: {"title": "หอเกียรติยศ", "desc": "ผู้ค้นพบเมนูก่อนใครของเซิร์ฟเวอร์"},
	5: {"title": "ซีซัน", "desc": "อันดับรายฤดูกาล"},
}

const TIER_ICONS := {
	1: preload("res://assets/Components/IconMisc/Icon_ImageIcon_Ranking.png"),
	2: preload("res://assets/Components/IconMisc/Icon_ImageIcon_Energy.png"),
	3: preload("res://assets/Components/Icon_ItemIcons/128/Icon_Food_Meat.png"),
	4: preload("res://assets/Components/IconMisc/Icon_ImageIcon_Crown_Gold.Png"),
	5: preload("res://assets/Components/IconMisc/Icon_ImageIcon_Star01_l.png"),
}

const AVATAR_TEX := preload("res://assets/Components/IconMisc/Icon_ImageIcon_UserThumbnail.png")
const TROPHY_TEX := preload("res://assets/Components/IconMisc/Icon_ImageIcon_Trophy_l.png")

const CARD_TEX      := preload("res://assets/Components/Label/Label_Round01_White.png")
const ITEM_SLOT_TEX := preload("res://assets/Components/Frame/ItemFrame01_Single_Yellow.png")
const CHEVRON_TEX   := preload("res://assets/Components/IconMisc/Icon_PictoIcon_Next01.png")

const MEDAL_GOLD_TEX   := preload("res://assets/Components/IconMisc/Icon_ImageIcon_Medal_Gold.png")
const MEDAL_SILVER_TEX := preload("res://assets/Components/IconMisc/Icon_ImageIcon_Medal_Silver.png")
const MEDAL_BRONZE_TEX := preload("res://assets/Components/IconMisc/Icon_ImageIcon_Medal_Bronze.png")

const FONT_BOLD := preload("res://assets/fonts/Kanit-Bold.ttf")

# ── FoodCraft warm palette (cream cards on dark cocoa) ──
const COL_CREAM        := Color(0.96, 0.92, 0.84)   # card bg
const COL_GOLD         := Color(1.0, 0.78, 0.25)    # buttons / highlights
const COL_GOLD_PRESSED := Color(0.85, 0.62, 0.12)
const COL_GREEN        := Color(0.45, 0.68, 0.24)   # active tab
const COL_OWNER_TINT   := Color(1.0, 0.84, 0.47)    # own-rank row
const COL_TEXT_DARK    := Color(0.3, 0.23, 0.14)    # text on cream
const COL_TEXT_SUB     := Color(0.55, 0.48, 0.37)   # secondary on cream
const COL_SCORE        := Color(0.78, 0.55, 0.08)   # score gold on cream

const SCORE_WIDTH := 88
const TAB_FONT_SIZE := 16
const ROW_MIN_HEIGHT := 64.0
const AVATAR_SIZE := 46.0

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
	_tier_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tier_menu_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_tier_menu()
	if Engine.is_editor_hint():
		return
	_records_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_records_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_apply_owner_panel_style()
	_back.pressed.connect(_back_to_tier_menu)
	NakamaService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	NakamaService.leaderboards_loaded.connect(_on_boards_loaded)
	NakamaService.hall_of_fame_loaded.connect(_on_hall_of_fame_loaded)
	NakamaService.connection_restored.connect(_on_connection_restored)
	_tier_menu_scroll.resized.connect(_sync_tier_menu_layout)


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
	# 5 cards → 4 separations
	var card_h := maxf((area_h - sep * 4.0) / 5.0, 80.0)
	_apply_tier_card_scale(card_h)


func _make_card_ninepatch(tint: Color) -> NinePatchRect:
	var bg := NinePatchRect.new()
	bg.texture = CARD_TEX
	bg.self_modulate = tint
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.patch_margin_left = 20
	bg.patch_margin_top = 20
	bg.patch_margin_right = 20
	bg.patch_margin_bottom = 24
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


func _make_card_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = CARD_TEX
	sb.modulate_color = tint
	sb.texture_margin_left = 20.0
	sb.texture_margin_top = 20.0
	sb.texture_margin_right = 20.0
	sb.texture_margin_bottom = 24.0
	return sb


func _make_tier_menu_card(tier: int, meta: Dictionary) -> Control:
	var root := Control.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Background: cream rounded card ──
	root.add_child(_make_card_ninepatch(COL_CREAM))

	# ── Content row ──
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# ── Left: golden badge slot with tier icon ──
	var slot_wrap := Control.new()
	slot_wrap.custom_minimum_size = Vector2(88, 88)
	slot_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot_wrap)

	var slot_bg := TextureRect.new()
	slot_bg.texture = ITEM_SLOT_TEX
	slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_wrap.add_child(slot_bg)

	var icon := TextureRect.new()
	icon.texture = TIER_ICONS.get(tier, TROPHY_TEX)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 16.0
	icon.offset_top = 14.0
	icon.offset_right = -16.0
	icon.offset_bottom = -18.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_wrap.add_child(icon)

	# ── Center: title + desc (dark text on cream) ──
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var title := Label.new()
	title.text = String(meta.get("title", ""))
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_TEXT_DARK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(title)

	var desc := Label.new()
	desc.text = String(meta.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", COL_TEXT_SUB)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(desc)

	# ── Right: gold "ดูอันดับ" button ──
	var btn_wrap := Control.new()
	btn_wrap.custom_minimum_size = Vector2(128, 52)
	btn_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn_wrap)

	var btn_bg := _make_card_ninepatch(COL_GOLD)
	btn_wrap.add_child(btn_bg)

	var btn_lbl := Label.new()
	btn_lbl.text = "ดูอันดับ"
	btn_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_lbl.offset_bottom = -4.0
	btn_lbl.add_theme_font_override("font", FONT_BOLD)
	btn_lbl.add_theme_font_size_override("font_size", 17)
	btn_lbl.add_theme_color_override("font_color", COL_TEXT_DARK)
	btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_wrap.add_child(btn_lbl)

	# ── Transparent hit area ──
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_style := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(s, empty_style)
	hit.pressed.connect(_open_tier.bind(tier))
	root.add_child(hit)

	root.set_meta("tier_icon_box", slot_wrap)
	root.set_meta("tier_title", title)
	root.set_meta("tier_desc", desc)
	root.set_meta("tier_chevron", btn_lbl)

	return root


func _apply_tier_card_scale(card_h: float) -> void:
	var icon_sz  := clampf(card_h * 0.62, 70.0, 100.0)
	var title_sz := int(clampf(card_h * 0.2, 22, 32))
	var desc_sz  := int(clampf(card_h * 0.13, 14, 22))
	var btn_sz   := int(clampf(card_h * 0.16, 13, 19))

	for child in _tier_menu_list.get_children():
		if not child.has_meta("tier_icon_box"):
			continue
		child.custom_minimum_size.y = card_h
		var icon_box: Control = child.get_meta("tier_icon_box")
		icon_box.custom_minimum_size = Vector2(icon_sz, icon_sz)
		var title: Label = child.get_meta("tier_title")
		title.add_theme_font_size_override("font_size", title_sz)
		var desc: Label = child.get_meta("tier_desc")
		desc.add_theme_font_size_override("font_size", desc_sz)
		var btn_lbl: Label = child.get_meta("tier_chevron")
		btn_lbl.add_theme_font_size_override("font_size", btn_sz)


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


func _on_connection_restored() -> void:
	if not visible:
		return
	if _in_tier_menu:
		await NakamaService.fetch_leaderboard_list()
	elif _showing_hall:
		await NakamaService.fetch_hall_of_fame()
	elif not _active_board.is_empty():
		var data := await NakamaService.fetch_leaderboard(_active_board)
		if not data.is_empty() and not bool(data.get("rpc_error", false)):
			_apply_leaderboard(data)


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
	_podium.visible = false
	for record in records:
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


func _make_rank_row(record: Dictionary, board_id: String, score_unit: String) -> PanelContainer:
	var rank := int(record.get("rank", 0))
	var username := String(record.get("username", "???"))
	var score_text := _format_score(int(record.get("score", 0)), board_id, score_unit)
	return _make_list_row(rank, username, "", score_text, false)


func _make_hall_row(entry: Dictionary, index: int) -> PanelContainer:
	var item_name := String(entry.get("item_name", entry.get("item_id", "?")))
	var title := item_name
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
	panel.add_theme_stylebox_override(
		"panel", _make_card_style(COL_OWNER_TINT if is_owner else COL_CREAM)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# ── Rank cell: winged medal for 1-3, number for the rest ──
	var rank_cell := Control.new()
	rank_cell.custom_minimum_size = Vector2(48, 0)
	row.add_child(rank_cell)
	if rank >= 1 and rank <= 3:
		var medal := TextureRect.new()
		match rank:
			1: medal.texture = MEDAL_GOLD_TEX
			2: medal.texture = MEDAL_SILVER_TEX
			_: medal.texture = MEDAL_BRONZE_TEX
		medal.set_anchors_preset(Control.PRESET_FULL_RECT)
		medal.offset_top = 2.0
		medal.offset_bottom = -2.0
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rank_cell.add_child(medal)
	else:
		var rank_label := Label.new()
		rank_label.text = str(rank)
		rank_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_override("font", FONT_BOLD)
		rank_label.add_theme_font_size_override("font_size", 20)
		rank_label.add_theme_color_override("font_color", COL_TEXT_SUB)
		rank_cell.add_child(rank_label)

	if not _showing_hall:
		row.add_child(_make_avatar())

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_override("font", FONT_BOLD)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", COL_TEXT_DARK)
	info.add_child(title_label)

	if not subtitle_text.is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle_text
		subtitle_label.clip_text = true
		subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", COL_TEXT_SUB)
		info.add_child(subtitle_label)

	if not score_text.is_empty():
		row.add_child(_make_score_box(score_text))

	return panel


func _make_avatar() -> Control:
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	face.texture = AVATAR_TEX
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return face


func _make_score_box(score_text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.custom_minimum_size.x = SCORE_WIDTH
	box.alignment = BoxContainer.ALIGNMENT_END

	var label := Label.new()
	label.text = score_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COL_SCORE)
	box.add_child(label)

	var trophy := TextureRect.new()
	trophy.custom_minimum_size = Vector2(24, 24)
	trophy.texture = TROPHY_TEX
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(trophy)
	return box


func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_stretch_ratio = 1.0
	btn.custom_minimum_size.y = 48
	btn.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	_apply_tab_style(btn, false)
	return btn


func _apply_tab_style(btn: Button, active: bool) -> void:
	var box := _make_card_style(COL_GREEN if active else COL_CREAM)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 12.0
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override(
		"font_color",
		Color(1, 1, 1, 1) if active else COL_TEXT_SUB
	)
	btn.add_theme_color_override(
		"font_outline_color",
		Color(0.25, 0.42, 0.1, 0.6) if active else Color(0, 0, 0, 0)
	)
	btn.add_theme_constant_override("outline_size", 3 if active else 0)


func _update_board_buttons() -> void:
	for board_id in _board_buttons:
		_apply_tab_style(_board_buttons[board_id], board_id == _active_board)


func _apply_owner_panel_style() -> void:
	var box := _make_card_style(COL_OWNER_TINT)
	box.content_margin_left = 12.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 12.0
	_owner_panel.add_theme_stylebox_override("panel", box)


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
