## Pétalos que caen con viento. Cambia `textura` (o el PNG) y el
## comportamiento sigue igual. Ajusta área y ritmos en el Inspector.
extends "res://scripts/ambiente/AmbientReactive.gd"

@export var textura: Texture2D
@export var area := Rect2(-60, -40, 420, 80)   # zona de nacimiento (local)
@export var suelo_y := 420.0                   # y local donde desaparecen
@export var ritmo_calma := 0.25                # pétalos/s en calma
@export var ritmo_intenso := 2.2               # pétalos/s con intensidad 1
@export var viento_calma := 18.0
@export var viento_intenso := 90.0
@export var max_petalos := 60

var _acc := 0.0
var _t := 0.0

func _process(dt: float) -> void:
	_t += dt * tempo
	_acc += dt * lerpf(ritmo_calma, ritmo_intenso, intensidad) * (1.0 - 0.5 * alivio)
	while _acc >= 1.0 and textura:
		_acc -= 1.0
		if get_child_count() < max_petalos:
			_spawn()
	var viento := lerpf(viento_calma, viento_intenso, intensidad)
	for p in get_children():
		var s := p as Sprite2D
		var ph: float = s.get_meta("ph")
		s.position += Vector2(viento + sin(_t * 1.5 + ph) * 25.0, 35.0 + 10.0 * sin(ph)) * dt * tempo
		s.rotation += dt * tempo * (1.0 + intensidad) * (1.0 if ph > PI else -1.0)
		s.scale.x = sin(_t * 3.0 + ph) * 0.5 + 0.6   # gira en el aire
		if s.position.y > suelo_y or s.position.x > 1400.0:
			s.queue_free()

func _spawn() -> void:
	var s := Sprite2D.new()
	s.texture = textura
	s.position = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	s.rotation = randf() * TAU
	s.set_meta("ph", randf() * TAU)
	add_child(s)
