@tool
extends Control
class_name IngredientGridCard

signal pressed

@export var title: String = "ข้าว":
	set(value):
		title = value
		if is_node_ready():
			_name_label.text = value

@export var food_id: String = "":
	set(value):
		food_id = value
		if is_node_ready() and not Engine.is_editor_hint():
			_apply_icon()

@onready var _bg: NinePatchRect = $Bg
@onready var _icon: TextureRect = $VBox/Icon
@onready var _name_label: Label = $VBox/NameLabel
@onready var _click: Button = $ClickArea
@onready var _craftable_badge: PanelContainer = $CraftableBadge
@onready var _craftable_badge_label: Label = $CraftableBadge/CraftableBadgeLabel


func _ready() -> void:
	_name_label.text = title
	if Engine.is_editor_hint():
		return
	_apply_icon()
	_apply_rarity()
	_apply_craftable_badge()
	_click.pressed.connect(func() -> void: pressed.emit())


func apply_display(data: Dictionary) -> void:
	title = String(data.get("title", ""))
	food_id = String(data.get("id", ""))


func _apply_icon() -> void:
	FoodIcons.apply_to(_icon, food_id)
	_apply_rarity()
	_apply_craftable_badge()


# Top-right badge: how many more distinct recipes this item can still lead
# to that aren't discovered yet (server-computed; see GameData.get_craftable_count).
func _apply_craftable_badge() -> void:
	if not is_node_ready() or Engine.is_editor_hint() or food_id.is_empty():
		return
	var count := GameData.get_craftable_count(food_id)
	_craftable_badge.visible = count > 0
	if count > 0:
		_craftable_badge_label.text = str(count) if count < 100 else "99+"


# All tiers share the same Bg frame texture now; the tier reads out purely as
# color: a constant translucent white wash (self_modulate) plus a per-tier hue
# on top (modulate, tier 0 = no hue).
func _apply_rarity() -> void:
	if not is_node_ready() or Engine.is_editor_hint() or food_id.is_empty():
		return
	var tier := RarityStyle.tier_for_id(food_id)
	_bg.texture = RarityStyle.frame_for_tier(tier)
	_bg.self_modulate = RarityStyle.bg_self_modulate()
	_bg.modulate = RarityStyle.bg_modulate_for_tier(tier)
	_name_label.add_theme_color_override("font_color", RarityStyle.color_for_tier(tier))
