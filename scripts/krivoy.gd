extends Node2D

signal game_over_requested
signal screen_shake_requested(duration: float, strength: float)
signal screen_shake_cancelled

enum Route {
	NONE,
	TO_DESK,
	PASSING
}

enum State {
	MOVING,
	WAITING_FOR_LIGHT,
	REVEALING,
	SCARING,
	ATTACKING,
	DEPARTURE_PAUSE,
	DEPARTING,
	PASSED,
	GAME_OVER
}

@export_group("Настройки движения")
@export var speed: float = 75.0
var approach_duration: float = 2.4
var approach_min_speed_multiplier: float = 0.8
var approach_max_speed_multiplier: float = 1.2
@export var approach_speed_multiplier: float = 2.0
@export var approach_walk_amplitude: float = 1.8
@export var passing_walk_amplitude: float = 0.5

@export_group("Точки маршрута")
@export var spawn_pos: Vector2 = Vector2(28.0, 150.0)
@export var wait_pos: Vector2 = Vector2(208.0, 180.0)
@export var exit_right_pos: Vector2 = Vector2(558.0, 150.0)
@export var exit_left_pos: Vector2 = Vector2(-180.0, 150.0)

@export_group("Масштаб")
@export var spawn_scale: float = 0.5
@export var wait_scale: float = 0.8
@export var exit_scale: float = 0.5

@export_group("Пороги маршрутов")
@export var desk_route_lock_x: float = 35.0
@export var pass_route_lock_x: float = 400.0

@export_group("Проявление")
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var reveal_start_distance: float = 60.0
@export var reveal_duration: float = 1.5

@export_group("Пугающее появление")
@export var scare_lunge_duration: float = 0.16
@export var scare_loom_duration: float = 0.28
@export var scare_lunge_scale: float = 1.35
@export var scare_loom_scale: float = 1.65
@export var scare_shake_duration: float = 0.3
@export var scare_shake_strength: float = 4.0

@export_group("Атака и защита")
@export var attack_duration: float = 3.0
@export var defense_duration: float = 5.0
@export var departure_pause_duration: float = 1.0
@export_range(0.1, 0.8, 0.05) var departure_fade_fraction: float = 0.45

@export_group("Процедурное искажение спрайта")
@export var bob_amount: float = 3.0
@export var bob_speed: float = 12.0
@export var squash_amount: float = 0.05
@export var rock_angle: float = 3.0
@export var rock_shift: float = 0.0
@export var run_jump_height: float = 15.0
@export var run_cycle_speed_multiplier: float = 1.0
@export var run_forward_lean: float = 0.0
@export var run_side_lean: float = 15.0
@export var run_landing_squash: float = 0.16

var has_arrived: bool = false
var is_leaving: bool = false

var _route: Route = Route.NONE
var _state: State = State.MOVING
var _route_locked: bool = false
var _is_light_enabled: bool = false
var _is_walking: bool = false

var _tween: Tween
var _reveal_tween: Tween
var _scare_tween: Tween
var _scare_recognized: bool = false
var _scare_paused: bool = false
var _reveal_progress: float = 0.0
var _reveal_started: bool = false
var _attack_remaining: float = 0.0
var _defense_remaining: float = 0.0
var _departure_pause_remaining: float = 0.0
var _game_over_sent: bool = false

var _walk_time: float = 0.0
var _walk_amplitude_multiplier: float = 1.0
var _walk_cycle_speed_multiplier: float = 1.0
var _base_sprite_pos: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite
@onready var _footsteps: AudioStreamPlayer2D = $Footsteps
@onready var fast_steps: AudioStreamWAV = preload("res://assets/audio/sfx/fast_shagi.wav")
@onready var superfast_steps: AudioStreamWAV = preload("res://assets/audio/sfx/superfast_shagi_normvolume.wav")


func _ready() -> void:
	add_to_group("visitor")
	add_to_group("anomaly")

	position = spawn_pos
	scale = Vector2.ONE * spawn_scale
	modulate = shadow_color
	modulate.a = 0.0
	_base_sprite_pos = _sprite.position

	GameState.light_mode_changed.connect(_on_light_mode_changed)
	_on_light_mode_changed(GameState.is_lit_mode)


