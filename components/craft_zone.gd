@tool
extends Control

const LOCK_ICON := preload("res://assets/Vector_UI_Pack_dobo_ui/Icons/128px/tabSelected_icon_128px.png")
const UNLOCK_ICON := preload("res://assets/Vector_UI_Pack_dobo_ui/Icons/128px/tab_icon_128px.png")
const EFFECT_TEX := preload("res://assets/Vector_UI_Pack_dobo_ui/Effects/effect_blue.png")
const EDITOR_PREVIEW_SIZE := Vector2(720, 520)
const EDITOR_PREVIEW_POS := Vector2(0, 184)

signal recipe_crafted(result_id: String, is_new: bool)
signal new_recipe_discovered(display: Dictionary)
signal reward_granted(reward: Dictionary, origin: Vector2)

@onready var _slot_a: Control = $Center/VBox/InputRow/SlotA
@onready var _slot_b: Control = $Center/VBox/InputRow/SlotB
@onready var _result_slot: Control = $Center/VBox/ResultSlot
@onready var _result_icon: TextureRect = $Center/VBox/ResultSlot/Icon
@onready var _result_title: Label = $Center/VBox/ResultSlot/Title
@onready var _result_glow: NinePatchRect = $Center/VBox/ResultSlot/Glow
@onready var _new_badge: TextureRect = $Center/VBox/ResultSlot/NewBadge
@onready var _status: Label = $Center/VBox/StatusWrap/StatusLabel
@onready var _hint_button: Button = $Center/VBox/HintButton

# Display-only; the server (HINT_COST_STARS) is the source of truth for the charge.
const HINT_COST_STARS := 2

var _slot_data: Array = [{}, {}]
var _slot_locked: Array[bool] = [false, false]
var _craft_busy := false
var _slot_a_icon: TextureRect
var _slot_b_icon: TextureRect
var _result_shake_tween: Tween
var _input_shake_tween: Tween
var _slot_bounce_tweens: Dictionary = {}
var _slot_effect_tweens: Dictionary = {}


func _enter_tree() -> void:
	_apply_editor_preview()


func _ready() -> void:
	_slot_a_icon = _slot_a.get_node("BounceRoot/Icon") as TextureRect
	_slot_b_icon = _slot_b.get_node("BounceRoot/Icon") as TextureRect
	_slot_a.get_node("LockButton").pressed.connect(_on_slot_a_lock_toggled)
	_slot_b.get_node("LockButton").pressed.connect(_on_slot_b_lock_toggled)
	_hint_button.pressed.connect(_on_hint_pressed)
	_clear_slot(_slot_a, 0)
	_clear_slot(_slot_b, 1)
	_reset_result()


func _on_hint_pressed() -> void:
	if _craft_busy:
		return
	if not NakamaService.is_online:
		_set_status("ขาดการเชื่อมต่อ — กดเชื่อมต่อใหม่บนหน้าจอ")
		return
	if GameData.get_stars() < HINT_COST_STARS:
		_set_status("เพชรไม่พอ — เติมเพชรได้ที่ร้านค้า")
		return

	_hint_button.disabled = true
	var data := await NakamaService.buy_hint()
	_hint_button.disabled = false

	if bool(data.get("rpc_error", false)):
		_set_status(NakamaService.format_rpc_error(data))
		return
	if not bool(data.get("available", false)):
		_set_status("ไม่มีเบาะแสเพิ่ม — ของที่มีตอนนี้ค้นพบครบแล้ว ลองปลดล็อกวัตถุดิบใหม่ที่ร้านค้า")
		return

	var a_name := String(data.get("a_name", ""))
	var b_name := String(data.get("b_name", ""))
	AudioManager.play_pop()
	_set_status("เบาะแส — ลองผสม: %s + %s" % [a_name, b_name])


