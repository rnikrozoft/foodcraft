extends Control

const DISCOVERY_BURST_SCENE := preload("res://components/discovery_burst.tscn")
const REWARD_FLY_SCENE := preload("res://components/reward_fly_effect.tscn")

@onready var _craft_zone = $ScreenVBox/CraftZone
@onready var _discovery_margin: Control = $ScreenVBox/DiscoveryMargin
@onready var _ingredients_panel: Control = $ScreenVBox/BottomMargin/BottomVBox/PopularIngredientsPanel
@onready var _discovery_panel: Control = $ScreenVBox/DiscoveryMargin/DiscoveryCenter/DiscoveryPanel
@onready var _profile_panel: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/ProfilePanel
@onready var _currency_display: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/CurrencyDisplay
@onready var _leaderboard_panel: Control = $ScreenVBox/LeaderboardPanel
@onready var _footer_menu: Control = $ScreenVBox/BottomMargin/BottomVBox/FooterMenu

var _discovery_burst
var _reward_fly
var _pending_reward: Dictionary = {}
var _pending_reward_origin := Vector2.ZERO


func _ready() -> void:
	_discovery_burst = DISCOVERY_BURST_SCENE.instantiate()
	add_child(_discovery_burst)
	_reward_fly = REWARD_FLY_SCENE.instantiate()
	add_child(_reward_fly)

	_ingredients_panel.ingredient_selected.connect(_on_ingredient_selected)
	_craft_zone.recipe_crafted.connect(_on_recipe_crafted)
	_craft_zone.new_recipe_discovered.connect(_on_new_recipe_discovered)
	_craft_zone.reward_granted.connect(_on_reward_granted)
	_footer_menu.tab_changed.connect(_on_tab_changed)
	GameData.progress_changed.connect(_update_discovery_panel)
	GameData.wallet_changed.connect(_update_currency_display)
	NakamaService.session_ready.connect(_on_session_ready)
	NakamaService.discovery_synced.connect(_on_discovery_synced)

	_leaderboard_panel.hide_panel()
	_show_craft_view()
	_update_discovery_panel()
	_update_profile_panel()
	_update_currency_display()
	await _sync_pending_progress()


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


func _on_tab_changed(index: int) -> void:
	if index == 3:
		_show_leaderboard_view()
	else:
		_show_craft_view()


func _show_craft_view() -> void:
	_discovery_margin.visible = true
	_craft_zone.visible = true
	_ingredients_panel.visible = true
	_leaderboard_panel.hide_panel()


func _show_leaderboard_view() -> void:
	_discovery_margin.visible = false
	_craft_zone.visible = false
	_ingredients_panel.visible = false
	_leaderboard_panel.show_panel()


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
