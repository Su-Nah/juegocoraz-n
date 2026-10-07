## Árbol: la copa se mece con el viento.
extends "res://scripts/ambiente/AmbientReactive.gd"

var _t := 0.0

func _process(dt: float) -> void:
	_t += dt * tempo
	$Copa.skew = sin(_t * lerpf(0.5, 1.6, intensidad)) * lerpf(0.03, 0.15, intensidad)
	$Copa.position.x = sin(_t * 0.8) * lerpf(2.0, 8.0, intensidad)
