## Las MANOS del jugador: todo lo que se toca en el puesto pasa por aquí.
##  - Arrastrar (o tocar) un cuenco → la bola/salsa va a la bandeja (hueco siguiente).
##  - Arrastrar el dango de la bandeja → a un gato (entregar) o al bote (descartar).
##  - Tocar la bandeja con un dango completo → se lo lleva al gato que lo quiere.
##  - Tocar un ingrediente caído → recogerlo. Tocar un gato escandaloso → "mimos".
## Emite `accion` para que StabilitySystem sepa cuándo estás actuando.
extends Node2D

signal accion()
signal bola_puesta(color_id: String)
signal salsa_puesta()
signal entregado(cat: Node2D)
signal descartado()
signal recogido(ing: Node2D)
signal mochi_acariciado()

const C := preload("res://scripts/core/Config.gd")
const PALETTE := preload("res://resources/dango_paleta.tres")
const DangoScene := preload("res://scenes/dango/Dango.tscn")

var bandeja: Node2D
var bote: Node2D
var ingredientes: Array = []
var clientela: Node2D
var companero: Node2D
var habilitado := true          # false durante la regulación (no produces)

var dragging := ""              # "" · "ingrediente" · "dango"
var _drag_ing: Node2D = null
var _float: Node2D = null
var _press_pos := Vector2.ZERO
var _moved := false
var _hover_cat: Node2D = null

func is_dragging() -> bool:
	return dragging != ""

func dragging_position() -> Vector2:
	return _float.global_position if _float else Vector2.ZERO

func _all_cats() -> Array:
	var r: Array = clientela.waiting()
	if companero and companero.is_active():
		r.append(companero)
	return r

func _cat_at(p: Vector2) -> Node2D:
	for c in _all_cats():
		if c.hit(p):
			return c
	return null

# ------------------------------------------------------------------ PRESS
func press(p: Vector2) -> void:
	_press_pos = p
	_moved = false
	if companero and companero.hit(p) and not companero.is_active():
		companero.pet()
		mochi_acariciado.emit()
		return
	if not habilitado:
		return
	for ing in ingredientes:
		if ing.hit_floor(p):
			ing.restore(true)
			recogido.emit(ing)
			accion.emit()
			return
	for ing in ingredientes:
		if ing.hit(p):
			if ing.usable():
				_start_ing_drag(ing, p)
			else:
				ing.wiggle()
			accion.emit()
			return
	if bandeja.hit(p) and not bandeja.is_empty():
		_start_dango_drag(p)
		accion.emit()
		return
	var cat := _cat_at(p)
	if cat:
		accion.emit()
		if bandeja.is_complete():
			_deliver(cat)
		elif cat == companero or cat.is_urgent():
			cat.pet()
		else:
			cat.say("miau")
		return
	if bote.hit(p) and not bandeja.is_empty():
		_discard_from_tray()
		accion.emit()

func _start_ing_drag(ing: Node2D, p: Vector2) -> void:
	dragging = "ingrediente"
	_drag_ing = ing
	var s := Sprite2D.new()
	s.texture = PALETTE.texture_for(ing.ingredient_id)
	s.scale = Vector2.ONE * (0.75 if ing.ingredient_id != "salsa" else 0.8)
	_float = s
	add_child(s)
	s.global_position = p
	ing.wiggle()

func _start_dango_drag(p: Vector2) -> void:
	dragging = "dango"
	var d := DangoScene.instantiate()
	add_child(d)
	d.set_data(bandeja.data())
	d.scale = bandeja.dango.global_scale
	_float = d
	d.global_position = p + Vector2(0, 60)
	bandeja.dango.visible = false

# ------------------------------------------------------------------ MOVE
func move(p: Vector2) -> void:
	if not is_dragging():
		return
	if p.distance_to(_press_pos) > C.DRAG_THRESHOLD:
		_moved = true
	if dragging == "ingrediente":
		_float.global_position = p
	else:
		_float.global_position = p + Vector2(0, 60)
		var c := _cat_at(p)
		if _hover_cat and _hover_cat != c and is_instance_valid(_hover_cat):
			_hover_cat.highlighted = false
		_hover_cat = c
		if c:
			c.highlighted = true
		bote.set_invitando(bote.hit(p))

# ------------------------------------------------------------------ RELEASE
func release(p: Vector2) -> void:
	if dragging == "ingrediente":
		var over_tray: bool = bandeja.hit(p) or p.distance_to(bandeja.next_slot_global()) < 70.0
		if (over_tray or not _moved) and _place(_drag_ing.ingredient_id):
			_fly_and_free(_float, bandeja.next_slot_global() if _drag_ing.ingredient_id == "salsa" else bandeja.dango.slot_global_position(maxi(0, bandeja.ball_count() - 1)), 0.12)
		else:
			_fly_and_free(_float, _drag_ing.global_position, 0.2)
	elif dragging == "dango":
		if _hover_cat and is_instance_valid(_hover_cat):
			_hover_cat.highlighted = false
		bote.set_invitando(false)
		var cat := _cat_at(p)
		if cat and _moved:
			_float.queue_free()
			bandeja.dango.visible = true
			_deliver(cat)
		elif bote.hit(p) and _moved:
			_discard_float()
		elif not _moved and bandeja.is_complete():
			_float.queue_free()
			bandeja.dango.visible = true
			_deliver_to_matching()
		else:
			_float.queue_free()
			bandeja.dango.visible = true
	dragging = ""
	_float = null
	_drag_ing = null
	_hover_cat = null

func _place(id: String) -> bool:
	if id == "salsa":
		if bandeja.add_sauce():
			salsa_puesta.emit()
			return true
		return false
	if bandeja.add_ball(id):
		bola_puesta.emit(id)
		return true
	return false

func _fly_and_free(n: Node2D, target: Vector2, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "global_position", target, t)
	tw.tween_callback(n.queue_free)

## Tocar la bandeja: el dango "vuela" al gato que lo quiere (si hay uno).
func _deliver_to_matching() -> void:
	for c in _all_cats():
		if c.wants(bandeja.data()):
			_deliver(c)
			return
	var tw := create_tween()
	tw.tween_property(bandeja, "rotation", 0.04, 0.07)
	tw.tween_property(bandeja, "rotation", -0.04, 0.07)
	tw.tween_property(bandeja, "rotation", 0.0, 0.07)

func _deliver(cat: Node2D) -> void:
	if not bandeja.is_complete():
		cat.say("¿?")
		return
	var d: Dictionary = bandeja.data()
	if cat.receive(d):
		bandeja.clear()
		entregado.emit(cat)

func _discard_from_tray() -> void:
	var d := DangoScene.instantiate()
	add_child(d)
	d.set_data(bandeja.data())
	d.scale = bandeja.dango.global_scale
	d.global_position = bandeja.dango.global_position
	_float = d
	_discard_float()
	_float = null

## "Este no salió bien. Lo descartamos y seguimos."
func _discard_float() -> void:
	bote.tirar()
	var f := _float
	var tw := create_tween().set_parallel(true)
	tw.tween_property(f, "global_position", bote.global_position + Vector2(0, -20), 0.25)
	tw.tween_property(f, "scale", f.scale * 0.4, 0.3)
	tw.chain().tween_callback(f.queue_free)
	bandeja.clear()
	descartado.emit()
