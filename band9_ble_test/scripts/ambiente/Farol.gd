## Farolillo: se balancea con el viento y su brillo "respira" lento.
extends "res://scripts/ambiente/AmbientReactive.gd"

@export var encendido := 1.0           # 0..1 (el ritual lo enciende poco a poco)
var _t := 0.0
var _ph := 0.0
var _seed := randf() * 10.0

func _process(dt: float) -> void:
	_t += dt * tempo
	_ph += dt * tempo * lerpf(0.7, 2.0, intensidad)
	rotation = sin(_ph + _seed) * lerpf(0.03, 0.14, intensidad)
	var s := 1.0 + 0.05 * respiracion * (1.0 + 1.5 * enfasis)
	$Farol.scale = Vector2(s, s)
	$Brillo.modulate.a = encendido * (0.35 + 0.25 * (1.0 + respiracion))
	$Brillo.scale = Vector2.ONE * (0.9 + 0.15 * respiracion) * (0.6 + 0.4 * encendido)
