extends CanvasLayer

const COIN_TEXTURE := preload("res://assets/ui_etc/ResourceBar_Icon_Coin.png")
const STAR_TEXTURE := preload("res://assets/ui_etc/ResourceBar_Icon_Gem_Purple.png")

const MIN_PARTICLES := 4
const MAX_PARTICLES := 12
const FLY_DURATION := 0.98
const STAGGER_DELAY := 0.055
const START_SCALE := 0.58
const PEAK_SCALE := 1.28
const END_SCALE := 0.72

@onready var _particles: Node2D = $Particles


func play(reward: Dictionary, from_global: Vector2, to_global: Vector2) -> void:
	var reward_type := String(reward.get("type", ""))
	var amount := int(reward.get("amount", 0))
	if reward_type.is_empty() or amount <= 0:
		return

	var texture := COIN_TEXTURE if reward_type == "coin" else STAR_TEXTURE
	var count := clampi(maxi(1, amount / 3), MIN_PARTICLES, MAX_PARTICLES)
	var longest := 0.0
	for i in count:
		var delay := float(i) * STAGGER_DELAY
		longest = maxf(longest, delay + FLY_DURATION + 0.14)
		_spawn_fly_particle(texture, from_global, to_global, delay)

	await get_tree().create_timer(longest).timeout
	if reward_type == "coin":
		AudioManager.play_coin()


func _spawn_fly_particle(texture: Texture2D, from_global: Vector2, to_global: Vector2, delay: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2(START_SCALE, START_SCALE)
	sprite.modulate = Color(1, 1, 1, 0)
	_particles.add_child(sprite)

	var spread := Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
	var start := from_global + spread
	var end := to_global + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	var lift := Vector2(randf_range(-50.0, 50.0), randf_range(-90.0, -35.0))
	var control := (start + end) * 0.5 + lift

	sprite.global_position = start

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(PEAK_SCALE, PEAK_SCALE), 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_method(
		func(t: float) -> void: sprite.global_position = _bezier_point(start, control, end, t),
		0.0,
		1.0,
		FLY_DURATION
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "scale", Vector2(END_SCALE, END_SCALE), 0.2).set_delay(FLY_DURATION - 0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.14).set_delay(FLY_DURATION - 0.12)
	tween.finished.connect(sprite.queue_free)


func _bezier_point(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return inv * inv * start + 2.0 * inv * t * control + t * t * end
