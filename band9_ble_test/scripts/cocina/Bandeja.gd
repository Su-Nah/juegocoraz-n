## La bandeja: el espacio donde se construye el dango.
## - Muestra el hueco SIGUIENTE (abajo → medio → arriba) con un aro que respira.
## - Cuando el dango está completo, la bandeja brilla suavemente: "esto ya se puede llevar".
@tool
extends "res://scripts/cocina/Interactivo.gd"

signal cambiado(data: Dictionary)

const DangoData := preload("res://scripts/core/DangoData.gd")

@onready var dango: Node2D = $Dango
@onready var _huecos: Node2D = $Huecos
@onready var _brillo: CanvasItem = $Brillo
var _t := 0.0
var enabled := true

func _ready() -> void:
	clear()

func data() -> Dictionary:
	return dango.get_data()

func ball_count() -> int:
	return DangoData.ball_count(data())

func is_complete() -> bool:
	return DangoData.is_complete(data())

func is_empty() -> bool:
	return ball_count() == 0 and not dango.sauce

func add_ball(color_id: String) -> bool:
	var n := ball_count()
	if n >= 3 or dango.sauce:
		return false
	match n:
		0: dango.lower = color_id
		1: dango.middle = color_id
		2: dango.upper = color_id
	dango.ball_node(n).pop()
	cambiado.emit(data())
	return true

func add_sauce() -> bool:
	if ball_count() == 0 or dango.sauce:
		return false
	dango.sauce = true
	cambiado.emit(data())
	return true

func clear() -> void:
	dango.set_data(DangoData.empty())
	dango.visible = true
	cambiado.emit(data())

func next_slot_global() -> Vector2:
	return dango.slot_global_position(mini(ball_count(), 2))

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += dt
	var n := ball_count()
	for i in _huecos.get_child_count():
		var h := _huecos.get_child(i) as Node2D
		h.global_position = dango.slot_global_position(i)
		h.visible = enabled and i == n and not dango.sauce and dango.visible
		h.scale = Vector2.ONE * (0.75 * dango.scale.x / 0.75) * (1.0 + 0.08 * sin(_t * 3.0))
	_brillo.visible = is_complete() and dango.visible
	_brillo.modulate.a = 0.35 + 0.25 * sin(_t * 2.5)