func add_ingredient(data: Dictionary) -> bool:
	var id := String(data.get("id", ""))
	if not GameData.can_use_in_craft(id):
		_set_status("ยังใช้วัตถุดิบนี้ไม่ได้ — ปลดล็อกจากร้านค้าหรือค้นพบสูตรก่อน")
		return false
	if not _slot_data[0].is_empty() and not _slot_data[1].is_empty():
		if _slot_locked[0] and _slot_locked[1]:
			_shake_input_slots()
			return true
		_clear_slot(_slot_a, 0)
		_clear_slot(_slot_b, 1)
		_reset_result()

	if _slot_data[0].is_empty():
		_set_slot(_slot_a, 0, data)
	elif _slot_data[1].is_empty():
		_set_slot(_slot_b, 1, data)
	else:
		return false

	AudioManager.play_pop()
	_check_recipe()
	return true


func _on_slot_a_lock_toggled() -> void:
	_toggle_lock(0)


func _on_slot_b_lock_toggled() -> void:
	_toggle_lock(1)


func _toggle_lock(index: int) -> void:
	if _slot_data[index].is_empty():
		return
	_slot_locked[index] = not _slot_locked[index]
	_update_lock_button(_slot_for_index(index), index)


func _slot_for_index(index: int) -> Control:
	return _slot_a if index == 0 else _slot_b


func _update_lock_button(slot: Control, index: int) -> void:
	var btn := slot.get_node("LockButton") as Button
	var locked := _slot_locked[index]
	btn.icon = LOCK_ICON if locked else UNLOCK_ICON
	btn.modulate = Color(1.0, 0.92, 0.45) if locked else Color.WHITE


func _set_slot(slot: Control, index: int, data: Dictionary) -> void:
	_slot_data[index] = data
	var icon := slot.get_node("BounceRoot/Icon") as TextureRect
	FoodIcons.apply_to(icon, String(data.get("id", "")))
	slot.get_node("BounceRoot/Title").text = data.get("title", "")
	slot.get_node("BounceRoot/Title").visible = true
	slot.get_node("LockButton").visible = true
	_update_lock_button(slot, index)
	_bounce_slot_content(slot)
	_start_slot_effect(slot)


func _clear_slot(slot: Control, index: int) -> void:
	if _slot_locked[index]:
		return
	_stop_slot_bounce(slot)
	_stop_slot_effect(slot)
	_slot_locked[index] = false
	_slot_data[index] = {}
	var icon := slot.get_node("BounceRoot/Icon") as TextureRect
	icon.texture = null
	icon.visible = false
	icon.scale = Vector2.ONE
	var title := slot.get_node("BounceRoot/Title") as Label
	title.text = ""
	title.visible = false
	title.scale = Vector2.ONE
	var bounce_root := slot.get_node("BounceRoot") as Control
	bounce_root.scale = Vector2.ONE
	bounce_root.pivot_offset = bounce_root.size * 0.5
	slot.get_node("LockButton").visible = false


func _check_recipe() -> void:
	if _slot_data[0].is_empty() or _slot_data[1].is_empty():
		_reset_result()
		return

	var from_ids := PackedStringArray([
		_slot_data[0].get("id", ""),
		_slot_data[1].get("id", ""),
	])
	for ingredient_id in from_ids:
		if not GameData.can_use_in_craft(String(ingredient_id)):
			_show_unknown_result()
			return
	_attempt_craft(from_ids)


func _attempt_craft(from_ids: PackedStringArray) -> void:
	if _craft_busy:
		return
	if not NakamaService.is_online:
		_set_status("ขาดการเชื่อมต่อ — กดเชื่อมต่อใหม่บนหน้าจอ")
		_shake_result_slot()
		return

	_craft_busy = true
	_result_icon.visible = false
	_result_title.visible = true
	_new_badge.visible = false

	var data := await NakamaService.process_craft(from_ids)
	_craft_busy = false

	if not _slots_match(from_ids):
		_check_recipe()
		return

	if bool(data.get("rpc_error", false)):
		if NakamaService.is_rate_limit_error(data):
			_reset_result()
			return
		if NakamaService.is_unknown_recipe_error(data):
			_show_unknown_result()
		else:
			_set_status(NakamaService.format_rpc_error(data))
			_shake_result_slot()
		return

	var result_id := String(data.get("item_id", ""))
	if result_id.is_empty():
		_show_unknown_result()
		return

	_show_craft_result(result_id, from_ids, data)


