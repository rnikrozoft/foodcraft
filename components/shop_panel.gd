extends Control
class_name ShopPanel

signal purchase_completed
signal purchase_celebrated(display: Dictionary, origin: Vector2, show_full: bool)

enum Tab { GENERAL, INGREDIENTS }

const TAB_META := {
	Tab.GENERAL: {"title": "ทั่วไป", "icon": "🛒", "subtitle": "เหรียญ ดาว และข้อเสนอพิเศษ"},
	Tab.INGREDIENTS: {"title": "วัตถุดิบ", "icon": "🥬", "subtitle": "ปลดล็อกวัตถุดิบหลากระดับ"},
}

const COIN_PACKS := [
	{"coins": 500, "price": "฿29", "bonus": ""},
	{"coins": 1200, "price": "฿59", "bonus": "+20%"},
	{"coins": 3000, "price": "฿129", "bonus": "ยอดนิยม"},
	{"coins": 8000, "price": "฿299", "bonus": "คุ้มสุด"},
	{"coins": 20000, "price": "฿599", "bonus": "มหาศาล"},
	{"coins": 50000, "price": "฿1290", "bonus": "VIP"},
]

const HINT_PACKS := [
	{"stars": 5, "price": "฿35", "bonus": ""},
	{"stars": 15, "price": "฿89", "bonus": "+3 ฟรี"},
	{"stars": 40, "price": "฿199", "bonus": "ยอดนิยม"},
	{"stars": 100, "price": "฿449", "bonus": "คุ้มสุด"},
]

const RARITY_COLORS := {
	"common": Color(0.52, 0.68, 0.42, 1),
	"uncommon": Color(0.34, 0.58, 0.86, 1),
	"rare": Color(0.58, 0.38, 0.86, 1),
	"epic": Color(0.9, 0.52, 0.18, 1),
	"legendary": Color(0.95, 0.76, 0.18, 1),
}

const COIN_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/coin.png")
const STAR_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/rataing star.png")
const BTN_GREEN := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/green.png")
const BTN_YELLOW := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/yellow.png")
const BTN_PURPLE := preload("res://assets/Hyper_Casual_UI/Sprites/Buttons/empty_buttons/PURPLE.png")
const TREASURE_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/Gold Treasure box.png")
const LOCK_TEX := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/lock.png")

const GRID_COLS_COINS := 2
const GRID_COLS_HINTS := 2
const CARD_ICON_BASE := 64.0
const SECTION_CARD_HEIGHT := 150.0
const TAB_HEIGHT := 46.0

@onready var _subtitle: Label = $Margin/VBox/HeaderPanel/HeaderVBox/SubtitleLabel
@onready var _tab_row: HBoxContainer = $Margin/VBox/TabRow
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _content: VBoxContainer = $Margin/VBox/Scroll/Content
@onready var _status: Label = $Margin/VBox/StatusLabel

var _active_tab := Tab.GENERAL
var _tab_buttons: Array = []
var _cooldown_timer: Timer
var _pending_burst_origin := Vector2.ZERO
var _daily_reward_status: Dictionary = {
	"can_claim": true,
	"coins": 0,
	"next_claim_sec": 0,
}


func _iap_billing_enabled() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.resized.connect(_on_scroll_resized)
	_build_tabs()
	GameData.wallet_changed.connect(_on_wallet_changed)
	GameData.progress_changed.connect(_on_progress_changed)
	GameData.shop_config_changed.connect(_on_shop_config_changed)
	NakamaService.connection_restored.connect(_on_connection_restored)
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.timeout.connect(_on_cooldown_tick)
	add_child(_cooldown_timer)


func _on_scroll_resized() -> void:
	if _active_tab == Tab.GENERAL:
		call_deferred("_apply_section_grid_heights")


func _ui_scale() -> float:
	return clampf(get_viewport_rect().size.x / 390.0, 0.88, 1.12)


func _s(value: float) -> float:
	return value * _ui_scale()


