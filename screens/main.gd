extends Control

const DISCOVERY_BURST_SCENE := preload("res://components/discovery_burst.tscn")
const REWARD_FLY_SCENE := preload("res://components/reward_fly_effect.tscn")
const SLIDE_DURATION := 0.3

enum Page { CRAFT, RECIPES, MISSIONS, LEADERBOARD, SHOP }

@onready var _content_host: Control = $ScreenVBox/ContentHost
@onready var _craft_page: Control = $ScreenVBox/ContentHost/CraftPage
@onready var _craft_zone = $ScreenVBox/ContentHost/CraftPage/CraftZone
@onready var _discovery_panel: Control = $ScreenVBox/ContentHost/CraftPage/DiscoveryMargin/DiscoveryCenter/DiscoveryPanel
@onready var _ingredients_panel: Control = $ScreenVBox/BottomMargin/BottomVBox/PopularIngredientsPanel
@onready var _profile_panel: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/ProfilePanel
@onready var _currency_display: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/CurrencyDisplay
@onready var _my_recipes_page: MarginContainer = $ScreenVBox/ContentHost/MyRecipesMargin
@onready var _my_recipes_panel: Control = $ScreenVBox/ContentHost/MyRecipesMargin/MyRecipesPanel
@onready var _missions_page: MarginContainer = $ScreenVBox/ContentHost/MissionsMargin
@onready var _missions_panel: Control = $ScreenVBox/ContentHost/MissionsMargin/MissionsPanel
@onready var _leaderboard_page: MarginContainer = $ScreenVBox/ContentHost/LeaderboardMargin
@onready var _leaderboard_panel: Control = $ScreenVBox/ContentHost/LeaderboardMargin/LeaderboardPanel
@onready var _shop_page: MarginContainer = $ScreenVBox/ContentHost/ShopMargin
@onready var _shop_panel: Control = $ScreenVBox/ContentHost/ShopMargin/ShopPanel
@onready var _footer_menu: Control = $ScreenVBox/BottomMargin/BottomVBox/FooterMenu

var _discovery_burst
var _reward_fly
var _pending_reward: Dictionary = {}
var _pending_reward_origin := Vector2.ZERO
var _current_page: Page = Page.CRAFT
var _transitioning := false
var _page_tween: Tween
var _pending_shop_tab: int = ShopPanel.Tab.GENERAL
var _shop_tab_override := false


func _ready() -> void:
	_discovery_burst = DISCOVERY_BURST_SCENE.instantiate()
	add_child(_discovery_burst)
	_reward_fly = REWARD_FLY_SCENE.instantiate()
	add_child(_reward_fly)

	_apply_safe_area()
	_content_host.resized.connect(_layout_pages)
	_layout_pages()

	_ingredients_panel.ingredient_selected.connect(_on_ingredient_selected)
	_ingredients_panel.see_all_pressed.connect(_on_see_all_pressed)
	_my_recipes_panel.ingredient_picked.connect(_on_my_recipes_ingredient_picked)
	_craft_zone.new_recipe_discovered.connect(_on_new_recipe_discovered)
	_craft_zone.reward_granted.connect(_on_reward_granted)
	_footer_menu.tab_changed.connect(_on_tab_changed)
	_currency_display.add_coins_pressed.connect(_on_add_coins_pressed)
	_currency_display.add_gems_pressed.connect(_on_add_gems_pressed)
	_shop_panel.purchase_completed.connect(_update_currency_display)
	_shop_panel.purchase_celebrated.connect(_on_shop_purchase_celebrated)
	GameData.wallet_changed.connect(_update_currency_display)
	NakamaService.session_ready.connect(_on_session_ready)
	NakamaService.discovery_synced.connect(_on_discovery_synced)
	NakamaService.connection_restored.connect(_on_connection_restored)

	_my_recipes_panel.visible = false
	_missions_panel.visible = false
	_leaderboard_panel.visible = false
	_shop_panel.visible = false
	_craft_page.visible = true
	_ingredients_panel.visible = true

	GameData.missions_changed.connect(_update_mission_badge)
	_update_mission_badge()

	_update_profile_panel()
	_update_currency_display()


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_y := viewport_size.y / float(screen.y)
	var top_inset := int(safe.position.y * scale_y)
	var bottom_inset := int((screen.y - safe.position.y - safe.size.y) * scale_y)
	var header_margin: MarginContainer = $ScreenVBox/Header/HeaderMargin
	header_margin.add_theme_constant_override("margin_top", 8 + top_inset)
	# Grow the header slot by the same inset, otherwise its content
	# (profile / currency) overflows into ContentHost and covers the
	# top of whatever page is showing (e.g. under a notch / Dynamic Island).
	var header: Control = $ScreenVBox/Header
	header.custom_minimum_size.y = 96 + top_inset
	if bottom_inset > 0:
		_footer_menu.add_theme_constant_override("margin_bottom", bottom_inset)


