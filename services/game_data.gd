extends Node

signal progress_changed
signal wallet_changed
signal shop_config_changed
signal catalog_loaded
signal missions_changed

const MAX_RECENT_DISCOVERIES := 20

var _mission_claimable := 0

var _items_by_id: Dictionary = {}
var _discoverable_total: int = 0
var _discovered_ids: Dictionary = {}
var _recent_discovered_ids: Array = []
var _discovery_points: int = 0
var _craft_count: int = 0
var _coins: int = 0
var _stars: int = 0
var _unlocked_ingredient_ids: Dictionary = {}
var _starter_item_ids: Dictionary = {}
var _ads_removed: bool = false
var _catalog_loaded: bool = false
var _daily_reward_coins: int = 0
var _ad_reward_coins: int = 0
var _starter_pack_coins: int = 0

var _shop_config: Dictionary = {}
var _shop_last_auto_reset_unix: int = 0
var _shop_active_ids: Dictionary = {}
var _shop_cached_offers: Array = []

var _daily_reward_last_claim: int = 0


func is_catalog_loaded() -> bool:
	return _catalog_loaded


func apply_catalog_from_server(data: Dictionary) -> void:
	_items_by_id = {}
	_discoverable_total = 0
	_starter_item_ids = {}

	for item in _array_from_variant(data.get("items", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var id := String(entry.get("id", ""))
		if id.is_empty():
			continue
		_items_by_id[id] = entry
		if int(entry.get("tier", 0)) >= 1:
			_discoverable_total += 1

	if data.has("discoverable_total"):
		_discoverable_total = int(data.get("discoverable_total", _discoverable_total))

	for id in _array_from_variant(data.get("starter_items", [])):
		_starter_item_ids[String(id)] = true

	if data.has("daily_reward_coins"):
		_daily_reward_coins = int(data.get("daily_reward_coins", 0))

	var monetization: Variant = data.get("monetization", {})
	if typeof(monetization) == TYPE_DICTIONARY:
		_ad_reward_coins = int(monetization.get("ad_reward_coins", 0))
		_starter_pack_coins = int(monetization.get("starter_pack_coins", 0))

	var shop: Dictionary = data.get("shop", {})
	if typeof(shop) == TYPE_DICTIONARY and not shop.is_empty():
		apply_shop_config(shop, false)

	_catalog_loaded = not _items_by_id.is_empty()
	if _catalog_loaded:
		FoodIcons.register_catalog(_items_by_id.keys())
		catalog_loaded.emit()
		progress_changed.emit()


func get_daily_reward_coins() -> int:
	return _daily_reward_coins


func get_ad_reward_coins() -> int:
	return _ad_reward_coins


func get_starter_pack_coins() -> int:
	return _starter_pack_coins


func apply_shop_config(shop: Dictionary, emit_signal: bool = true) -> void:
	if shop.is_empty():
		return
	_shop_config = shop.duplicate(true)
	if emit_signal:
		shop_config_changed.emit()
		progress_changed.emit()


func get_shop_config() -> Dictionary:
	return _shop_config.duplicate(true)


func get_item(id: String) -> Dictionary:
	return _items_by_id.get(id, {})


func to_display_dict(id: String) -> Dictionary:
	var item := get_item(id)
	if item.is_empty():
		return {}

	return {
		"id": id,
		"title": item.get("name_th", id),
		"category": item.get("category", ""),
		"type": item.get("type", ""),
		"tier": int(item.get("tier", 0)),
	}


func get_panel_ingredients() -> Array:
	var results: Array = []
	for item in _items_by_id.values():
		if item.get("category") != "ingredient":
			continue
		if int(item.get("tier", 0)) != 0:
			continue
		if not is_ingredient_unlocked(String(item.get("id", ""))):
			continue
		results.append(to_display_dict(item["id"]))

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var starter_a := is_starter_ingredient(String(a.get("id", "")))
		var starter_b := is_starter_ingredient(String(b.get("id", "")))
		if starter_a != starter_b:
			return starter_a and not starter_b
		return String(a.get("title", "")) < String(b.get("title", ""))
	)
	return results


func get_ingredient_types() -> Array:
	var types := {}
	for item in _items_by_id.values():
		if item.get("category") != "ingredient":
			continue
		if int(item.get("tier", 0)) != 0:
			continue
		var t := String(item.get("type", ""))
		if not t.is_empty():
			types[t] = true
	var result := types.keys()
	result.sort()
	return result


func craft_result_kind(id: String) -> String:
	var item := get_item(id)
	if item.is_empty():
		return ""
	if int(item.get("tier", 0)) == 0 and String(item.get("category", "")) == "ingredient":
		return "ingredient"
	return "menu"


func note_server_discovery(id: String) -> void:
	if id.is_empty():
		return
	_push_recent_discovery(id)


func get_coins() -> int:
	return _coins


func get_stars() -> int:
	return _stars


func is_starter_ingredient(id: String) -> bool:
	return _starter_item_ids.has(id)


func is_ingredient_unlocked(id: String) -> bool:
	if not get_item(id).is_empty() and is_starter_ingredient(id):
		return true
	return _unlocked_ingredient_ids.has(id)


func can_use_in_craft(id: String) -> bool:
	if id.is_empty():
		return false
	var item := get_item(id)
	if item.is_empty():
		return false
	if int(item.get("tier", 0)) == 0:
		return is_ingredient_unlocked(id)
	return _discovered_ids.has(id)


func get_starter_items() -> Array:
	var results: Array = []
	for id in _starter_item_ids.keys():
		var display := to_display_dict(String(id))
		if not display.is_empty():
			results.append(display)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("title", "")) < String(b.get("title", ""))
	)
	return results