func get_active_tab() -> Tab:
	return _active_tab


func prepare_panel(tab: Tab = Tab.GENERAL) -> void:
	show_tab(tab)


func show_panel(tab: Tab = Tab.GENERAL) -> void:
	prepare_panel(tab)
	visible = true
	if tab == Tab.INGREDIENTS:
		_sync_shop_from_server()


func hide_panel() -> void:
	visible = false
	_cooldown_timer.stop()
	show_tab(Tab.GENERAL)


func show_tab(tab: Tab) -> void:
	_active_tab = tab
	_update_tab_buttons()
	if tab == Tab.GENERAL:
		_prepare_general_tab_async()
	elif visible:
		call_deferred("_refresh")
	else:
		_rebuild_content()


func _prepare_general_tab_async() -> void:
	await _refresh_daily_reward_status()
	if _active_tab != Tab.GENERAL:
		return
	if visible:
		_rebuild_content()
	else:
		_rebuild_content()


func _refresh_daily_reward_status() -> void:
	var data := await NakamaService.fetch_daily_reward_status()
	if not bool(data.get("rpc_error", false)) and not data.is_empty():
		_daily_reward_status = data


func _build_tabs() -> void:
	for child in _tab_row.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for tab in [Tab.GENERAL, Tab.INGREDIENTS]:
		var meta: Dictionary = TAB_META[tab]
		var btn := _make_tab_button(String(meta.get("title", "")), String(meta.get("icon", "")))
		btn.pressed.connect(_on_tab_pressed.bind(tab))
		_tab_row.add_child(btn)
		_tab_buttons.append({"tab": tab, "button": btn})


func _on_tab_pressed(tab: Tab) -> void:
	show_tab(tab)


func _update_tab_buttons() -> void:
	for entry in _tab_buttons:
		_apply_tab_style(entry["button"], entry["tab"] == _active_tab)


func _refresh() -> void:
	call_deferred("_rebuild_content")


func _rebuild_content() -> void:
	if not is_inside_tree():
		return
	var meta: Dictionary = TAB_META.get(_active_tab, {})
	_subtitle.text = String(meta.get("subtitle", ""))
	for child in _content.get_children():
		child.free()
	match _active_tab:
		Tab.GENERAL:
			_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			_build_general_tab()
			_cooldown_timer.start()
		Tab.INGREDIENTS:
			_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			_build_ingredient_tab()
			_cooldown_timer.start()
	_clear_status()
	call_deferred("_apply_section_grid_heights")


func _build_general_tab() -> void:
	_content.add_child(_make_section_header("พิเศษ"))
	_content.add_child(_make_remove_ads_banner())
	var special_grid := _make_product_grid(GRID_COLS_HINTS)
	var can_claim := bool(_daily_reward_status.get("can_claim", true))
	var coins := int(_daily_reward_status.get("coins", GameData.get_daily_reward_coins()))
	var next_sec := int(_daily_reward_status.get("next_claim_sec", 0))
	var daily_desc := "รับ %d เหรียญฟรีทุกวัน" % coins
	var daily_btn := "รับฟรี"
	if not can_claim:
		daily_btn = "รับแล้ว"
		if next_sec > 0:
			daily_desc = "รับแล้ว — รอบถัดไปใน %s" % _format_duration(next_sec)
		else:
			daily_desc = "รับเหรียญรายวันแล้ววันนี้"
	special_grid.add_child(_make_special_card(
		"เหรียญรายวัน",
		daily_desc,
		"🎁",
		daily_btn,
		BTN_GREEN,
		_on_daily_coins_pressed,
		can_claim,
		not can_claim
	))
	special_grid.add_child(_make_special_card(
		"ดูโฆษณา",
		"รับ %d เหรียญจากโฆษณา" % GameData.get_ad_reward_coins(),
		"📺",
		"ดูโฆษณา",
		BTN_YELLOW,
		_on_watch_ad_pressed
	))
	_content.add_child(special_grid)

	_content.add_child(_make_feature_banner(
		"แพ็กเริ่มต้น",
		"%d เหรียญ + วัตถุดิบหายาก 1 ชิ้น" % GameData.get_starter_pack_coins(),
		"฿49",
		BTN_PURPLE,
		_on_starter_pack_pressed
	))

	_content.add_child(_make_section_header("เหรียญเงิน"))
	var coin_grid := _make_product_grid(GRID_COLS_COINS)
	for pack in COIN_PACKS:
		coin_grid.add_child(_make_coin_card(pack))
	_content.add_child(coin_grid)

	_content.add_child(_make_section_header("แพ็กดาว"))
	_content.add_child(_make_info_banner(
		"Hint (ดาว) ซื้อได้ด้วยเงินจริงเท่านั้น",
		"ใช้ดาวเพื่อเปิดเบาะแสสูตรลับระหว่างทดลองผสม"
	))
	var hint_grid := _make_product_grid(GRID_COLS_HINTS)
	for pack in HINT_PACKS:
		hint_grid.add_child(_make_hint_card(pack))
	_content.add_child(hint_grid)


