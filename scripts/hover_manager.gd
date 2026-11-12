extends Node

var _current: Interactable = null

func _process(_delta: float) -> void:
	var best_target: Interactable = null
	var all_interactables = get_tree().get_nodes_in_group("interactables")
	
	# Просто спрашиваем у каждого предмета: "Мышь на тебе?"
	for item in all_interactables:
		if not is_instance_valid(item):
			continue
		if item.check_mouse_inside():
			best_target = item
			break # Нашли предмет — выходим из цикла

	# Если предмет под мышкой изменился — переключаем подсветку
	if best_target != _current:
		if is_instance_valid(_current):
			_current.set_outline(false)
			_current._is_hovered = false
			
		_current = best_target
		
		if is_instance_valid(_current):
			_current.set_outline(true)
			_current._is_hovered = true
			if _current._hover_sound and not _current._hover_sound.playing:
				_current._hover_sound.play()
