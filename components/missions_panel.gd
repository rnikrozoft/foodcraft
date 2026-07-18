@tool
extends Control

const CARD_TEX := preload("res://assets/labels/Label_Round01_White.png")
const SLOT_TEX := preload("res://assets/frames/custom/ItemFrame01_Single_Yellow.png")
const COIN_TEX := preload("res://assets/icons/misc/Icon_ImageIcon_Coin01_s.png")
const STAR_TEX := preload("res://assets/icons/misc/Icon_ImageIcon_Star01_s.png")
const FONT_BOLD := preload("res://assets/fonts/Kanit-Bold.ttf")

const TYPE_ICONS := {
	"craft": preload("res://assets/icons/item_icons/128/Icon_Potion02_Green.png"),
	"discover": preload("res://assets/icons/item_icons/128/Icon_Food_Meat.png"),
	"ingredient": preload("res://assets/icons/item_icons/128/Icon_Egg.png"),
}

# ── FoodCraft warm palette (shared with leaderboard/shop/my recipes) ──
const COL_CREAM      := Color(0.96, 0.92, 0.84)
const COL_CREAM_DIM  := Color(0.84, 0.8, 0.72)
const COL_GOLD       := Color(1.0, 0.78, 0.25)
const COL_GREEN      := Color(0.45, 0.68, 0.24)
const COL_TRACK      := Color(0.38, 0.31, 0.22)
const COL_TEXT_DARK  := Color(0.3, 0.23, 0.14)
const COL_TEXT_SUB   := Color(0.55, 0.48, 0.37)
const COL_SCORE      := Color(0.78, 0.55, 0.08)

@onready var _reset_label: Label = $Margin/VBox/ResetRow/ResetLabel
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var _status: Label = $Margin/VBox/StatusLabel
@onready var _summary: Label = $Margin/VBox/SummaryLabel

var _reset_sec: int = -1
var _tick_timer: Timer
var _claiming := false


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if Engine.is_editor_hint():
		return
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	NakamaService.connection_restored.connect(_on_connection_restored)


func prepare_panel() -> void:
	pass


func show_panel() -> void:
	visible = true
	_refresh()
	_tick_timer.start()


func hide_panel() -> void:
	visible = false
	_tick_timer.stop()


func _on_connection_restored() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if not NakamaService.is_online:
		_show_status("ออฟไลน์ — ไม่สามารถโหลดภารกิจได้")
		return
	_show_status("กำลังโหลด...")
	var data := await NakamaService.fetch_missions()
	if bool(data.get("rpc_error", false)) or data.is_empty():
		_show_status("โหลดไม่สำเร็จ — ลองใหม่อีกครั้ง")
		return
	_apply_data(data)


func _apply_data(data: Dictionary) -> void:
	_reset_sec = int(data.get("next_reset_sec", -1))
	_update_reset_label()
	var missions: Array = data.get("missions", [])
	if missions.is_empty():
		_show_status("ยังไม่มีภารกิจวันนี้")
		return
	_hide_status()
	_clear_list()
	var done := 0
	for mission in missions:
		if bool(mission.get("claimed", false)):
			done += 1
		_list.add_child(_make_mission_card(mission))
	_summary.text = "สำเร็จแล้ว %d/%d วันนี้" % [done, missions.size()]
	_summary.visible = true


func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()


func _show_status(message: String) -> void:
	_status.text = message
	_status.visible = true
	_scroll.visible = false
	_summary.visible = false


func _hide_status() -> void:
	_status.visible = false
	_scroll.visible = true


func _on_tick() -> void:
	if not visible or _reset_sec < 0:
		return
	_reset_sec -= 1
	if _reset_sec <= 0:
		_reset_sec = -1
		_refresh()
		return
	_update_reset_label()


func _update_reset_label() -> void:
	if _reset_sec < 0:
		_reset_label.text = "รีเซ็ตทุกเที่ยงคืน (UTC)"
		return
	var h := _reset_sec / 3600
	var m := (_reset_sec % 3600) / 60
	var s := _reset_sec % 60
	_reset_label.text = "รีเซ็ตใน %02d:%02d:%02d" % [h, m, s]


# ── Card builders ──

func _make_bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	return sb