func _build_ingredient_tab() -> void:
	_content.add_child(_make_shop_auto_banner())
	_content.add_child(_make_section_header("ปลดล็อกวัตถุดิบด้วยเหรียญ"))
	var offers := GameData.get_shop_ingredient_offers()
	var current_rarity := ""
	for offer in offers:
		var rarity := String(offer.get("rarity", "common"))
		if rarity != current_rarity:
			current_rarity = rarity
			_content.add_child(_make_rarity_header(
				String(offer.get("rarity_label", rarity)),
				RARITY_COLORS.get(rarity, Color.WHITE)
			))
		_content.add_child(_make_ingredient_row(offer))


func _make_shop_auto_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.28, 0.38, 0.52, 1)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var title := Label.new()
	title.text = "ร้านวัตถุดิบรายวัน"
	title.add_theme_font_size_override("font_size", int(_s(17)))
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	col.add_child(title)

	var desc := Label.new()
	desc.text = "สุ่มวัตถุดิบที่ยังไม่มีมาขาย — ร้านเปลี่ยนสินค้าอัตโนมัติทุกเที่ยงคืน (UTC)"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", int(_s(12)))
	desc.add_theme_color_override("font_color", Color(0.9, 0.94, 1, 1))
	col.add_child(desc)

	var timer := _make_countdown_label(GameData.get_next_shop_reset_sec(), "shop_reset")
	timer.autowrap_mode = TextServer.AUTOWRAP_WORD
	timer.add_theme_font_size_override("font_size", int(_s(13)))
	timer.add_theme_color_override("font_color", Color(0.75, 0.9, 1, 1))
	col.add_child(timer)

	return panel


func _apply_section_grid_heights() -> void:
	if _active_tab != Tab.GENERAL or not is_visible():
		return
	var card_h := _s(SECTION_CARD_HEIGHT)
	for child in _content.get_children():
		if child is GridContainer:
			for card in child.get_children():
				if card is PanelContainer:
					_apply_card_height(card as PanelContainer, card_h)


func _apply_card_height(panel: PanelContainer, card_h: float) -> void:
	panel.custom_minimum_size.y = card_h
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := panel.get_child(0) as MarginContainer
	if margin == null:
		return
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := margin.get_child(0) as VBoxContainer
	if body == null:
		return
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child in body.get_children():
		if child.has_meta("shop_badge"):
			var badge := child as Label
			badge.add_theme_font_size_override("font_size", int(clampf(card_h * 0.1, 12, 16)))
		elif child is CenterContainer:
			child.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var icon := _find_texture_rect(child)
			if icon:
				var sz := clampf(card_h * 0.34, 56.0, 108.0)
				icon.custom_minimum_size = Vector2(sz, sz)
		elif child.has_meta("shop_amount"):
			var amount := child as Label
			amount.add_theme_font_size_override("font_size", int(clampf(card_h * 0.15, 18, 30)))
		elif child is Button:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.custom_minimum_size.y = clampf(card_h * 0.2, 40.0, 54.0)
			child.add_theme_font_size_override("font_size", int(clampf(card_h * 0.11, 14, 20)))


