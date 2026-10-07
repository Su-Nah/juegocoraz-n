## Cocina del lado del jugador: 3 estaciones (té, onigiri, dango) + la mano.
## Preparación automática; hacer clic repetido acelera (productividad frenética,
## que a cambio cuesta estabilidad en StabilitySystem).
extends Node2D

signal picked(kind: String)

const C := preload("res://scripts/core/Config.gd")
const DishArt := preload("res://scripts/game/DishArt.gd")
const STATIONS := ["te", "onigiri", "dango"]
const STATION_X := [330.0, 640.0, 950.0]
const STATION_Y := 650.0
const HAND_POS := Vector2(1170, 650)

var progress := [-1.0, -1.0, -1.0]   # -1 libre · 0..1 preparando · >=1 listo
var blocked := [false, false, false]
var hand: Array = []
var tempo := 1.0
var intensity := 0.0
var breath := 0.0                    # -1..1, del puesto
var enabled := true                  # false durante la pausa voluntaria
var _steam: Array = []               # [pos, vel, life, size]
var _steam_acc := 0.0

func reset() -> void:
	progress = [-1.0, -1.0, -1.0]
	blocked = [false, false, false]
	hand.clear()

func set_blocked(station_id: String, b: bool) -> void:
	var i := STATIONS.find(station_id)
	if i >= 0:
		blocked[i] = b

func station_at(p: Vector2) -> int:
	for i in 3:
		if Rect2(STATION_X[i] - 90, STATION_Y - 70, 180, 130).has_point(p):
			return i
	return -1

func hit_hand(p: Vector2) -> bool:
	return Rect2(HAND_POS - Vector2(90, 60), Vector2(180, 120)).has_point(p) and not hand.is_empty()

## Devuelve un texto corto de lo que pasó (para sonidos).
func click_station(i: int) -> String:
	if not enabled:
		return ""
	if blocked[i]:
		return "blocked"
	if progress[i] < 0.0:
		progress[i] = 0.0
		return "start"
	if progress[i] < 1.0:
		progress[i] = minf(1.0, progress[i] + C.PREP_CLICK_BOOST)
		return "boost"
	if hand.size() >= C.HAND_CAPACITY:
		return "full"
	hand.append(STATIONS[i])
	progress[i] = -1.0
	picked.emit(STATIONS[i])
	return "pick"

func clear_hand() -> void:
	hand.clear()

func _process(dt: float) -> void:
	for i in 3:
		if progress[i] >= 0.0 and progress[i] < 1.0 and not blocked[i]:
			progress[i] = minf(1.0, progress[i] + dt / C.PREP_TIME)
	_update_steam(dt)
	queue_redraw()

## Vapor de la tetera y la olla: sube con el ciclo de "respiración" del puesto
## (pista opcional para respirar despacio) y se acelera con la intensidad.
func _update_steam(dt: float) -> void:
	var inhale := 0.5 + 0.5 * breath
	_steam_acc += dt * (1.5 + 4.0 * inhale + 5.0 * intensity)
	while _steam_acc >= 1.0:
		_steam_acc -= 1.0
		for x in [STATION_X[0] + 10.0, STATION_X[1] - 40.0]:
			_steam.append([Vector2(x + randf_range(-6, 6), STATION_Y - 60), Vector2(randf_range(-6, 6), -(18 + 40 * intensity) * tempo), 0.0, randf_range(6, 10)])
	for s in _steam:
		s[2] += dt
		s[0] += s[1] * dt + Vector2(sin(s[2] * 2.0 + s[0].y * 0.05) * 10.0 * dt, 0)
		s[3] += dt * 6.0
	_steam = _steam.filter(func(s): return s[2] < 2.4)

func _draw() -> void:
	# mesa de trabajo
	draw_rect(Rect2(0, 600, 1280, 120), Color(0.55, 0.42, 0.32))
	draw_rect(Rect2(0, 600, 1280, 6), Color(0.45, 0.33, 0.25))
	for s in _steam:
		var a: float = 0.2 * (1.0 - s[2] / 2.4)
		draw_circle(s[0], s[3], Color(1, 1, 1, a))
	for i in 3:
		var c := Vector2(STATION_X[i], STATION_Y)
		var col := Color(0.97, 0.93, 0.85) if not blocked[i] else Color(0.8, 0.75, 0.72)
		draw_rect(Rect2(c - Vector2(85, 45), Vector2(170, 95)), col)
		_draw_tool(i, c)
		var label: String = DishArt.NAMES[STATIONS[i]]
		draw_string(ThemeDB.fallback_font, c + Vector2(-80, 44), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 0.28, 0.25))
		if blocked[i]:
			draw_string(ThemeDB.fallback_font, c + Vector2(-20, 44), "(falta un objeto)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.35, 0.3))
		elif progress[i] >= 1.0:
			DishArt.draw(self, STATIONS[i], c + Vector2(40, -5), 1.1)
		elif progress[i] >= 0.0:
			draw_arc(c + Vector2(40, -5), 16, -PI / 2, -PI / 2 + TAU * progress[i], 24, Color(0.45, 0.6, 0.5), 4)
	# mano
	draw_rect(Rect2(HAND_POS - Vector2(85, 45), Vector2(170, 95)), Color(0.9, 0.86, 0.8, 0.9))
	draw_string(ThemeDB.fallback_font, HAND_POS + Vector2(-80, 44), "bandeja", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 0.28, 0.25))
	for j in hand.size():
		DishArt.draw(self, hand[j], HAND_POS + Vector2(-30 + 55 * j, -5), 1.1)
	if not enabled:
		draw_rect(Rect2(0, 600, 1280, 120), Color(0.1, 0.15, 0.2, 0.25))

func _draw_tool(i: int, c: Vector2) -> void:
	match i:
		0:  # tetera
			draw_circle(c + Vector2(-25, -5), 26, Color(0.35, 0.45, 0.42))
			draw_rect(Rect2(c + Vector2(-35, -36), Vector2(20, 8)), Color(0.3, 0.38, 0.36))
			draw_line(c + Vector2(-2, -8), c + Vector2(18, -26), Color(0.35, 0.45, 0.42), 6)
		1:  # olla de arroz
			draw_rect(Rect2(c + Vector2(-70, -20), Vector2(60, 40)), Color(0.4, 0.35, 0.33))
			draw_rect(Rect2(c + Vector2(-74, -24), Vector2(68, 6)), Color(0.5, 0.45, 0.42))
		2:  # brasero
			draw_rect(Rect2(c + Vector2(-72, 0), Vector2(70, 22)), Color(0.3, 0.27, 0.26))
			for k in 3:
				draw_circle(c + Vector2(-60 + 22 * k, 4), 5, Color(0.95, 0.5 + 0.2 * intensity, 0.3, 0.8))
