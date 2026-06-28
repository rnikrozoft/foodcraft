extends Node

const FOOD_COUNT := 36
const FOOD_PATH := "res://assets/foods/%d.png"

var _textures: Array[Texture2D] = []
var _sprite_num_by_id: Dictionary = {}


func _ready() -> void:
	for i in range(1, FOOD_COUNT + 1):
		_textures.append(load(FOOD_PATH % i) as Texture2D)


func register_catalog(item_ids: Array) -> void:
	var ids: Array[String] = []
	for id in item_ids:
		ids.append(String(id))
	ids.sort()
	_sprite_num_by_id.clear()
	for i in range(ids.size()):
		_sprite_num_by_id[ids[i]] = (i % FOOD_COUNT) + 1


func get_texture(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var num: int = int(_sprite_num_by_id.get(item_id, _fallback_sprite_num(item_id)))
	if num < 1 or num > FOOD_COUNT:
		return null
	return _textures[num - 1]


func apply_to(icon: TextureRect, item_id: String) -> void:
	var tex := get_texture(item_id)
	icon.texture = tex
	icon.visible = tex != null


func _fallback_sprite_num(item_id: String) -> int:
	var h := item_id.hash()
	return ((h % FOOD_COUNT) + FOOD_COUNT) % FOOD_COUNT + 1
