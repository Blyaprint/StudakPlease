extends Node2D

@export var item_name: String = "environment"
@export var anim_dark: String = "dark"
@export var anim_lit: String = "lit"

var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = find_child("AnimatedSprite2D", true, false)
	
	if _sprite == null:
		var all_children = find_children("*", "AnimatedSprite2D", true, false)
		if all_children.size() > 0:
			_sprite = all_children[0]
			
	if _sprite == null:
		return

	GameState.light_mode_changed.connect(_on_light_mode_changed)
	_on_light_mode_changed(GameState.is_lit_mode)

func _on_light_mode_changed(is_lit: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
		
	var target_anim = anim_lit if is_lit else anim_dark
	var anim_found = false
	
	if _sprite.sprite_frames.has_animation(target_anim):
		_sprite.animation = target_anim
		anim_found = true
	else:
		for anim in _sprite.sprite_frames.get_animation_names():
			if anim.to_lower() == target_anim.to_lower():
				_sprite.animation = anim
				anim_found = true
				break

	if anim_found:
		_sprite.stop()
		_sprite.frame = 0