func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node
	for child in node.get_children():
		var found := _find_texture_rect(child)
		if found:
			return found
	return null


func _make_feature_banner(
	title: String,
	desc: String,
	price: String,
	btn_tex: Texture2D,
	callback: Callable
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.42, 0.28, 0.62, 1)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(_s(52), _s(52))
	icon.texture = TREASURE_TEX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", int(_s(17)))
	title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	info.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", int(_s(12)))
	desc_label.add_theme_color_override("font_color", Color(0.92, 0.86, 1, 1))
	info.add_child(desc_label)

	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_child(_make_price_button(price, btn_tex, callback, true))
	row.add_child(btn_col)
	return panel


func _make_remove_ads_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	if GameData.is_ads_removed():
		panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.22, 0.48, 0.34, 1)))
	else:
		panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.55, 0.22, 0.28, 1)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "ลบโฆษณา Google"
	title.add_theme_font_size_override("font_size", int(_s(18)))
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	col.add_child(title)

	var desc := Label.new()
	if GameData.is_ads_removed():
		desc.text = "✓ คุณปิดโฆษณาแล้ว — เล่นได้อย่างราบรื่น"
	else:
		desc.text = "ซื้อครั้งเดียว ลบโฆษณาทุกจุดในเกมถาวร"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", int(_s(12)))
	desc.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 1))
	col.add_child(desc)

	if not GameData.is_ads_removed():
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		col.add_child(btn_row)
		btn_row.add_child(_make_price_button("฿149", BTN_YELLOW, _on_remove_ads_pressed, true))

	return panel


func _make_info_banner(title: String, desc: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.2, 0.36, 0.52, 1)))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", int(_s(15)))
	title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.55, 1))
	col.add_child(title_label)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", int(_s(12)))
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.94, 1, 1))
	col.add_child(desc_label)
	return panel


func _make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = "— %s —" % text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(_s(13)))
	label.add_theme_color_override("font_color", Color(0.72, 0.58, 0.38, 1))
	return label


func _make_rarity_header(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.22)
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(_s(14)))
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return panel


func _make_product_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(_s(8)))
	grid.add_theme_constant_override("v_separation", int(_s(8)))
	return grid


func _make_coin_card(pack: Dictionary) -> PanelContainer:
	var coins := int(pack.get("coins", 0))
	var bonus := String(pack.get("bonus", ""))
	var card := _make_product_card()
	var panel: PanelContainer = card["panel"]
	var body: VBoxContainer = card["body"]

	if not bonus.is_empty():
		var badge := Label.new()
		badge.set_meta("shop_badge", true)
		badge.text = bonus
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color(0.85, 0.35, 0.2, 1))
		body.add_child(badge)

	body.add_child(_make_card_icon_block(COIN_TEX, _coin_icon_scale(coins)))
	var amount := Label.new()
	amount.set_meta("shop_amount", true)
	amount.text = _format_number(coins)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))
	body.add_child(amount)

	var price := String(pack.get("price", ""))
	body.add_child(_make_price_button(price, BTN_GREEN, _on_coin_pack_pressed.bind(coins), true))
	return panel


func _make_hint_card(pack: Dictionary) -> PanelContainer:
	var stars := int(pack.get("stars", 0))
	var bonus := String(pack.get("bonus", ""))
	var card := _make_product_card()
	var panel: PanelContainer = card["panel"]
	var body: VBoxContainer = card["body"]

	if not bonus.is_empty():
		var badge := Label.new()
		badge.set_meta("shop_badge", true)
		badge.text = bonus
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color(0.75, 0.45, 0.1, 1))
		body.add_child(badge)

	body.add_child(_make_card_icon_block(STAR_TEX, 1.0))
	var amount := Label.new()
	amount.set_meta("shop_amount", true)
	amount.text = "%d ดาว" % stars
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))
	body.add_child(amount)

	var price := String(pack.get("price", ""))
	body.add_child(_make_price_button(price, BTN_YELLOW, _on_hint_pack_pressed.bind(stars), true))
	return panel


