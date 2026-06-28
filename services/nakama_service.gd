extends Node

signal session_ready(profile: Dictionary)
signal session_failed(message: String)
signal connection_lost(reason: String)
signal connection_restored()
signal reconnecting(busy: bool)
signal game_config_loaded(config: Dictionary)
signal leaderboard_loaded(data: Dictionary)
signal leaderboards_loaded(boards: Array)
signal hall_of_fame_loaded(data: Dictionary)
signal discovery_synced(data: Dictionary)

const DEVICE_ID_PATH := "user://device_id.txt"
const HEALTH_CHECK_SEC := 30.0

var session_token: String = ""
var user_id: String = ""
var username: String = ""
var profile: Dictionary = {}
var is_online: bool = false

var _config: Node
var _reconnect_busy: bool = false
var _health_timer: Timer


func _ready() -> void:
	_config = NakamaConfig
	_health_timer = Timer.new()
	_health_timer.wait_time = HEALTH_CHECK_SEC
	_health_timer.autostart = true
	_health_timer.timeout.connect(_on_health_check)
	add_child(_health_timer)


func authenticate_guest(display_name: String = "") -> bool:
	var device_id := _get_device_id()
	var guest_name := display_name if not display_name.is_empty() else _make_guest_username(device_id)
	var ok := await _establish_session(device_id, guest_name)
	if ok:
		session_ready.emit(profile)
	else:
		session_failed.emit("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้")
	return ok


func try_reconnect() -> bool:
	if _reconnect_busy:
		return false
	_reconnect_busy = true
	reconnecting.emit(true)

	var device_id := _get_device_id()
	var guest_name := username if not username.is_empty() else _make_guest_username(device_id)
	var ok := await _establish_session(device_id, guest_name)

	_reconnect_busy = false
	reconnecting.emit(false)

	if ok:
		connection_restored.emit()
	else:
		connection_lost.emit("เชื่อมต่อไม่สำเร็จ — ลองอีกครั้ง")
	return ok


func refresh_profile() -> void:
	var data := await call_rpc("get_profile", "")
	if bool(data.get("rpc_error", false)):
		return
	if data.is_empty():
		return
	profile = data
	username = String(profile.get("username", username))
	user_id = String(profile.get("user_id", user_id))
	GameData.apply_server_state(profile)


func fetch_game_config() -> Dictionary:
	var data := await call_rpc("get_game_config", "")
	if bool(data.get("rpc_error", false)):
		return {}
	if data.is_empty():
		return {}
	GameData.apply_catalog_from_server(data)
	game_config_loaded.emit(data)
	return data


func fetch_shop_state() -> Dictionary:
	var data := await call_rpc("get_shop_state", "")
	if bool(data.get("rpc_error", false)):
		return data
	if not data.is_empty():
		GameData.apply_shop_state_from_server(data)
	return data


func purchase_shop_ingredient(ingredient_id: String) -> Dictionary:
	var payload := JSON.stringify({"ingredient_id": ingredient_id})
	var data := await call_rpc("purchase_shop_ingredient", payload)
	if bool(data.get("rpc_error", false)):
		return data
	if not data.is_empty():
		GameData.apply_shop_state_from_server(data)
	return data


func process_craft(from_ids: PackedStringArray) -> Dictionary:
	var payload := {
		"from": [from_ids[0], from_ids[1]],
	}
	var data := await call_rpc("process_craft", JSON.stringify(payload))
	if bool(data.get("rpc_error", false)):
		return data
	if data.is_empty():
		return {"rpc_error": true, "error_message": "empty response"}
	discovery_synced.emit(data)
	GameData.apply_server_state(data)
	return data


func fetch_leaderboard_list() -> Array:
	var data := await call_rpc("list_leaderboards", "")
	var boards: Array
	if data.is_empty() or bool(data.get("rpc_error", false)):
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
		_mark_connection_lost("ไม่ได้เข้าสู่ระบบ — กดเชื่อมต่อใหม่")
		return {"rpc_error": true, "error_message": "ไม่ได้เข้าสู่ระบบ"}
	var url := "%s/v2/rpc/%s" % [_config.get_base_url(), rpc_id]
	var body := JSON.stringify(payload)
	var response := await _request(HTTPClient.METHOD_POST, url, body, true)
	if _is_connection_failure(response):
		var reason := String(response.get("error_message", "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้"))
		_mark_connection_lost(reason)
		return {"rpc_error": true, "error_message": reason}
	if response.is_empty():
		_mark_connection_lost("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้")
		return {"rpc_error": true, "error_message": "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้"}
	if bool(response.get("rpc_error", false)):
		return response
	if response.has("payload") and typeof(response["payload"]) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(response["payload"])
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return response


