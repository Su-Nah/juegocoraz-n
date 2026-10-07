## Gestiona los asientos de la barra y crea gatos (Gato.tscn) cuando el
## director lo pide. Reenvía sus eventos al juego. No sabe nada de BPM.
extends Node2D

signal servido(cat: Node2D)
signal se_fue(cat: Node2D)
signal fu_calmada(cat: Node2D)
signal fu_reaccion(cat: Node2D)
signal tiro(cat: Node2D, ing: Node2D)
signal maullido(urgent: bool)

const C := preload("res://scripts/core/Config.gd")
@export var gato_scene: PackedScene = preload("res://scenes/gatos/Gato.tscn")

var seats: Array = [null, null, null, null]
var ingredientes: Array = []      # los asigna Game

func clear() -> void:
	for c in get_children():
		c.queue_free()
	seats = [null, null, null, null]

func free_seats() -> Array:
	var r := []
	for i in seats.size():
		if seats[i] == null:
			r.append(i)
	return r

func cats() -> Array:
	return seats.filter(func(c): return c != null)

func waiting() -> Array:
	return seats.filter(func(c): return c != null and c.is_active())

func active_count() -> int:
	return waiting().size()

func any_urgent() -> bool:
	return seats.any(func(c): return c != null and c.is_urgent())

func cat_at(p: Vector2) -> Node2D:
	for c in waiting():
		if c.hit(p):
			return c
	return null

## [ingrediente, asiento] para un gato travieso: cuenco disponible con asiento libre al lado.
func knock_option() -> Array:
	var free := free_seats()
	var pool := ingredientes.duplicate()
	pool.shuffle()
	for ing in pool:
		if not ing.can_be_knocked():
			continue
		for s in free:
			if absf(C.SEATS_X[s] - ing.global_position.x) < 140.0:
				return [ing, s]
	return []

func spawn(kind: String, order: Dictionary, patience: float) -> void:
	var seat := -1
	var target: Node2D = null
	if kind == "travieso":
		var opt := knock_option()
		if opt.is_empty():
			kind = "normal"
		else:
			target = opt[0]
			seat = opt[1]
	if seat < 0:
		var free := free_seats()
		if free.is_empty():
			return
		seat = free.pick_random()
	var cat := gato_scene.instantiate()
	add_child(cat)
	cat.setup(kind, order, patience, seat)
	if target:
		cat.knock_target = target
		target.reservado = true
	cat.left.connect(_on_left)
	cat.knock_now.connect(func(c, ing): tiro.emit(c, ing))
	cat.meowed.connect(func(u): maullido.emit(u))
	cat.fu_reacted.connect(func(c): fu_reaccion.emit(c))
	seats[seat] = cat

func _on_left(cat: Node2D, reason: String) -> void:
	if reason == "fu_calmed":
		fu_calmada.emit(cat)
		return
	if cat.seat >= 0 and seats[cat.seat] == cat:
		seats[cat.seat] = null
	if reason == "served":
		servido.emit(cat)
	else:
		se_fue.emit(cat)

## Estado del mundo para los gatos (valores abstractos del director).
func set_world(activity: float, tempo: float, calm: float, imp: float, tray_ready: bool, tray_pos: Vector2, tray_data: Dictionary) -> int:
	var purring := 0
	for c in get_children():
		c.activity = activity
		c.tempo = tempo
		c.calm = calm
		c.impatience_scale = imp
		c.tray_ready = tray_ready
		c.tray_pos = tray_pos
		c.tray_matches = tray_ready and c.wants(tray_data)
		if c.is_purring():
			purring += 1
	return purring
