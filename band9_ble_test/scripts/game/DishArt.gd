## Dibujo vectorial de los platillos (té, onigiri, dango). Sin texturas externas.
extends RefCounted

const NAMES := {"te": "Té", "onigiri": "Onigiri", "dango": "Dango"}

static func draw(ci: CanvasItem, kind: String, p: Vector2, s: float = 1.0, alpha: float = 1.0) -> void:
	match kind:
		"te":
			var cup := Color(0.93, 0.9, 0.82, alpha)
			ci.draw_rect(Rect2(p + Vector2(-13, -8) * s, Vector2(26, 20) * s), cup)
			ci.draw_circle(p + Vector2(0, 12) * s, 13 * s, cup)
			ci.draw_rect(Rect2(p + Vector2(-11, -6) * s, Vector2(22, 5) * s), Color(0.45, 0.65, 0.35, alpha))
			ci.draw_arc(p + Vector2(15, 3) * s, 6 * s, -PI / 2, PI / 2, 8, cup, 3 * s)
		"onigiri":
			var pts := PackedVector2Array([p + Vector2(0, -17) * s, p + Vector2(18, 14) * s, p + Vector2(-18, 14) * s])
			ci.draw_colored_polygon(pts, Color(0.98, 0.98, 0.95, alpha))
			ci.draw_rect(Rect2(p + Vector2(-8, 3) * s, Vector2(16, 11) * s), Color(0.12, 0.2, 0.15, alpha))
		"dango":
			ci.draw_line(p + Vector2(-20, 14) * s, p + Vector2(18, -16) * s, Color(0.7, 0.55, 0.35, alpha), 2.5 * s)
			ci.draw_circle(p + Vector2(-9, 6) * s, 7 * s, Color(0.55, 0.78, 0.45, alpha))
			ci.draw_circle(p + Vector2(0, -1) * s, 7 * s, Color(0.98, 0.97, 0.9, alpha))
			ci.draw_circle(p + Vector2(9, -8) * s, 7 * s, Color(0.98, 0.65, 0.72, alpha))
