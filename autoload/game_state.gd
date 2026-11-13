extends Node

# Сигнал, который оповестит все предметы, что режим изменился
signal light_mode_changed(is_lit: bool)

var is_lit_mode: bool = false

func toggle_light() -> void:
	is_lit_mode = not is_lit_mode
	print("Режим освещения: ", is_lit_mode)
	light_mode_changed.emit(is_lit_mode)
