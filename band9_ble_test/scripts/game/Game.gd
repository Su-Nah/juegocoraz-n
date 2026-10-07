## Game: orquesta el vertical slice.
##   TITLE → BASELINE (actividad tranquila) → PLAY (fases) → RESULTS
## Arquitectura:
##   HeartRate (autoload, proveedores) → Physio (autoload, estado abstracto)
##   → ArousalDirector + StabilitySystem → gatos · cocina · puesto · música · shader
## Ningún nodo del juego llama a JavaScriptBridge.
extends Node2D

const C := preload("res://scripts/core/Config.gd")
const Director := preload("res://scripts/game/ArousalDirector.gd")
const Stability := preload("res://scripts/game/StabilitySystem.gd")
const StallScript := preload("res://scripts/game/Stall.gd")
const KitchenScript := preload("res://scripts/game/Kitchen.gd")
const CatScript := preload("res://scripts/game/Cat.gd")
const ObjScript := preload("res://scripts/game/CounterObject.gd")
const Music := preload("res://scripts/audio/MusicLayers.gd")
const Debug := preload("res://scripts/ui/DebugPanel.gd")
const MOOD_SHADER := preload("res://shaders/mood.gdshader")

enum Mode { TITLE, BASELINE, PLAY, RESULTS }

var mode := Mode.TITLE
var director: Director
var stability: Stability
var music: Music
var stall: StallScript
var kitchen: KitchenScript
var seats: Array = [null, null, null, null]
var objects: Array = []
var resident: Node2D = null

var _cats_layer: Node2D
var _camera: Camera2D
var _mood: ShaderMaterial
var _mood_vals := {"saturation": 0.9, "contrast": 1.0, "brightness": 0.02, "hue_shift": 0.0, "tint_amount": 0.12, "vignette": 0.12}
var _ui: CanvasLayer
var _title: Control
var _title_status: Label
var _start_btn: Button
var _hint: Label
var _pause_btn: Button
var _signal_box: HBoxContainer
var _results: PanelContainer
var _debug: Debug

var _t := 0.0
var _baseline_t := 0.0
var _beat_acc := 0.0
var _hint_breath_cd := 10.0
var _hint_once := {}
var _breath_emphasis_t := 0.0
var _finishing := false
var _dishes_requested := 0

func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	director = Director.new()
	stability = Stability.new()
	director.stability = stability
	add_child(director)
	add_child(stability)
	music = Music.new()
	add_child(music)
	director.spawn_requested.connect(_on_spawn_requested)
	director.session_finished.connect(func(): _finishing = true)
	stability.pause_ended.connect(_on_pause_ended)
	_debug.game = self
	_show_title()