func _process(delta: float) -> void:
	_try_lock_route()
	_try_start_reveal()

	if _is_walking:
		_update_walk(delta)

	match _state:
		State.ATTACKING:
			if _is_light_enabled:
				_attack_remaining -= delta
				if _attack_remaining <= 0.0 and not _game_over_sent:
					_game_over_sent = true
					_state = State.GAME_OVER
					game_over_requested.emit()
			else:
				_defense_remaining -= delta
				if _defense_remaining <= 0.0:
					_begin_departure_pause()
		State.DEPARTURE_PAUSE:
			_departure_pause_remaining -= delta
			if _departure_pause_remaining <= 0.0:
				_start_departure()


func _update_walk(delta: float) -> void:
	var cycle_multiplier := _walk_cycle_speed_multiplier
	if _route == Route.TO_DESK and not has_arrived:
		cycle_multiplier *= run_cycle_speed_multiplier
	_walk_time += delta * bob_speed * cycle_multiplier

	if _route == Route.TO_DESK and not has_arrived:
		_update_approach_run()
		return

	var wave := sin(_walk_time)
	var wave_01 := (wave + 1.0) / 2.0
	var amplitude := _walk_amplitude_multiplier

	_sprite.position.y = _base_sprite_pos.y - wave_01 * bob_amount * amplitude

	var squash := 1.0 + wave_01 * squash_amount * amplitude
	_sprite.scale = Vector2(2.0 - squash, squash)
	_sprite.rotation_degrees = wave * rock_angle * amplitude
	_sprite.position.x = _base_sprite_pos.x + wave * rock_shift * amplitude


func _update_approach_run() -> void:
	# Два коротких прыжка за цикл: знак cos меняется на каждом приземлении,
	# создавая ощущение попеременного отталкивания с ноги на ногу.
	var hop := absf(sin(_walk_time))
	var side := 1.0 if cos(_walk_time) >= 0.0 else -1.0
	var landing := pow(absf(cos(_walk_time)), 12.0)

	_sprite.position.y = _base_sprite_pos.y - hop * run_jump_height * _walk_amplitude_multiplier
	_sprite.position.x = _base_sprite_pos.x + side * rock_shift * _walk_amplitude_multiplier
	var landing_squash := landing * run_landing_squash
	var stretch := hop * squash_amount * _walk_amplitude_multiplier
	_sprite.scale = Vector2(
		1.0 + landing_squash - stretch,
		1.0 - landing_squash + stretch
	)
	_sprite.rotation_degrees = run_forward_lean + side * run_side_lean


func _start_footsteps(stream: AudioStreamWAV) -> void:
	if _footsteps.stream != stream:
		_footsteps.stop()
		_footsteps.stream = stream
	if not _footsteps.playing:
		_footsteps.play()

func _stop_footsteps() -> void:
	if _footsteps.playing:
		_footsteps.stop()

func _reset_sprite_transform() -> void:
	_is_walking = false
	_walk_amplitude_multiplier = 1.0
	_walk_cycle_speed_multiplier = 1.0
	if _sprite:
		_sprite.position = _base_sprite_pos
		_sprite.scale = Vector2.ONE
		_sprite.rotation_degrees = 0.0


func _on_light_mode_changed(is_lit: bool) -> void:
	_is_light_enabled = is_lit
	_apply_reveal_color()

	match _state:
		State.REVEALING:
			# Прогресс проявления, как у обычного NPC, не останавливается в темноте.
			return
		State.SCARING:
			if not is_lit:
				if _scare_recognized:
					# После начала тряски игрок уже распознал аномалию:
					# отменяем остаток появления и сразу запускаем защиту.
					_cancel_scare()
					_begin_defense_from_scare()
				elif _scare_tween and _scare_tween.is_valid():
					# До момента распознавания эффект можно продолжить после включения света.
					_scare_tween.pause()
					_scare_paused = true
			else:
				if _scare_tween and _scare_tween.is_valid() and _scare_paused:
					_scare_tween.play()
					_scare_paused = false
			return
		State.ATTACKING:
			if not is_lit:
				# В темноте спрайт возвращается к исходной позе и размеру.
				_reset_sprite_transform()
			# Повторное включение света сбрасывает только таймер защиты.
			_defense_remaining = defense_duration
			return
		State.WAITING_FOR_LIGHT:
			if is_lit:
				if _reveal_progress >= 1.0:
					_start_arrival_scare()
				else:
					_start_reveal()
			return
		State.DEPARTURE_PAUSE, State.DEPARTING, State.PASSED, State.GAME_OVER:
			return

	_try_lock_route()
	if has_arrived or _route_locked:
		return

	_set_route(Route.TO_DESK if is_lit else Route.PASSING)


