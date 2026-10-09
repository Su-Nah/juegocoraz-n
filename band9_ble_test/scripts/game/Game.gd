## GATOS EN LA BARRA — orquestador.
##   TITLE → RITUAL (línea base + tutorial con Mochi) → PLAY (fases) → RESULTS
## Flujo de datos:
##   HeartRate → Physio → ArousalDirector + StabilitySystem
##     → valores abstractos (ambient_intensity, cat_activity, event_density, audio_intensity)
##     → Ambiente/Puesto/Agua (grupo "ambiente_reactivo") · Clientela · MusicLayers · shader
## Los gráficos viven en escenas (scenes/…); este script solo coordina.
extends Node2D

const C := preload("res://scripts/core/Config.gd")
const DangoData := preload("res://scripts/core/DangoData.gd")

enum Mode { TITLE, RITUAL, PLAY, RESULTS }

@onready var director: Node = $Director
@onready var stability: Node = $Stability
@onready var music: Node = $Musica
@onready var clientela: Node2D = $Gatos
@onready var manos: Node2D = $Manos
@onready var companero: Node2D = $Barra/Mochi
@onready var bandeja: Node2D = $Cocina/Bandeja
@onready var bote: Node2D = $Cocina/Bote
@onready var agua: Node2D = $Barra/Agua
@onready var campanilla: Node2D = $Puesto/Campanilla
@onready var tablilla: Node2D = $Puesto/Tablilla
@onready var tutorial: Node2D = $Tutorial
@onready var camara: Camera2D = $Camara
@onready var ui: CanvasLayer = $UI
@onready var _mood: ShaderMaterial = $Atmosfera/Filtro.material

var mode := Mode.TITLE
var ingredientes: Array = []
var _t := 0.0
var _ritual_t := 0.0
var _ritual_served := 0
var _beat_acc := 0.0
var _breath_t := 0.0
var _enfasis_t := 0.0
var _finishing := false
var _progress_t := 0.0         # tiempo sin progreso (para la ayuda contextual)
var _mood_vals := {}

func _ready() -> void:
	randomize()
	ingredientes = get_tree().get_nodes_in_group("ingrediente")
	clientela.ingredientes = ingredientes
	manos.bandeja = bandeja
	manos.bote = bote
	manos.ingredientes = ingredientes
	manos.clientela = clientela
	manos.companero = companero
	director.stability = stability
	director.spawn_requested.connect(clientela.spawn)
	director.session_finished.connect(func(): _finishing = true)
	stability.pause_ended.connect(func(): manos.habilitado = mode == Mode.PLAY or mode == Mode.RITUAL)
	clientela.servido.connect(_on_served)
	clientela.se_fue.connect(func(_c): if mode == Mode.PLAY: stability.cat_left())
	clientela.fu_calmada.connect(func(_c): if mode == Mode.PLAY: stability.false_urgency_ignored())
	clientela.fu_reaccion.connect(func(_c): if mode == Mode.PLAY: stability.false_urgency_reacted())
	clientela.tiro.connect(_on_knock)
	clientela.maullido.connect(func(u): Sfx.play_variation("meow_urgent" if u else "meow"))
	companero.left.connect(func(_c, r): if r == "served": _on_mochi_served())
	manos.accion.connect(_on_player_action)
	manos.bola_puesta.connect(func(_id): Sfx.play("pop", -10.0, randf_range(0.95, 1.1)); _progress_t = 0.0)
	manos.salsa_puesta.connect(func(): Sfx.play("pop", -12.0, 0.7); _progress_t = 0.0)
	manos.entregado.connect(func(_c): _progress_t = 0.0)
	manos.descartado.connect(_on_discard)
	manos.recogido.connect(func(_i): Sfx.play("tuk", -10.0); stability.stats["objects_restored"] += 1)
	for ing in ingredientes:
		ing.recuperado.connect(func(_i, por_jugador): if not por_jugador and mode == Mode.PLAY: stability.fall_ignored())
	Physio.recovery_started.connect(func(): if mode == Mode.PLAY: stability.recovery_moment())
	ui.conectar.connect(func(): HeartRate.web.connect_device())   # gesto directo del usuario
	ui.simulador.connect(_use_simulator)
	ui.comenzar.connect(_start_ritual)
	ui.diagnostico.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Main.tscn"))
	ui.continuar.connect(func(): get_tree().paused = false)
	ui.inicio.connect(func():
		get_tree().paused = false
		_show_title())
	ui.reintentar.connect(_start_ritual)
	ui.debug.game = self
	_show_title()

# ======================================================================= FLUJO
func _show_title() -> void:
	mode = Mode.TITLE
	clientela.clear()
	bandeja.clear()
	tutorial.ocultar()
	ui.mostrar_titulo()
	_set_faroles(0.3)

func _use_simulator() -> void:
	HeartRate.sim.jitter = 1
	HeartRate.sim.target_bpm = 72
	HeartRate.set_active_source("sim")
	if HeartRate.sim.get_connection_status() != "connected":
		HeartRate.sim.connect_device()

