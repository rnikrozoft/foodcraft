extends Control

signal back_requested

const TIER_LABELS := {
	1: "หลัก",
	2: "สมรรถนะ",
	3: "หมวด",
	4: "หอเกียรติ",
	5: "ซีซัน",
}

@onready var _title: Label = $Margin/VBox/HeaderRow/TitleLabel
@onready var _tier_tabs: HBoxContainer = $Margin/VBox/TierTabs
@onready var _board_scroll: ScrollContainer = $Margin/VBox/BoardScroll
@onready var _board_tabs: HBoxContainer = $Margin/VBox/BoardScroll/BoardTabs
@onready var _desc: Label = $Margin/VBox/DescLabel
@onready var _rows: VBoxContainer = $Margin/VBox/Scroll/Rows
@onready var _owner_row: Label = $Margin/VBox/OwnerRow
@onready var _status: Label = $Margin/VBox/StatusLabel

var _boards: Array = []
var _active_tier := 1
var _active_board := ""
var _tier_buttons: Dictionary = {}
var _board_buttons: Dictionary = {}
var _showing_hall := false


func _ready() -> void:
	NakamaService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	NakamaService.leaderboards_loaded.connect(_on_boards_loaded)
	NakamaService.hall_of_fame_loaded.connect(_on_hall_of_fame_loaded)
	_build_tier_tabs()


func show_panel() -> void:
	visible = true
	if not NakamaService.is_online:
		_status.text = "ออฟไลน์ — ไม่สามารถโหลดอันดับได้"
		_owner_row.text = ""
		_clear_rows()
		return
	if _boards.is_empty():
		_status.text = "กำลังโหลด..."
		await NakamaService.fetch_leaderboard_list()
	else:
		_refresh_tier_view()


func hide_panel() -> void:
	visible = false


func _build_tier_tabs() -> void:
	for child in _tier_tabs.get_children():
		child.queue_free()
	_tier_buttons.clear()
	for tier in [1, 2, 3, 4, 5]:
		var btn := Button.new()
		btn.text = TIER_LABELS[tier]
		btn.pressed.connect(_on_tier_pressed.bind(tier))
		_tier_tabs.add_child(btn)
		_tier_buttons[tier] = btn


func _on_tier_pressed(tier: int) -> void:
	_active_tier = tier
	_refresh_tier_view()


func _refresh_tier_view() -> void:
	_showing_hall = _active_tier == 4
	_board_scroll.visible = not _showing_hall
	_update_tier_buttons()
	_clear_rows()
	_owner_row.text = ""

	if _showing_hall:
		_title.text = "หอเกียรติยศ"
		_desc.text = "ผู้ค้นพบเมนูก่อนใครของเซิร์ฟเวอร์"
		_status.text = "กำลังโหลด..."
		var hall_data := await NakamaService.fetch_hall_of_fame()
		_apply_hall_of_fame(hall_data)
		return

	_rebuild_board_tabs()
	var tier_boards := _boards_for_tier(_active_tier)
	if tier_boards.is_empty():
		_desc.text = ""
		_status.text = "ยังไม่มีกระดานในกลุ่มนี้"
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
		var btn := Button.new()
		btn.text = String(board.get("title", board_id))
		btn.pressed.connect(_on_board_pressed.bind(board_id))
		_board_tabs.add_child(btn)
		_board_buttons[board_id] = btn


func _on_board_pressed(board_id: String) -> void:
	_set_board(board_id)


func _set_board(board_id: String) -> void:
	_active_board = board_id
	for id in _board_buttons:
		_board_buttons[id].disabled = id == board_id
	var board := _board_meta(board_id)
	_title.text = String(board.get("title", "อันดับ"))
	_desc.text = String(board.get("description", ""))
	_load_active_board()


func _board_meta(board_id: String) -> Dictionary:
	for board in _boards:
		if String(board.get("id", "")) == board_id:
			return board
	return {}


func _load_active_board() -> void:
	_status.text = "กำลังโหลด..."
	_clear_rows()
	_owner_row.text = ""
	var data := await NakamaService.fetch_leaderboard(_active_board)
	if not data.is_empty():
		_apply_leaderboard(data)


func _on_boards_loaded(boards: Array) -> void:
	_boards = boards
	if visible:
		_refresh_tier_view()


func _on_leaderboard_loaded(data: Dictionary) -> void:
	if _showing_hall or String(data.get("board_id", "")) != _active_board:
		return
	_apply_leaderboard(data)


func _on_hall_of_fame_loaded(data: Dictionary) -> void:
	if not _showing_hall:
		return
	_apply_hall_of_fame(data)


func _apply_leaderboard(data: Dictionary) -> void:
	if data.is_empty():
		_status.text = "โหลดไม่สำเร็จ — ลองใหม่อีกครั้ง"
		return
	_title.text = String(data.get("title", _title.text))
	_desc.text = String(data.get("description", _desc.text))
	_clear_rows()

	var records: Array = data.get("records", [])
	if records.is_empty():
		_status.text = "ยังไม่มีข้อมูลอันดับ"
	else:
		_status.text = ""

	var score_unit := String(data.get("score_unit", ""))
	var board_id := String(data.get("board_id", _active_board))
	for record in records:
		_rows.add_child(_make_rank_row(record, board_id, score_unit))

	var owner_data: Dictionary = data.get("owner", {})
	if owner_data.is_empty():
		_owner_row.text = "อันดับของคุณ: -"
	else:
		_owner_row.text = "อันดับของคุณ: #%d  (%s)" % [
			int(owner_data.get("rank", 0)),
			_format_score(int(owner_data.get("score", 0)), board_id, score_unit)
		]


func _apply_hall_of_fame(data: Dictionary) -> void:
	if not _showing_hall:
		return
	_clear_rows()
	if data.is_empty():
		_status.text = "โหลดไม่สำเร็จ — รีสตาร์ทเซิร์ฟเวอร์ (make build && make run)"
		return
	var entries: Array = data.get("entries", [])
	if entries.is_empty():
		_status.text = "ยังไม่มีผู้ค้นพบคนแรก"
		return
	_status.text = ""
	for entry in entries:
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 18)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s %s — %s" % [
			String(entry.get("emoji", "🍽")),
			String(entry.get("item_name", entry.get("item_id", "?"))),
			String(entry.get("username", "???"))
		]
		_rows.add_child(row)


func _make_rank_row(record: Dictionary, board_id: String, score_unit: String) -> Label:
	var row := Label.new()
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_font_size_override("font_size", 20)
	row.text = "#%d  %s  %s" % [
		int(record.get("rank", 0)),
		String(record.get("username", "???")),
		_format_score(int(record.get("score", 0)), board_id, score_unit)
	]
	return row


func _format_score(score: int, board_id: String, score_unit: String) -> String:
	if score <= 0 and board_id.begins_with("speed_runner"):
		return "ยังไม่ถึง"
	if board_id == "efficiency" or board_id == "season_efficiency":
		var pct := float(score) / 100.0
		return "%.1f%%" % pct
	if board_id.begins_with("speed_runner") and score > 0:
		var reached: int = NakamaConfig.SPEED_SCORE_BASE - score
		return Time.get_datetime_string_from_unix_time(reached, true)
	if not score_unit.is_empty():
		return "%d %s" % [score, score_unit]
	return str(score)


func _update_tier_buttons() -> void:
	for tier in _tier_buttons:
		_tier_buttons[tier].disabled = tier == _active_tier


func _clear_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
