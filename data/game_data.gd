extends Node

const DATA_PATH := "res://data/game_data.json"
const SAVE_PATH := "user://player_progress.json"

signal progress_changed
signal wallet_changed
signal shop_config_changed

const STAR_DROP_PERCENT := 28
const MAX_RECENT_DISCOVERIES := 20

var _items_by_id: Dictionary = {}
var _recipes_by_key: Dictionary = {}
var _discoverable_total: int = 0
var _discovered_ids: Dictionary = {}
var _recent_discovered_ids: Array = []
var _discovery_points: int = 0
var _craft_count: int = 0
var _pending_sync: Array = []
var _coins: int = 0
var _stars: int = 0
var _unlocked_ingredient_ids: Dictionary = {}
var _starter_item_ids: Dictionary = {}
var _ads_removed: bool = false

const _SHOP_CONFIG_DEFAULTS := {
	"reset_cycle_sec": 86400,
	"reset_mid_count": 5,
	"reset_prices": {"mid": 90, "high": 150, "currency": "coins"},
	"rarity_cooldown_days": {
		"common": 3,
		"uncommon": 5,
		"rare": 7,
		"epic": 10,
		"legendary": 14,
	},
	"rarity_costs": {
		"common": 80,
		"uncommon": 150,
		"rare": 280,
		"epic": 450,
		"legendary": 700,
	},
	"rarity_labels": {
		"common": "ธรรมดา",
		"uncommon": "หายาก",
		"rare": "แรร์",
		"epic": "เอปิค",
		"legendary": "ตำนาน",
	},
	"rotation_count": 8,
}
var _shop_config: Dictionary = {}
var _shop_cycle_start: int = 0
var _shop_manual_reset_count: int = 0
var _shop_item_expires_at: Dictionary = {}
var _shop_active_ids: Dictionary = {}
var _shop_cached_offers: Array = []


func _ready() -> void:
	_shop_config = _SHOP_CONFIG_DEFAULTS.duplicate(true)
	_load_data()
	_load_local_progress()


func _load_data() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("GameData: cannot open %s" % DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: invalid JSON in %s" % DATA_PATH)
		return

	for item in parsed.get("items", []):
		_items_by_id[item["id"]] = item
		if int(item.get("tier", 0)) >= 1:
			_discoverable_total += 1

	for recipe in parsed.get("recipes", []):
		var key := _recipe_key(recipe.get("a", ""), recipe.get("b", ""))
		_recipes_by_key[key] = recipe.get("result", "")

	_starter_item_ids = {}
	for id in _array_from_variant(parsed.get("starter_items", parsed.get("initial_discovered", ["rice", "egg"]))):
		_starter_item_ids[String(id)] = true

	var shop: Dictionary = parsed.get("shop", {})
	if typeof(shop) == TYPE_DICTIONARY and not shop.is_empty():
		apply_shop_config(shop, false)


func apply_shop_config(shop: Dictionary, emit_signal: bool = true) -> void:
	_shop_config = _merge_shop_config(shop)
	if emit_signal:
		shop_config_changed.emit()
		progress_changed.emit()


func get_shop_config() -> Dictionary:
	return _shop_config.duplicate(true)


func _merge_shop_config(shop: Dictionary) -> Dictionary:
	var merged: Dictionary = _SHOP_CONFIG_DEFAULTS.duplicate(true)
	for key in shop.keys():
		var value: Variant = shop[key]
		if typeof(value) == TYPE_DICTIONARY and typeof(merged.get(key)) == TYPE_DICTIONARY:
			var nested: Dictionary = (merged[key] as Dictionary).duplicate()
			nested.merge(value, true)
			merged[key] = nested
		else:
			merged[key] = value
	return merged


func _shop_reset_cycle_sec() -> int:
	return int(_shop_config.get("reset_cycle_sec", 86400))


func _shop_reset_mid_count() -> int:
	return int(_shop_config.get("reset_mid_count", 5))


func _shop_reset_price_mid() -> int:
	return int(_shop_config.get("reset_prices", {}).get("mid", 90))


func _shop_reset_price_high() -> int:
	return int(_shop_config.get("reset_prices", {}).get("high", 150))


func _shop_cooldown_days(rarity: String) -> int:
	return int(_shop_config.get("rarity_cooldown_days", {}).get(rarity, 3))


func _shop_rarity_cost(rarity: String) -> int:
	return int(_shop_config.get("rarity_costs", {}).get(rarity, 150))


func _shop_rarity_label(rarity: String) -> String:
	return String(_shop_config.get("rarity_labels", {}).get(rarity, rarity))


func get_item(id: String) -> Dictionary:
	return _items_by_id.get(id, {})


func to_display_dict(id: String) -> Dictionary:
	var item := get_item(id)
	if item.is_empty():
		return {}

	return {
		"id": id,
		"title": item.get("name_th", id),
		"emoji": item.get("emoji", ""),
		"category": item.get("category", ""),
		"tier": int(item.get("tier", 0)),
	}


func lookup_recipe(id_a: String, id_b: String) -> String:
	if id_a.is_empty() or id_b.is_empty():
		return ""
	return _recipes_by_key.get(_recipe_key(id_a, id_b), "")


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
		var item_a := get_item(a.get("id", ""))
		var item_b := get_item(b.get("id", ""))
		var starter_a := is_starter_ingredient(String(a.get("id", "")))
		var starter_b := is_starter_ingredient(String(b.get("id", "")))
		if starter_a != starter_b:
			return starter_a and not starter_b
		return String(a.get("title", "")) < String(b.get("title", ""))
	)
	return results


