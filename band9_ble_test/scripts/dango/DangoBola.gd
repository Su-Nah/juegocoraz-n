## Una bola del dango. Solo cambia su textura según color_id; el sprite
## concreto viene de la paleta (DangoPalette), así puedes reemplazar los PNG.
@tool
extends Node2D

const PALETTE := preload("res://resources/dango_paleta.tres")

@export var color_id := "":
	set(v):
		color_id = v
		_refresh()

@onready var _bola: Sprite2D = $Bola

const Simbolo := preload("res://scripts/dango/SimboloIngrediente.gd")
## Color más contrastado (multiplica la textura). Edita en el Inspector.
const TINTE := {"verde": Color(0.62, 1.0, 0.55), "blanca": Color(1, 1, 1), "rosa": Color(1.0, 0.62, 0.8)}
var _simbolo: Node2D

func _ready() -> void:
	if not Engine.is_editor_hint():
		_simbolo = Simbolo.new()
		_simbolo.size = 12.0
		add_child(_simbolo)
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	visible = color_id != ""
	_bola.texture = PALETTE.texture_for(color_id)
	_bola.self_modulate = TINTE.get(color_id, Color.WHITE)
	if _simbolo:
		_simbolo.id = color_id

## Pequeño "pop" al colocarla (feedback inmediato).
func pop() -> void:
	scale = Vector2(1.25, 0.8)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
