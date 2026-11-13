extends Node2D

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return

	var pc = get_tree().get_first_node_in_group("pc_ui")
	if pc and pc.is_open:
		if event.keycode == KEY_ESCAPE:
			pc.close_pc()
			get_viewport().set_input_as_handled()
		return

	var npc = get_tree().get_first_node_in_group("npc")
	if not npc:
		return

	# Если NPC еще едет или уже уходит, клавиши игнорируются.
	if not npc.has_arrived or npc.is_leaving:
		return

	if event.keycode == KEY_SPACE:
		npc.allow_pass()
	elif event.keycode == KEY_ESCAPE:
		npc.deny_pass()


func _on_icon_radar_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_icon_database_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_icon_folder_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
