## Anima con viento TODAS las telas (Sprite2D hijos). Puedes duplicar, mover o
## cambiar la textura de las telas en el editor: el viento sigue funcionando.
## Cada tela debe tener su origen arriba (centered = false u offset).
extends "res://scripts/ambiente/AmbientReactive.gd"

@export var balanceo_calma := 0.04     # skew en calma
@export var balanceo_intenso := 0.22
@export var frecuencia_calma := 0.5
@export var frecuencia_intensa := 1.8

var _t := 0.0

func _process(dt: float) -> void:
	_t += dt * lerpf(frecuencia_calma, frecuencia_intensa, intensidad) * tempo
	var amp := lerpf(balanceo_calma, balanceo_intenso, intensidad) + 0.05 * enfasis
	var i := 0
	for c in get_children():
		if c is Node2D:
			var n := c as Node2D
			n.skew = sin(_t + i * 0.7) * amp + respiracion * 0.03 * (1.0 + 2.0 * enfasis)
			n.scale.y = 1.0 + 0.04 * respiracion * enfasis
			i += 1
