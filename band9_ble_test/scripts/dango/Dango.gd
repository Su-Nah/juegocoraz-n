## Dango compuesto: Palito + 3 DangoBola + Salsa opcional.
## Se genera a partir de datos (DangoData) — no existen 54 escenas.
@tool
extends Node2D

const DangoData := preload("res://scripts/core/DangoData.gd")

@export var lower := "":
	set(v):
		lower = v
		_refresh()
@export var middle := "":
	set(v):
		middle = v
		_refresh()
@export var upper := "":
	set(v):
		upper = v
		_refresh()
@export var sauce := false:
	set(v):
		sauce = v
		_refresh()

func _ready() -> void:
	_refresh()

func set_data(d: Dictionary) -> void:
	lower = d["lower"]
	middle = d["middle"]
	upper = d["upper"]
	sauce = d["sauce"]

func get_data() -> Dictionary:
	return DangoData.make(lower, middle, upper, sauce)

func ball_node(slot_index: int) -> Node2D:
	return get_node(["BolaInferior", "BolaCentral", "BolaSuperior"][slot_index])

## Posición global del hueco (para la bandeja y las pistas).
func slot_global_position(slot_index: int) -> Vector2:
	return ball_node(slot_index).global_position

func _refresh() -> void:
	if not is_node_ready():
		return
	$BolaInferior.color_id = lower
	$BolaCentral.color_id = middle
	$BolaSuperior.color_id = upper
	# La salsa solo se ve sobre las bolas que existen.
	var salsa := $Salsa
	salsa.visible = sauce
	for i in salsa.get_child_count():
		var s := salsa.get_child(i) as CanvasItem
		s.visible = [lower, middle, upper][mini(i, 2)] != ""
