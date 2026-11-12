extends Control

@onready var boot_screen = $BootScreen
@onready var boot_text = $BootScreen/BootText
@onready var desktop = $Desktop
@onready var window_layer = $WindowLayer

# Окна (находим их по именам в дереве)
@onready var win_radar = get_node_or_null("WindowLayer/RadarWindow")
@onready var win_db = get_node_or_null("WindowLayer/DatabaseWindow")
@onready var win_folder = get_node_or_null("WindowLayer/FolderWindow")

var selected_icon: TextureButton = null
var click_timer: float = 0.0
var last_clicked_icon: TextureButton = null

# Для перетаскивания окон
var dragging_window: Control = null
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Скрываем окна на старте
	for w in [win_radar, win_db, win_folder]:
		if w: w.visible = false
		
	# Делаем фон прозрачным для кликов
	$Desktop/Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Подключаем иконки
	var icons = [
		get_node_or_null("Desktop/IconsContainer/IconRadar"),
		get_node_or_null("Desktop/IconsContainer/IconDatabase"),
		get_node_or_null("Desktop/IconsContainer/IconFolder")
	]
	for icon in icons:
		if icon is TextureButton:
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			icon.button_down.connect(_on_icon_down.bind(icon))
	
	# Запускаем загрузку
	desktop.visible = false
	boot_screen.visible = true
	boot_text.text = "Загрузка системы..."
	
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		boot_screen.visible = false
		desktop.visible = true
	)

# --- КЛИКИ ПО ИКОНКАМ ---
func _on_icon_down(icon: TextureButton) -> void:
	if last_clicked_icon == icon and click_timer < 0.3:
		_open_window(icon.name)
		click_timer = 0.0
		last_clicked_icon = null
	else:
		_select_icon(icon)
		click_timer = 0.0
		last_clicked_icon = icon

func _process(delta: float) -> void:
	if click_timer < 1.0:
		click_timer += delta

# --- ЛОГИКА ВЫДЕЛЕНИЯ (РАБОТАЕТ БЕЗ БАГОВ) ---
func _select_icon(icon: TextureButton) -> void:
	# Снимаем выделение со ВСЕХ иконок
	var all_icons = [
		get_node_or_null("Desktop/IconsContainer/IconRadar"),
		get_node_or_null("Desktop/IconsContainer/IconDatabase"),
		get_node_or_null("Desktop/IconsContainer/IconFolder")
	]
	for i in all_icons:
		if i:
			# Ищем рамку и скрываем её
			var frame = i.get_node_or_null("SelectionFrame")
			if frame: frame.visible = false
			
	# Выделяем новую
	selected_icon = icon
	if selected_icon:
		var frame = selected_icon.get_node_or_null("SelectionFrame")
		if frame: 
			frame.visible = true

# --- ОТКРЫТИЕ ОКОН ---
func _open_window(icon_name: String) -> void:
	match icon_name:
		"IconRadar":
			if win_radar: _show_window(win_radar)
		"IconDatabase":
			if win_db: _show_window(win_db)
		"IconFolder":
			if win_folder: _show_window(win_folder)

func _show_window(win: Control) -> void:
	win.visible = true
	win.move_to_front() # Поднимаем окно наверх, если открыто несколько
	# Центрируем окно при первом открытии
	if win.position == Vector2.ZERO:
		win.position = (size - win.size) / 2

# --- ПЕРЕТАСКИВАНИЕ ОКОН ---
func _on_window_gui_input(event: InputEvent, win: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_window = win
				drag_offset = win.get_global_mouse_position() - win.position
				win.move_to_front()
			else:
				dragging_window = null

func _input(event: InputEvent) -> void:
	if dragging_window and event is InputEventMouseMotion:
		dragging_window.position = dragging_window.get_global_mouse_position() - drag_offset


func _on_radar_window_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_database_window_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.


func _on_folder_window_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
