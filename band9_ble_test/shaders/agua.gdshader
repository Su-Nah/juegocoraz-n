shader_type canvas_item;
// Ondula y desplaza la textura de la superficie del agua (funciona con
// cualquier textura que pongas en el Sprite2D "Superficie").
uniform float amplitud = 0.01;
uniform float velocidad = 0.5;
uniform float frecuencia = 18.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * velocidad;
	uv.x = fract(uv.x + t * 0.05);
	uv.y += sin(uv.x * frecuencia + t * 3.0) * amplitud + sin(uv.x * frecuencia * 0.37 - t * 2.0) * amplitud * 0.6;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	c.rgb += vec3(0.08) * smoothstep(0.6, 1.0, sin(UV.x * 40.0 + t * 4.0)) * amplitud * 20.0;
	COLOR = c * COLOR;
}
