extends Node

signal session_ready(profile: Dictionary)
signal session_failed(message: String)
signal leaderboard_loaded(data: Dictionary)
signal leaderboards_loaded(boards: Array)
signal hall_of_fame_loaded(data: Dictionary)
signal discovery_synced(data: Dictionary)

const DEVICE_ID_PATH := "user://device_id.txt"

var session_token: String = ""
var user_id: String = ""
var username: String = ""
var profile: Dictionary = {}
var is_online: bool = false

var _config: Node


func _ready() -> void:
	_config = NakamaConfig


func authenticate_guest(display_name: String = "") -> bool:
	var device_id := _get_device_id()
	var guest_name := display_name if not display_name.is_empty() else _make_guest_username(device_id)
	var url := "%s/v2/account/authenticate/device?create=true&username=%s" % [
		_config.get_base_url(),
		guest_name.uri_encode()
	]
	var body := JSON.stringify({"id": device_id})
	var response := await _request(HTTPClient.METHOD_POST, url, body, false)
	if response.is_empty() or not response.has("token"):
		is_online = false
		session_failed.emit("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้")
		return false

	session_token = String(response.get("token", ""))
	is_online = true
	username = guest_name
	await refresh_profile()
	session_ready.emit(profile)
	return true


func refresh_profile() -> void:
	var data := await call_rpc("get_profile", "")
	if data.is_empty():
		return
	profile = data
	username = String(profile.get("username", username))
	user_id = String(profile.get("user_id", user_id))
	GameData.apply_server_state(profile)


func discover_recipe(item_id: String, from_ids: PackedStringArray) -> Dictionary:
	return await _discover_recipe_async(item_id, from_ids)


func _discover_recipe_async(item_id: String, from_ids: PackedStringArray) -> Dictionary:
	var payload := {
		"item_id": item_id,
		"from": [from_ids[0], from_ids[1]],
	}
	var data := await call_rpc("discover_recipe", JSON.stringify(payload))
	if data.is_empty():
		GameData.queue_discovery(item_id, from_ids)
		return {}
	discovery_synced.emit(data)
	GameData.apply_server_state(data, true)
	return data


func sync_discoveries(queue: Array, craft_count: int) -> Dictionary:
	var discoveries: Array = []
	for entry in queue:
		discoveries.append(entry)
	var payload := {
		"discoveries": discoveries,
		"craft_count": craft_count,
	}
	var data := await call_rpc("sync_discoveries", JSON.stringify(payload))
	if not data.is_empty():
		discovery_synced.emit(data)
		GameData.apply_server_state(data)
	return data


func record_craft(is_new_discovery: bool = false) -> void:
	if not is_online:
		return
	var payload := JSON.stringify({"is_new_discovery": is_new_discovery})
	await call_rpc("record_craft", payload)


func fetch_leaderboard_list() -> Array:
	var data := await call_rpc("list_leaderboards", "")
	var boards: Array
	if data.is_empty():
		boards = NakamaConfig.get_fallback_boards()
	else:
		boards = data.get("boards", [])
		if boards.is_empty():
			boards = NakamaConfig.get_fallback_boards()
	leaderboards_loaded.emit(boards)
	return boards


func fetch_hall_of_fame() -> Dictionary:
	var payload := JSON.stringify({"limit": 30})
	var data := await call_rpc("get_hall_of_fame", payload)
	hall_of_fame_loaded.emit(data)
	return data


func fetch_leaderboard(board_id: String) -> Dictionary:
	var payload := JSON.stringify({"board_id": board_id, "limit": 20})
	var data := await call_rpc("get_leaderboard", payload)
	leaderboard_loaded.emit(data)
	return data


func call_rpc(rpc_id: String, payload: String) -> Dictionary:
	if session_token.is_empty():
		return {}
	var url := "%s/v2/rpc/%s" % [_config.get_base_url(), rpc_id]
	var body := JSON.stringify(payload)
	var response := await _request(HTTPClient.METHOD_POST, url, body, true)
	if response.is_empty():
		return {}
	if response.has("payload") and typeof(response["payload"]) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(response["payload"])
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return response


func _request(method: int, url: String, body: String, use_session: bool) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var headers: PackedStringArray = ["Content-Type: application/json", "Accept: application/json"]
	if use_session:
		headers.append("Authorization: Bearer %s" % session_token)
	else:
		headers.append("Authorization: Basic %s" % Marshalls.utf8_to_base64("%s:" % _config.SERVER_KEY))

	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		push_warning("Nakama HTTP %s -> %s" % [url, response_body])
		return {}

	if response_body.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(response_body)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func get_display_name() -> String:
	if not username.is_empty():
		return username
	return _make_guest_username(_get_device_id())


func _make_guest_username(device_id: String) -> String:
	var hash := hash(device_id)
	var short_code := "%04X" % (hash & 0xFFFF)
	return "Chef_%s" % short_code


func _get_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file := FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if file:
			var existing := file.get_as_text().strip_edges()
			if not existing.is_empty():
				return existing

	var generated := "%s-%s" % [OS.get_unique_id(), str(Time.get_unix_time_from_system())]
	var write := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if write:
		write.store_string(generated)
	return generated