func mark_discovered(id: String) -> bool:
	if id.is_empty():
		return false

	var item := get_item(id)
	if item.is_empty() or int(item.get("tier", 0)) < 1:
		return false

	var is_new := not _discovered_ids.has(id)
	_discovered_ids[id] = true
	if is_new:
		_discovery_points += get_item_discovery_points(id)
	_push_recent_discovery(id)
	_save_local_progress()
	progress_changed.emit()
	return is_new


func process_craft_result(id: String) -> Dictionary:
	var item := get_item(id)
	if item.is_empty():
		return {"is_new": false, "result_kind": ""}
	if int(item.get("tier", 0)) == 0 and String(item.get("category", "")) == "ingredient":
		var was_unlocked := is_ingredient_unlocked(id)
		unlock_ingredient(id)
		_push_recent_discovery(id)
		_save_local_progress()
		progress_changed.emit()
		return {"is_new": not was_unlocked, "result_kind": "ingredient"}
	var is_new := mark_discovered(id)
	return {"is_new": is_new, "result_kind": "menu"}


func queue_discovery(item_id: String, from_ids: PackedStringArray) -> void:
	_pending_sync.append({
		"item_id": item_id,
		"from": [from_ids[0], from_ids[1]],
	})
	_save_local_progress()


func record_craft_local() -> void:
	_craft_count += 1
	_save_local_progress()


func roll_discovery_reward(item_id: String) -> Dictionary:
	var tier := maxi(1, int(get_item(item_id).get("tier", 1)))
	if randi() % 100 < STAR_DROP_PERCENT:
		return {"type": "star", "amount": _star_amount(tier)}
	return {"type": "coin", "amount": _coin_amount(tier)}


func apply_reward(reward: Dictionary) -> void:
	var reward_type := String(reward.get("type", ""))
	var amount := int(reward.get("amount", 0))
	if amount <= 0:
		return
	match reward_type:
		"coin":
			_coins += amount
		"star":
			_stars += amount
	_save_local_progress()
	wallet_changed.emit()


var _staged_reward: Dictionary = {}


func stage_reward(reward: Dictionary) -> void:
	var amount := int(reward.get("amount", 0))
	if amount <= 0 or String(reward.get("type", "")).is_empty():
		_staged_reward = {}
		return
	_staged_reward = reward.duplicate()


func commit_staged_reward() -> void:
	if _staged_reward.is_empty():
		return
	var reward := _staged_reward.duplicate()
	_staged_reward = {}
	apply_reward(reward)


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


func spend_coins(amount: int) -> bool:
	if amount <= 0 or _coins < amount:
		return false
	_coins -= amount
	_save_local_progress()
	wallet_changed.emit()
	return true


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount
	_save_local_progress()
	wallet_changed.emit()


func add_stars(amount: int) -> void:
	if amount <= 0:
		return
	_stars += amount
	_save_local_progress()
	wallet_changed.emit()


