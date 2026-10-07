shader_type canvas_item;
// Capa visual adaptativa. Cambios lentos y sutiles en varios parámetros a la vez
// (nunca flashes ni pulsos por latido). Los valores los interpola Game.gd.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 0.9;
uniform float contrast = 1.0;
uniform float brightness = 0.0;
uniform float hue_shift = 0.0;            // radianes, muy pequeño
uniform vec4 tint : source_color = vec4(0.75, 0.92, 0.95, 1.0);
uniform float tint_amount = 0.1;
uniform float vignette = 0.15;

vec3 hue_rotate(vec3 c, float a) {
	// rotación de matiz en espacio YIQ
	const mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	const mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * c;
	float h = atan(yiq.z, yiq.y) + a;
	float ch = length(yiq.yz);
	return to_rgb * vec3(yiq.x, ch * cos(h), ch * sin(h));
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	c = hue_rotate(c, hue_shift);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5 + brightness;
	c = mix(c, c * tint.rgb * 1.15, tint_amount);
	float d = distance(UV, vec2(0.5));
	c *= 1.0 - vignette * smoothstep(0.35, 0.85, d);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