func is_ads_removed() -> bool:
	return _ads_removed


func set_ads_removed(value: bool = true) -> void:
	_ads_removed = value
	progress_changed.emit()


func get_shop_ingredient_offers() -> Array:
	return _reconcile_shop_offers(_shop_cached_offers)


func _reconcile_shop_offers(offers: Array) -> Array:
	var result: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (offer as Dictionary).duplicate()
		var sid := String(entry.get("id", ""))
		if sid.is_empty():
			continue
		var unlocked := is_ingredient_unlocked(sid)
		var buyable := not unlocked and is_shop_ingredient_buyable(sid)
		entry["unlocked"] = unlocked
		entry["buyable"] = buyable
		result.append(entry)
	return result


func get_next_shop_reset_sec() -> int:
	var next_midnight := _utc_midnight_unix() + 86400
	return maxi(0, next_midnight - _shop_unix_now())


func is_shop_ingredient_buyable(id: String) -> bool:
	if is_ingredient_unlocked(id):
		return false
	if not _is_shop_active(id):
		return false
	return true


func get_shop_timer_sec(kind: String, _target_id: String = "") -> int:
	if kind == "shop_reset":
		return get_next_shop_reset_sec()
	return 0


func apply_shop_state_from_server(data: Dictionary) -> void:
	apply_wallet_from_server(data)
	_shop_last_auto_reset_unix = int(data.get("shop_last_auto_reset_unix", _shop_last_auto_reset_unix))
	_shop_active_ids = {}
	for id in _array_from_variant(data.get("shop_active_ids", [])):
		_shop_active_ids[String(id)] = true
	if data.has("unlocked_ingredients"):
		_unlocked_ingredient_ids = {}
		for id in _array_from_variant(data.get("unlocked_ingredients", [])):
			_unlocked_ingredient_ids[String(id)] = true
	_shop_cached_offers = []
	var server_offers := _array_from_variant(data.get("offers", []))
	if not server_offers.is_empty():
		_shop_cached_offers = server_offers
	wallet_changed.emit()
	progress_changed.emit()


func apply_wallet_from_server(data: Dictionary) -> void:
	if data.has("coins"):
		_coins = int(data.get("coins", _coins))
	if data.has("stars"):
		_stars = int(data.get("stars", _stars))
	wallet_changed.emit()


func _utc_midnight_unix() -> int:
	var now := int(Time.get_unix_time_from_system())
	return now - (now % 86400)


func apply_daily_reward_status_from_server(data: Dictionary) -> void:
	if data.has("last_claim_unix"):
		_daily_reward_last_claim = int(data.get("last_claim_unix", _daily_reward_last_claim))


