## Vapor que sube. Sube más en la "inspiración" del puesto y se acelera con la
## intensidad: es una pista visual (opcional) para bajar el ritmo.
extends "res://scripts/ambiente/AmbientReactive.gd"

@export var textura: Texture2D
@export var ritmo := 3.0
@export var velocidad := 22.0
@export var vida := 2.4
@export var ancho := 16.0

var _acc := 0.0

func _process(dt: float) -> void:
	var inhala := 0.5 + 0.5 * respiracion
	_acc += dt * ritmo * (0.4 + 0.9 * inhala + 1.2 * intensidad)
	while _acc >= 1.0 and textura:
		_acc -= 1.0
		var s := Sprite2D.new()
		s.texture = textura
		s.position = Vector2(randf_range(-ancho, ancho), 0)
		s.scale = Vector2.ONE * 0.35
		s.set_meta("t", 0.0)
		add_child(s)
	for p in get_children():
		var s := p as Sprite2D
		var t: float = s.get_meta("t") + dt
		s.set_meta("t", t)
		s.position += Vector2(sin(t * 2.0 + s.position.y * 0.05) * 8.0, -velocidad * (1.0 + 1.2 * intensidad)) * dt * tempo
		s.scale = Vector2.ONE * (0.35 + t * 0.4)
		s.modulate.a = 0.55 * (1.0 - t / vida)
		if t >= vida:
			s.queue_free()
