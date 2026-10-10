## Indicador de pulso grande y legible (proyector): un círculo que late con cada
## lectura y el BPM actual. Indica si el dato es REAL (pulsera) o SIMULADO.
extends Control

var _beat := 0.0
var highlight := false

func beat() -> void:
	_beat = 1.0

func _process(dt: float) -> void:
	_beat = move_toward(_beat, 0.0, dt * 3.0)
	queue_redraw()

func _draw() -> void:
	var c := Vector2(44, size.y / 2)
	var r := 30.0 * (1.0 + 0.18 * _beat)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.14, 0.82 if highlight else 0.62))
	if highlight:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.85, 0.3), false, 4.0)
	draw_circle(c, r, Color(0.35, 0.72, 0.95))
	draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1), 3.0)
	var font := ThemeDB.fallback_font
	var receiving: bool = HeartRate.is_receiving()
	var bpm := "%d" % roundi(Physio.current_hr) if receiving and Physio.current_hr > 0 else "—"
	draw_string(font, Vector2(84, 44), bpm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	var src := "sin señal"
	if receiving:
		src = "BPM pulsera" if HeartRate.active_source == "web" else "BPM SIMULADO"
	draw_string(font, Vector2(84, 70), src, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.85, 0.9, 1.0))
