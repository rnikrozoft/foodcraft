extends Control

const DISCOVERY_BURST_SCENE := preload("res://components/discovery_burst.tscn")
const REWARD_FLY_SCENE := preload("res://components/reward_fly_effect.tscn")
const SLIDE_DURATION := 0.3

enum Page { CRAFT, RECIPES, LEADERBOARD, SHOP }

@onready var _content_host: Control = $ScreenVBox/ContentHost
@onready var _craft_page: Control = $ScreenVBox/ContentHost/CraftPage
@onready var _craft_zone = $ScreenVBox/ContentHost/CraftPage/CraftZone
@onready var _discovery_panel: Control = $ScreenVBox/ContentHost/CraftPage/DiscoveryMargin/DiscoveryCenter/DiscoveryPanel
@onready var _ingredients_panel: Control = $ScreenVBox/BottomMargin/BottomVBox/PopularIngredientsPanel
@onready var _profile_panel: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/ProfilePanel
@onready var _currency_display: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/CurrencyDisplay
@onready var _leaderboard_panel: Control = $ScreenVBox/ContentHost/LeaderboardPanel
@onready var _my_recipes_panel: Control = $ScreenVBox/ContentHost/MyRecipesPanel
@onready var _shop_panel: Control = $ScreenVBox/ContentHost/ShopPanel
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

	_content_host.resized.connect(_layout_pages)
	_layout_pages()

	_ingredients_panel.ingredient_selected.connect(_on_ingredient_selected)
	_ingredients_panel.see_all_pressed.connect(_on_see_all_pressed)
	_my_recipes_panel.ingredient_picked.connect(_on_my_recipes_ingredient_picked)
	_craft_zone.recipe_crafted.connect(_on_recipe_crafted)
	_craft_zone.new_recipe_discovered.connect(_on_new_recipe_discovered)
	_craft_zone.reward_granted.connect(_on_reward_granted)
	_footer_menu.tab_changed.connect(_on_tab_changed)
	_currency_display.add_coins_pressed.connect(_on_add_coins_pressed)
	_currency_display.add_gems_pressed.connect(_on_add_gems_pressed)
	_shop_panel.purchase_completed.connect(_update_currency_display)
	_shop_panel.purchase_celebrated.connect(_on_shop_purchase_celebrated)
	GameData.progress_changed.connect(_update_discovery_panel)
	GameData.wallet_changed.connect(_update_currency_display)
	NakamaService.session_ready.connect(_on_session_ready)
	NakamaService.discovery_synced.connect(_on_discovery_synced)

	_my_recipes_panel.visible = false
	_leaderboard_panel.visible = false
	_shop_panel.visible = false
	_craft_page.visible = true
	_ingredients_panel.visible = true

	_update_discovery_panel()
	_update_profile_panel()
	_update_currency_display()
	await _sync_pending_progress()


func _layout_pages() -> void:
	if _transitioning:
		return
	var host_size := _content_host.size
	for page in [_craft_page, _my_recipes_panel, _leaderboard_panel, _shop_panel]:
		page.size = host_size
		page.position = Vector2.ZERO


func _on_ingredient_selected(data: Dictionary) -> void:
	_craft_zone.add_ingredient(data)


func _on_recipe_crafted(_result_id: String, _is_new: bool) -> void:
	_update_discovery_panel()


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
	var burst_origin := _screen_burst_origin()
	if show_full:
		_discovery_burst.play_celebration(display, burst_origin)
	else:
		_discovery_burst.play_particle_burst(burst_origin)


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
		3:
			return Page.LEADERBOARD
		4:
			return Page.SHOP
		_:
			return Page.CRAFT


func _page_node(page: Page) -> Control:
	match page:
		Page.RECIPES:
			return _my_recipes_panel
		Page.LEADERBOARD:
			return _leaderboard_panel
		Page.SHOP:
			return _shop_panel
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

	to_node.visible = true
	to_node.position.x = direction * width
	from_node.position.x = 0.0

	_transitioning = true
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
		Page.LEADERBOARD:
			_leaderboard_panel.hide_panel()
		Page.SHOP:
			_shop_panel.hide_panel()


func _update_discovery_panel() -> void:
	_discovery_panel.set_progress(GameData.get_discovered_count(), GameData.get_total_discoverable())


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


func _on_discovery_synced(_data: Dictionary) -> void:
	_update_discovery_panel()
	_update_profile_panel()
	_update_currency_display()


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
	GameData.commit_staged_reward()
	_update_currency_display()
	_currency_display.pulse_reward(reward_type)


func _sync_pending_progress() -> void:
	if not NakamaService.is_online:
		return

	var pending := GameData.get_pending_sync()
	if pending.is_empty():
		return

	var data := await NakamaService.sync_discoveries(pending, GameData.get_craft_count())
	if not data.is_empty():
		GameData.clear_pending_sync()