# ======================================================================= MUNDO
func _build_world() -> void:
	stall = StallScript.new()
	add_child(stall)
	_cats_layer = Node2D.new()
	_cats_layer.z_index = 1   # la etiqueta "dejar ir" se dibuja sobre el frente del mostrador
	add_child(_cats_layer)
	var front := StallScript.CounterFront.new()
	add_child(front)
	kitchen = KitchenScript.new()
	add_child(kitchen)
	var defs := [["taza", 370.0, "te"], ["plato", 610.0, "onigiri"], ["limon", 850.0, ""]]
	for d in defs:
		var o := ObjScript.new()
		o.setup(d[0], Vector2(d[1], C.COUNTER_Y - 10), d[2])
		o.fallen.connect(func(obj): kitchen.set_blocked(obj.blocks, true))
		o.restored.connect(func(obj): kitchen.set_blocked(obj.blocks, false))
		add_child(o)
		objects.append(o)
	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	var mood_layer := CanvasLayer.new()
	mood_layer.layer = 1
	add_child(mood_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood = ShaderMaterial.new()
	_mood.shader = MOOD_SHADER
	rect.material = _mood
	mood_layer.add_child(rect)

# ======================================================================= UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(340, 470)
	_hint.size = Vector2(600, 40)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_hint.add_theme_color_override("font_outline_color", Color(0.25, 0.18, 0.15, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hint)

	_pause_btn = Button.new()
	_pause_btn.text = "Pausa"
	_pause_btn.tooltip_text = "Durante unos segundos no produces. El mundo sigue."
	_pause_btn.position = Vector2(30, 620)
	_pause_btn.size = Vector2(150, 70)
	_pause_btn.add_theme_font_size_override("font_size", 20)
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(_on_pause_pressed)
	_ui.add_child(_pause_btn)

	_signal_box = HBoxContainer.new()
	_signal_box.position = Vector2(930, 12)
	var sl := Label.new()
	sl.text = "Pulsera sin señal"
	sl.add_theme_color_override("font_color", Color(0.3, 0.25, 0.25))
	_signal_box.add_child(sl)
	var rb := Button.new()
	rb.text = "Reconectar"
	rb.focus_mode = Control.FOCUS_NONE
	rb.pressed.connect(func(): HeartRate.web.connect_device())   # gesto directo del usuario
	_signal_box.add_child(rb)
	_signal_box.visible = false
	_ui.add_child(_signal_box)

	_build_title()

	_results = PanelContainer.new()
	_results.visible = false
	_ui.add_child(_results)

	_debug = Debug.new()
	_ui.add_child(_debug)

func _panel_style(alpha: float = 0.92) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.9, alpha)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	return sb

func _build_title() -> void:
	_title = PanelContainer.new()
	_title.add_theme_stylebox_override("panel", _panel_style())
	_title.position = Vector2(390, 150)
	_title.custom_minimum_size = Vector2(500, 0)
	_ui.add_child(_title)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_title.add_child(v)
	v.add_child(_label("Neko Yatai", 40, Color(0.35, 0.25, 0.3)))
	v.add_child(_label("un pequeño puesto, gatos, y lo que no puedes controlar", 15, Color(0.45, 0.4, 0.4)))
	var connect_btn := _btn("Conectar Huawei Band 9", func(): HeartRate.web.connect_device())
	v.add_child(connect_btn)
	_title_status = _label("", 14, Color(0.35, 0.35, 0.4))
	_title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title_status)
	_start_btn = _btn("Comenzar", _start_baseline)
	_start_btn.disabled = true
	v.add_child(_start_btn)
	v.add_child(HSeparator.new())
	var dev := HBoxContainer.new()
	dev.add_child(_btn("Simulador (desarrollo)", _use_simulator, 13))
	dev.add_child(_btn("Diagnóstico BLE", func(): get_tree().change_scene_to_file("res://Main.tscn"), 13))
	v.add_child(dev)
	v.add_child(_label("F3: panel técnico · F1: secuencia de prueba del simulador", 12, Color(0.55, 0.5, 0.5)))

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _btn(text: String, cb: Callable, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size.y = 40 if size >= 18 else 30
	b.pressed.connect(cb)
	return b

func show_hint(text: String, dur: float = 4.0) -> void:
	_hint.text = text
	var tw := create_tween()
	tw.tween_property(_hint, "modulate:a", 0.95, 1.0)
	tw.tween_interval(dur)
	tw.tween_property(_hint, "modulate:a", 0.0, 1.5)

# ======================================================================= FLUJO
func _show_title() -> void:
	mode = Mode.TITLE
	_title.visible = true
	_results.visible = false
	_pause_btn.visible = false
	kitchen.visible = false
	stall.lantern_glow = 0.3

func _use_simulator() -> void:
	HeartRate.sim.jitter = 1
	HeartRate.sim.target_bpm = 72
	HeartRate.set_active_source("sim")
	if HeartRate.sim.get_connection_status() != "connected":
		HeartRate.sim.connect_device()

func _start_baseline() -> void:
	mode = Mode.BASELINE
	_title.visible = false
	_results.visible = false
	_clear_cats()
	for o in objects:
		o.position = o.home
		o.state = "counter"
		o.cooldown = 0.0
		o.reserved = false
		o._rot = 0.0
	kitchen.reset()
	kitchen.visible = true
	kitchen.enabled = false
	stability.reset()
	_baseline_t = 0.0
	_hint_once = {}
	_dishes_requested = 0
	stall.lantern_glow = 0.0
	resident = CatScript.new()
	resident.setup("resident", [], 999.0, 1)
	_cats_layer.add_child(resident)
	Physio.start_baseline()
	music.start()
	show_hint("Antes de abrir el puesto…", 3.0)
	get_tree().create_timer(5.5).timeout.connect(func():
		if mode == Mode.BASELINE:
			show_hint("Vamos a empezar despacio.", 5.0))

func _start_play() -> void:
	mode = Mode.PLAY
	if resident:
		resident.dismiss()
		resident = null
	kitchen.enabled = true
	_pause_btn.visible = true
	_finishing = false
	Sfx.play("bell", -10.0)
	show_hint("El puesto abre.", 2.5)
	director.start()

func _show_results() -> void:
	mode = Mode.RESULTS
	_pause_btn.visible = false
	kitchen.enabled = false
	for ch in _results.get_children():
		ch.queue_free()
	_results.add_theme_stylebox_override("panel", _panel_style(0.95))
	_results.position = Vector2(300, 60)
	_results.custom_minimum_size = Vector2(680, 0)
	_results.visible = true
	var s: Dictionary = stability.stats
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_results.add_child(v)
	v.add_child(_label("Fin del día", 32, Color(0.35, 0.25, 0.3)))

	var met: int = s["served"] + s["let_go"] + s["left_on_own"]
	var served_ratio := float(s["served"]) / maxf(1.0, met)
	var money_ratio := float(s["money"]) / maxf(1.0, _dishes_requested * C.PRICE)
	var stab := stability.average_stability()
	var stab_score := stab * 4.0 + (0.5 if s["recovery_times"].size() > 0 else 0.0) + (0.5 if s["pauses"] + s["rests"] >= 3 else 0.0)
	v.add_child(_stars_row("DINERO", money_ratio * 5.0))
	v.add_child(_stars_row("CLIENTES ATENDIDOS", served_ratio * 5.0))
	v.add_child(_stars_row("ESTABILIDAD", stab_score))
	v.add_child(HSeparator.new())

	var rt: Array = s["recovery_times"]
	var rt_text := "no hubo picos de activación que recuperar"
	if rt.size() > 0:
		var best: float = rt.min()
		var avg := 0.0
		for x in rt:
			avg += x
		rt_text = "%.0f s (mejor %.0f s, %d episodio%s)" % [avg / rt.size(), best, rt.size(), "" if rt.size() == 1 else "s"]
	var lines := [
		"Ventas: %d monedas  ·  Clientes atendidos: %d" % [s["money"], s["served"]],
		"Clientes que dejaste ir: %d  ·  Se fueron solos: %d" % [s["let_go"], s["left_on_own"]],
		"Veces que te detuviste: %d  (pausas %d · descansos %d)" % [s["pauses"] + s["rests"], s["pauses"], s["rests"]],
		"Falsas urgencias que dejaste pasar: %d de %d" % [s["fu_ignored"], s["fu_ignored"] + s["fu_reacted"]],
		"Tiempo bajo presión sin escalada prolongada: %.0f s de %.0f s" % [s["time_pressure_ok"], s["time_pressure"]],
		"Tiempo de recuperación: %s" % rt_text,
	]
	if Physio.has_baseline:
		lines.append("Tu pulso de referencia: %.0f BPM  ·  pico: %.0f BPM" % [Physio.baseline_hr, s["peak_hr"]])
	for line in lines:
		v.add_child(_label(line, 16, Color(0.3, 0.28, 0.3)))
	v.add_child(HSeparator.new())
	var closing := "No necesitabas salvarlo todo."
	if stab_score < money_ratio * 5.0 - 1.0:
		closing = "No controlas lo que llega al puesto. Tu respuesta sí se puede practicar."
	v.add_child(_label(closing, 20, Color(0.3, 0.45, 0.45)))
	if s["let_go"] > 0:
		v.add_child(_label("Dejar ir también fue una decisión.", 15, Color(0.45, 0.45, 0.5)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_btn("Jugar otra vez", _start_baseline))
	row.add_child(_btn("Inicio", _show_title))
	v.add_child(row)

func _stars_row(title: String, score: float) -> Label:
	var n := clampi(roundi(score), 1, 5)
	return _label("%s  %s%s" % [title, "★".repeat(n), "☆".repeat(5 - n)], 20, Color(0.4, 0.3, 0.3))

# ======================================================================= GATOS
func _free_seats() -> Array:
	var r := []
	for i in 4:
		if seats[i] == null:
			r.append(i)
	return r

func _knock_option() -> Array:
	# [objeto, asiento] para un gato travieso: objeto disponible con asiento libre al lado.
	var free := _free_seats()
	objects.shuffle()
	for o in objects:
		if not o.can_be_knocked() or o.reserved:
			continue
		for s in free:
			if absf(C.SEATS_X[s] - o.home.x) < 130.0:
				return [o, s]
	return []

func _on_spawn_requested(kind: String, order: Array, patience: float) -> void:
	var seat := -1
	var target: Node2D = null
	if kind == "knock":
		var opt := _knock_option()
		if opt.is_empty():
			kind = "impatient" if director.tier >= 2 else "normal"
			if order.is_empty():
				order = ["te"]
		else:
			target = opt[0]
			seat = opt[1]
	if seat < 0:
		var free := _free_seats()
		if free.is_empty():
			return
		seat = free[randi() % free.size()]
	var cat := CatScript.new()
	cat.setup(kind, order, patience, seat)
	if target:
		cat.knock_target = target
		target.reserved = true
	cat.left.connect(_on_cat_left)
	cat.knock_now.connect(_on_knock)
	cat.meowed.connect(func(urgent): Sfx.play("meow_urgent" if urgent else "meow", -6.0 if urgent else -12.0, randf_range(0.92, 1.12)))
	seats[seat] = cat
	_cats_layer.add_child(cat)
	_dishes_requested += order.size()

func _on_knock(cat: Node2D, obj: Node2D) -> void:
	obj.knock(signf(obj.global_position.x - cat.global_position.x))
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("crash", -8.0, randf_range(0.95, 1.05)))

func _on_cat_left(cat: Node2D, reason: String) -> void:
	if cat.seat >= 0 and seats[cat.seat] == cat:
		seats[cat.seat] = null
	if cat.knock_target and cat.knock_target.state == "counter":
		cat.knock_target.reserved = false
	if mode != Mode.PLAY:
		return
	var s: Dictionary = stability.stats
	match reason:
		"served":
			s["served"] += 1
			Sfx.play("coin", -10.0)
		"let_go":
			stability.let_go()
			_float_text(cat.global_position + Vector2(-40, -230), "se fue · está bien")
		"patience":
			s["left_on_own"] += 1
			_float_text(cat.global_position + Vector2(-50, -230), "El cliente se fue.")
		"fu_ignored":
			stability.false_urgency_ignored()
		"fu_pet":
			stability.false_urgency_reacted()

func _float_text(p: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = p
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.35, 0.33, 0.38))
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", p.y - 30, 2.5)
	tw.tween_property(l, "modulate:a", 0.0, 2.5)
	tw.chain().tween_callback(l.queue_free)