func _layout_pages() -> void:
	if _transitioning:
		return
	var host_size := _content_host.size
	for page in [_craft_page, _my_recipes_page, _missions_page, _leaderboard_page, _shop_page]:
		page.size = host_size
		page.position = Vector2.ZERO


func _on_ingredient_selected(data: Dictionary) -> void:
	_craft_zone.add_ingredient(data)

func _on_reward_granted(reward: Dictionary, origin: Vector2) -> void:
	_pending_reward = reward
	_pending_reward_origin = origin


func _on_new_recipe_discovered(display: Dictionary) -> void:
	var burst_origin: Vector2 = _craft_zone.get_result_burst_origin()
	await _discovery_burst.play_celebration(display, burst_origin)
	await _play_pending_reward_fly()


func _screen_burst_origin() -> Vector2:
	return get_viewport().get_visible_rect().get_center()


func _on_shop_purchase_celebrated(display: Dictionary, _origin: Vector2, show_full: bool) -> void:
	if show_full:
		_discovery_burst.play_celebration(display, _screen_burst_origin())


func _on_tab_changed(index: int) -> void:
	_go_to_page(_tab_to_page(index))


func _on_see_all_pressed() -> void:
	_footer_menu.set_active_tab(1, false)
	_go_to_page(Page.RECIPES, true)


func _on_my_recipes_ingredient_picked(data: Dictionary) -> void:
	_craft_zone.add_ingredient(data)
	_footer_menu.set_active_tab(0, false)
	_go_to_page(Page.CRAFT)


func _on_add_coins_pressed() -> void:
	_open_shop(ShopPanel.Tab.GENERAL)


func _on_add_gems_pressed() -> void:
	_open_shop(ShopPanel.Tab.GENERAL)


func _open_shop(tab: int = ShopPanel.Tab.GENERAL) -> void:
	_footer_menu.set_active_tab(4, false)
	_shop_tab_override = true
	_pending_shop_tab = tab
	if _current_page == Page.SHOP:
		_shop_panel.show_tab(tab)
		_shop_tab_override = false
		return
	_go_to_page(Page.SHOP)


func _resolve_shop_tab() -> int:
	if _shop_tab_override:
		return _pending_shop_tab
	return ShopPanel.Tab.GENERAL


func _tab_to_page(tab_index: int) -> Page:
	match tab_index:
		1:
			return Page.RECIPES
		2:
			return Page.MISSIONS
		3:
			return Page.LEADERBOARD
		4:
			return Page.SHOP
		_:
			return Page.CRAFT


func _page_node(page: Page) -> Control:
	match page:
		Page.RECIPES:
			return _my_recipes_page
		Page.MISSIONS:
			return _missions_page
		Page.LEADERBOARD:
			return _leaderboard_page
		Page.SHOP:
			return _shop_page
		_:
			return _craft_page


