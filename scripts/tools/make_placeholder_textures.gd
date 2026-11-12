@tool
extends EditorScript

# Запуск: в редакторе — File → Run (Ctrl+Shift+X) при открытом этом скрипте.
# Создаёт PNG-заглушки в res://assets/sprites/desk/. Прозрачный фон + цветной прямоугольник.

const OUT_DIR := "res://assets/sprites/desk/"

const ITEMS := {
	"phone.png":            {"size": Vector2i(12, 8),  "color": Color(0.30, 0.30, 0.34, 1.0)},
	"journal.png":          {"size": Vector2i(16, 12), "color": Color(0.36, 0.28, 0.18, 1.0)},
	"monitor.png":          {"size": Vector2i(20, 15), "color": Color(0.12, 0.18, 0.28, 1.0)},
	"turnstile_button.png": {"size": Vector2i(6, 6),   "color": Color(0.55, 0.22, 0.15, 1.0)},
}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	for fname: String in ITEMS.keys():
		var info: Dictionary = ITEMS[fname]
		var size: Vector2i = info["size"]
		var color: Color = info["color"]

		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		# 1 px прозрачной рамки, тело — цвет
		for x in range(1, size.x - 1):
			for y in range(1, size.y - 1):
				img.set_pixel(x, y, color)

		var path: String = OUT_DIR + fname
		var err: Error = img.save_png(path)
		if err != OK:
			push_error("Не сохранил %s: %s" % [path, err])
		else:
			print("OK: ", path)

	# Обновить импорт ассетов
	EditorInterface.get_resource_filesystem().scan()