func _make_special_card(
	title: String,
	desc: String,
	emoji: String,
	price: String,
	btn_tex: Texture2D,
	callback: Callable,
	enabled: bool = true,
	countdown_desc: bool = false
) -> PanelContainer:
	var card := _make_product_card()
	var panel: PanelContainer = card["panel"]
	var body: VBoxContainer = card["body"]
	var emoji_label := Label.new()
	emoji_label.set_meta("shop_amount", true)
	emoji_label.text = emoji
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(emoji_label)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", int(_s(15)))
	body.add_child(title_label)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", int(_s(12)))
	desc_label.add_theme_color_override("font_color", Color(0.48, 0.36, 0.26, 1))
	if countdown_desc:
		desc_label.set_meta("daily_reward_countdown", true)
	body.add_child(desc_label)
	var btn := _make_price_button(price, btn_tex, callback, true)
	btn.disabled = not enabled
	body.add_child(btn)
	return panel


func _make_ingredient_row(offer: Dictionary) -> PanelContainer:
	var unlocked := bool(offer.get("unlocked", false))
	var buyable := bool(offer.get("buyable", false))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_card_style(unlocked or not buyable))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var emoji_box := PanelContainer.new()
	emoji_box.custom_minimum_size = Vector2(_s(48), _s(48))
	var rarity := String(offer.get("rarity", "common"))
	emoji_box.add_theme_stylebox_override("panel", _make_icon_box_style(RARITY_COLORS.get(rarity, Color.WHITE)))
	var emoji_center := CenterContainer.new()
	emoji_box.add_child(emoji_center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(_s(36), _s(36))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	FoodIcons.apply_to(icon, String(offer.get("id", "")))
	emoji_center.add_child(icon)
	row.add_child(emoji_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var title := Label.new()
	title.text = String(offer.get("title", ""))
	title.add_theme_font_size_override("font_size", int(_s(16)))
	title.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06, 1))
	info.add_child(title)

	var rarity_label := Label.new()
	rarity_label.text = String(offer.get("rarity_label", ""))
	rarity_label.add_theme_font_size_override("font_size", int(_s(12)))
	rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	info.add_child(rarity_label)

	if unlocked:
		var owned := Label.new()
		owned.text = "ปลดล็อกแล้ว ✓"
		owned.add_theme_font_size_override("font_size", 14)
		owned.add_theme_color_override("font_color", Color(0.22, 0.52, 0.3, 1))
		row.add_child(owned)
	elif buyable:
		var cost := int(offer.get("cost", 0))
		var id := String(offer.get("id", ""))
		row.add_child(_make_coin_price_button(cost, _on_ingredient_pressed.bind(id, cost), true))
	else:
		var unavailable := Label.new()
		unavailable.text = "ไม่พร้อมขาย"
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unavailable.add_theme_font_size_override("font_size", int(_s(12)))
		unavailable.add_theme_color_override("font_color", Color(0.55, 0.42, 0.32, 1))
		row.add_child(unavailable)

	return panel


func _make_product_card() -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_card_style(false))
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", int(_s(6)))
	margin.add_child(body)
	return {"panel": panel, "body": body}


func _make_card_icon_block(texture: Texture2D, scale_factor: float) -> CenterContainer:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	var base := _s(CARD_ICON_BASE) * scale_factor
	icon.custom_minimum_size = Vector2(base, base)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(icon)
	return center


