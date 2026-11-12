shader_type canvas_item;
render_mode blend_add;

uniform vec4 beam_color : source_color = vec4(0.6, 0.8, 1.0, 1.0); // Холодный лунный
uniform float intensity : hint_range(0.0, 2.0) = 0.8; // Яркость
uniform float spread : hint_range(0.0, 1.0) = 0.5; // Насколько широко рассеивается луч к низу
uniform float distance_fade : hint_range(0.0, 2.0) = 1.0; // Как быстро луч тает в конце

void fragment() {
	// uv.x - от 0 (левый край) до 1 (правый)
	// uv.y - от 0 (верх, где окно) до 1 (низ, где пол)
	vec2 uv = UV;
	
	// 1. Считаем, насколько далеко мы от центра по горизонтали
	// Чем ниже спускаемся (чем больше uv.y), тем шире должен быть луч
	float current_width = mix(0.1, spread, uv.y); 
	float dist_x = abs(uv.x - 0.5); // Расстояние от центральной оси
	
	// 2. Считаем, попали ли мы в конус луча
	// Если расстояние больше текущей ширины — луч прозрачный
	float in_beam = smoothstep(current_width, current_width - 0.1, dist_x);
	
	// 3. Затухание по длине (чем дальше вниз, тем тусклее)
	float fade_y = smoothstep(1.0, 1.0 - distance_fade, uv.y);
	
	// 4. Итоговая яркость
	float alpha = in_beam * fade_y * intensity;
	
	if (alpha <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(beam_color.rgb * alpha, alpha);
	}
}