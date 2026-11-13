extends Node2D

const NPC_SCENE: PackedScene = preload("res://scenes/npc.tscn")
const KRIVOY_SCENE: PackedScene = preload("res://scenes/krivoy.tscn")

@export_group("Появление посетителей")
@export var spawn_delay: float = 1.0
@export_range(0.0, 1.0, 0.05) var krivoy_spawn_chance: float = 0.5

@export_group("Общие параметры посетителей")
@export var visitor_speed: float = 75.0
@export var visitor_spawn_pos: Vector2 = Vector2(28.0, 150.0)
@export var visitor_wait_pos: Vector2 = Vector2(208.0, 180.0)
@export var visitor_exit_right_pos: Vector2 = Vector2(558.0, 150.0)
@export var visitor_exit_left_pos: Vector2 = Vector2(-180.0, 150.0)
@export var visitor_spawn_scale: float = 0.5
@export var visitor_wait_scale: float = 0.8
@export var visitor_exit_scale: float = 0.5
@export var desk_route_lock_x: float = 35.0
@export var pass_route_lock_x: float = 400.0
@export var reveal_start_distance: float = 60.0
@export var reveal_duration: float = 1.5

@onready var night_overlay: CanvasLayer = get_node_or_null("NightOverlay")

var _spawn_timer: Timer
var _active_visitor: Node2D
var _game_over: bool = false


func _ready() -> void:
	GameState.light_mode_changed.connect(_on_light_mode_changed)
	_on_light_mode_changed(GameState.is_lit_mode)

	_spawn_timer = Timer.new()
	_spawn_timer.name = "VisitorSpawnTimer"
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_spawn_next_visitor)
	_spawn_timer.start(maxf(spawn_delay, 0.05))


func _on_light_mode_changed(is_lit: bool) -> void:
	if night_overlay:
		night_overlay.visible = not is_lit


func _spawn_next_visitor() -> void:
	if _game_over:
		return

	# Защита от повторного запуска, пока предыдущий посетитель ещё в дереве.
	if get_tree().get_first_node_in_group("visitor") != null:
		_spawn_timer.start(0.25)
		return

	var visitor: Node2D
	if randf() < krivoy_spawn_chance:
		visitor = KRIVOY_SCENE.instantiate() as Node2D
	else:
		visitor = NPC_SCENE.instantiate() as Node2D

	_configure_visitor(visitor)

	if visitor.has_signal("game_over_requested"):
		visitor.connect("game_over_requested", Callable(self, "_show_game_over"))

	_active_visitor = visitor
	visitor.tree_exited.connect(_on_active_visitor_exited)
	add_child(visitor)


func _configure_visitor(visitor: Node2D) -> void:
	visitor.set("speed", visitor_speed)
	visitor.set("spawn_pos", visitor_spawn_pos)
	visitor.set("wait_pos", visitor_wait_pos)
	visitor.set("exit_right_pos", visitor_exit_right_pos)
	visitor.set("exit_left_pos", visitor_exit_left_pos)
	visitor.set("spawn_scale", visitor_spawn_scale)
	visitor.set("wait_scale", visitor_wait_scale)
	visitor.set("exit_scale", visitor_exit_scale)
	visitor.set("desk_route_lock_x", desk_route_lock_x)
	visitor.set("pass_route_lock_x", pass_route_lock_x)
	visitor.set("reveal_start_distance", reveal_start_distance)
	visitor.set("reveal_duration", reveal_duration)
	visitor.set("passing_walk_amplitude", 0.5)

	# Сохраняем текущее значение squash для стандартного NPC из main.tscn.
	if visitor.has_method("allow_pass"):
		visitor.set("squash_amount", 0.0)
		visitor.set("fade_to_shadow_time", 0.7)


func _on_active_visitor_exited() -> void:
	_active_visitor = null
	if not _game_over and is_instance_valid(_spawn_timer):
		_spawn_timer.start(maxf(spawn_delay, 0.05))


func _show_game_over() -> void:
	if _game_over:
		return

	_game_over = true
	if _spawn_timer:
		_spawn_timer.stop()

	var overlay := CanvasLayer.new()
	overlay.name = "GameOverLayer"
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.85)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)

	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(label)

	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if _game_over or event is not InputEventKey or not event.pressed or event.echo:
		return

	var pc = get_tree().get_first_node_in_group("pc_ui")
	if pc and pc.is_open:
		if event.keycode == KEY_ESCAPE:
			pc.close_pc()
			get_viewport().set_input_as_handled()
		return

	# Во время встречи с аномалией эти клавиши не должны запускать действия посетителя.
	if get_tree().get_first_node_in_group("anomaly") != null:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
		return

	# В этой группе находятся только обычные NPC. «Кривой» в неё не входит.
	var npc = get_tree().get_first_node_in_group("npc")
	if not npc:
		return

	if not npc.has_arrived or npc.is_leaving:
		return

	if event.keycode == KEY_SPACE:
		npc.allow_pass()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		npc.deny_pass()
		get_viewport().set_input_as_handled()


func _on_icon_radar_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_icon_database_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_icon_folder_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