func _make_price_button(text: String, texture: Texture2D, callback: Callable, celebrate := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", _make_action_button_style(texture, false))
	btn.add_theme_stylebox_override("hover", _make_action_button_style(texture, true))
	btn.add_theme_stylebox_override("pressed", _make_action_button_style(texture, true))
	btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1))
	if celebrate:
		_connect_purchase_button(btn, callback)
	else:
		btn.pressed.connect(callback)
	return btn


func _make_action_button_style(texture: Texture2D, pressed: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 12
	style.texture_margin_top = 8
	style.texture_margin_right = 12
	style.texture_margin_bottom = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.modulate_color = Color(0.92, 0.92, 0.92, 1) if pressed else Color.WHITE
	return style


func _make_coin_price_button(cost: int, callback: Callable, celebrate := false) -> Button:
	var btn := Button.new()
	btn.text = "🪙 %s" % _format_number(cost)
	btn.custom_minimum_size = Vector2(_s(96), _s(36))
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", int(_s(14)))
	btn.add_theme_stylebox_override("normal", _make_card_style(false))
	btn.add_theme_stylebox_override("hover", _make_card_style(false))
	btn.add_theme_stylebox_override("pressed", _make_card_style(true))
	btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06, 1))
	if GameData.get_coins() < cost:
		btn.add_theme_color_override("font_color", Color(0.55, 0.4, 0.3, 1))
		btn.text = "🔒 %s" % _format_number(cost)
	if celebrate:
		_connect_purchase_button(btn, callback)
	else:
		btn.pressed.connect(callback)
	return btn


func _connect_purchase_button(btn: Button, callback: Callable) -> void:
	btn.pressed.connect(func() -> void:
		_pending_burst_origin = btn.get_global_rect().get_center()
		callback.call()
	)


func _play_purchase_burst(display: Dictionary = {}) -> void:
	if _pending_burst_origin == Vector2.ZERO:
		return
	purchase_celebrated.emit(display, _pending_burst_origin, not display.is_empty())


func _make_tab_button(text: String, icon_text: String) -> Button:
	var btn := Button.new()
	btn.text = "%s %s" % [icon_text, text]
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = _s(TAB_HEIGHT)
	btn.add_theme_font_size_override("font_size", int(_s(10)))
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_tab_style(btn, false)
	return btn


func _apply_tab_style(btn: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.content_margin_left = 2
	box.content_margin_right = 2
	if active:
		box.bg_color = Color(0.98, 0.86, 0.42, 1)
		box.border_color = Color(0.82, 0.62, 0.18, 1)
	else:
		box.bg_color = Color(0.88, 0.8, 0.68, 1)
		box.border_color = Color(0.68, 0.54, 0.34, 0.55)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_color_override(
		"font_color",
		Color(0.24, 0.14, 0.08, 1) if active else Color(0.45, 0.34, 0.24, 1)
	)


func _make_banner_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(1, 1, 1, 0.15)
	return box


func _make_card_style(dimmed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.97, 0.93, 0.86, 0.85 if dimmed else 1)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.72, 0.58, 0.38, 0.55)
	return box


func _make_icon_box_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.98, 0.92, 0.8, 1)
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(color.r, color.g, color.b, 0.75)
	return box


func _coin_icon_scale(coins: int) -> float:
	if coins >= 20000:
		return 1.18
	if coins >= 8000:
		return 1.12
	if coins >= 3000:
		return 1.06
	if coins >= 1200:
		return 1.0
	return 0.94


func _format_number(value: int) -> String:
	var text := str(value)
	if text.length() <= 3:
		return text
	var parts: PackedStringArray = []
	while text.length() > 3:
		parts.insert(0, text.substr(text.length() - 3, 3))
		text = text.substr(0, text.length() - 3)
	if not text.is_empty():
		parts.insert(0, text)
	return ",".join(parts)


func _format_duration(total_sec: int) -> String:
	var sec := maxi(0, total_sec)
	if sec >= 86400:
		var days := sec / 86400
		var hours := (sec % 86400) / 3600
		if hours > 0:
			return "%d วัน %d ชม." % [days, hours]
		return "%d วัน" % days
	if sec >= 3600:
		return "%d ชม. %d นาที" % [sec / 3600, (sec % 3600) / 60]
	if sec >= 60:
		return "%d นาที %d วิ" % [sec / 60, sec % 60]
	return "%d วิ" % sec