func _slots_match(from_ids: PackedStringArray) -> bool:
	if _slot_data[0].is_empty() or _slot_data[1].is_empty():
		return false
	return (
		String(_slot_data[0].get("id", "")) == from_ids[0]
		and String(_slot_data[1].get("id", "")) == from_ids[1]
	)


func _show_craft_result(result_id: String, _from_ids: PackedStringArray, data: Dictionary) -> void:
	var display := GameData.to_display_dict(result_id)
	if display.is_empty():
		_show_unknown_result()
		return

	var is_new := bool(data.get("is_new", false))
	var result_kind := GameData.craft_result_kind(result_id)
	var reward := {}
	var reward_type := String(data.get("reward_type", ""))
	if not reward_type.is_empty():
		reward = {
			"type": reward_type,
			"amount": int(data.get("reward_amount", 0)),
		}
	if is_new:
		GameData.note_server_discovery(result_id)

	FoodIcons.apply_to(_result_icon, result_id)
	_result_title.text = display.get("title", "")
	_result_title.visible = true
	_new_badge.visible = is_new
	_set_status(_format_result_status(is_new, result_kind, reward))
	if is_new and not reward.is_empty():
		reward_granted.emit(reward, get_result_burst_origin())
	if is_new:
		new_recipe_discovered.emit(display)
	AudioManager.play_pop()
	recipe_crafted.emit(result_id, is_new)


func _format_result_status(is_new: bool, result_kind: String, reward: Dictionary) -> String:
	var headline := ""
	match result_kind:
		"ingredient":
			headline = "ปลดล็อกวัตถุดิบใหม่!" if is_new else "วัตถุดิบที่มีแล้ว"
		_:
			headline = "ค้นพบโดยคุณเมื่อสักครู่" if is_new else "สูตรที่รู้จักแล้ว"
	var amount := int(reward.get("amount", 0))
	if amount <= 0:
		return headline
	if String(reward.get("type", "")) == "star":
		return "%s  |  +%d ดาว" % [headline, amount]
	return "%s  |  +%d เหรียญ" % [headline, amount]


func _show_unknown_result() -> void:
	_result_icon.visible = false
	_result_title.text = ""
	_result_title.visible = false
	_new_badge.visible = false
	_set_status("ยังไม่พบสูตรนี้ ลองผสมอย่างอื่นดู")
	_shake_result_slot()


func _reset_result() -> void:
	_stop_result_shake()
	_stop_input_shake()
	_result_icon.texture = null
	_result_icon.visible = false
	_result_title.visible = false
	_new_badge.visible = false
	_set_status("")


func _set_status(message: String) -> void:
	_status.text = message


func _shake_result_slot() -> void:
	_stop_result_shake()
	_result_slot.pivot_offset = _result_slot.size * 0.5

	var strength := deg_to_rad(5.0)
	_result_shake_tween = create_tween()
	_result_shake_tween.tween_property(_result_slot, "rotation", strength, 0.04).set_trans(Tween.TRANS_SINE)
	_result_shake_tween.tween_property(_result_slot, "rotation", -strength, 0.08).set_trans(Tween.TRANS_SINE)
	_result_shake_tween.tween_property(_result_slot, "rotation", strength * 0.55, 0.07).set_trans(Tween.TRANS_SINE)
	_result_shake_tween.tween_property(_result_slot, "rotation", 0.0, 0.06).set_trans(Tween.TRANS_SINE)


func _shake_input_slots() -> void:
	_stop_input_shake()
	var slots: Array[Control] = [_slot_a, _slot_b]
	for slot in slots:
		slot.pivot_offset = slot.size * 0.5

	var strength := deg_to_rad(5.0)
	_input_shake_tween = create_tween()
	_shake_tween_step(_input_shake_tween, slots[0], strength, 0.04, slots[1])
	_shake_tween_step(_input_shake_tween, slots[0], -strength, 0.08, slots[1])
	_shake_tween_step(_input_shake_tween, slots[0], strength * 0.55, 0.07, slots[1])
	_shake_tween_step(_input_shake_tween, slots[0], 0.0, 0.06, slots[1])


