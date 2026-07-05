extends Node
## Central rarity/tier palette. Maps a food item's tier (0-5) to a colored item
## frame and an accent color so cards across craft / discovery / recipes / shop
## share one consistent, colorful rarity language instead of a single brown tone.
##
## Ramp: 0 brown (base) → 1 green → 2 blue → 3 purple → 4 gold → 5 red.

const _FRAMES := {
	0: preload("res://assets/Components/Frame/ItemFrame01_Single_Brown.png"),
	1: preload("res://assets/Components/Frame/ItemFrame01_Single_Green.png"),
	2: preload("res://assets/Components/Frame/ItemFrame01_Single_Blue.png"),
	3: preload("res://assets/Components/Frame/ItemFrame01_Single_Purple.png"),
	4: preload("res://assets/Components/Frame/ItemFrame01_Single_Yellow.png"),
	5: preload("res://assets/Components/Frame/ItemFrame01_Single_Red.png"),
}

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


func frame_for_tier(tier: int) -> Texture2D:
	return _FRAMES[_clamp_tier(tier)]


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