func _make_countdown_label(initial_sec: int, kind: String, target_id: String = "") -> Label:
	var label := Label.new()
	label.set_meta("shop_countdown", true)
	label.set_meta("countdown_kind", kind)
	label.set_meta("countdown_target", target_id)
	label.text = _countdown_text(kind, initial_sec)
	return label


func _countdown_text(kind: String, sec: int) -> String:
	var duration := _format_duration(sec)
	match kind:
		"shop_reset":
			if sec <= 0:
				return "กำลังเปลี่ยนสินค้า..."
			return "ร้านเปลี่ยนสินค้าใน %s" % duration
	return duration


func _update_countdown_labels() -> bool:
	return _update_countdown_labels_in(_content)


func _update_countdown_labels_in(node: Node) -> bool:
	var needs_refresh := false
	if node is Label and node.has_meta("shop_countdown"):
		var kind := String(node.get_meta("countdown_kind", ""))
		var target := String(node.get_meta("countdown_target", ""))
		var sec := GameData.get_shop_timer_sec(kind, target)
		node.text = _countdown_text(kind, sec)
		if sec <= 0 and kind == "shop_reset":
			needs_refresh = true
	for child in node.get_children():
		if _update_countdown_labels_in(child):
			needs_refresh = true
	return needs_refresh


func _sync_shop_from_server() -> void:
	await NakamaService.sync_wallet()
	await NakamaService.fetch_shop_state()
	if visible and _active_tab == Tab.INGREDIENTS:
		_refresh()


func _on_coin_pack_pressed(coins: int) -> void:
	var on_success := func() -> void:
		_play_purchase_burst()
		_show_status("ได้รับ %s เหรียญแล้ว!" % _format_number(coins))
		purchase_completed.emit()
	_simulate_iap("ซื้อ %s เหรียญ" % _format_number(coins), on_success, coins, 0)


func _on_hint_pack_pressed(stars: int) -> void:
	var on_success := func() -> void:
		_play_purchase_burst()
		_show_status("ได้รับ %d ดาวแล้ว!" % stars)
		purchase_completed.emit()
	_simulate_iap("ซื้อ %d ดาว" % stars, on_success, 0, stars)


func _on_ingredient_pressed(id: String, _cost: int) -> void:
	if GameData.is_ingredient_unlocked(id):
		_show_status("ปลดล็อกวัตถุดิบนี้แล้ว")
		return
	_purchase_ingredient_online(id)


func _purchase_ingredient_online(id: String) -> void:
	var data := await NakamaService.purchase_shop_ingredient(id)
	if bool(data.get("rpc_error", false)):
		if NakamaService.is_rate_limit_error(data):
			return
		_show_status(NakamaService.format_rpc_error(data))
		return
	if data.is_empty():
		_show_status("ซื้อไม่สำเร็จ — ลองใหม่อีกครั้ง")
		return
	var display := GameData.to_display_dict(id)
	_play_purchase_burst(display)
	_show_status("ปลดล็อก %s แล้ว!" % display.get("title", id))
	purchase_completed.emit()
	_refresh()


func _on_cooldown_tick() -> void:
	if not visible:
		return
	if _active_tab == Tab.GENERAL:
		var next_sec := int(_daily_reward_status.get("next_claim_sec", 0))
		if next_sec > 0:
			_daily_reward_status["next_claim_sec"] = next_sec - 1
		_update_daily_reward_countdown_labels()
		if next_sec <= 1 and not bool(_daily_reward_status.get("can_claim", false)):
			await _refresh_daily_reward_status()
			_refresh()
		return
	if _active_tab != Tab.INGREDIENTS:
		return
	if _update_countdown_labels():
		await _sync_shop_from_server()
		_refresh()