func unlock_ingredient(id: String) -> bool:
	var item := get_item(id)
	if item.is_empty() or item.get("category") != "ingredient":
		return false
	if is_ingredient_unlocked(id):
		return true
	_unlocked_ingredient_ids[id] = true
	_shop_cached_offers = []
	_save_local_progress()
	progress_changed.emit()
	return true


func purchase_ingredient_with_coins(id: String, cost: int) -> bool:
	if is_ingredient_unlocked(id):
		return true
	if not is_shop_ingredient_buyable(id):
		return false
	if not spend_coins(cost):
		return false
	if not unlock_ingredient(id):
		return false
	_mark_shop_item_purchased(id)
	_shop_cached_offers = []
	return true


func set_ads_removed(value: bool = true) -> void:
	_ads_removed = value
	_save_local_progress()
	progress_changed.emit()


func get_shop_ingredient_offers() -> Array:
	if not _shop_cached_offers.is_empty():
		return _reconcile_shop_offers(_shop_cached_offers)
	return _build_local_shop_offers()


func _reconcile_shop_offers(offers: Array) -> Array:
	var result: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (offer as Dictionary).duplicate()
		var sid := String(entry.get("id", ""))
		if sid.is_empty():
			continue
		var rarity := String(entry.get("rarity", "common"))
		var unlocked := is_ingredient_unlocked(sid)
		var buyable := not unlocked and is_shop_ingredient_buyable(sid)
		entry["unlocked"] = unlocked
		entry["buyable"] = buyable
		entry["cooldown_sec"] = 0 if unlocked else get_shop_ingredient_cooldown_sec(sid, rarity)
		entry["window_remaining_sec"] = 0 if unlocked or not buyable else get_shop_ingredient_window_remaining_sec(sid)
		result.append(entry)
	return result


func _build_local_shop_offers() -> Array:
	_ensure_shop_initialized()
	var catalog_by_id: Dictionary = {}
	for raw in _build_shop_ingredient_catalog():
		catalog_by_id[String(raw.get("id", ""))] = raw
	var active_ids: Array = _shop_active_ids.keys()
	active_ids.sort()
	if active_ids.is_empty():
		active_ids = catalog_by_id.keys()
		active_ids.sort()
	var offers: Array = []
	for id in active_ids:
		var sid := String(id)
		if not catalog_by_id.has(sid):
			continue
		var raw: Dictionary = catalog_by_id[sid]
		var rarity := String(raw.get("rarity", "common"))
		var unlocked := is_ingredient_unlocked(sid)
		var buyable := not unlocked and is_shop_ingredient_buyable(sid)
		var cooldown_sec := 0 if unlocked else get_shop_ingredient_cooldown_sec(sid, rarity)
		var window_remaining_sec := 0 if unlocked or not buyable else get_shop_ingredient_window_remaining_sec(sid)
		var entry: Dictionary = raw.duplicate()
		entry["unlocked"] = unlocked
		entry["buyable"] = buyable
		entry["cooldown_sec"] = cooldown_sec
		entry["window_remaining_sec"] = window_remaining_sec
		offers.append(entry)
	return offers


func get_shop_reset_info() -> Dictionary:
	_normalize_shop_cycle()
	var price_type := "free"
	var coin_cost := 0
	if _shop_manual_reset_count >= 1:
		price_type = "mid" if _shop_manual_reset_count < 1 + _shop_reset_mid_count() else "high"
	var price_label := "ฟรี"
	if price_type == "mid":
		coin_cost = _shop_reset_price_mid()
		price_label = str(coin_cost)
	elif price_type == "high":
		coin_cost = _shop_reset_price_high()
		price_label = str(coin_cost)
	var next_free_sec := maxi(0, _shop_reset_cycle_sec() - (_shop_unix_now() - _shop_cycle_start))
	return {
		"price_type": price_type,
		"price_label": price_label,
		"coin_cost": coin_cost,
		"resets_used": _shop_manual_reset_count,
		"next_free_reset_sec": next_free_sec,
	}


func get_shop_reset_coin_cost() -> int:
	return int(get_shop_reset_info().get("coin_cost", 0))


func is_shop_ingredient_buyable(id: String) -> bool:
	if is_ingredient_unlocked(id):
		return false
	if not _is_shop_active(id):
		return false
	_ensure_shop_initialized()
	var expires := int(_shop_item_expires_at.get(id, 0))
	var now := _shop_unix_now()
	if now < expires:
		return true
	var rarity := _shop_rarity_for_id(id)
	var days: int = _shop_cooldown_days(rarity)
	var restock_at: int = expires + days * 86400
	if now >= restock_at:
		_shop_item_expires_at[id] = now + days * 86400
		_save_local_progress()
		return true
	return false


