extends Control

const DISCOVERY_BURST_SCENE := preload("res://components/discovery_burst.tscn")

@onready var _craft_zone = $ScreenVBox/CraftZone
@onready var _discovery_margin: Control = $ScreenVBox/DiscoveryMargin
@onready var _ingredients_panel: Control = $ScreenVBox/BottomMargin/BottomVBox/PopularIngredientsPanel
@onready var _discovery_panel: Control = $ScreenVBox/DiscoveryMargin/DiscoveryCenter/DiscoveryPanel
@onready var _profile_panel: Control = $ScreenVBox/Header/HeaderMargin/HeaderHBox/ProfilePanel
@onready var _leaderboard_panel: Control = $ScreenVBox/LeaderboardPanel
@onready var _footer_menu: Control = $ScreenVBox/BottomMargin/BottomVBox/FooterMenu

var _discovery_burst


func _ready() -> void:
	_discovery_burst = DISCOVERY_BURST_SCENE.instantiate()
	add_child(_discovery_burst)

	_ingredients_panel.ingredient_selected.connect(_on_ingredient_selected)
	_craft_zone.recipe_crafted.connect(_on_recipe_crafted)
	_craft_zone.new_recipe_discovered.connect(_on_new_recipe_discovered)
	_footer_menu.tab_changed.connect(_on_tab_changed)
	GameData.progress_changed.connect(_update_discovery_panel)
	NakamaService.session_ready.connect(_on_session_ready)
	NakamaService.discovery_synced.connect(_on_discovery_synced)

	_leaderboard_panel.hide_panel()
	_show_craft_view()
	_update_discovery_panel()
	_update_profile_panel()
	await _sync_pending_progress()


func _on_ingredient_selected(data: Dictionary) -> void:
	_craft_zone.add_ingredient(data)


func _on_recipe_crafted(_result_id: String, _is_new: bool) -> void:
	_update_discovery_panel()


func _on_new_recipe_discovered(display: Dictionary) -> void:
	var burst_origin: Vector2 = _craft_zone.get_result_burst_origin()
	await _discovery_burst.play_celebration(display, burst_origin)


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


func _update_profile_panel() -> void:
	var display_name := NakamaService.get_display_name()

	var discovered := GameData.get_discovered_count()
	var total := GameData.get_total_discoverable()
	_profile_panel.set_profile(display_name, maxi(1, discovered / 3 + 1), discovered, total)


func _on_session_ready(_profile: Dictionary) -> void:
	_update_profile_panel()


func _on_discovery_synced(_data: Dictionary) -> void:
	_update_discovery_panel()
	_update_profile_panel()


func _sync_pending_progress() -> void:
	if not NakamaService.is_online:
		return

	var pending := GameData.get_pending_sync()
	if pending.is_empty():
		return

	var data := await NakamaService.sync_discoveries(pending, GameData.get_craft_count())
	if not data.is_empty():
		GameData.clear_pending_sync()
