shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.2;
uniform bool highlight_active = false;

// Параметры для обводки
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	if (highlight_active) {
		// --- 1. МЯГКИЙ СВЕТ (ТВОЙ РАБОЧИЙ КОД) ---
		vec3 blend = tex.rgb;
		vec3 light = highlight_color.rgb;
		
		vec3 result_light = blend + (2.0 * light - 1.0) * (sqrt(blend) - blend);
		vec3 result_dark = blend - (1.0 - 2.0 * light) * blend * (1.0 - blend);
		vec3 soft_light = mix(result_light, result_dark, step(0.5, light));
		
		vec3 final_rgb = mix(tex.rgb, soft_light, highlight_strength);
		
		// --- 2. ОБВОДКА ---
		vec2 px = vec2(1.0 / 640.0, 1.0 / 360.0) * outline_size;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

		// --- 3. СБОРКА ---
		if (tex.a < 0.5 && a > 0.5) {
			// Контур
			COLOR = outline_color;
		} else if (tex.a >= 0.5) {
			// Сам предмет с мягким светом
			COLOR = vec4(final_rgb, tex.a);
		} else {
			// Пустота
			COLOR = vec4(0.0);
		}
	} else {
		COLOR = tex;
	}
}