func _clear_cats() -> void:
	for c in _cats_layer.get_children():
		c.queue_free()
	seats = [null, null, null, null]

func active_cats() -> int:
	var n := 0
	for c in seats:
		if c != null and c.is_active():
			n += 1
	return n

func active_stimuli() -> int:
	var n := active_cats()
	for o in objects:
		if o.is_on_floor():
			n += 1
	return n

# ======================================================================= INPUT
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_pause_pressed()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	click_at(get_global_mouse_position())

## Un clic en el mundo (también lo usa la prueba automática).
func click_at(p: Vector2) -> void:
	if mode == Mode.BASELINE:
		if resident and resident.hit_body(p):
			resident.pet()
			Sfx.play("meow", -16.0, 0.9)
		return
	if mode != Mode.PLAY or stability.paused:
		return
	stability.register_action()
	for o in objects:
		if o.hit(p):
			o.restore()
			s_inc("objects_restored")
			Sfx.play("tuk", -8.0)
			return
	for c in seats:
		if c == null or not c.is_active():
			continue
		if c.hit_let_go(p):
			c.let_go()
			return
		if c.hit_body(p):
			if c.is_urgent():
				c.pet()
			elif not kitchen.hand.is_empty():
				var used: Array = c.receive(kitchen.hand)
				for u in used:
					kitchen.hand.erase(u)
				if used.size() > 0:
					stability.stats["money"] += C.PRICE * used.size()
					Sfx.play("pop", -8.0)
			return
	var st := kitchen.station_at(p)
	if st >= 0:
		var r := kitchen.click_station(st)
		if r == "pick" or r == "start":
			Sfx.play("pop", -12.0, 1.2)
		elif r == "blocked" or r == "full":
			Sfx.play("tuk", -12.0, 0.8)
		return
	if kitchen.hit_hand(p):
		kitchen.clear_hand()
		Sfx.play("tuk", -12.0)

