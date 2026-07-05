extends Node

## AudioManager — autoload singleton
## Usage: AudioManager.play_pop()
##        AudioManager.play_pop(-6.0)   # ลดเสียง 6 dB

const POP_STREAM := preload("res://assets/audio/pop1.wav")
const BGM_STREAM := preload("res://assets/audio/background.wav")

var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = BGM_STREAM
	_bgm_player.volume_db = -7.0
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	_bgm_player.finished.connect(_bgm_player.play)  # loop
	_bgm_player.play()


func play_pop(volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = POP_STREAM
	player.volume_db = volume_db
	player.bus = "Master"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
