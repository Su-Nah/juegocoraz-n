## Base de todo lo ambiental que reacciona al estado del mundo.
## El GameDirector NO toca sprites: Game.gd difunde un diccionario a todos los
## nodos del grupo "ambiente_reactivo" y cada sistema decide cómo representarlo.
##   intensidad  0..1  (ambient_intensity: más movimiento / densidad)
##   tempo       ~0.8..1.4 (velocidad de animaciones; la recuperación lo baja)
##   respiracion -1..1 ciclo lento del puesto (pista opcional para respirar)
##   enfasis     0..1  la regulación voluntaria amplía el ciclo
##   alivio      0..1  recuperación / espacio
extends Node2D

var intensidad := 0.0
var tempo := 1.0
var respiracion := 0.0
var enfasis := 0.0
var alivio := 0.0

func _enter_tree() -> void:
	add_to_group("ambiente_reactivo")

func aplicar_ambiente(e: Dictionary) -> void:
	intensidad = e.get("intensidad", intensidad)
	tempo = e.get("tempo", tempo)
	respiracion = e.get("respiracion", respiracion)
	enfasis = e.get("enfasis", enfasis)
	alivio = e.get("alivio", alivio)
