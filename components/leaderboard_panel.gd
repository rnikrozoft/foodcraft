extends Control

signal back_requested

@onready var _title: Label = $Margin/VBox/HeaderRow/TitleLabel
@onready var _fame_button: Button = $Margin/VBox/BoardTabs/FameButton
@onready var _explorer_button: Button = $Margin/VBox/BoardTabs/ExplorerButton
@onready var _rows: VBoxContainer = $Margin/VBox/Scroll/Rows
@onready var _owner_row: Label = $Margin/VBox/OwnerRow
@onready var _status: Label = $Margin/VBox/StatusLabel

var _active_board := NakamaConfig.BOARD_FAME


func _ready() -> void:
	_fame_button.pressed.connect(_on_fame_pressed)
	_explorer_button.pressed.connect(_on_explorer_pressed)
	NakamaService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	_set_board(NakamaConfig.BOARD_FAME)


func show_panel() -> void:
	visible = true
	_load_active_board()


func hide_panel() -> void:
	visible = false


func _on_fame_pressed() -> void:
	_set_board(NakamaConfig.BOARD_FAME)


func _on_explorer_pressed() -> void:
	_set_board(NakamaConfig.BOARD_EXPLORER)


func _set_board(board_id: String) -> void:
	_active_board = board_id
	_fame_button.disabled = board_id == NakamaConfig.BOARD_FAME
	_explorer_button.disabled = board_id == NakamaConfig.BOARD_EXPLORER
	_load_active_board()


func _load_active_board() -> void:
	_status.text = "กำลังโหลด..."
	_clear_rows()
	if not NakamaService.is_online:
		_status.text = "ออฟไลน์ — ไม่สามารถโหลดอันดับได้"
		_owner_row.text = ""
		return
	await NakamaService.fetch_leaderboard(_active_board)


func _on_leaderboard_loaded(data: Dictionary) -> void:
	if String(data.get("board_id", "")) != _active_board:
		return
	_title.text = String(data.get("title", "Leaderboard"))
	_clear_rows()

	var records: Array = data.get("records", [])
	if records.is_empty():
		_status.text = "ยังไม่มีข้อมูลอันดับ"
	else:
		_status.text = ""

	for record in records:
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 20)
		row.text = "#%d  %s  %s" % [
			int(record.get("rank", 0)),
			String(record.get("username", "???")),
			_format_score(int(record.get("score", 0)))
		]
		_rows.add_child(row)

	var owner: Dictionary = data.get("owner", {})
	if owner.is_empty():
		_owner_row.text = "อันดับของคุณ: -"
	else:
		_owner_row.text = "อันดับของคุณ: #%d  (%s)" % [
			int(owner.get("rank", 0)),
			_format_score(int(owner.get("score", 0)))
		]


func _format_score(score: int) -> String:
	if _active_board == NakamaConfig.BOARD_FAME:
		return "%d แต้ม" % score
	return "%d เมนู" % score


func _clear_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
