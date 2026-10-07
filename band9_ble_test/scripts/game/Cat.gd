## Gato cliente. Dibujado por código (sin sprites) para iterar rápido.
## Tipos: normal · impatient · knock (travieso, derriba un objeto) · false_urgency.
## Adaptado del sistema de "slot + paciencia" de Micheladas Nancy (Main.gd), pero
## irse NO es un fracaso: solo es un resultado.
extends Node2D

signal left(cat: Node2D, reason: String)    # served · let_go · patience · fu_ignored · fu_pet
signal knock_now(cat: Node2D, obj: Node2D)
signal meowed(urgent: bool)

const C := preload("res://scripts/core/Config.gd")
const DishArt := preload("res://scripts/game/DishArt.gd")
const FONT_SIZE := 15

const PALETTES := [
	[Color(0.97, 0.95, 0.92), Color(0.95, 0.75, 0.55)],  # blanco con manchas naranja
	[Color(0.98, 0.72, 0.45), Color(1.0, 0.88, 0.7)],    # naranja
	[Color(0.62, 0.64, 0.7), Color(0.85, 0.86, 0.9)],    # gris
	[Color(0.22, 0.22, 0.26), Color(0.4, 0.4, 0.45)],    # negro
	[Color(0.9, 0.85, 0.75), Color(0.35, 0.3, 0.28)],    # siamés
]

var kind := "normal"
var order: Array = []
var patience := 30.0
var patience_max := 30.0
var seat := 0
var seat_x := 0.0
var state := "arriving"     # arriving · waiting · urgent · settled · leaving
var knock_target: Node2D = null

# Lo fija Game cada frame
var agitation := 0.0        # 0..1
var tempo := 1.0
var calm := 0.5             # estabilidad del jugador
var impatience_scale := 1.0

var _base: Color
var _accent: Color
var _t := 0.0
var _state_t := 0.0
var _knock_phase := "none"  # none · wait · look · paw · done
var _knock_t := 0.0
var _paw := 0.0
var _meow_cd := 0.0
var _speech := ""
var _speech_t := 0.0
var _exit_dir := 1.0
var _leave_reason := ""
var _blink := 0.0
var _purring := false

func setup(p_kind: String, p_order: Array, p_patience: float, p_seat: int) -> void:
	kind = p_kind
	order = p_order.duplicate()
	seat = p_seat
	seat_x = C.SEATS_X[p_seat]
	patience_max = p_patience * (0.65 if kind == "impatient" else 1.0)
	if kind == "false_urgency":
		patience_max = 999.0
	patience = patience_max
	var pal: Array = PALETTES[randi() % PALETTES.size()]
	_base = pal[0]
	_accent = pal[1]
	_exit_dir = -1.0 if seat_x < 640.0 else 1.0
	position = Vector2(-80.0 if _exit_dir < 0 else 1360.0, C.COUNTER_Y)
	_t = randf() * 10.0
	if kind == "resident":
		# Gato de la actividad tranquila previa: ya está ahí, dormitando.
		position = Vector2(seat_x, C.COUNTER_Y)
		state = "resting"
	if kind == "knock":
		_knock_phase = "wait"
		_knock_t = randf_range(C.KNOCK_DELAY.x, C.KNOCK_DELAY.y)

func is_active() -> bool:
	return state == "waiting" or state == "urgent" or state == "settled"

func is_urgent() -> bool:
	return state == "urgent"

func is_purring() -> bool:
	return _purring

func _process(dt: float) -> void:
	var tdt := dt * tempo
	_t += tdt
	_state_t += dt
	_speech_t -= dt
	_blink -= dt
	match state:
		"arriving":
			position.x = move_toward(position.x, seat_x, dt * 260.0)
			if is_equal_approx(position.x, seat_x):
				_set_state("urgent" if kind == "false_urgency" else "waiting")
				if kind == "false_urgency":
					_meow(true)
		"waiting":
			patience -= dt * impatience_scale
			_update_knock(dt)
			_idle_sounds(dt)
			if patience <= 0.0:
				_say("...")
				_leave("patience")
		"urgent":
			_meow_cd -= dt
			if _meow_cd <= 0.0:
				_meow(true)
			if _state_t >= C.FU_DURATION:
				# Nadie le hizo caso... y no pasa nada. Se acomoda.
				_set_state("settled")
				_say("♪")
		"resting":
			pass
		"settled":
			if _state_t >= 4.0:
				_leave("fu_ignored")
		"leaving":
			position.x += _exit_dir * dt * 220.0
			modulate.a = move_toward(modulate.a, 0.0, dt * 0.8)
			if position.x < -120.0 or position.x > 1400.0:
				queue_free()
	_purring = (state == "settled" or state == "resting") or (is_active() and calm > 0.72 and agitation < 0.35 and _knock_phase != "paw")
	queue_redraw()