func get_shop_ingredient_cooldown_sec(id: String, rarity: String = "") -> int:
	if is_ingredient_unlocked(id):
		return 0
	_ensure_shop_initialized()
	var expires := int(_shop_item_expires_at.get(id, 0))
	var remaining := expires - _shop_unix_now()
	if remaining > 0:
		return 0
	var days: int = _shop_cooldown_days(rarity if not rarity.is_empty() else _shop_rarity_for_id(id))
	var restock_at: int = expires + days * 86400
	return maxi(0, restock_at - _shop_unix_now())


func get_shop_ingredient_window_remaining_sec(id: String) -> int:
	if is_ingredient_unlocked(id):
		return 0
	if not is_shop_ingredient_buyable(id):
		return 0
	_ensure_shop_initialized()
	var expires := int(_shop_item_expires_at.get(id, 0))
	return maxi(0, expires - _shop_unix_now())


func get_shop_timer_sec(kind: String, target_id: String = "") -> int:
	match kind:
		"cooldown":
			return get_shop_ingredient_cooldown_sec(target_id)
		"window":
			return get_shop_ingredient_window_remaining_sec(target_id)
		"reset_free":
			return int(get_shop_reset_info().get("next_free_reset_sec", 0))
	return 0


func apply_shop_state_from_server(data: Dictionary) -> void:
	apply_wallet_from_server(data)
	_shop_cycle_start = int(data.get("shop_cycle_start", _shop_cycle_start))
	_shop_manual_reset_count = int(data.get("shop_manual_reset_count", _shop_manual_reset_count))
	_shop_item_expires_at = {}
	var expires := _dict_from_variant(data.get("shop_item_expires_at", {}))
	for id in expires.keys():
		_shop_item_expires_at[String(id)] = int(expires[id])
	_shop_active_ids = {}
	for id in _array_from_variant(data.get("shop_active_ids", [])):
		_shop_active_ids[String(id)] = true
	_merge_unlocked_from_server(data.get("unlocked_ingredients", []))
	_shop_cached_offers = []
	var server_offers := _array_from_variant(data.get("offers", []))
	if not server_offers.is_empty():
		_shop_cached_offers = server_offers
	_save_local_progress()
	wallet_changed.emit()
	progress_changed.emit()


func apply_wallet_from_server(data: Dictionary) -> void:
	if data.has("coins"):
		_coins = int(data.get("coins", _coins))
	if data.has("stars"):
		_stars = int(data.get("stars", _stars))
	_save_local_progress()
	wallet_changed.emit()


func reset_shop_free() -> bool:
	_normalize_shop_cycle()
	if _shop_manual_reset_count >= 1:
		return false
	_perform_shop_reset()
	return true


func reset_shop_paid() -> bool:
	_normalize_shop_cycle()
	var cost := get_shop_reset_coin_cost()
	if cost <= 0:
		return false
	if not spend_coins(cost):
		return false
	_perform_shop_reset()
	return true


func _shop_unix_now() -> int:
	return int(Time.get_unix_time_from_system())


func _normalize_shop_cycle() -> void:
	var now := _shop_unix_now()
	if _shop_cycle_start <= 0:
		_shop_cycle_start = now
		_shop_manual_reset_count = 0
		return
	if now - _shop_cycle_start >= _shop_reset_cycle_sec():
		_shop_cycle_start = now
		_shop_manual_reset_count = 0


func _ensure_shop_initialized() -> void:
	if _shop_active_ids.is_empty():
		_roll_shop_rotation()
	var now := _shop_unix_now()
	var changed := false
	for id in _shop_active_ids.keys():
		if is_ingredient_unlocked(String(id)):
			continue
		if _shop_item_expires_at.has(id):
			continue
		var rarity := _shop_rarity_for_id(String(id))
		var days: int = _shop_cooldown_days(rarity)
		_shop_item_expires_at[id] = now + days * 86400
		changed = true
	if changed:
		_save_local_progress()


func _perform_shop_reset() -> void:
	_shop_manual_reset_count += 1
	_shop_cached_offers = []
	_roll_shop_rotation()
	_refresh_shop_item_windows()
	_save_local_progress()
	progress_changed.emit()


