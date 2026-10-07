## Cuenco de ingrediente sobre la barra (bola verde/blanca/rosa o salsa).
## Un gato puede tirarlo: cae, queda inutilizable un rato y vuelve solo
## (o lo recoges antes). Después hay un cooldown antes de poder caer otra vez.
@tool
extends "res://scripts/cocina/Interactivo.gd"

signal tirado(ing: Node2D)
signal recuperado(ing: Node2D, por_jugador: bool)

const C := preload("res://scripts/core/Config.gd")
const PALETTE := preload("res://resources/dango_paleta.tres")

@export_enum("verde", "blanca", "rosa", "salsa") var ingredient_id := "verde":
	set(v):
		ingredient_id = v
		_refresh()

## Opcional: otra textura de recipiente (p.ej. la olla de salsa).
@export var textura_recipiente: Texture2D:
	set(v):
		textura_recipiente = v
		_refresh()

var state := "listo"          # listo · cayendo · suelo · volviendo
var cooldown := 0.0           # s hasta poder volver a ser tirado
var reservado := false        # un gato travieso ya lo eligió
var _suelo_t := 0.0
var _t := 0.0

@onready var _visual: Node2D = $Visual

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	# Las bolitas de muestra usan la MISMA paleta que el dango.
	if textura_recipiente:
		$Visual/Recipiente.texture = textura_recipiente
		$Visual/Recipiente.position = Vector2(0, -40)
	var cont := get_node_or_null("Visual/Contenido")
	if cont:
		for s in cont.get_children():
			(s as Sprite2D).texture = PALETTE.texture_for(ingredient_id) if ingredient_id != "salsa" else null

func usable() -> bool:
	return state == "listo"

func can_be_knocked() -> bool:
	return state == "listo" and cooldown <= 0.0 and not reservado

func is_on_floor() -> bool:
	return state == "suelo"

func knock(dir: float) -> void:
	if state != "listo":
		return
	state = "cayendo"
	reservado = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "position", Vector2(dir * 55.0, 150.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation", dir * 1.6, 0.55)
	tw.chain().tween_callback(func():
		state = "suelo"
		_suelo_t = 0.0
		_visual.modulate = Color(0.8, 0.8, 0.8)
		tirado.emit(self))

func hit_floor(p: Vector2) -> bool:
	return state == "suelo" and p.distance_to(_visual.global_position) < 60.0

func restore(por_jugador: bool) -> void:
	if state != "suelo":
		return
	state = "volviendo"
	cooldown = C.INGREDIENT_KNOCK_COOLDOWN
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "position", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "rotation", 0.0, 0.4)
	tw.chain().tween_callback(func():
		state = "listo"
		_visual.modulate = Color.WHITE)
	recuperado.emit(self, por_jugador)

func reset() -> void:
	state = "listo"
	cooldown = 0.0
	reservado = false
	_visual.position = Vector2.ZERO
	_visual.rotation = 0.0
	_visual.modulate = Color.WHITE

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += dt
	cooldown = maxf(0.0, cooldown - dt)
	if state == "suelo":
		_suelo_t += dt
		_visual.position.y = 150.0 + sin(_t * 3.0) * 1.5
		if _suelo_t >= C.INGREDIENT_AUTO_RETURN:
			restore(false)   # podía esperar: vuelve solo

## Pequeña reacción al tocarlo.
func wiggle() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "rotation", 0.12, 0.06)
	tw.tween_property(_visual, "rotation", -0.08, 0.08)
	tw.tween_property(_visual, "rotation", 0.0, 0.08)