func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0

func _idle_sounds(dt: float) -> void:
	_meow_cd -= dt
	var chance := (0.015 + 0.08 * agitation) * (1.6 if kind == "impatient" else 1.0)
	if patience / patience_max < 0.3:
		chance *= 2.0
	if _meow_cd <= 0.0 and randf() < chance * dt * 4.0:
		_meow(false)

func _meow(urgent: bool) -> void:
	_meow_cd = 1.7 if urgent else 5.0
	_say("¡MIAU MIAU!" if urgent else "miau")
	meowed.emit(urgent)

func _say(text: String, dur: float = 1.4) -> void:
	_speech = text
	_speech_t = dur

func _update_knock(dt: float) -> void:
	if _knock_phase == "none" or _knock_phase == "done" or knock_target == null:
		return
	_knock_t -= dt
	match _knock_phase:
		"wait":
			if _knock_t <= 0.0:
				if knock_target.can_be_knocked():
					_knock_phase = "look"   # lo mira primero... (humor)
					_knock_t = 1.6
				else:
					_knock_phase = "done"
		"look":
			if _knock_t <= 0.0:
				_knock_phase = "paw"
				_knock_t = 0.5
		"paw":
			_paw = 1.0 - _knock_t / 0.5
			if _knock_t <= 0.0:
				_paw = 0.0
				_knock_phase = "done"
				knock_now.emit(self, knock_target)
				_say("...", 2.0)  # y se queda sentado como si nada

## Entrega lo que hay en la mano. Devuelve los platillos usados.
func receive(hand: Array) -> Array:
	var used: Array = []
	for item in hand:
		var i := order.find(item)
		if i >= 0:
			order.remove_at(i)
			used.append(item)
	if used.size() > 0:
		patience = minf(patience_max, patience + 4.0)
	if order.is_empty():
		_say("♥")
		_leave("served")
	return used

func pet() -> void:
	if kind == "resident":
		_say("prrr ♥", 2.0)
		return
	# Falsa urgencia atendida: solo quería atención.
	_say("prrr ♥")
	_leave("fu_pet")

func dismiss() -> void:
	_leave("resident")

func let_go() -> void:
	_say("miau~")
	_leave("let_go")

func _leave(reason: String) -> void:
	if state == "leaving":
		return
	_leave_reason = reason
	_set_state("leaving")
	left.emit(self, reason)

# ------------------------------------------------------------ hit tests (coords globales)
func hit_body(p: Vector2) -> bool:
	var l := p - global_position
	return Rect2(-58, -175, 116, 175).has_point(l)

func hit_let_go(p: Vector2) -> bool:
	if state != "waiting":
		return false
	var l := p - global_position
	return Rect2(-46, 14, 92, 28).has_point(l)

# ------------------------------------------------------------ dibujo
func _draw() -> void:
	var calm_pose := _purring
	var agit := agitation if state != "settled" else 0.0
	var urgent := state == "urgent"
	var bob := sin(_t * (1.2 + 2.5 * agit)) * (1.5 + 3.0 * agit)
	if urgent:
		bob = sin(_t * 22.0) * 4.0
	var squash := 6.0 if calm_pose else 0.0   # sentado/acomodado = más bajito y redondo

	# Cola
	var tail_speed := 1.0 + 4.0 * agit + (4.0 if kind == "impatient" else 0.0)
	var tail_amp := 0.3 + 0.6 * agit
	var ta := sin(_t * tail_speed) * tail_amp
	var tail := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		tail.append(Vector2(40 + f * 30, -10 - f * 60).rotated(ta * f) + Vector2(0, 0))
	draw_polyline(tail, _base.darkened(0.1), 9.0, true)

	# Cuerpo (media elipse por encima del mostrador)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(Vector2(cos(a) * (50 + squash), sin(a) * (62 - squash)))
	draw_colored_polygon(body, _base)
	draw_circle(Vector2(0, -18), 22, _accent.lerp(_base, 0.4))

	# Cabeza
	var head := Vector2(0, -82 + squash + bob)
	if _knock_phase == "look" and knock_target:
		head.x += signf(knock_target.global_position.x - global_position.x) * 6.0
	var ear_back := 1.0 if (kind == "impatient" and patience / patience_max < 0.35) else 0.0
	for sx in [-1.0, 1.0]:
		var e := PackedVector2Array([
			head + Vector2(sx * 12, -26), head + Vector2(sx * (32 + 6 * ear_back), -48 + 14 * ear_back), head + Vector2(sx * 33, -10)])
		draw_colored_polygon(e, _base)
		draw_colored_polygon(PackedVector2Array([e[0].lerp(e[1], 0.2) + Vector2(sx * 4, 6), e[1].lerp(head, 0.15), e[2].lerp(e[1], 0.3)]), Color(0.98, 0.75, 0.78))
	draw_circle(head, 36, _base)
	draw_circle(head + Vector2(16, -12), 11, _accent)

	# Ojos
	var eye_c := Color(0.15, 0.13, 0.12)
	var look := Vector2.ZERO
	if knock_target and (_knock_phase == "look" or _knock_phase == "paw"):
		look = Vector2(signf(knock_target.global_position.x - global_position.x) * 4, 3)
	for sx in [-1.0, 1.0]:
		var ep: Vector2 = head + Vector2(sx * 13, -4) + look
		if calm_pose or (_blink > 0.0):
			draw_arc(ep, 6, 0.2, PI - 0.2, 8, eye_c, 2.5)  # ojos cerrados, contento
		elif urgent:
			draw_circle(ep, 8, Color.WHITE)
			draw_circle(ep, 5, eye_c)
		else:
			draw_circle(ep, 5.5, eye_c)
			draw_circle(ep + Vector2(-1.5, -2), 1.8, Color.WHITE)
	if _blink < -randf_range(2.5, 6.0) * (2.0 if calm > 0.7 else 1.0):
		_blink = 0.18
	# Nariz y boca
	draw_circle(head + Vector2(0, 7), 3.2, Color(0.95, 0.55, 0.6))
	draw_arc(head + Vector2(-5, 11), 5, 0.1, PI - 0.1, 6, eye_c, 1.6)
	draw_arc(head + Vector2(5, 11), 5, 0.1, PI - 0.1, 6, eye_c, 1.6)
	if urgent:
		draw_circle(head + Vector2(0, 19), 6, Color(0.6, 0.2, 0.25))
	for sy in [6.0, 12.0]:
		draw_line(head + Vector2(18, sy), head + Vector2(44, sy - 4 + bob * 0.2), eye_c.lightened(0.4), 1.2)
		draw_line(head + Vector2(-18, sy), head + Vector2(-44, sy - 4 + bob * 0.2), eye_c.lightened(0.4), 1.2)

	# Pata que derriba
	if _knock_phase == "paw" and knock_target:
		var dir := signf(knock_target.global_position.x - global_position.x)
		var reach := absf(knock_target.global_position.x - global_position.x) - 20.0
		draw_circle(Vector2(dir * (30 + reach * _paw), -8), 11, _base)

	_draw_bubble()
	_draw_speech()
	if state == "waiting":
		var tag := Rect2(-46, 14, 92, 28)
		draw_rect(tag, Color(0.98, 0.95, 0.88, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(-34, 33), "dejar ir", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.35, 0.3, 0.3))

func _draw_bubble() -> void:
	if state == "leaving" or state == "arriving":
		return
	var top := Vector2(0, -190)
	if state == "urgent" or state == "settled":
		var shake := Vector2(sin(_t * 30.0) * 3.0, 0) if state == "urgent" else Vector2.ZERO
		var r := Rect2(top + Vector2(-30, -24) + shake, Vector2(60, 40))
		draw_rect(r, Color(1, 0.97, 0.9))
		var txt := "!!!" if state == "urgent" else "♪"
		draw_string(ThemeDB.fallback_font, r.position + Vector2(14, 29), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.85, 0.25, 0.3) if state == "urgent" else Color(0.4, 0.6, 0.5))
		return
	if order.is_empty():
		return
	var w := 46.0 * order.size() + 16.0
	var r2 := Rect2(top + Vector2(-w / 2, -26), Vector2(w, 50))
	draw_rect(r2, Color(1, 0.98, 0.94))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-8, 24), top + Vector2(8, 24), top + Vector2(0, 36)]), Color(1, 0.98, 0.94))
	for i in order.size():
		DishArt.draw(self, order[i], top + Vector2(-w / 2 + 31 + 46 * i, -1), 0.9)
	# Paciencia: arco discreto alrededor de la burbuja, sin números.
	var ratio := clampf(patience / patience_max, 0.0, 1.0)
	var col := Color(0.55, 0.75, 0.6).lerp(Color(0.95, 0.65, 0.4), 1.0 - ratio)
	draw_arc(top + Vector2(w / 2 + 14, -14), 9, -PI / 2, -PI / 2 + TAU * ratio, 20, col, 4.0)

func _draw_speech() -> void:
	if _speech_t <= 0.0 or _speech == "":
		return
	var a := clampf(_speech_t, 0.0, 1.0)
	var size := 20 if _speech.begins_with("¡") else FONT_SIZE
	draw_string(ThemeDB.fallback_font, Vector2(30, -130), _speech, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.3, 0.25, 0.25, a))