func _refresh_shop_item_windows() -> void:
	var now := _shop_unix_now()
	for id in _shop_active_ids.keys():
		if is_ingredient_unlocked(String(id)):
			continue
		var rarity := _shop_rarity_for_id(String(id))
		var days: int = _shop_cooldown_days(rarity)
		_shop_item_expires_at[id] = now + days * 86400


func _shop_rotation_count() -> int:
	return int(_shop_config.get("rotation_count", 8))


func _is_shop_active(id: String) -> bool:
	if _shop_active_ids.is_empty():
		return true
	return _shop_active_ids.has(id)


func _roll_shop_rotation() -> void:
	_shop_active_ids = {}
	var locked: Array = []
	for offer in _build_shop_ingredient_catalog():
		var offer_id := String(offer.get("id", ""))
		if is_ingredient_unlocked(offer_id):
			continue
		locked.append(offer)
	var count := _shop_rotation_count()
	if count <= 0 or count >= locked.size():
		for offer in locked:
			_shop_active_ids[String(offer.get("id", ""))] = true
		return
	locked.shuffle()
	for i in mini(count, locked.size()):
		var picked: Dictionary = locked[i] as Dictionary
		_shop_active_ids[String(picked.get("id", ""))] = true


func _mark_shop_item_purchased(id: String) -> void:
	_shop_active_ids[id] = true
	_shop_item_expires_at[id] = _shop_unix_now()
	_shop_cached_offers = []
	_save_local_progress()
	progress_changed.emit()


func _shop_rarity_for_id(id: String) -> String:
	for offer in _build_shop_ingredient_catalog():
		if String(offer.get("id", "")) == id:
			return String(offer.get("rarity", "common"))
	return "common"


func _build_shop_ingredient_catalog() -> Array:
	var rarity_order := ["common", "uncommon", "rare", "epic", "legendary"]
	var shopable: Array = []
	for item in _items_by_id.values():
		if item.get("category") != "ingredient":
			continue
		if int(item.get("tier", 0)) != 0:
			continue
		if bool(item.get("starter", false)):
			continue
		shopable.append(item)
	shopable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name_th", "")) < String(b.get("name_th", ""))
	)
	var offers: Array = []
	for i in shopable.size():
		var item: Dictionary = shopable[i]
		var id := String(item.get("id", ""))
		var bucket := mini(int(float(i) / float(shopable.size()) * 5.0), 4)
		var rarity: String = String(rarity_order[bucket])
		offers.append({
			"id": id,
			"title": item.get("name_th", id),
			"emoji": item.get("emoji", ""),
			"rarity": rarity,
			"rarity_label": _shop_rarity_label(rarity),
			"cost": _shop_rarity_cost(rarity),
		})
	return offers


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
	# เมนูที่ค้นพบ + วัตถุดิบที่ปลดล็อก (เริ่มต้น, ซื้อจากร้าน, หรือผสมได้)
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
	# แถบล่างหน้าทดลอง — ครบตามหน้าสูตรของฉัน โดยของที่ค้นพบล่าสุดอยู่ซ้ายสุด
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


func get_pending_sync() -> Array:
	return _pending_sync.duplicate()


func clear_pending_sync() -> void:
	_pending_sync.clear()
	_save_local_progress()


func get_total_discoverable() -> int:
	return _discoverable_total


func get_item_discovery_points(id: String) -> int:
	var item := get_item(id)
	if item.is_empty() or int(item.get("tier", 0)) < 1:
		return 0
	var tier := int(item.get("tier", 0))
	var branch := _count_branch_factor(id)
	var bonus := mini(branch * 2, 30)
	return tier * 10 + bonus


func _merge_unlocked_from_server(unlocked: Variant) -> void:
	for id in _array_from_variant(unlocked):
		_unlocked_ingredient_ids[String(id)] = true


