extends Control

const SLOT_EMOJI_SIZE := 112
const RESULT_EMOJI_SIZE := 120
const LOCK_ICON := preload("res://assets/Hyper_Casual_UI/Sprites/Icons/lock.png")
const UNLOCK_ICON := preload("res://assets/Icons/PictoIcon_64/Icon_PictoIcon_Unlock.Png")

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
@onready var _arrow: Label = $Center/VBox/ArrowLabel
@onready var _result_empty: Label = $Center/VBox/ResultSlot/EmptyHint

var _slot_data: Array = [{}, {}]
var _slot_locked: Array[bool] = [false, false]
var _slot_a_emoji: Label
var _slot_b_emoji: Label
var _result_emoji: Label
var _result_shake_tween: Tween
var _input_shake_tween: Tween


func _ready() -> void:
	_slot_a_emoji = _ensure_emoji_label(_slot_a, SLOT_EMOJI_SIZE)
	_slot_b_emoji = _ensure_emoji_label(_slot_b, SLOT_EMOJI_SIZE)
	_result_emoji = _ensure_emoji_label(_result_slot, RESULT_EMOJI_SIZE)
	_slot_a.get_node("RemoveButton").pressed.connect(_on_slot_a_cleared)
	_slot_b.get_node("RemoveButton").pressed.connect(_on_slot_b_cleared)
	_slot_a.get_node("LockButton").pressed.connect(_on_slot_a_lock_toggled)
	_slot_b.get_node("LockButton").pressed.connect(_on_slot_b_lock_toggled)
	_clear_slot(_slot_a, 0, _slot_a_emoji)
	_clear_slot(_slot_b, 1, _slot_b_emoji)
	_reset_result()


func add_ingredient(data: Dictionary) -> bool:
	if not _slot_data[0].is_empty() and not _slot_data[1].is_empty():
		if _slot_locked[0] and _slot_locked[1]:
			_shake_input_slots()
			return true
		_clear_slot(_slot_a, 0, _slot_a_emoji)
		_clear_slot(_slot_b, 1, _slot_b_emoji)
		_reset_result()

	if _slot_data[0].is_empty():
		_set_slot(_slot_a, 0, data, _slot_a_emoji)
	elif _slot_data[1].is_empty():
		_set_slot(_slot_b, 1, data, _slot_b_emoji)
	else:
		return false

	_check_recipe()
	return true


func _on_slot_a_cleared() -> void:
	_clear_slot(_slot_a, 0, _slot_a_emoji, true)
	_check_recipe()


func _on_slot_b_cleared() -> void:
	_clear_slot(_slot_b, 1, _slot_b_emoji, true)
	_check_recipe()


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


func _set_slot(slot: Control, index: int, data: Dictionary, emoji_label: Label) -> void:
	_slot_data[index] = data
	slot.get_node("Glow").visible = false
	slot.get_node("Icon").visible = false
	emoji_label.text = data.get("emoji", "")
	emoji_label.visible = true
	slot.get_node("Title").text = data.get("title", "")
	slot.get_node("Title").visible = true
	slot.get_node("EmptyHint").visible = false
	slot.get_node("RemoveButton").visible = true
	slot.get_node("LockButton").visible = true
	_update_lock_button(slot, index)


func _clear_slot(slot: Control, index: int, emoji_label: Label, force := false) -> void:
	if not force and _slot_locked[index]:
		return
	_slot_locked[index] = false
	_slot_data[index] = {}
	slot.get_node("Glow").visible = false
	slot.get_node("Icon").visible = false
	emoji_label.text = ""
	emoji_label.visible = false
	slot.get_node("Title").text = ""
	slot.get_node("Title").visible = false
	slot.get_node("EmptyHint").visible = true
	slot.get_node("RemoveButton").visible = false
	slot.get_node("LockButton").visible = false


