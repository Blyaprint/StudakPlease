extends Node

# Сигнал, который оповестит все предметы, что режим изменился
signal light_mode_changed(is_lit: bool)

var is_lit_mode: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# По нажатию на клавишу L переключаем режим
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			is_lit_mode = not is_lit_mode
			print("Режим освещения: ", is_lit_mode)
			light_mode_changed.emit(is_lit_mode)
