## Campanilla de viento (fūrin) colgada del puesto = regulación voluntaria.
## Tocarla NO pausa el juego: durante unos segundos no produces, el mundo sigue,
## el puesto amplía su respiración. Se mece con el viento como el resto.
@tool
extends "res://scripts/cocina/Interactivo.gd"

var intensidad := 0.0
var tempo := 1.0
var _t := 0.0
var _ph := 0.0
var _golpe := 0.0

func _enter_tree() -> void:
	add_to_group("ambiente_reactivo")

func aplicar_ambiente(e: Dictionary) -> void:
	intensidad = e.get("intensidad", 0.0)
	tempo = e.get("tempo", 1.0)

func sonar() -> void:
	_golpe = 1.0

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += dt * tempo
	_golpe = move_toward(_golpe, 0.0, dt * 0.5)
	_ph += dt * tempo * lerpf(0.8, 2.2, intensidad)
	rotation = sin(_ph) * lerpf(0.05, 0.18, intensidad) + sin(_t * 6.0) * 0.25 * _golpe
