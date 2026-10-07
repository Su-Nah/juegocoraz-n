## Base para objetos del puesto que se pueden tocar. La zona táctil se edita
## en el Inspector (hit_size / hit_offset) y se dibuja en el editor.
@tool
extends Node2D

@export var hit_size := Vector2(100, 100):
	set(v):
		hit_size = v
		queue_redraw()
@export var hit_offset := Vector2.ZERO:
	set(v):
		hit_offset = v
		queue_redraw()

func hit(global_point: Vector2) -> bool:
	var local := to_local(global_point) - hit_offset
	return Rect2(-hit_size / 2.0, hit_size).has_point(local)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(hit_offset - hit_size / 2.0, hit_size), Color(1, 0.6, 0.2, 0.6), false, 2.0)
