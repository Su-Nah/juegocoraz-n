## Símbolo de alto contraste para no depender solo del color:
##   verde ▲ · blanca ■ · rosa ● · salsa ≈ . Se usa en bolas, cuencos y pedidos.
@tool
extends Node2D

@export var id := "":
	set(v):
		id = v
		queue_redraw()
@export var size := 12.0:
	set(v):
		size = v
		queue_redraw()

const INK := Color(0.12, 0.09, 0.1)
const RIM := Color(1, 1, 1)

func _draw() -> void:
	var s := size
	match id:
		"verde":
			var p := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.95, s * 0.7), Vector2(-s * 0.95, s * 0.7)])
			draw_colored_polygon(p, INK)
			draw_polyline(p + PackedVector2Array([p[0]]), RIM, 2.0)
		"blanca":
			var r := Rect2(-s * 0.75, -s * 0.75, s * 1.5, s * 1.5)
			draw_rect(r, INK)
			draw_rect(r, RIM, false, 2.0)
		"rosa":
			draw_circle(Vector2.ZERO, s * 0.8, INK)
			draw_arc(Vector2.ZERO, s * 0.8, 0, TAU, 24, RIM, 2.0)
		"salsa":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var x := -s + 2.0 * s * i / 8.0
					pts.append(Vector2(x, (k * 0.9 - 0.45) * s + sin(i * 0.8) * s * 0.25))
				draw_polyline(pts, RIM, 6.0)
				draw_polyline(pts, INK, 3.5)