func _check_recipe() -> void:
	if _slot_data[0].is_empty() or _slot_data[1].is_empty():
		_reset_result()
		return

	var from_ids := PackedStringArray([
		_slot_data[0].get("id", ""),
		_slot_data[1].get("id", ""),
	])
	var result_id := GameData.lookup_recipe(from_ids[0], from_ids[1])
	if result_id.is_empty():
		_show_unknown_result()
	else:
		_show_result_async(result_id, from_ids)


func _show_result_async(result_id: String, from_ids: PackedStringArray) -> void:
	var display := GameData.to_display_dict(result_id)
	if display.is_empty():
		_show_unknown_result()
		return

	GameData.record_craft_local()
	var is_new := GameData.mark_discovered(result_id)
	if NakamaService.is_online:
		NakamaService.record_craft(is_new)
	var reward := {}
	if is_new:
		reward = await _grant_discovery_reward(result_id, from_ids)
	_result_icon.visible = false
	_result_emoji.text = display.get("emoji", "")
	_result_emoji.visible = true
	_result_title.text = display.get("title", "")
	_result_title.visible = true
	_result_glow.visible = false
	_result_empty.visible = false
	_new_badge.visible = is_new
	_set_status(_format_result_status(is_new, reward))
	_arrow.modulate = Color(1, 0.85, 0.35, 1)
	if is_new and not reward.is_empty():
		reward_granted.emit(reward, get_result_burst_origin())
	if is_new:
		new_recipe_discovered.emit(display)
	recipe_crafted.emit(result_id, is_new)


func _grant_discovery_reward(result_id: String, from_ids: PackedStringArray) -> Dictionary:
	if NakamaService.is_online:
		var data := await NakamaService.discover_recipe(result_id, from_ids)
		if not data.is_empty() and String(data.get("reward_type", "")) != "":
			return {
				"type": String(data.get("reward_type", "")),
				"amount": int(data.get("reward_amount", 0)),
			}
		if data.is_empty():
			GameData.queue_discovery(result_id, from_ids)
	var reward := GameData.roll_discovery_reward(result_id)
	GameData.apply_reward(reward)
	if not NakamaService.is_online:
		GameData.queue_discovery(result_id, from_ids)
	return reward


func _format_result_status(is_new: bool, reward: Dictionary) -> String:
	var headline := "ค้นพบโดยคุณเมื่อสักครู่" if is_new else "สูตรที่รู้จักแล้ว"
	var amount := int(reward.get("amount", 0))
	if amount <= 0:
		return headline
	if String(reward.get("type", "")) == "star":
		return "%s  |  +%d ดาว" % [headline, amount]
	return "%s  |  +%d เหรียญ" % [headline, amount]


func _show_unknown_result() -> void:
	_result_icon.visible = false
	_result_emoji.visible = false
	_result_title.text = "?"
	_result_title.visible = true
	_result_glow.visible = false
	_result_empty.visible = false
	_new_badge.visible = false
	_set_status("ยังไม่พบสูตรนี้ ลองผสมอย่างอื่นดู")
	_arrow.modulate = Color(0.7, 0.7, 0.7, 1)
	_shake_result_slot()


func _reset_result() -> void:
	_stop_result_shake()
	_stop_input_shake()
	_result_icon.visible = false
	_result_emoji.text = ""
	_result_emoji.visible = false
	_result_title.visible = false
	_result_glow.visible = false
	_result_empty.visible = true
	_new_badge.visible = false
	_set_status("")
	_arrow.modulate = Color(0.55, 0.55, 0.55, 0.8)


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


func _ensure_emoji_label(slot: Control, font_size: int) -> Label:
	var existing := slot.get_node_or_null("Emoji") as Label
	var label := existing
	if label == null:
		label = Label.new()
		label.name = "Emoji"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		label.grow_vertical = Control.GROW_DIRECTION_BOTH
		slot.add_child(label)

	label.offset_left = -105.0
	label.offset_top = -50.0
	label.offset_right = 105.0
	label.offset_bottom = 18.0
	label.add_theme_font_size_override("font_size", font_size)
	return label