func s_inc(key: String) -> void:
	stability.stats[key] += 1

func _on_pause_pressed() -> void:
	if mode != Mode.PLAY:
		return
	if stability.start_pause():
		kitchen.enabled = false
		_pause_btn.disabled = true
		_breath_emphasis_t = C.PAUSE_DURATION + 2.0
		show_hint("Respira despacio.", C.PAUSE_DURATION - 1.0)

func _on_pause_ended() -> void:
	if mode == Mode.PLAY:
		kitchen.enabled = true
	_pause_btn.disabled = false

# ======================================================================= PROCESO
func _process(dt: float) -> void:
	_t += dt
	match mode:
		Mode.TITLE:
			_update_title()
		Mode.BASELINE:
			_update_baseline(dt)
		Mode.PLAY:
			_update_play(dt)
	_update_world(dt)
	_update_heartbeat(dt)

func _update_title() -> void:
	var st := HeartRate.web.get_connection_status()
	var txt := ""
	if not HeartRate.web.has_js_bridge():
		txt = "Bluetooth solo funciona en la versión Web (Chrome/Edge). En el editor usa el simulador."
	else:
		txt = {"disconnected": "Pulsera desconectada.", "scanning": "Buscando dispositivo…", "connecting": "Conectando…", "connected": "Pulsera conectada.", "error": "Error de conexión (ver Diagnóstico BLE)."}.get(st, st)
	if HeartRate.is_receiving():
		txt += "  Recibiendo señal (%s)." % HeartRate.source_label()
	elif st == "connected":
		txt += "  Esperando la primera lectura…"
	_title_status.text = txt
	_start_btn.disabled = not HeartRate.is_receiving()