func _make_card_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = CARD_TEX
	sb.modulate_color = tint
	sb.texture_margin_left = 20.0
	sb.texture_margin_top = 20.0
	sb.texture_margin_right = 20.0
	sb.texture_margin_bottom = 24.0
	return sb


func _make_mission_card(mission: Dictionary) -> PanelContainer:
	var claimed := bool(mission.get("claimed", false))
	var can_claim := bool(mission.get("can_claim", false))
	var target := maxi(1, int(mission.get("target", 1)))
	var progress := clampi(int(mission.get("progress", 0)), 0, target)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 108.0
	panel.add_theme_stylebox_override(
		"panel", _make_card_style(COL_CREAM_DIM if claimed else COL_CREAM)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# ── Icon slot ──
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)

	var slot_bg := TextureRect.new()
	slot_bg.texture = SLOT_TEX
	slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(slot_bg)

	var icon := TextureRect.new()
	icon.texture = TYPE_ICONS.get(String(mission.get("type", "")), COIN_TEX)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 11.0
	icon.offset_top = 10.0
	icon.offset_right = -11.0
	icon.offset_bottom = -13.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)

	# ── Middle: title, desc, progress ──
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var title := Label.new()
	title.text = String(mission.get("title", ""))
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_TEXT_DARK)
	info.add_child(title)

	var desc := Label.new()
	desc.text = String(mission.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", COL_TEXT_SUB)
	info.add_child(desc)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	info.add_child(bar_row)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(target)
	bar.value = float(progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _make_bar_style(COL_TRACK))
	bar.add_theme_stylebox_override("fill", _make_bar_style(COL_GREEN))
	bar_row.add_child(bar)

	var bar_label := Label.new()
	bar_label.text = "%d/%d" % [progress, target]
	bar_label.custom_minimum_size.x = 44.0
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_label.add_theme_font_override("font", FONT_BOLD)
	bar_label.add_theme_font_size_override("font_size", 13)
	bar_label.add_theme_color_override("font_color", COL_TEXT_SUB)
	bar_row.add_child(bar_label)

	# ── Right: reward + claim button ──
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	right.add_child(_make_reward_row(mission))
	right.add_child(_make_claim_button(mission, claimed, can_claim))
	return panel


func _make_reward_row(mission: Dictionary) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var coins := int(mission.get("reward_coins", 0))
	if coins > 0:
		box.add_child(_make_reward_chip(COIN_TEX, "+%d" % coins))
	var stars := int(mission.get("reward_stars", 0))
	if stars > 0:
		box.add_child(_make_reward_chip(STAR_TEX, "+%d" % stars))
	return box


func _make_reward_chip(tex: Texture2D, amount: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)

	var label := Label.new()
	label.text = amount
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COL_SCORE)
	chip.add_child(label)
	return chip


func _make_claim_button(mission: Dictionary, claimed: bool, can_claim: bool) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(112, 46)
	btn.add_theme_font_override("font", FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if claimed:
		btn.text = "รับแล้ว"
		btn.disabled = true
		_apply_button_color(btn, COL_GREEN, Color(1, 1, 1, 1))
	elif can_claim:
		btn.text = "รับรางวัล"
		_apply_button_color(btn, COL_GOLD, COL_TEXT_DARK)
		btn.pressed.connect(_on_claim_pressed.bind(String(mission.get("id", "")), btn))
	else:
		btn.text = "กำลังทำ"
		btn.disabled = true
		_apply_button_color(btn, COL_CREAM_DIM, COL_TEXT_SUB)
	return btn


func _apply_button_color(btn: Button, bg: Color, font_col: Color) -> void:
	var normal := _make_card_style(bg)
	var pressed := _make_card_style(bg.darkened(0.18))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_pressed_color", font_col)
	btn.add_theme_color_override("font_disabled_color", font_col)


func _on_claim_pressed(mission_id: String, btn: Button) -> void:
	if _claiming or mission_id.is_empty():
		return
	_claiming = true
	btn.disabled = true
	var data := await NakamaService.claim_mission(mission_id)
	_claiming = false
	if bool(data.get("rpc_error", false)):
		if not NakamaService.is_rate_limit_error(data):
			_show_status(NakamaService.format_rpc_error(data))
			await get_tree().create_timer(1.2).timeout
		_refresh()
		return
	AudioManager.play_pop()
	_apply_data(data)
