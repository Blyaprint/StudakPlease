shader_type canvas_item;
render_mode blend_add; // Режим сложения (свет)

// Цвет света (экран монитора голубовато-белый)
uniform vec4 light_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float intensity = 1.5;

// Размеры света (в UV спрайта MonitorLight)
// X - насколько широко, Y - насколько вниз падает
uniform vec2 light_size = vec2(1.0, 1.0); 
// Смещение центра (чтобы свет падал вниз)
uniform vec2 light_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV;
	
	// Смещаем UV, чтобы свет падал в нужное место
	uv -= light_offset;
	
	// Считаем края (0 в центре, 1 по краям)
	// Делаем мягкий прямоугольник
	float edge_x = smoothstep(0.0, light_size.x, abs(uv.x - 0.5));
	float edge_y = smoothstep(0.0, light_size.y, abs(uv.y - 0.5));
	
	// Комбинируем края
	float falloff = (1.0 - edge_x) * (1.0 - edge_y);
	
	// Квадратичное затухание для мягкости
	falloff = falloff * falloff;
	
	// Выход: добавляем свет
	COLOR = vec4(light_color.rgb * intensity * falloff, falloff);
}