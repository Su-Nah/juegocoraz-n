## Guía diegética: una huella de gato que señala QUÉ tocar después.
## Sin texto. La usa el ritual (Mochi pide su primer dango) y, si alguien se
## queda atascado al principio, reaparece con suavidad.
extends Node2D

const DangoData := preload("res://scripts/core/DangoData.gd")

@onready var huella: Sprite2D = $Huella
var _t := 0.0
var _target := Vector2.ZERO
var activo := false

func _ready() -> void:
	huella.modulate.a = 0.0

func ocultar() -> void:
	activo = false

func _process(dt: float) -> void:
	_t += dt
	var a := huella.modulate.a
	huella.modulate.a = move_toward(a, 0.95 if activo else 0.0, dt * 2.0)
	huella.global_position = huella.global_position.lerp(_target + Vector2(0, -50 + sin(_t * 4.0) * 8.0), minf(1.0, dt * 8.0))
	huella.scale = Vector2.ONE * (1.0 + 0.1 * sin(_t * 4.0))

## Decide adónde señalar para preparar `order` y llevárselo a `cat`.
func guiar(order: Dictionary, cat: Node2D, manos: Node2D) -> void:
	activo = true
	var bandeja: Node2D = manos.bandeja
	if manos.dragging == "ingrediente":
		_target = bandeja.next_slot_global() + Vector2(0, 40)
		return
	if manos.dragging == "dango":
		_target = cat.global_position + Vector2(0, -60)
		return
	var d: Dictionary = bandeja.data()
	var n := DangoData.ball_count(d)
	# ¿Algo no coincide? → el bote (descartar es normal).
	var wrong := false
	for i in n:
		if d[DangoData.SLOTS[i]] != order[DangoData.SLOTS[i]]:
			wrong = true
	if d["sauce"] and not order["sauce"]:
		wrong = true
	if wrong:
		_target = manos.bote.global_position
		return
	if n < 3:
		_target = _ing(manos, order[DangoData.SLOTS[n]])
	elif order["sauce"] and not d["sauce"]:
		_target = _ing(manos, "salsa")
	else:
		_target = bandeja.global_position + Vector2(0, 20)   # ahora: llevar la bandeja
		if fmod(_t, 2.4) > 1.2:
			_target = cat.global_position + Vector2(0, -40)

func _ing(manos: Node2D, id: String) -> Vector2:
	for ing in manos.ingredientes:
		if ing.ingredient_id == id:
			if ing.is_on_floor():
				return ing.get_node("Visual").global_position
			return ing.global_position
	return Vector2.ZERO