func _try_lock_route() -> void:
	if _route_locked:
		return

	if _route == Route.TO_DESK and position.x >= desk_route_lock_x:
		_route_locked = true
	elif _route == Route.PASSING and position.x >= pass_route_lock_x:
		_route_locked = true


func _set_route(new_route: Route) -> void:
	if _route_locked or _route == new_route:
		return

	_route = new_route
	_start_footsteps(superfast_steps if _route == Route.TO_DESK else fast_steps)
	_is_walking = true

	var target_pos: Vector2
	var target_scale: float
	var movement_speed := speed

	if _route == Route.TO_DESK:
		_walk_amplitude_multiplier = approach_walk_amplitude
		# Множитель ускоряет прыжковый цикл, но не сокращает общее время подхода.
		_walk_cycle_speed_multiplier = approach_speed_multiplier
		target_pos = wait_pos
		target_scale = wait_scale
	else:
		_walk_amplitude_multiplier = passing_walk_amplitude
		_walk_cycle_speed_multiplier = 1.0
		target_pos = exit_right_pos
		target_scale = exit_scale

	if _tween and _tween.is_running():
		_tween.kill()

	var duration: float
	if _route == Route.TO_DESK:
		# Скорость рассчитывается по горизонтальному расстоянию; глубина по Y не влияет на время.
		var horizontal_distance := absf(target_pos.x - position.x)
		var reference_duration := maxf(approach_duration, 0.001)
		var min_approach_speed := maxf(movement_speed * approach_min_speed_multiplier, 0.001)
		var max_approach_speed := maxf(movement_speed * approach_max_speed_multiplier, min_approach_speed)
		var desired_approach_speed := horizontal_distance / reference_duration
		var approach_speed := clampf(desired_approach_speed, min_approach_speed, max_approach_speed)
		duration = horizontal_distance / approach_speed if horizontal_distance > 0.001 else reference_duration
	else:
		duration = position.distance_to(target_pos) / maxf(movement_speed, 0.001)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, duration)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, duration)

	if _route == Route.TO_DESK:
		_tween.tween_property(self, "modulate:a", 1.0, minf(0.3, duration))
		_tween.finished.connect(_on_arrived)
	else:
		modulate.a = 1.0
		_tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
		_tween.finished.connect(_on_passed)

	_try_lock_route()


func _on_arrived() -> void:
	_stop_footsteps()
	has_arrived = true
	_route_locked = true
	_state = State.WAITING_FOR_LIGHT
	_reset_sprite_transform()
	_apply_reveal_color()

	if _reveal_progress >= 1.0 and _is_light_enabled:
		_start_arrival_scare()


func _try_start_reveal() -> void:
	if _route != Route.TO_DESK or _reveal_started or is_leaving:
		return
	if position.distance_to(wait_pos) > reveal_start_distance:
		return
	_start_reveal()


func _start_reveal() -> void:
	if _reveal_started or _route != Route.TO_DESK or _state in [State.DEPARTURE_PAUSE, State.DEPARTING, State.PASSED, State.GAME_OVER]:
		return

	_reveal_started = true
	if has_arrived:
		_state = State.REVEALING
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(
		_set_reveal_progress,
		_reveal_progress,
		1.0,
		maxf(reveal_duration, 0.001)
	)
	_reveal_tween.finished.connect(_on_reveal_finished)