func apply_missions_from_server(data: Dictionary) -> void:
	if data.has("claimable_count"):
		set_mission_claimable(int(data.get("claimable_count", 0)))


func set_mission_claimable(count: int) -> void:
	if _mission_claimable == count:
		return
	_mission_claimable = count
	missions_changed.emit()


func get_mission_claimable() -> int:
	return _mission_claimable


func _shop_unix_now() -> int:
	return int(Time.get_unix_time_from_system())


func _is_shop_active(id: String) -> bool:
	if _shop_active_ids.is_empty():
		return false
	return _shop_active_ids.has(id)


func get_discovered_count() -> int:
	return _discovered_ids.size()


func get_discovered_items() -> Array:
	var results: Array = []
	for id in _discovered_ids.keys():
		var display := to_display_dict(String(id))
		if not display.is_empty():
			results.append(display)

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("title", "")) < String(b.get("title", ""))
	)
	return results


func get_collection_items() -> Array:
	return _merge_display_items(get_discovered_items(), get_panel_ingredients())


func get_recent_discoveries() -> Array:
	var results: Array = []
	for id in _recent_discovered_ids:
		var display := to_display_dict(String(id))
		if not display.is_empty():
			results.append(display)
	return results


func get_craft_pick_items() -> Array:
	return get_collection_items()


func get_craft_bar_items() -> Array:
	var collection := get_collection_items()
	if collection.is_empty():
		return get_panel_ingredients()

	var seen := {}
	var ordered: Array = []
	for id in _recent_discovered_ids:
		var sid := String(id)
		if seen.has(sid):
			continue
		for item in collection:
			if String(item.get("id", "")) == sid:
				ordered.append(item)
				seen[sid] = true
				break

	var rest: Array = []
	for item in collection:
		var sid := String(item.get("id", ""))
		if sid.is_empty() or seen.has(sid):
			continue
		rest.append(item)
	rest.sort_custom(func(a, b): return String(a.get("title", "")) < String(b.get("title", "")))
	return ordered + rest


func _push_recent_discovery(id: String) -> void:
	_recent_discovered_ids.erase(id)
	_recent_discovered_ids.insert(0, id)
	if _recent_discovered_ids.size() > MAX_RECENT_DISCOVERIES:
		_recent_discovered_ids.resize(MAX_RECENT_DISCOVERIES)


func _merge_display_items(primary: Array, extra: Array) -> Array:
	var merged: Array = []
	var seen := {}
	for data in primary + extra:
		var item_id := String(data.get("id", ""))
		if item_id.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		merged.append(data)
	return merged


func get_discovery_points() -> int:
	return _discovery_points


func get_craft_count() -> int:
	return _craft_count


func get_total_discoverable() -> int:
	return _discoverable_total


func apply_server_state(data: Dictionary) -> void:
	if data.has("discovered"):
		_discovered_ids = {}
		for id in data.get("discovered", []):
			_discovered_ids[String(id)] = true
		if _recent_discovered_ids.is_empty() and not _discovered_ids.is_empty():
			_backfill_recent_discoveries()
	if data.has("discovery_points"):
		_discovery_points = int(data.get("discovery_points", 0))
	if data.has("craft_count"):
		_craft_count = int(data.get("craft_count", 0))
	apply_wallet_from_server(data)
	if data.has("unlocked_ingredients"):
		_unlocked_ingredient_ids = {}
		for id in _array_from_variant(data.get("unlocked_ingredients", [])):
			_unlocked_ingredient_ids[String(id)] = true
	if data.has("mission_claimable"):
		set_mission_claimable(int(data.get("mission_claimable", 0)))
	progress_changed.emit()
	wallet_changed.emit()


func _backfill_recent_discoveries() -> void:
	var items: Array = get_discovered_items()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var tier_a := int(a.get("tier", 0))
		var tier_b := int(b.get("tier", 0))
		if tier_a != tier_b:
			return tier_a > tier_b
		return String(a.get("title", "")) > String(b.get("title", ""))
	)
	for item in items.slice(0, MAX_RECENT_DISCOVERIES):
		_recent_discovered_ids.append(String(item.get("id", "")))


func _array_from_variant(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []
