## El puesto "respira": cielo, árbol, techo, noren, farolillos, mostrador y la
## fuente de agua donde cae una gota por latido. Todo se mueve según:
##   breath    ciclo lento (BREATH_PERIOD) — pista visual opcional para respirar despacio
##   intensity 0..1 del ArousalDirector — más viento, hojas, movimiento
##   tempo     velocidad de las animaciones (la recuperación desacelera)
extends Node2D

const C := preload("res://scripts/core/Config.gd")

var intensity := 0.0
var tempo := 1.0
var calm := 0.5
var lantern_glow := 1.0      # 0..1; en el baseline se encienden poco a poco
var breath := 0.0            # -1..1 (lo leen otros nodos)
var breath_emphasis := 0.0   # 0..1 durante la pausa voluntaria
var _t := 0.0
var _bt := 0.0
var _leaves: Array = []      # [pos, vel, rot]
var _drops: Array = []       # [y, vy]
var _ripples: Array = []     # [r, a]

const SPOUT := Vector2(1215, 250)
const BOWL := Vector2(1215, 418)

func emit_drop() -> void:
	_drops.append([SPOUT.y, 0.0])

func _process(dt: float) -> void:
	_t += dt * tempo
	_bt += dt
	breath = sin(TAU * _bt / C.BREATH_PERIOD)
	# hojas que caen: más con viento
	if randf() < dt * (0.15 + 1.6 * intensity):
		_leaves.append([Vector2(randf_range(0, 400), randf_range(20, 120)), Vector2(randf_range(15, 40) * (1.0 + intensity), randf_range(20, 40)), randf() * TAU])
	for l in _leaves:
		l[0] += l[1] * dt * tempo + Vector2(sin(_t * 2.0 + l[2]) * 12.0 * dt, 0)
		l[2] += dt * 2.0
	_leaves = _leaves.filter(func(l): return l[0].y < 430 and l[0].x < 1300)
	for d in _drops:
		d[1] += 900.0 * dt
		d[0] += d[1] * dt
	for d in _drops:
		if d[0] >= BOWL.y - 8:
			_ripples.append([4.0, 0.7])
	_drops = _drops.filter(func(d): return d[0] < BOWL.y - 8)
	for r in _ripples:
		r[0] += dt * 30.0
		r[1] -= dt * 0.9
	_ripples = _ripples.filter(func(r): return r[1] > 0.0)
	queue_redraw()

func _draw() -> void:
	var calm_tint := Color(0.78, 0.9, 0.92)
	var warm_tint := Color(0.98, 0.82, 0.7)
	var sky := calm_tint.lerp(warm_tint, intensity * 0.6)
	# cielo en franjas suaves
	for i in 8:
		draw_rect(Rect2(0, i * 55, 1280, 56), sky.lerp(Color(0.95, 0.95, 0.9), i / 10.0))
	# montañas lejanas
	draw_colored_polygon(PackedVector2Array([Vector2(0, 330), Vector2(200, 230), Vector2(420, 320), Vector2(650, 210), Vector2(900, 310), Vector2(1100, 240), Vector2(1280, 300), Vector2(1280, 440), Vector2(0, 440)]), Color(0.62, 0.74, 0.74).lerp(sky, 0.4))
	# árbol con copa que se mece
	var sway := sin(_t * (0.6 + 1.2 * intensity)) * (4.0 + 14.0 * intensity)
	draw_rect(Rect2(80, 150, 28, 290), Color(0.4, 0.3, 0.25))
	for k in 5:
		var off := Vector2(sway * (0.6 + k * 0.1), 0)
		draw_circle(Vector2(60 + k * 30, 120 + (k % 2) * 30) + off, 60, Color(0.95, 0.75, 0.8).lerp(Color(0.6, 0.78, 0.55), 0.35))
	for l in _leaves:
		draw_circle(l[0], 4, Color(0.98, 0.72, 0.78))

	# techo del puesto
	draw_rect(Rect2(150, 70, 1120, 22), Color(0.55, 0.25, 0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(130, 92), Vector2(1290, 92), Vector2(1250, 135), Vector2(170, 135)]), Color(0.72, 0.32, 0.27))
	draw_rect(Rect2(175, 135, 16, 300), Color(0.45, 0.32, 0.25))
	draw_rect(Rect2(1230, 135, 16, 300), Color(0.45, 0.32, 0.25))
	# noren (cortinas): se mecen con la respiración y el viento
	var amp := 3.0 + 10.0 * intensity + 6.0 * breath_emphasis
	for i in 6:
		var x0 := 260.0 + i * 160.0
		var sw := sin(_t * (0.5 + 1.5 * intensity) + i * 0.7) * amp + breath * (2.0 + 4.0 * breath_emphasis)
		var pts := PackedVector2Array([Vector2(x0, 135), Vector2(x0 + 130, 135), Vector2(x0 + 130 + sw, 205), Vector2(x0 + sw, 205)])
		draw_colored_polygon(pts, Color(0.22, 0.32, 0.5).lerp(Color(0.5, 0.3, 0.45), intensity * 0.5))
		draw_circle(Vector2(x0 + 65 + sw * 0.5, 172), 12, Color(0.95, 0.93, 0.88, 0.8))
	# farolillos: se expanden y contraen lentamente (pista de respiración)
	for lx in [215.0, 1205.0]:
		var swing := sin(_t * (0.8 + 2.0 * intensity) + lx) * (2.0 + 8.0 * intensity)
		var s := 1.0 + 0.06 * breath * (1.0 + 1.5 * breath_emphasis)
		var lp := Vector2(lx + swing, 175)
		draw_line(Vector2(lx, 135), lp - Vector2(0, 28 * s), Color(0.2, 0.2, 0.2), 2)
		var glow := lantern_glow * (0.5 + 0.25 * (1.0 + breath))
		draw_circle(lp, 46 * s, Color(1.0, 0.75, 0.4, 0.12 * glow))
		draw_set_transform(lp, 0, Vector2(s * 0.8, s))
		draw_circle(Vector2.ZERO, 30, Color(0.9, 0.3, 0.25).lerp(Color(1, 0.8, 0.5), 0.4 * glow))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# mostrador (los gatos quedan detrás)
	draw_rect(Rect2(0, C.COUNTER_Y - 12, 1280, 14), Color(0.76, 0.58, 0.42))

	# fuente: caño de bambú, gotas y cuenco
	draw_line(SPOUT + Vector2(40, -6), SPOUT, Color(0.55, 0.7, 0.4), 9)
	for d in _drops:
		draw_circle(Vector2(SPOUT.x, d[0]), 3.5, Color(0.7, 0.85, 1.0, 0.9))
	draw_colored_polygon(PackedVector2Array([BOWL + Vector2(-40, -8), BOWL + Vector2(40, -8), BOWL + Vector2(28, 10), BOWL + Vector2(-28, 10)]), Color(0.55, 0.55, 0.58))
	for r in _ripples:
		draw_set_transform(BOWL + Vector2(0, -8), 0, Vector2(1, 0.3))
		draw_arc(Vector2.ZERO, r[0], 0, TAU, 20, Color(0.8, 0.9, 1.0, r[1]), 1.5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## Frente del mostrador: nodo aparte para dibujarse POR DELANTE de los gatos.
class CounterFront extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 432, 1280, 168), Color(0.62, 0.45, 0.32))
		for i in 12:
			draw_line(Vector2(i * 110 + 40, 440), Vector2(i * 110 + 40, 595), Color(0.55, 0.39, 0.28), 3)
		draw_rect(Rect2(0, 560, 1280, 40), Color(0.5, 0.4, 0.33))