func apply_server_state(data: Dictionary, defer_reward_wallet: bool = false) -> void:
	var discovered: Array = data.get("discovered", [])
	for id in discovered:
		_discovered_ids[String(id)] = true
	_discovery_points = int(data.get("discovery_points", _discovery_points))
	_craft_count = int(data.get("craft_count", _craft_count))
	var reward_type := String(data.get("reward_type", ""))
	var reward_amount := int(data.get("reward_amount", 0))
	var defer_wallet := defer_reward_wallet and reward_amount > 0 and not reward_type.is_empty()
	if defer_wallet:
		stage_reward({"type": reward_type, "amount": reward_amount})
	else:
		if data.has("coins"):
			_coins = int(data.get("coins", 0))
	if data.has("stars"):
		_stars = int(data.get("stars", 0))
	if data.has("unlocked_ingredients"):
		_merge_unlocked_from_server(data.get("unlocked_ingredients", []))
	_save_local_progress()
	progress_changed.emit()
	if not defer_wallet:
		wallet_changed.emit()


func _count_branch_factor(item_id: String) -> int:
	var count := 0
	for key in _recipes_by_key.keys():
		var parts: PackedStringArray = key.split("|")
		if parts.size() != 2:
			continue
		if parts[0] == item_id or parts[1] == item_id:
			count += 1
	return count


func _load_local_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for id in parsed.get("discovered", []):
		_discovered_ids[String(id)] = true
	_discovery_points = int(parsed.get("discovery_points", 0))
	_craft_count = int(parsed.get("craft_count", 0))
	_pending_sync = parsed.get("pending_sync", []).duplicate()
	_coins = int(parsed.get("coins", 0))
	_stars = int(parsed.get("stars", 0))
	_ads_removed = bool(parsed.get("ads_removed", false))
	_shop_cycle_start = int(parsed.get("shop_cycle_start", 0))
	_shop_manual_reset_count = int(parsed.get("shop_manual_reset_count", 0))
	_shop_item_expires_at = {}
	var shop_expires := _dict_from_variant(parsed.get("shop_item_expires_at", {}))
	for id in shop_expires.keys():
		_shop_item_expires_at[String(id)] = int(shop_expires[id])
	_shop_active_ids = {}
	for id in _array_from_variant(parsed.get("shop_active_ids", [])):
		_shop_active_ids[String(id)] = true
	_unlocked_ingredient_ids = {}
	for id in _array_from_variant(parsed.get("unlocked_ingredients", [])):
		_unlocked_ingredient_ids[String(id)] = true
	_recent_discovered_ids = []
	for id in parsed.get("recent_discovered", []):
		_recent_discovered_ids.append(String(id))
	if _recent_discovered_ids.is_empty() and not _discovered_ids.is_empty():
		_backfill_recent_discoveries()
		if not _recent_discovered_ids.is_empty():
			_save_local_progress()
	if _discovery_points == 0 and not _discovered_ids.is_empty():
		_recalculate_points()


func _save_local_progress() -> void:
	var discovered: Array = []
	for id in _discovered_ids.keys():
		discovered.append(id)
	discovered.sort()
	var unlocked_ingredients: Array = []
	for id in _unlocked_ingredient_ids.keys():
		unlocked_ingredients.append(id)
	unlocked_ingredients.sort()
	var shop_expires: Dictionary = {}
	for id in _shop_item_expires_at.keys():
		shop_expires[String(id)] = int(_shop_item_expires_at[id])
	var shop_active: Array = []
	for id in _shop_active_ids.keys():
		shop_active.append(String(id))
	shop_active.sort()
	var payload := {
		"discovered": discovered,
		"recent_discovered": _recent_discovered_ids.duplicate(),
		"discovery_points": _discovery_points,
		"craft_count": _craft_count,
		"pending_sync": _pending_sync,
		"coins": _coins,
		"stars": _stars,
		"unlocked_ingredients": unlocked_ingredients,
		"ads_removed": _ads_removed,
		"shop_cycle_start": _shop_cycle_start,
		"shop_manual_reset_count": _shop_manual_reset_count,
		"shop_item_expires_at": shop_expires,
		"shop_active_ids": shop_active,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))


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


func _recalculate_points() -> void:
	_discovery_points = 0
	for id in _discovered_ids.keys():
		_discovery_points += get_item_discovery_points(String(id))


func _recipe_key(id_a: String, id_b: String) -> String:
	var pair := [id_a, id_b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]


func _coin_amount(tier: int) -> int:
	var base := 10 + tier * 12
	return base + randi() % (tier * 8 + 1)


func _star_amount(tier: int) -> int:
	if tier <= 2:
		return 1
	return 2


func _dict_from_variant(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _array_from_variant(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []
