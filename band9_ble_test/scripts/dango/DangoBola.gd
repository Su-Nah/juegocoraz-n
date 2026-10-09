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

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	visible = color_id != ""
	_bola.texture = PALETTE.texture_for(color_id)

## Pequeño "pop" al colocarla (feedback inmediato).
func pop() -> void:
	scale = Vector2(1.25, 0.8)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
