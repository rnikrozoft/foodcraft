extends CanvasLayer

const HOLD_SECONDS := 3.0
const FADE_SECONDS := 0.8
const SKIP_FADE_SECONDS := 0.25
const FLASH_FADE_IN := 0.22
const FLASH_HOLD := 0.18
const FLASH_FADE_OUT := 0.75
const DIM_ALPHA := 0.78
const STAR_LIFETIME_MIN := 4.6
const STAR_LIFETIME_MAX := 5.4

signal celebration_finished

@onready var _celebration_stack: Control = $CelebrationStack
@onready var _dim: ColorRect = $CelebrationStack/Dim
@onready var _flash: ColorRect = $CelebrationStack/Root/Flash
@onready var _content: Control = $CelebrationStack/Root/Center/Content
@onready var _particles_root: Node2D = $CelebrationStack/ParticlesRoot
@onready var _header: Label = $CelebrationStack/Root/Center/Content/VBox/Header
@onready var _emoji: Label = $CelebrationStack/Root/Center/Content/VBox/Emoji
@onready var _title: Label = $CelebrationStack/Root/Center/Content/VBox/Title

var _bursts: Array[CPUParticles2D] = []
var _star_bursts: Array[CPUParticles2D] = []
var _sparkle_burst: CPUParticles2D
var _flash_burst: CPUParticles2D
var _playing := false
var _skip_requested := false
var _active_tween: Tween


func _ready() -> void:
	visible = false
	_fit_root()
	_build_particles()
	_reset_visual_state()
	get_viewport().size_changed.connect(_fit_root)
	_dim.gui_input.connect(_on_dismiss_input)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if _is_dismiss_input(event):
		_request_skip()
		get_viewport().set_input_as_handled()


func play_celebration(display: Dictionary, burst_origin: Vector2, header_text: String = "ค้นพบสูตรใหม่!") -> void:
	if _playing:
		return

	_playing = true
	_skip_requested = false
	_kill_tween()
	_reset_visual_state()
	_fit_root()
	set_process_unhandled_input(true)

	_header.text = header_text
	_emoji.text = display.get("emoji", "")
	_title.text = display.get("title", "")

	visible = true
	_play_screen_flash()
	_start_particles(burst_origin)

	await _play_intro_phase()
	if not _skip_requested:
		await _play_hold_phase()
	await _play_fade_phase(_skip_requested)
	_finish_celebration()


func play_particle_burst(burst_origin: Vector2) -> void:
	# เอฟเฟกต์ดาว/sparkle เดียวกับตอนผสมของ แต่ไม่เปิด overlay ข้อความ
	if _playing:
		return

	_fit_root()
	_reset_visual_state()
	visible = true
	_dim.modulate.a = 0.0
	_content.modulate.a = 0.0
	_particles_root.modulate.a = 1.0
	_play_screen_flash()
	_start_particles(burst_origin)

	await get_tree().create_timer(1.9).timeout
	if _playing:
		return
	_stop_particles()
	_flash.modulate.a = 0.0
	visible = false


func _finish_celebration() -> void:
	_kill_tween()
	_snap_fade_out()
	set_process_unhandled_input(false)
	_stop_particles()
	_reset_visual_state()
	visible = false
	_playing = false
	_skip_requested = false
	_active_tween = null
	celebration_finished.emit()


func _request_skip() -> void:
	if not _playing or _skip_requested:
		return
	_skip_requested = true
	_stop_particles()


func _on_dismiss_input(event: InputEvent) -> void:
	if _is_dismiss_input(event):
		_request_skip()