func _shake_tween_step(
	tween: Tween,
	primary: Control,
	rotation: float,
	duration: float,
	secondary: Control = null
) -> void:
	tween.tween_property(primary, "rotation", rotation, duration).set_trans(Tween.TRANS_SINE)
	if secondary != null:
		tween.parallel().tween_property(secondary, "rotation", rotation, duration).set_trans(Tween.TRANS_SINE)


func _play_slot_bounce(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	var bounce_root := slot.get_node("BounceRoot") as Control
	var icon := bounce_root.get_node("Icon") as TextureRect
	if not icon.visible:
		return

	_stop_slot_bounce(slot)
	bounce_root.scale = Vector2(0.72, 0.72)
	bounce_root.pivot_offset = bounce_root.size * 0.5
	if bounce_root.pivot_offset == Vector2.ZERO:
		bounce_root.pivot_offset = Vector2(125.0, 125.0)

	var tween := bounce_root.create_tween()
	_slot_bounce_tweens[slot.get_instance_id()] = tween
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bounce_root, "scale", Vector2(1.16, 1.16), 0.14)
	tween.tween_property(bounce_root, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)


func _stop_slot_bounce(slot: Control) -> void:
	var key := slot.get_instance_id()
	if _slot_bounce_tweens.has(key):
		var old_tween: Tween = _slot_bounce_tweens[key]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_slot_bounce_tweens.erase(key)
	var bounce_root := slot.get_node("BounceRoot") as Control
	bounce_root.scale = Vector2.ONE


func _bounce_slot_content(slot: Control) -> void:
	# Layout settles after the slot icon/title update; then play the pop bounce.
	if not is_instance_valid(slot):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(slot):
		return

	var bounce_root := slot.get_node("BounceRoot") as Control
	bounce_root.pivot_offset = bounce_root.size * 0.5
	if bounce_root.pivot_offset == Vector2.ZERO:
		bounce_root.pivot_offset = Vector2(125.0, 125.0)
	_play_slot_bounce(slot)


func _stop_result_shake() -> void:
	if _result_shake_tween != null and _result_shake_tween.is_valid():
		_result_shake_tween.kill()
	_result_shake_tween = null
	_result_slot.rotation = 0.0


func _stop_input_shake() -> void:
	if _input_shake_tween != null and _input_shake_tween.is_valid():
		_input_shake_tween.kill()
	_input_shake_tween = null
	_slot_a.rotation = 0.0
	_slot_b.rotation = 0.0


func get_result_burst_origin() -> Vector2:
	return _result_slot.get_global_rect().get_center()


func _start_slot_effect(slot: Control) -> void:
	_stop_slot_effect(slot)
	var bounce_root := slot.get_node("BounceRoot") as Control
	var effect := TextureRect.new()
	effect.name = "EffectSprite"
	effect.texture = EFFECT_TEX
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Center at same position as the food icon (icon center is at anchor 50%,50% offset -80,-85,80,30)
	effect.set_anchors_preset(Control.PRESET_CENTER)
	var half := 90.0
	var icon_center_y := (-85.0 + 30.0) / 2.0  # = -27.5
	effect.offset_left   = -half
	effect.offset_top    = icon_center_y - half
	effect.offset_right  = half
	effect.offset_bottom = icon_center_y + half
	effect.pivot_offset  = Vector2(half, half)
	bounce_root.add_child(effect)
	bounce_root.move_child(effect, 0)  # behind icon and title
	var tween := create_tween().set_loops()
	tween.tween_property(effect, "rotation", TAU, 26.0).from(0.0)
	_slot_effect_tweens[slot] = {"node": effect, "tween": tween}


func _stop_slot_effect(slot: Control) -> void:
	if not _slot_effect_tweens.has(slot):
		return
	var entry: Dictionary = _slot_effect_tweens[slot]
	var t: Tween = entry.get("tween")
	if t and t.is_valid():
		t.kill()
	var n: TextureRect = entry.get("node")
	if n and is_instance_valid(n):
		n.queue_free()
	_slot_effect_tweens.erase(slot)


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if get_tree().edited_scene_root == self:
		custom_minimum_size = EDITOR_PREVIEW_SIZE
		position = EDITOR_PREVIEW_POS
		size = EDITOR_PREVIEW_SIZE
	else:
		custom_minimum_size = Vector2.ZERO
		position = Vector2.ZERO
