shader_type canvas_item;

// --- Хроматическая аберрация ---
uniform float aberration_strength : hint_range(0.0, 10.0) = 2.0; // Сдвиг цветов в пикселях
uniform float aberration_vignette : hint_range(0.0, 1.0) = 0.5;  // Усиление аберрации к краям экрана

// --- Шум / Зерно ---
uniform float noise_strength : hint_range(0.0, 1.0) = 0.15; // Сила шума
uniform float noise_speed : hint_range(0.0, 50.0) = 20.0;    // Скорость мерцания шума

// --- Разрешение экрана (для правильного сдвига) ---
uniform vec2 viewport_size = vec2(334.0, 187.0);

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Функция генерации псевдо-случайного числа (шума)
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// 1. Считаем UV и центрируем их (-0.5 до 0.5)
	vec2 uv = SCREEN_UV;
	vec2 centered_uv = uv - vec2(0.5);
	
	// 2. Считаем дистанцию от центра для виньетки
	float dist = length(centered_uv);
	
	// 3. Хроматическая аберрация
	// Сдвигаем красный канал в одну сторону, синий в другую
	// Сила сдвига зависит от расстояния до центра (чтобы в центре было чисто, а по краям "мылило")
	float shift = aberration_strength * (dist * aberration_vignette);
	vec2 offset = vec2(shift / viewport_size.x, shift / viewport_size.y);
	
	// Берем текстуру с учетом сдвигов
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	vec3 final_color = vec3(r, g, b);
	
	// 4. Шум (Зерно)
	// Используем TIME для анимации шума
	float noise = rand(uv + TIME * noise_speed);
	// Добавляем шум к цвету
	final_color += (noise - 0.5) * noise_strength;
	
	// 5. Выводим результат
	COLOR = vec4(final_color, 1.0);
}