func _is_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _play_intro_phase() -> void:
	var intro := create_tween()
	_active_tween = intro
	intro.set_parallel(true)
	intro.tween_property(_dim, "modulate:a", DIM_ALPHA, 0.28).set_ease(Tween.EASE_OUT)
	intro.tween_property(_content, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
	intro.tween_property(_content, "scale", Vector2.ONE, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	while intro.is_valid() and intro.is_running():
		if _skip_requested:
			_kill_tween()
			return
		await get_tree().process_frame


func _play_hold_phase() -> void:
	var remaining := HOLD_SECONDS
	while remaining > 0.0 and not _skip_requested:
		var step := minf(0.05, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step


func _play_fade_phase(fast: bool = false) -> void:
	if _skip_requested:
		_snap_fade_out()
		return

	var duration := SKIP_FADE_SECONDS if fast else FADE_SECONDS
	_kill_tween()
	var fade := create_tween()
	_active_tween = fade
	fade.set_parallel(true)
	fade.tween_property(_dim, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	fade.tween_property(_content, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	fade.tween_property(_celebration_stack, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	fade.tween_property(_particles_root, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	while fade.is_valid() and fade.is_running():
		if _skip_requested:
			_snap_fade_out()
			_kill_tween()
			return
		await get_tree().process_frame


func _snap_fade_out() -> void:
	_dim.modulate.a = 0.0
	_content.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_celebration_stack.modulate.a = 0.0
	_particles_root.modulate.a = 0.0


func _reset_visual_state() -> void:
	_content.pivot_offset = _content.custom_minimum_size * 0.5
	_content.modulate = Color(1, 1, 1, 0)
	_content.scale = Vector2(0.45, 0.45)
	_celebration_stack.modulate = Color(1, 1, 1, 1)
	_particles_root.modulate = Color(1, 1, 1, 1)
	_dim.modulate = Color(1, 1, 1, 0)
	_flash.modulate = Color(1, 1, 1, 0)
	_stop_particles()


func _fit_root() -> void:
	var rect := get_viewport().get_visible_rect()
	_celebration_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration_stack.position = rect.position
	_celebration_stack.size = rect.size


func _build_particles() -> void:
	var sparkle_tex := load("res://assets/Icons/PictoIcon_64/Icon_PictoIcon_Sparkle.Png") as Texture2D
	_sparkle_burst = _make_burst(sparkle_tex, 40, STAR_LIFETIME_MIN, 140.0, 280.0, 0.25, 0.85)
	_flash_burst = _make_flash_burst(sparkle_tex)


func _play_screen_flash() -> void:
	_flash.modulate.a = 0.0
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash, "modulate:a", 0.65, FLASH_FADE_IN).set_ease(Tween.EASE_OUT)
	flash_tween.tween_interval(FLASH_HOLD)
	flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_FADE_OUT).set_ease(Tween.EASE_IN)


func _start_particles(burst_origin: Vector2) -> void:
	_rebuild_star_bursts()

	for star in _star_bursts:
		star.global_position = burst_origin + Vector2(
			randf_range(-28.0, 28.0),
			randf_range(-28.0, 28.0)
		)
		star.emitting = false
		star.restart()
		star.emitting = true

	for burst in _bursts:
		if burst in _star_bursts:
			continue
		burst.global_position = burst_origin
		burst.emitting = false
		burst.restart()
		burst.emitting = true

	_flash_burst.global_position = burst_origin
	_flash_burst.emitting = false
	_flash_burst.restart()
	_flash_burst.emitting = true


func _rebuild_star_bursts() -> void:
	_destroy_star_bursts()

	var star_tex := load("res://assets/Hyper_Casual_UI/Sprites/Icons/star golden.png") as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var star_primary := _make_random_star_burst(star_tex, rng)
	var star_secondary := _make_random_star_burst(star_tex, rng)
	_star_bursts.append(star_primary)
	_star_bursts.append(star_secondary)

	_bursts.clear()
	_bursts.append(star_primary)
	_bursts.append(_sparkle_burst)
	_bursts.append(star_secondary)


func _destroy_star_bursts() -> void:
	for star in _star_bursts:
		if is_instance_valid(star):
			star.queue_free()
	_star_bursts.clear()
	_bursts.clear()


func _stop_particles() -> void:
	for burst in _bursts:
		if is_instance_valid(burst):
			burst.emitting = false
	if _flash_burst != null and is_instance_valid(_flash_burst):
		_flash_burst.emitting = false


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _make_burst(
	texture: Texture2D,
	amount: int,
	lifetime: float,
	velocity_min: float,
	velocity_max: float,
	scale_min: float,
	scale_max: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 12.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300.0)
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color_ramp = _gold_gradient()
	_particles_root.add_child(particles)
	return particles


func _make_random_star_burst(texture: Texture2D, rng: RandomNumberGenerator) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = rng.randi_range(48, 82)
	particles.lifetime = rng.randf_range(STAR_LIFETIME_MIN, STAR_LIFETIME_MAX)
	particles.randomness = rng.randf_range(0.65, 1.0)
	particles.spread = rng.randf_range(130.0, 180.0)
	particles.direction = Vector2(
		rng.randf_range(-0.55, 0.55),
		rng.randf_range(-1.0, -0.45)
	).normalized()
	particles.initial_velocity_min = rng.randf_range(90.0, 210.0)
	particles.initial_velocity_max = rng.randf_range(260.0, 460.0)
	particles.angular_velocity_min = rng.randf_range(-560.0, -180.0)
	particles.angular_velocity_max = rng.randf_range(180.0, 560.0)
	particles.scale_amount_min = rng.randf_range(0.28, 0.55)
	particles.scale_amount_max = rng.randf_range(0.7, 1.35)
	particles.gravity = Vector2(
		rng.randf_range(-80.0, 80.0),
		rng.randf_range(180.0, 400.0)
	)

	if rng.randf() > 0.4:
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(
			rng.randf_range(20.0, 56.0),
			rng.randf_range(16.0, 44.0)
		)
	else:
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = rng.randf_range(8.0, 40.0)

	particles.color_ramp = _gold_gradient()
	_particles_root.add_child(particles)
	return particles


func _gold_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.96, 0.5, 1.0))
	gradient.add_point(0.65, Color(1.0, 0.78, 0.15, 0.95))
	gradient.add_point(0.88, Color(1.0, 0.62, 0.08, 0.85))
	gradient.add_point(1.0, Color(1.0, 0.55, 0.05, 0.75))
	return gradient


func _make_flash_burst(texture: Texture2D) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 52
	particles.lifetime = 0.75
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 80.0)
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 380.0
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 1.05
	particles.color_ramp = _flash_gradient()
	_particles_root.add_child(particles)
	return particles


func _flash_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.92, 1.0))
	gradient.add_point(0.25, Color(1.0, 0.95, 0.5, 0.95))
	gradient.add_point(0.6, Color(1.0, 0.78, 0.2, 0.5))
	gradient.add_point(0.7, Color(1.0, 0.78, 0.2, 0.4))
	gradient.add_point(1.0, Color(1.0, 0.65, 0.1, 0.0))
	return gradient