func is_unknown_recipe_error(data: Dictionary) -> bool:
	var message := String(data.get("error_message", ""))
	return message in ["invalid recipe combination", "item is not a valid craft result"]


func format_rpc_error(data: Dictionary) -> String:
	var message := String(data.get("error_message", ""))
	match message:
		"insufficient coins":
			return "เหรียญบนเซิร์ฟเวอร์ไม่พอ (มี %d เหรียญ)" % GameData.get_coins()
		"ingredient not available":
			return "วัตถุดิบนี้ไม่อยู่ในร้านรอบนี้ — รอร้านเปลี่ยนสินค้าเที่ยงคืน"
		"already unlocked":
			return "ปลดล็อกวัตถุดิบนี้แล้ว"
		"daily reward already claimed":
			return "รับเหรียญรายวันแล้ว — กลับมาพรุ่งนี้นะ"
		"เชื่อมต่อเซิร์ฟเวอร์ไม่ได้", "ไม่ได้เข้าสู่ระบบ", "เซสชันหมดอายุ — กดเชื่อมต่อใหม่":
			return message
		"too many requests":
			return "เร็วเกินไป — รอสักครู่แล้วลองใหม่"
		"invalid recipe combination":
			return "ยังไม่พบสูตรนี้ ลองผสมอย่างอื่นดู"
	if message.is_empty():
		return "เกิดข้อผิดพลาด — ลองใหม่อีกครั้ง"
	return message


func fetch_daily_reward_status() -> Dictionary:
	var data := await call_rpc("get_daily_reward", "")
	if bool(data.get("rpc_error", false)):
		return data
	if not data.is_empty():
		GameData.apply_daily_reward_status_from_server(data)
	return data


func claim_daily_reward() -> Dictionary:
	var data := await call_rpc("claim_daily_reward", "")
	if bool(data.get("rpc_error", false)):
		return data
	if not data.is_empty():
		if data.has("coins") or data.has("stars"):
			GameData.apply_wallet_from_server(data)
		GameData.apply_daily_reward_status_from_server(data)
	return data


func sync_wallet() -> Dictionary:
	var data := await call_rpc("sync_wallet", "")
	if bool(data.get("rpc_error", false)):
		return data
	if not data.is_empty():
		GameData.apply_wallet_from_server(data)
	return data


func get_display_name() -> String:
	if not username.is_empty():
		return username
	return _make_guest_username(_get_device_id())


func _establish_session(device_id: String, guest_name: String) -> bool:
	var url := "%s/v2/account/authenticate/device?create=true&username=%s" % [
		_config.get_base_url(),
		guest_name.uri_encode()
	]
	var body := JSON.stringify({"id": device_id})
	var response := await _request(HTTPClient.METHOD_POST, url, body, false)
	if _is_connection_failure(response) or response.is_empty() or not response.has("token"):
		is_online = false
		session_token = ""
		return false

	session_token = String(response.get("token", ""))
	is_online = true
	username = guest_name
	await refresh_profile()
	if not is_online:
		return false
	await fetch_game_config()
	if not is_online or not GameData.is_catalog_loaded():
		is_online = false
		return false
	await sync_wallet()
	if not is_online:
		return false
	await fetch_shop_state()
	if not is_online:
		return false
	return true


func _mark_connection_lost(reason: String) -> void:
	if not is_online:
		return
	is_online = false
	connection_lost.emit(reason)


func _is_connection_failure(response: Dictionary) -> bool:
	if response.is_empty():
		return false
	return bool(response.get("connection_error", false))


func _on_health_check() -> void:
	if not is_online or session_token.is_empty() or _reconnect_busy:
		return
	await sync_wallet()


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
		return {
			"rpc_error": true,
			"connection_error": true,
			"error_message": "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้",
		}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	if response_code == 401:
		return {
			"rpc_error": true,
			"connection_error": true,
			"error_message": "เซสชันหมดอายุ — กดเชื่อมต่อใหม่",
		}
	if response_code == 0 or response_code >= 500:
		return {
			"rpc_error": true,
			"connection_error": true,
			"error_message": "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้",
		}
	if response_code < 200 or response_code >= 300:
		push_warning("Nakama HTTP %s -> %s" % [url, response_body])
		var parsed: Variant = JSON.parse_string(response_body)
		if typeof(parsed) == TYPE_DICTIONARY:
			return {
				"rpc_error": true,
				"error_message": String(parsed.get("message", parsed.get("error", "RPC failed"))),
			}
		return {"rpc_error": true, "error_message": "RPC failed (%d)" % response_code}

	if response_body.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(response_body)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


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