func _set_reveal_progress(progress: float) -> void:
	_reveal_progress = clampf(progress, 0.0, 1.0)
	_apply_reveal_color()


func _apply_reveal_color() -> void:
	var alpha := modulate.a
	var reveal := _reveal_progress if _is_light_enabled else 0.0
	modulate = Color(
		lerpf(shadow_color.r, 1.0, reveal),
		lerpf(shadow_color.g, 1.0, reveal),
		lerpf(shadow_color.b, 1.0, reveal),
		alpha
	)


func _on_reveal_finished() -> void:
	_reveal_progress = 1.0
	_apply_reveal_color()
	if has_arrived:
		if _is_light_enabled:
			_start_arrival_scare()
		else:
			_state = State.WAITING_FOR_LIGHT


func _start_arrival_scare() -> void:
	if not has_arrived or not _is_light_enabled or _reveal_progress < 1.0:
		return
	if _state in [State.SCARING, State.ATTACKING, State.DEPARTURE_PAUSE, State.DEPARTING, State.PASSED, State.GAME_OVER]:
		return

	_state = State.SCARING
	# Мгновенно увеличиваем спрайт до отправки сигнала: тряска начинается в тот же кадр.
	_scare_recognized = true
	_sprite.scale = Vector2.ONE * scare_lunge_scale
	screen_shake_requested.emit(scare_shake_duration, scare_shake_strength)
	_scare_tween = create_tween()
	_scare_tween.tween_property(
		_sprite,
		"position",
		_base_sprite_pos + Vector2(0.0, 15.0),
		maxf(scare_lunge_duration, 0.001)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_scare_tween.chain().tween_property(
		_sprite,
		"position",
		_base_sprite_pos + Vector2(0.0, 80.0),
		maxf(scare_loom_duration, 0.001)
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_scare_tween.parallel().tween_property(
		_sprite,
		"scale",
		Vector2.ONE * scare_loom_scale,
		maxf(scare_loom_duration, 0.001)
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_scare_tween.tween_callback(_on_scare_finished)


func _on_scare_finished() -> void:
	_scare_tween = null
	_scare_paused = false
	if _is_light_enabled:
		_begin_attack()
	else:
		_state = State.WAITING_FOR_LIGHT


func _cancel_scare() -> void:
	if _scare_tween and _scare_tween.is_running():
		_scare_tween.kill()
	_scare_tween = null
	screen_shake_cancelled.emit()
	_reset_sprite_transform()


func _begin_defense_from_scare() -> void:
	# Свет уже выключен в момент распознавания: сразу включаем обычную фазу защиты.
	_state = State.ATTACKING
	_attack_remaining = attack_duration
	_defense_remaining = defense_duration


func _begin_attack() -> void:
	if not has_arrived or not _is_light_enabled or _state == State.ATTACKING:
		return
	_state = State.ATTACKING
	_attack_remaining = attack_duration
	_defense_remaining = defense_duration


func _on_passed() -> void:
	_stop_footsteps()
	_state = State.PASSED
	queue_free()


func _begin_departure_pause() -> void:
	_state = State.DEPARTURE_PAUSE
	is_leaving = true
	_reset_sprite_transform()
	_departure_pause_remaining = departure_pause_duration


func _start_departure() -> void:
	_state = State.DEPARTING
	_is_walking = true
	_start_footsteps(fast_steps)
	_walk_amplitude_multiplier = 1.0
	_walk_cycle_speed_multiplier = 1.0
	_walk_time = 0.0
	_sprite.flip_h = exit_left_pos.x < position.x

	if _tween and _tween.is_running():
		_tween.kill()

	var duration := position.distance_to(exit_left_pos) / maxf(speed, 0.001)
	var fade_duration := maxf(duration * departure_fade_fraction, 0.001)
	var fade_delay := maxf(duration - fade_duration, 0.0)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", exit_left_pos, duration)
	_tween.tween_property(self, "scale", Vector2.ONE * exit_scale, duration)
	_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	_tween.finished.connect(_on_departure_finished)


func _on_departure_finished() -> void:
	_stop_footsteps()
	queue_free()