func _go_to_page(page: Page, pick_for_craft: bool = false) -> void:
	if page == Page.RECIPES and page == _current_page:
		_my_recipes_panel.show_panel(pick_for_craft)
		return
	if page == _current_page or _transitioning:
		return

	_ingredients_panel.visible = page == Page.CRAFT

	var from_node := _page_node(_current_page)
	var to_node := _page_node(page)
	var direction := 1 if int(page) > int(_current_page) else -1
	var width := maxf(_content_host.size.x, 1.0)

	if page == Page.SHOP:
		_shop_panel.prepare_panel(_resolve_shop_tab())
	elif page == Page.LEADERBOARD:
		_leaderboard_panel.prepare_panel()
	elif page == Page.MISSIONS:
		_missions_panel.prepare_panel()
	elif page == Page.RECIPES:
		_my_recipes_panel.prepare_panel(pick_for_craft)

	# Containers inside a hidden page don't get re-sorted while visible=false —
	# Godot only flushes their queued layout pass once it's shown again, which
	# lands a frame late and shows up as a brief clip/pop before things settle
	# (worst offender: CraftZone, which is clip_contents=true and shrink-to-fit
	# height). Refresh this page's size, position it off-screen, and let the
	# queued sort resolve for a frame while it's still off-screen — so any
	# stale/mid-layout frame happens where the player can't see it, before the
	# slide-in tween reveals it.
	to_node.size = _content_host.size
	to_node.position.x = direction * width
	from_node.position.x = 0.0
	to_node.visible = true
	to_node.queue_sort()
	_transitioning = true
	await get_tree().process_frame

	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(from_node, "position:x", -direction * width, SLIDE_DURATION)
	_page_tween.tween_property(to_node, "position:x", 0.0, SLIDE_DURATION)
	await _page_tween.finished

	_deactivate_page(_current_page)
	from_node.visible = false
	from_node.position = Vector2.ZERO
	to_node.position = Vector2.ZERO
	_current_page = page
	_transitioning = false
	_activate_page(page, pick_for_craft)
	_layout_pages()


func _activate_page(page: Page, pick_for_craft: bool) -> void:
	match page:
		Page.RECIPES:
			_my_recipes_panel.show_panel(pick_for_craft)
		Page.MISSIONS:
			_missions_panel.show_panel()
		Page.LEADERBOARD:
			_leaderboard_panel.show_panel()
		Page.SHOP:
			_shop_panel.show_panel(_resolve_shop_tab())
			_shop_tab_override = false
			_pending_shop_tab = ShopPanel.Tab.GENERAL


func _deactivate_page(page: Page) -> void:
	match page:
		Page.RECIPES:
			_my_recipes_panel.hide_panel()
		Page.MISSIONS:
			_missions_panel.hide_panel()
		Page.LEADERBOARD:
			_leaderboard_panel.hide_panel()
		Page.SHOP:
			_shop_panel.hide_panel()

func _update_currency_display() -> void:
	_currency_display.set_coins(GameData.get_coins())
	_currency_display.set_gems(GameData.get_stars())


func _update_profile_panel() -> void:
	var display_name := NakamaService.get_display_name()

	var discovered := GameData.get_discovered_count()
	var total := GameData.get_total_discoverable()
	_profile_panel.set_profile(display_name, maxi(1, discovered / 3 + 1), discovered, total)


func _on_session_ready(_profile: Dictionary) -> void:
	_update_profile_panel()
	_update_currency_display()
	NakamaService.fetch_missions()


func _update_mission_badge() -> void:
	_footer_menu.set_tab_badge(2, GameData.get_mission_claimable())


func _on_discovery_synced(_data: Dictionary) -> void:
	_refresh_after_server_sync()


func _on_connection_restored() -> void:
	_refresh_after_server_sync()


func _refresh_after_server_sync() -> void:
	_update_profile_panel()
	_update_currency_display()
	if _current_page == Page.SHOP:
		_shop_panel.prepare_panel(_shop_panel.get_active_tab())


func _play_pending_reward_fly() -> void:
	if _pending_reward.is_empty():
		return

	var reward := _pending_reward
	var origin := _pending_reward_origin
	_pending_reward = {}
	_pending_reward_origin = Vector2.ZERO

	var reward_type := String(reward.get("type", ""))
	var target: Vector2 = _currency_display.get_coin_icon_global_center()
	if reward_type == "star":
		target = _currency_display.get_star_icon_global_center()

	await _reward_fly.play(reward, origin, target)
	_update_currency_display()
	_currency_display.pulse_reward(reward_type)
