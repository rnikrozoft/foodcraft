extends CanvasLayer

const BUTTON_SCENE := preload("res://components/button.tscn")

@onready var _backdrop: ColorRect = $Backdrop
@onready var _card: PanelContainer = $Center/Card
@onready var _title: Label = $Center/Card/Margin/VBox/TitleLabel
@onready var _message: Label = $Center/Card/Margin/VBox/MessageLabel
@onready var _retry_slot: Control = $Center/Card/Margin/VBox/RetrySlot

var _retry_button: Control


func _ready() -> void:
	layer = 115
	visible = false
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()

	_retry_button = BUTTON_SCENE.instantiate()
	_retry_slot.add_child(_retry_button)
	var retry_label: Label = _retry_button.get_node("Label")
	retry_label.text = "เชื่อมต่อใหม่"
	_retry_button.pressed.connect(_on_retry_pressed)

	NakamaService.connection_lost.connect(_on_connection_lost)
	NakamaService.connection_restored.connect(_on_connection_restored)
	NakamaService.reconnecting.connect(_on_reconnecting)


func _fit_viewport() -> void:
	var rect := get_viewport().get_visible_rect()
	_backdrop.position = rect.position
	_backdrop.size = rect.size


func _on_connection_lost(reason: String) -> void:
	_title.text = "ขาดการเชื่อมต่อ"
	_message.text = reason if not reason.is_empty() else "ตรวจสอบอินเทอร์เน็ตแล้วลองเชื่อมต่อใหม่"
	_set_retry_enabled(true)
	visible = true


func _on_connection_restored() -> void:
	visible = false


func _on_reconnecting(busy: bool) -> void:
	if busy:
		_message.text = "กำลังเชื่อมต่อใหม่..."
	_set_retry_enabled(not busy)


func _set_retry_enabled(enabled: bool) -> void:
	if _retry_button != null:
		_retry_button.disabled = not enabled


func _on_retry_pressed() -> void:
	await NakamaService.try_reconnect()
