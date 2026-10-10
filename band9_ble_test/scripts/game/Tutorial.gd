## Guía en el mundo: una huella que señala QUÉ tocar y, la primera vez que
## aparece una acción, una DEMOSTRACIÓN animada del control real:
##   "point" señala · "click" pulsa sobre el objetivo · "drag" va de A a B (arrastrar).
## Cada demostración se muestra hasta que el jugador aprende la acción (Coach).
extends Node2D

const DangoData := preload("res://scripts/core/DangoData.gd")

@onready var huella: Sprite2D = $Huella
var _t := 0.0
var _target := Vector2.ZERO
var _from := Vector2.ZERO
var mode := "point"
var activo := false

func _ready() -> void:
	huella.modulate.a = 0.0

func ocultar() -> void:
	activo = false

func point(at: Vector2) -> void:
	activo = true
	mode = "point"
	_target = at

func demo_click(at: Vector2) -> void:
	activo = true
	mode = "click"
	_target = at

func demo_drag(from: Vector2, to: Vector2) -> void:
	activo = true
	mode = "drag"
	_from = from
	_target = to

func _process(dt: float) -> void:
	_t += dt
	huella.modulate.a = move_toward(huella.modulate.a, 0.95 if activo else 0.0, dt * 2.0)
	match mode:
		"drag":
			# Pulsa en A, viaja a B, suelta (1,6 s por ciclo)
			var k := fmod(_t, 1.6) / 1.6
			var m := clampf((k - 0.15) / 0.6, 0.0, 1.0)
			huella.global_position = _from.lerp(_target, m * m * (3.0 - 2.0 * m)) + Vector2(0, -20)
			huella.scale = Vector2.ONE * (0.85 if (k > 0.1 and k < 0.8) else 1.1)
		"click":
			huella.global_position = huella.global_position.lerp(_target + Vector2(0, -30), minf(1.0, dt * 8.0))
			huella.scale = Vector2.ONE * (0.85 if fmod(_t, 0.9) < 0.25 else 1.1)
		_:
			huella.global_position = huella.global_position.lerp(_target + Vector2(0, -50 + sin(_t * 4.0) * 8.0), minf(1.0, dt * 8.0))
			huella.scale = Vector2.ONE * (1.0 + 0.1 * sin(_t * 4.0))
	queue_redraw()

func _draw() -> void:
	if huella.modulate.a < 0.05:
		return
	var a := huella.modulate.a
	var ink := Color(1.0, 0.92, 0.3, 0.9 * a)
	if mode == "drag":
		# flecha punteada A → B
		var d := _target - _from
		var n := int(d.length() / 22.0)
		for i in n:
			if i % 2 == 0:
				draw_line(to_local(_from + d * (float(i) / n)), to_local(_from + d * (float(i + 1) / n)), ink, 6.0)
		var dir := d.normalized()
		var tip := to_local(_target)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 28 + dir.orthogonal() * 16, tip - dir * 28 - dir.orthogonal() * 16]), ink)
	elif mode == "click":
		var r := 28.0 + 26.0 * fmod(_t, 0.9) / 0.9
		draw_arc(to_local(_target), r, 0, TAU, 32, Color(ink, ink.a * (1.0 - fmod(_t, 0.9) / 0.9)), 6.0)

## Señala el siguiente paso para preparar `order` y llevárselo a `cat`.
## Devuelve el paso: "bote" · "bola" · "salsa" · "entregar".
func guiar(order: Dictionary, cat: Node2D, manos: Node2D, demos := {}) -> String:
	var bandeja: Node2D = manos.bandeja
	if manos.dragging == "ingrediente":
		point(bandeja.next_slot_global() + Vector2(0, 40))
		return "bola"
	if manos.dragging == "dango":
		point(cat.global_position + Vector2(0, -60))
		return "entregar"
	var d: Dictionary = bandeja.data()
	var n := DangoData.ball_count(d)
	var wrong := false
	for i in n:
		if d[DangoData.SLOTS[i]] != order[DangoData.SLOTS[i]]:
			wrong = true
	if d["sauce"] and not order["sauce"]:
		wrong = true
	if wrong:
		_show("bote", demos, manos.bote.global_position, manos.bote.global_position)
		return "bote"
	if n < 3:
		var from := _ing(manos, order[DangoData.SLOTS[n]])
		_show("bola", demos, from, bandeja.next_slot_global(), true)
		return "bola"
	if order["sauce"] and not d["sauce"]:
		var p := _ing(manos, "salsa")
		_show("salsa", demos, p, p)
		return "salsa"
	_show("entregar", demos, bandeja.global_position + Vector2(0, -40), cat.global_position + Vector2(0, -60), true)
	return "entregar"

func _show(step: String, demos: Dictionary, from: Vector2, to: Vector2, drag := false) -> void:
	if demos.get(step, false):
		if drag:
			demo_drag(from, to)
		else:
			demo_click(from)
	else:
		point(from if not drag or step == "bola" else to)

func _ing(manos: Node2D, id: String) -> Vector2:
	for ing in manos.ingredientes:
		if ing.ingredient_id == id:
			if ing.is_on_floor():
				return ing.get_node("Visual").global_position
			return ing.global_position + Vector2(0, -30)
	return Vector2.ZERO