func _update_daily_reward_countdown_labels() -> void:
	_update_daily_reward_countdown_labels_in(_content)


func _update_daily_reward_countdown_labels_in(node: Node) -> void:
	if node is Label and node.has_meta("daily_reward_countdown"):
		var next_sec := int(_daily_reward_status.get("next_claim_sec", 0))
		var coins := int(_daily_reward_status.get("coins", GameData.get_daily_reward_coins()))
		if next_sec > 0:
			node.text = "รับแล้ว — รอบถัดไปใน %s" % _format_duration(next_sec)
		else:
			node.text = "รับ %d เหรียญฟรีทุกวัน" % coins
	for child in node.get_children():
		_update_daily_reward_countdown_labels_in(child)


func _on_remove_ads_pressed() -> void:
	if GameData.is_ads_removed():
		_show_status("ปิดโฆษณาแล้ว")
		return
	_simulate_iap("ลบโฆษณา", func() -> void:
		GameData.set_ads_removed(true)
		_play_purchase_burst()
		_show_status("ลบโฆษณาเรียบร้อย — ขอบคุณที่สนับสนุน!")
		purchase_completed.emit()
		_refresh()
	)


func _on_starter_pack_pressed() -> void:
	var on_success := func() -> void:
		_show_status("ได้รับแพ็กเริ่มต้นแล้ว!")
		_play_purchase_burst()
		purchase_completed.emit()
		_refresh()
	_simulate_iap("แพ็กเริ่มต้น", on_success, GameData.get_starter_pack_coins(), 0)


func _on_daily_coins_pressed() -> void:
	if not bool(_daily_reward_status.get("can_claim", true)):
		_show_status("รับเหรียญรายวันแล้ว — กลับมาพรุ่งนี้นะ")
		return
	var data := await NakamaService.claim_daily_reward()
	if bool(data.get("rpc_error", false)):
		if NakamaService.is_rate_limit_error(data):
			return
		_show_status(NakamaService.format_rpc_error(data))
		_refresh()
		return
	var received := int(data.get("coins_received", 0))
	if received <= 0:
		_daily_reward_status = data
		_show_status("รับเหรียญรายวันแล้ว — กลับมาพรุ่งนี้นะ")
		_refresh()
		return
	_daily_reward_status = data
	_play_purchase_burst()
	_show_status("ได้รับ %d เหรียญรายวัน!" % received)
	purchase_completed.emit()
	_refresh()


func _on_watch_ad_pressed() -> void:
	if GameData.is_ads_removed():
		var on_success := func() -> void:
			_play_purchase_burst()
			_show_status("ได้รับ %d เหรียญ!" % GameData.get_ad_reward_coins())
			purchase_completed.emit()
		_simulate_iap("ดูโฆษณา", on_success, GameData.get_ad_reward_coins(), 0)
		return
	_show_status("โฆษณาจะแสดงที่นี่ (ยังไม่เชื่อม AdMob)")


func _simulate_iap(label: String, _on_success: Callable, _coins_delta: int = 0, _stars_delta: int = 0) -> void:
	if not _iap_billing_enabled():
		_show_status("รีเซ็ตนี้ต้องชำระเงินจริง — ไม่ใช่เหรียญในเกม (รอเชื่อม Google Play / App Store)")
		return
	_show_status("ยังไม่เชื่อม IAP — รอ Google Play / App Store")


func _show_status(message: String) -> void:
	_status.text = message
	_status.visible = true


func _clear_status() -> void:
	_status.text = ""
	_status.visible = false


func _on_wallet_changed() -> void:
	if visible and _active_tab == Tab.INGREDIENTS:
		_refresh()


func _on_progress_changed() -> void:
	if visible and (_active_tab == Tab.INGREDIENTS or _active_tab == Tab.GENERAL):
		_refresh()


func _on_connection_restored() -> void:
	if visible:
		_sync_shop_from_server()


func _on_shop_config_changed() -> void:
	if visible:
		_refresh()
