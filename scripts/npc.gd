extends Node2D

@export_group("Настройки движения")
@export var speed: float = 150.0

@export_group("Точки маршрута (Координаты)")
@export var spawn_pos: Vector2 = Vector2(-100, 40)
@export var wait_pos: Vector2 = Vector2(200, 100)
@export var exit_right_pos: Vector2 = Vector2(800, 40)
@export var exit_left_pos: Vector2 = Vector2(-100, 100)

@export_group("Настройки перспективы (Размеры)")
@export var spawn_scale: float = 0.4 # Размер при появлении
@export var wait_scale: float = 1.0  # Размер в центре
@export var exit_scale: float = 0.4  # Размер при уходе вправо

@export_group("Эффект Тени (Выход из темноты)")
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var reveal_time: float = 1.0
@export var fade_to_shadow_time: float = 0.5

@export_group("Эффект 'переваливания'")
@export var bob_amount: float = 3.0
@export var bob_speed: float = 12.0
@export var squash_amount: float = 0.05
@export var rock_angle: float = 3.0
@export var rock_shift: float = 2.0

var _tween: Tween
var _reveal_tween: Tween
var _reveal_progress: float = 0.0
var _reveal_completed: bool = false
var _is_light_enabled: bool = false
var dialog_panel: Control = null
var dialog_label: Label = null

var has_arrived: bool = false
var is_leaving: bool = false
var _is_walking: bool = false

var _base_sprite_pos: Vector2 = Vector2.ZERO
var _walk_time: float = 0.0

func _ready() -> void:
	add_to_group("npc")

	position = spawn_pos
	scale = Vector2(spawn_scale, spawn_scale)
	modulate = shadow_color
	modulate.a = 0.0

	if $Sprite:
		_base_sprite_pos = $Sprite.position

	dialog_panel = get_tree().current_scene.get_node_or_null("UILayer/DialogPanel")
	if dialog_panel:
		dialog_label = dialog_panel.get_node_or_null("DialogText")
		dialog_panel.visible = false

	GameState.light_mode_changed.connect(_on_light_mode_changed)
	_on_light_mode_changed(GameState.is_lit_mode)
	walk_to_desk()

func _process(delta: float) -> void:
	if not _is_walking or $Sprite == null:
		return

	_walk_time += delta * bob_speed

	var wave = sin(_walk_time)
	var wave_01 = (wave + 1.0) / 2.0

	$Sprite.position.y = _base_sprite_pos.y - (wave_01 * bob_amount)

	var squash = 1.0 + (wave_01 * squash_amount)
	$Sprite.scale = Vector2(2.0 - squash, squash)

	$Sprite.rotation_degrees = wave * rock_angle
	$Sprite.position.x = _base_sprite_pos.x + (wave * rock_shift)

func _reset_sprite_transform() -> void:
	_is_walking = false
	if $Sprite:
		$Sprite.position = _base_sprite_pos
		$Sprite.scale = Vector2(1.0, 1.0)
		$Sprite.rotation_degrees = 0.0

func _on_light_mode_changed(is_lit: bool) -> void:
	_is_light_enabled = is_lit
	if is_leaving:
		return

	_apply_reveal_color()

func _set_reveal_progress(progress: float) -> void:
	_reveal_progress = progress
	_apply_reveal_color()

func _apply_reveal_color() -> void:
	var alpha = modulate.a
	var reveal = _reveal_progress if _is_light_enabled else 0.0
	modulate = Color(
		lerp(shadow_color.r, 1.0, reveal),
		lerp(shadow_color.g, 1.0, reveal),
		lerp(shadow_color.b, 1.0, reveal),
		alpha
	)

func _on_reveal_finished() -> void:
	_reveal_completed = true

# --- ПРИХОД К СТОЙКЕ ---
func walk_to_desk() -> void:
	_is_walking = true
	if $Sprite.sprite_frames and $Sprite.sprite_frames.has_animation("walk"):
		$Sprite.play("walk")

	_tween = create_tween()
	_tween.set_parallel(true)

	var distance = position.distance_to(wait_pos)
	var duration = distance / speed

	_tween.tween_property(self, "position", wait_pos, duration)
	_tween.tween_property(self, "scale", Vector2(wait_scale, wait_scale), duration)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)

	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_set_reveal_progress, _reveal_progress, 1.0, 0.5).set_delay(reveal_time)
	_reveal_tween.finished.connect(_on_reveal_finished)

	_tween.finished.connect(_on_arrived)

func _on_arrived() -> void:
	has_arrived = true
	_reset_sprite_transform()

	if $Sprite.sprite_frames and $Sprite.sprite_frames.has_animation("idle"):
		$Sprite.play("idle")

	if dialog_panel and dialog_label:
		dialog_label.text = "Здравствуйте. Вот мой пропуск."
		dialog_panel.visible = true

# --- УХОД ---
func allow_pass() -> void:
	if not has_arrived or is_leaving: return
	is_leaving = true
	if dialog_panel: dialog_panel.visible = false
	_leave(exit_right_pos, exit_scale, true)

func deny_pass() -> void:
	if not has_arrived or is_leaving: return
	is_leaving = true
	if dialog_panel: dialog_panel.visible = false
	# Отправляем его обратно в spawn_pos и уменьшаем до spawn_scale
	_leave(spawn_pos, spawn_scale, true)

func _leave(target_pos: Vector2, target_scale: float, fade_out: bool) -> void:
	_is_walking = true
	if $Sprite.sprite_frames and $Sprite.sprite_frames.has_animation("walk"):
		$Sprite.play("walk")

	$Sprite.flip_h = target_pos.x < position.x

	if _reveal_tween and not _reveal_completed:
		_reveal_tween.kill()
		_reveal_completed = true

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	var distance = position.distance_to(target_pos)
	var duration = distance / speed

	_tween.tween_property(self, "position", target_pos, duration)
	_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), duration)

	if fade_out:
		_tween.tween_property(self, "modulate:r", 0.0, fade_to_shadow_time)
		_tween.tween_property(self, "modulate:g", 0.0, fade_to_shadow_time)
		_tween.tween_property(self, "modulate:b", 0.0, fade_to_shadow_time)
		_tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)

	_tween.finished.connect(queue_free)
