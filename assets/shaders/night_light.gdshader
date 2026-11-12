shader_type canvas_item;

// Цвет тени (базовое затемнение)
uniform vec4 shadow_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.85;

// Цветовой оттенок
uniform vec4 tint_color : source_color = vec4(0.8, 0.9, 0.9, 1.0); 
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;

// Насыщенность
uniform float saturation : hint_range(0.0, 2.0) = 0.7;

// Режим наложения для Tint (0=Normal, 1=Multiply, 2=Screen, 3=Overlay, 4=Soft Light, 5=Hard Light)
uniform int blend_mode : hint_range(0, 5) = 3; // По умолчанию Overlay

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Функция для режимов наложения (как в Photoshop)
vec3 apply_blend(vec3 base, vec3 blend, int mode) {
	if (mode == 0) return blend; // Normal
	if (mode == 1) return base * blend; // Multiply
	if (mode == 2) return 1.0 - (1.0 - base) * (1.0 - blend); // Screen
	if (mode == 3) { // Overlay
		return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5, base));
	}
	if (mode == 4) { // Soft Light
		vec3 d = mix(sqrt(base), ((16.0 * base - 12.0) * base + 4.0) * base, step(0.25, base));
		return mix(base - (1.0 - 2.0 * blend) * base * (1.0 - base), base + (2.0 * blend - 1.0) * (d - base), step(0.5, blend));
	}
	if (mode == 5) { // Hard Light
		return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5, blend));
	}
	return blend;
}

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	
	// 1. Затемнение
	vec3 darkened = scene.rgb * shadow_color.rgb;
	vec3 col = mix(scene.rgb, darkened, darkness);
	
	// 2. Изменение насыщенности
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	
	// 3. Наложение оттенка (Tint) через выбранный режим
	vec3 blended = apply_blend(col, tint_color.rgb, blend_mode);
	
	// Смешиваем результат с оригиналом (чтобы контролировать силу эффекта)
	col = mix(col, blended, tint_strength);
	
	COLOR = vec4(col, scene.a);
}