## Ritual de ~30 s: preparar el puesto antes de abrir. Mochi pide su dango
## (tutorial por demostración) mientras se mide la línea base. Sin clientes,
## sin prisa, sin puntos.
func _start_ritual() -> void:
	mode = Mode.RITUAL
	ui.ocultar_todo()
	clientela.clear()
	bandeja.clear()
	for ing in ingredientes:
		ing.reset()
	stability.reset()
	manos.habilitado = true
	_ritual_t = 0.0
	_ritual_served = 0
	_set_faroles(0.0)
	Physio.start_baseline()
	music.start()
	companero.say("Antes de abrir...", 2.5)
	get_tree().create_timer(2.0).timeout.connect(func():
		if mode == Mode.RITUAL:
			companero.pedir(DangoData.traditional(true)))

func _on_mochi_served() -> void:
	Sfx.play("coin", -14.0)
	if mode == Mode.RITUAL:
		_ritual_served += 1
		tutorial.ocultar()
		# Otro dango tranquilo, sin guía (solo si se atasca).
		get_tree().create_timer(3.0).timeout.connect(func():
			if mode == Mode.RITUAL and not companero.is_active():
				companero.pedir(DangoData.random_order(1)))

func _start_play() -> void:
	mode = Mode.PLAY
	tutorial.ocultar()
	if companero.is_active():
		companero.setup_companero()
		companero.pedido.visible = false
	companero.say("Abrimos.", 2.0)
	Sfx.play("bell", -12.0)
	_set_faroles(1.0)
	_finishing = false
	_progress_t = 0.0
	director.start()

func _show_results() -> void:
	mode = Mode.RESULTS
	tutorial.ocultar()
	ui.mostrar_resultados(stability.stats, stability.average_stability(), Physio.has_baseline, Physio.baseline_hr)

# ======================================================================= EVENTOS
func _on_served(_cat: Node2D) -> void:
	if mode != Mode.PLAY:
		return
	stability.stats["served"] += 1
	stability.stats["dangos"] += 1
	Sfx.play("coin", -12.0)

func _on_discard() -> void:
	Sfx.play("tuk", -14.0, 0.8)    # sonido suave, nunca de "error"
	if mode == Mode.PLAY:
		stability.discard()

func _on_knock(cat: Node2D, ing: Node2D) -> void:
	ing.knock(signf(ing.global_position.x - cat.global_position.x))
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("crash", -10.0, randf_range(0.95, 1.05)))

func _on_player_action() -> void:
	if mode == Mode.PLAY:
		stability.register_action()

## Regulación voluntaria (campanilla): no pausa el mundo.
func _on_regulacion() -> void:
	if not (mode == Mode.PLAY or mode == Mode.RITUAL):
		return
	if stability.start_pause():
		manos.habilitado = false
		campanilla.sonar()
		Sfx.play("chime", -8.0)
		_enfasis_t = C.PAUSE_DURATION + 2.0
		companero.acompanar_regulacion(C.PAUSE_DURATION + 1.0)

# ======================================================================= INPUT
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and (mode == Mode.PLAY or mode == Mode.RITUAL):
			_toggle_pause()
		return
	if mode == Mode.TITLE or mode == Mode.RESULTS:
		return
	var p := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_at(p)
		else:
			manos.release(p)
	elif event is InputEventMouseMotion:
		manos.move(p)

## Un toque en el mundo (también lo usa la prueba automática).
func press_at(p: Vector2) -> void:
	if tablilla.hit(p):
		_toggle_pause()
		return
	if campanilla.hit(p):
		_on_regulacion()
		return
	manos.press(p)

func tap_at(p: Vector2) -> void:
	press_at(p)
	manos.release(p)

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		ui.mostrar_pausa()
	else:
		ui.ocultar_pausa()

# ======================================================================= PROCESO
func _process(dt: float) -> void:
	_t += dt
	match mode:
		Mode.TITLE:
			ui.actualizar_titulo()
		Mode.RITUAL:
			_update_ritual(dt)
		Mode.PLAY:
			_update_play(dt)
	_update_world(dt)
	_update_heartbeat(dt)

func _update_ritual(dt: float) -> void:
	if HeartRate.is_receiving():
		_ritual_t += dt
	_set_faroles(clampf(_ritual_t / C.BASELINE_SECONDS, 0.0, 1.0))
	stability.tick(dt, 0, 0)
	if companero.is_active():
		_progress_t += dt
		if _ritual_served == 0 or _progress_t > C.TUTORIAL_HINT_IDLE:
			tutorial.guiar(companero.order, companero, manos)
		else:
			tutorial.ocultar()
	var enough: bool = _ritual_t >= C.BASELINE_SECONDS and (_ritual_served > 0 or _ritual_t >= C.RITUAL_MAX_SECONDS)
	if enough and not manos.is_dragging() and Physio.finish_baseline():
		_start_play()

