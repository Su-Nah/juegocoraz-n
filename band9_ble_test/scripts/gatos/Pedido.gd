## Bocadillo del pedido: muestra un dango de referencia (misma escena Dango),
## no texto. El aro de paciencia es discreto y sin números.
extends Node2D

@export var color_lleno := Color(0.45, 0.7, 0.55)
@export var color_poco := Color(0.92, 0.62, 0.4)

@onready var dango: Node2D = $Dango
@onready var _urgente: CanvasItem = $Urgente
var ratio := 1.0
var urgente := false:
	set(v):
		urgente = v
		if is_node_ready():
			_urgente.visible = v

func set_order(d: Dictionary) -> void:
	dango.set_data(d)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := color_lleno.lerp(color_poco, 1.0 - ratio)
	var center := Vector2(46, -58)
	draw_circle(center, 12, Color(1, 0.98, 0.94))
	draw_arc(center, 10, -PI / 2, -PI / 2 + TAU * clampf(ratio, 0.0, 1.0), 24, c, 5.0)
