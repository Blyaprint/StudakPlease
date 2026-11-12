class_name Interactable
extends Node2D

@export var item_name: String = "item"

# Параметры для переключения анимаций
@export var anim_dark: String = "dark"
@export var anim_lit: String = "lit"
@export var force_first_frame: bool = false 

const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")

var _sprite: AnimatedSprite2D = null
var _polygon: Polygon2D = null
var _material: ShaderMaterial = null
var _hover_sound: AudioStreamPlayer = null
var _click_sound: AudioStreamPlayer = null
var _is_hovered: bool = false

func _ready() -> void:
	add_to_group("interactables")

	for child in get_children():
		if child is AnimatedSprite2D:
			_sprite = child
		elif child is Polygon2D:
			_polygon = child
		elif child is AudioStreamPlayer:
			if child.name == "HoverSound":
				_hover_sound = child
			elif child.name == "ClickSound":
				_click_sound = child

	if _sprite == null or _polygon == null:
		push_warning("Предмет '%s': нет AnimatedSprite2D или Polygon2D!" % item_name)
		return

	# Настройка шейдера (подсветка)
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_sprite.material = _material
	_material.set_shader_parameter("highlight_active", false)
	_material.set_shader_parameter("highlight_color", Color(1.0, 1.0, 1.0, 1.0))
	_material.set_shader_parameter("highlight_strength", 0.2) # Твоя рабочая яркость
	_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0)) # Цвет обводки
	_material.set_shader_parameter("outline_size", 2.0) # Толщина обводки
	
	# Подписка на свет
	GameState.light_mode_changed.connect(_on_light_mode_changed)
	_on_light_mode_changed(GameState.is_lit_mode)

# Проверка мыши (используем встроенный метод Godot, он сам учитывает масштабы)
func check_mouse_inside() -> bool:
	if _polygon == null:
		return false
	var local_mouse = _polygon.to_local(get_global_mouse_position())
	return Geometry2D.is_point_in_polygon(local_mouse, _polygon.polygon)

func set_outline(on: bool) -> void:
	if _material:
		_material.set_shader_parameter("highlight_active", on)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_hovered:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_interact()
		if _click_sound:
			_click_sound.play()
		get_viewport().set_input_as_handled()

func _interact() -> void:
	print("[Interactable] Клик по предмету: %s" % item_name)

func _on_light_mode_changed(is_lit: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
		
	var target_anim = anim_lit if is_lit else anim_dark
	
	if not _sprite.sprite_frames.has_animation(target_anim):
		for anim in _sprite.sprite_frames.get_animation_names():
			if anim.to_lower() == target_anim.to_lower():
				_sprite.animation = anim
				break
	else:
		_sprite.animation = target_anim
		
	if force_first_frame:
		_sprite.stop()
		_sprite.frame = 0
	else:
		_sprite.play()