func _update_baseline(dt: float) -> void:
	if HeartRate.is_receiving():
		_baseline_t += dt
	stall.lantern_glow = clampf(_baseline_t / C.BASELINE_SECONDS, 0.0, 1.0)
	if not HeartRate.is_receiving() and _hint.modulate.a < 0.05:
		show_hint("Esperando la señal de la pulsera…", 2.0)
	if _baseline_t >= C.BASELINE_SECONDS and Physio.finish_baseline():
		_start_play()

func _update_play(dt: float) -> void:
	var ctx := {
		"cats": active_cats(),
		"free_seat": not _free_seats().is_empty(),
		"knockable": not _knock_option().is_empty(),
		"fu_present": _any_urgent(),
	}
	director.tick(dt, ctx)
	stability.tick(dt, active_stimuli(), director.pressure_level)
	_signal_box.visible = HeartRate.active_source == "web" and not Physio.signal_ok
	_update_hints()
	if _finishing and active_cats() == 0:
		_show_results()

func _any_urgent() -> bool:
	for c in seats:
		if c != null and c.is_urgent():
			return true
	return false

func _update_hints() -> void:
	_hint_breath_cd -= get_process_delta_time()
	if active_cats() >= 3 and not _hint_once.has("let_go"):
		_hint_once["let_go"] = true
		show_hint("No tienes que atender a todos.", 3.5)
		return
	var pressured: bool = Physio.activation_level >= 2 or (stability.value < 0.4 and director.pressure_level >= 2)
	if pressured and _hint_breath_cd <= 0.0 and not stability.paused:
		_hint_breath_cd = C.HINT_BREATH_COOLDOWN
		_breath_emphasis_t = 10.0
		show_hint("Respira despacio." if randf() < 0.6 else "Haz una pausa.", 3.0)

