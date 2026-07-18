extends Node
## Central rarity/tier palette. Every tier shares the SAME card frame image;
## the tier is communicated purely through color instead of a different frame
## per tier: Bg.self_modulate stays a fixed translucent white wash, and
## Bg.modulate carries the tier's hue on top of it (tier 0 = no hue, plain
## white wash only).
##
## Ramp: 0 plain (base) → 1 green → 2 blue → 3 purple → 4 orange → 5 red.
##
## To swap the shared frame image, open services/rarity_style.tscn, select the
## root node, and drag a texture onto the "Frame Texture" slot in the
## Inspector — no code editing needed.

## Shared frame texture used by every tier.
@export var frame_texture: Texture2D = preload("res://assets/frames/custom/BasicFrame_Square02_White1.png")

## Applied to Bg.self_modulate on every tier — a constant translucent white wash.
const BG_SELF_MODULATE := Color("ffffff58")

## Index i holds the Bg.modulate tint for tier i (0-5). Tier 0 stays plain
## white (no hue tint, just the self_modulate wash above).
@export var tier_modulate: Array[Color] = [
	Color("ffffffff"),
	Color("53ab80"),
	Color("076eb0"),
	Color("a51bad"),
	Color("ad4303"),
	Color("c2172c"),
]

# Soft accent colors used for item names / small highlights (kept readable on dark bg).
const _ACCENTS := {
	0: Color(0.86, 0.78, 0.66, 1.0),  # warm sand
	1: Color(0.62, 0.90, 0.55, 1.0),  # green
	2: Color(0.53, 0.78, 1.00, 1.0),  # blue
	3: Color(0.80, 0.63, 1.00, 1.0),  # purple
	4: Color(1.00, 0.86, 0.35, 1.0),  # gold
	5: Color(1.00, 0.55, 0.50, 1.0),  # red
}

const MAX_TIER := 5


func _clamp_tier(tier: int) -> int:
	return clampi(tier, 0, MAX_TIER)


func frame_for_tier(_tier: int) -> Texture2D:
	return frame_texture


func bg_self_modulate() -> Color:
	return BG_SELF_MODULATE


func bg_modulate_for_tier(tier: int) -> Color:
	var i := _clamp_tier(tier)
	if i >= tier_modulate.size():
		return Color.WHITE
	return tier_modulate[i]


func color_for_tier(tier: int) -> Color:
	return _ACCENTS[_clamp_tier(tier)]


func tier_for_id(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	return int(GameData.get_item(item_id).get("tier", 0))


func frame_for_id(item_id: String) -> Texture2D:
	return frame_for_tier(tier_for_id(item_id))


func color_for_id(item_id: String) -> Color:
	return color_for_tier(tier_for_id(item_id))
