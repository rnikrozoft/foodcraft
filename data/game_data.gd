extends Node

const DATA_PATH := "res://data/game_data.json"
const SAVE_PATH := "user://player_progress.json"

signal progress_changed

var _items_by_id: Dictionary = {}
var _recipes_by_key: Dictionary = {}
var _discoverable_total: int = 0
var _discovered_ids: Dictionary = {}
var _discovery_points: int = 0
var _craft_count: int = 0
var _pending_sync: Array = []


func _ready() -> void:
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
		results.append(to_display_dict(item["id"]))

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := get_item(a.get("id", ""))
		var item_b := get_item(b.get("id", ""))
		var starter_a := bool(item_a.get("starter", false))
		var starter_b := bool(item_b.get("starter", false))
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
	_save_local_progress()
	progress_changed.emit()
	return is_new


func queue_discovery(item_id: String, from_ids: PackedStringArray) -> void:
	_pending_sync.append({
		"item_id": item_id,
		"from": [from_ids[0], from_ids[1]],
	})
	_save_local_progress()


func record_craft_local() -> void:
	_craft_count += 1
	_save_local_progress()


func get_discovered_count() -> int:
	return _discovered_ids.size()


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


func apply_server_state(data: Dictionary) -> void:
	var discovered: Array = data.get("discovered", [])
	for id in discovered:
		_discovered_ids[String(id)] = true
	_discovery_points = int(data.get("discovery_points", _discovery_points))
	_craft_count = int(data.get("craft_count", _craft_count))
	_save_local_progress()
	progress_changed.emit()


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
	if _discovery_points == 0 and not _discovered_ids.is_empty():
		_recalculate_points()


func _save_local_progress() -> void:
	var discovered: Array = []
	for id in _discovered_ids.keys():
		discovered.append(id)
	discovered.sort()
	var payload := {
		"discovered": discovered,
		"discovery_points": _discovery_points,
		"craft_count": _craft_count,
		"pending_sync": _pending_sync,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))


func _recalculate_points() -> void:
	_discovery_points = 0
	for id in _discovered_ids.keys():
		_discovery_points += get_item_discovery_points(String(id))


func _recipe_key(id_a: String, id_b: String) -> String:
	var pair := [id_a, id_b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]
