extends Interactable

func _interact() -> void:
	var pc = get_tree().get_first_node_in_group("pc_ui")
	if pc:
		pc.open_pc()