## Lo que el jugador SIENTE: ritmo, espacio, movimiento, sonido. Sin números en pantalla.
func _update_world(dt: float) -> void:
	var playing := mode == Mode.PLAY
	var inten: float = director.world_intensity if playing else 0.0
	var relief: float = director.relief if playing else 0.0
	var stab: float = stability.value if playing else 0.8
	if stability.paused:
		relief = maxf(relief, 0.7)
	var tempo := lerpf(0.85, 1.35, inten) * (1.0 - 0.3 * relief)
	_breath_emphasis_t -= dt
	stall.intensity = inten
	stall.tempo = tempo
	stall.calm = stab
	stall.breath_emphasis = move_toward(stall.breath_emphasis, 1.0 if _breath_emphasis_t > 0.0 else 0.0, dt * 0.5)
	kitchen.tempo = tempo
	kitchen.intensity = inten
	kitchen.breath = stall.breath
	var imp := director.impatience_scale() if playing else 1.0
	var purring := 0
	for c in _cats_layer.get_children():
		c.agitation = clampf(inten * 0.8 + (1.0 - stab) * 0.4 - relief * 0.3, 0.0, 1.0)
		c.tempo = tempo
		c.calm = stab
		c.impatience_scale = imp
		if c.is_purring():
			purring += 1
	# Música
	var level := inten * 3.0
	if stability.paused:
		level *= 0.5
	var recovering: bool = Physio.is_recovering or relief > 0.4
	music.update(dt, level, recovering, stability.calm_time >= C.CALM_SUSTAIN or mode == Mode.BASELINE, clampf(purring / 2.0, 0.0, 1.0))
	# Shader: varios parámetros a la vez, siempre graduales.
	var target := {
		"saturation": lerpf(0.85, 1.12, inten),
		"contrast": lerpf(0.97, 1.1, inten) - 0.04 * relief,
		"brightness": 0.03 * (1.0 - inten) + 0.02 * relief,
		"hue_shift": 0.12 * inten * (1.0 - relief),
		"tint_amount": lerpf(0.14, 0.0, inten) + 0.08 * relief,
		"vignette": 0.12 + 0.18 * inten - 0.08 * relief,
	}
	var k := 1.0 - exp(-dt * C.MOOD_LERP * 3.0)
	for key in target:
		_mood_vals[key] = lerpf(_mood_vals[key], target[key], k)
		_mood.set_shader_parameter(key, _mood_vals[key])
	# Cámara: deriva suavísima con la intensidad; quieta en recuperación.
	var amp := 2.5 * inten * (1.0 - relief)
	_camera.offset = Vector2(sin(_t * 1.7), cos(_t * 1.3)) * amp

## Una gota por latido ("plim"): el cuerpo habla, sin alarma. Nunca un flash.
func _update_heartbeat(dt: float) -> void:
	if mode == Mode.TITLE or mode == Mode.RESULTS or not Physio.signal_ok or Physio.current_hr <= 0.0:
		return
	var hr := lerpf(Physio.current_hr, Physio.filtered_hr, 0.5)
	_beat_acc += dt
	if _beat_acc >= 60.0 / hr:
		_beat_acc = 0.0
		var pitches := [1.0, 1.122, 1.26, 1.498]
		Sfx.play("plim", -20.0 - 4.0 * Physio.activation, pitches[randi() % pitches.size()])
		stall.emit_drop()