func _update_play(dt: float) -> void:
	var ctx := {
		"cats": clientela.active_count(),
		"free_seat": not clientela.free_seats().is_empty(),
		"knockable": not clientela.knock_option().is_empty(),
		"fu_present": clientela.any_urgent(),
	}
	director.tick(dt, ctx)
	stability.tick(dt, active_stimuli(), director.pressure_level)
	ui.set_sin_senal(HeartRate.active_source == "web" and not Physio.signal_ok)
	_update_contextual_help(dt)
	if _finishing and clientela.cats().is_empty():
		_show_results()

## Al principio, si alguien se queda quieto sin saber qué hacer, la huella ayuda.
func _update_contextual_help(dt: float) -> void:
	var w: Array = clientela.waiting()
	if director.phase_index > 0 or w.is_empty():
		tutorial.ocultar()
		return
	_progress_t += dt
	if _progress_t > C.TUTORIAL_HINT_IDLE:
		tutorial.guiar(w[0].order, w[0], manos)
	else:
		tutorial.ocultar()

func active_stimuli() -> int:
	var n: int = clientela.active_count()
	for ing in ingredientes:
		if ing.is_on_floor():
			n += 1
	return n

func _set_faroles(v: float) -> void:
	for f in get_tree().get_nodes_in_group("farol"):
		f.encendido = v

## Lo que el jugador SIENTE: ritmo, espacio, movimiento, sonido. Sin números.
func _update_world(dt: float) -> void:
	var playing := mode == Mode.PLAY
	var amb: float = director.ambient_intensity if playing else 0.0
	var relief: float = director.relief if playing else 0.0
	var stab: float = stability.value if (playing or mode == Mode.RITUAL) else 0.8
	if stability.paused:
		relief = maxf(relief, 0.7)
	var tempo := lerpf(0.8, 1.4, amb) * (1.0 - 0.3 * relief)
	_breath_t += dt
	_enfasis_t -= dt
	var ambiente := {
		"intensidad": amb,
		"tempo": tempo,
		"respiracion": sin(TAU * _breath_t / C.BREATH_PERIOD),
		"enfasis": 1.0 if _enfasis_t > 0.0 else 0.0,
		"alivio": relief,
	}
	get_tree().call_group("ambiente_reactivo", "aplicar_ambiente", ambiente)
	var activity: float = director.cat_activity if playing else 0.1
	var imp: float = director.impatience_scale() if playing else 1.0
	var purring: int = clientela.set_world(activity, tempo, stab, imp, bandeja.is_complete(), bandeja.global_position, bandeja.data())
	companero.activity = activity * 0.5
	companero.tempo = tempo
	companero.calm = stab
	companero.tray_ready = bandeja.is_complete()
	companero.tray_pos = bandeja.global_position
	companero.tray_matches = companero.wants(bandeja.data())
	if companero.is_purring():
		purring += 1
	# Música: el inicio es solo agua + armonía (consonante).
	var level: float = director.audio_intensity * 3.0 if playing else 0.0
	if stability.paused:
		level *= 0.5
	var recovering: bool = playing and (Physio.is_recovering or relief > 0.4)
	music.update(dt, level, recovering, stability.calm_time >= C.CALM_SUSTAIN or mode != Mode.PLAY, clampf(purring / 2.0, 0.0, 1.0))
	_update_mood(dt, amb, relief)
	camara.offset = Vector2(sin(_t * 1.7), cos(_t * 1.3)) * 3.0 * amb * (1.0 - relief)

## Color ambiental: varios parámetros a la vez, siempre graduales.
## Calma: pastel suave y luminoso · activación: más contraste y saturación,
## luz algo más dorada · recuperación: se abre y se suaviza. Nunca azul=calma/rojo=ansiedad.
func _update_mood(dt: float, amb: float, relief: float) -> void:
	var target := {
		"saturation": lerpf(0.78, 1.25, amb) - 0.08 * relief,
		"contrast": lerpf(0.95, 1.14, amb) - 0.05 * relief,
		"brightness": lerpf(0.04, -0.03, amb) + 0.03 * relief,
		"hue_shift": lerpf(-0.04, 0.10, amb) * (1.0 - relief),
		"tint_amount": lerpf(0.12, 0.0, amb) + 0.06 * relief,
		"vignette": lerpf(0.08, 0.32, amb) - 0.1 * relief,
	}
	var k := 1.0 - exp(-dt * C.MOOD_LERP * 3.0)
	for key in target:
		_mood_vals[key] = lerpf(_mood_vals.get(key, target[key]), target[key], k)
		_mood.set_shader_parameter(key, _mood_vals[key])

## Una gota por latido en la fuente: el cuerpo habla, sin alarma. Nunca un flash.
func _update_heartbeat(dt: float) -> void:
	if mode == Mode.TITLE or mode == Mode.RESULTS or not Physio.signal_ok or Physio.current_hr <= 0.0:
		return
	var hr := lerpf(Physio.current_hr, Physio.filtered_hr, 0.5)
	_beat_acc += dt
	if _beat_acc >= 60.0 / hr:
		_beat_acc = 0.0
		Sfx.play("plim", -21.0 - 4.0 * Physio.activation, [1.0, 1.122, 1.26, 1.498].pick_random())
		agua.emit_drop()
