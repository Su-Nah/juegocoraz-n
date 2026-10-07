## Bote del puesto: "este no salió bien, lo descartamos y seguimos".
## Sin sonido de error, sin texto negativo: tapa que se abre, cae, se cierra.
@tool
extends "res://scripts/cocina/Interactivo.gd"

@onready var _tapa: Node2D = $Tapa
var _abierto := 0.0

func tirar() -> void:
	var tw := create_tween()
	tw.tween_property(_tapa, "rotation", -0.9, 0.15).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.35)
	tw.tween_property(_tapa, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Mientras arrastras un dango encima, la tapa se entreabre (affordance).
func set_invitando(on: bool) -> void:
	var target := -0.35 if on else 0.0
	if not is_equal_approx(_abierto, target):
		_abierto = target
		create_tween().tween_property(_tapa, "rotation", target, 0.15)
