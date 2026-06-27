extends Control

@export var discovered: int = 158:
	set(value):
		discovered = value
		_update_text()

@export var total: int = 5000:
	set(value):
		total = value
		_update_text()

@onready var _margin: MarginContainer = $Margin
@onready var _hbox: HBoxContainer = $Margin/HBox
@onready var _discovered_label: RichTextLabel = $Margin/HBox/DiscoveredLabel


func _ready() -> void:
	_update_text()


func set_progress(current: int, max_total: int) -> void:
	discovered = current
	total = max_total


func _update_text() -> void:
	if not is_node_ready():
		return
	var current_text := _format_number(discovered)
	var total_text := _format_number(total)
	_discovered_label.text = (
		"[color=#FFF5E8]ค้นพบแล้ว[/color] "
		+ "[color=#FFD147]%s[/color]" % current_text
		+ "[color=#FFF5E8] / %s[/color]" % total_text
	)
	_resize_to_content()


func _resize_to_content() -> void:
	if not is_node_ready():
		return
	call_deferred("_apply_content_size")


func _apply_content_size() -> void:
	var margin_x := _margin.get_theme_constant("margin_left") + _margin.get_theme_constant("margin_right")
	var margin_y := _margin.get_theme_constant("margin_top") + _margin.get_theme_constant("margin_bottom")
	var content_size := _hbox.get_combined_minimum_size()
	custom_minimum_size = Vector2(content_size.x + margin_x, maxf(content_size.y + margin_y, 44.0))


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
