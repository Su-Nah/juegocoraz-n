## ArousalDirector: decide la presión del mundo a partir de
##   fase del día + estado fisiológico abstracto (Physio) + estabilidad del jugador.
## Reglas clave:
##  - Sube de escalón solo si el jugador demuestra estabilidad bajo la presión actual.
##  - Con activación fisiológica muy alta NO sube más; si se sostiene, PROTEGE (baja).
##  - La recuperación (tendencia) alivia el mundo: menos llegadas, más paciencia, menos eventos.
## No conoce Bluetooth ni JavaScript.
extends Node

signal phase_changed(index: int, phase: Dictionary)
signal pressure_changed(level: int)
signal challenge_raised(tier: int)
signal protection_changed(active: bool)
signal spawn_requested(kind: String, order: Dictionary, patience: float)
signal session_finished()

const C := preload("res://scripts/core/Config.gd")
const DangoData := preload("res://scripts/core/DangoData.gd")

var phase_index := -1
var phase_time := 0.0
var pressure_level := 0
var tier := 0
var protecting := false
var relief := 0.0            # 0..1 alivio por recuperación/pausa (suavizado)
var world_intensity := 0.0   # 0..1 lo que siente el mundo (visual/audio), suavizado
var effective_pressure := 0.0

## SALIDAS ABSTRACTAS del director (cada sistema decide cómo representarlas):
var ambient_intensity := 0.0 # agua, viento, pétalos, vapor, telas, color
var cat_activity := 0.0      # inquietud de los gatos (con límites)
var event_density := 0.0     # densidad de llegadas/eventos
var audio_intensity := 0.0   # capas musicales
var running := false
var _mastery := 0.0
var _protect_time := 0.0
var _spawn_acc := 0.0
var _forced_done := {}

var stability: Node          # StabilitySystem

func start() -> void:
	running = true
	phase_index = -1
	pressure_level = 0
	tier = 0
	_next_phase()

func phase() -> Dictionary:
	return C.PHASES[clampi(phase_index, 0, C.PHASES.size() - 1)]

func _next_phase() -> void:
	phase_index += 1
	phase_time = 0.0
	_mastery = 0.0
	_forced_done = {}
	if phase_index >= C.PHASES.size():
		running = false
		session_finished.emit()
		return
	var ph := phase()
	_set_pressure(clampi(pressure_level, ph["pmin"], ph["pmax"]))
	tier = maxi(tier, ph["min_tier"])
	_spawn_acc = C.SPAWN_INTERVAL[pressure_level] * 0.6
	phase_changed.emit(phase_index, ph)

func _set_pressure(p: int) -> void:
	if p != pressure_level:
		pressure_level = p
		pressure_changed.emit(p)

## ctx: {cats:int, free_seat:bool, knockable:bool, fu_present:bool}
func tick(dt: float, ctx: Dictionary) -> void:
	if not running:
		return
	phase_time += dt
	var ph := phase()
	if phase_time >= ph["duration"] * C.DURATION_SCALE:
		_next_phase()
		if not running:
			return
		ph = phase()

	_update_protection(dt)
	_update_mastery(dt, ph)

	# Alivio: recuperación fisiológica, pausa voluntaria y estabilidad alta.
	var target_relief := 0.0
	if Physio.is_recovering:
		target_relief = maxf(target_relief, 0.4 + 0.6 * Physio.recovery_strength)
	if stability.paused:
		target_relief = maxf(target_relief, 0.6)
	if protecting:
		target_relief = maxf(target_relief, 0.5)
	if ph["id"] == "recuperacion":
		target_relief = maxf(target_relief, 0.35)
	relief = move_toward(relief, target_relief, dt * (0.5 if target_relief > relief else 0.15))

	# BPM moderado → algo más de presión percibida; nunca en protección.
	var bonus := 0.0 if protecting or Physio.activation_level >= C.PROTECT_LEVEL else Physio.activation * C.PHYSIO_PRESSURE_BONUS
	effective_pressure = clampf(pressure_level + bonus - relief, 0.0, 3.0)

	var target_int := clampf(0.55 * effective_pressure / 3.0 + 0.45 * Physio.activation, 0.0, 1.0)
	target_int *= 1.0 - 0.6 * relief
	world_intensity = move_toward(world_intensity, target_int, dt * 0.12)
	ambient_intensity = world_intensity
	audio_intensity = world_intensity
	event_density = effective_pressure / 3.0
	cat_activity = clampf(world_intensity * 0.75 + (1.0 - stability.value) * 0.35 - relief * 0.3, 0.0, 0.85)

	if not ph.get("no_spawn", false):
		_update_spawning(dt, ctx, ph)

func _update_protection(dt: float) -> void:
	if Physio.activation_level >= C.PROTECT_LEVEL and Physio.signal_ok:
		_protect_time += dt
	else:
		_protect_time = maxf(0.0, _protect_time - dt * 2.0)
	if not protecting and _protect_time >= C.PROTECT_SECONDS:
		protecting = true
		_set_pressure(maxi(0, pressure_level - 1))
		protection_changed.emit(true)
	elif protecting and Physio.activation_level <= 1:
		protecting = false
		_protect_time = 0.0
		protection_changed.emit(false)

## "Este nivel ya parece administrable para este jugador" → nuevo reto, gradual.
func _update_mastery(dt: float, ph: Dictionary) -> void:
	var physio_ok: bool = Physio.activation_level < C.PROTECT_LEVEL and not protecting
	var stable: bool = stability.value >= C.MASTERY_STABILITY and physio_ok
	if stable:
		_mastery += dt
	else:
		_mastery = maxf(0.0, _mastery - dt * 0.5)
	if _mastery >= C.MASTERY_SECONDS:
		_mastery = 0.0
		var raised := false
		if pressure_level < ph["pmax"]:
			_set_pressure(pressure_level + 1)
			raised = true
		if tier < C.MAX_TIER:
			tier += 1
			raised = true
		if raised:
			challenge_raised.emit(tier)

func _update_spawning(dt: float, ctx: Dictionary, ph: Dictionary) -> void:
	var p := clampi(roundi(effective_pressure), 0, 3)
	var interval: float = C.SPAWN_INTERVAL[p] * (1.0 + C.RECOVERY_SPAWN_SLOWDOWN * relief)
	if stability.paused:
		interval /= C.PAUSE_SPAWN_SLOWDOWN
	_spawn_acc += dt
	var forced := _pending_forced(ph, ctx)
	if forced != "" and ctx["free_seat"]:
		_forced_done[forced] = true
		_spawn(forced, p)
		return
	if _spawn_acc < interval or not ctx["free_seat"] or ctx["cats"] >= C.MAX_CATS[p]:
		return
	_spawn_acc = 0.0
	_spawn(_choose_kind(p, ctx), p)

## Cada fase garantiza ver sus eventos (para que la slice siempre los muestre).
func _pending_forced(ph: Dictionary, ctx: Dictionary) -> String:
	var forced: Array = ph["force"]
	for i in forced.size():
		var k: String = forced[i]
		var when: float = float(ph["duration"]) * C.DURATION_SCALE * (0.2 + 0.35 * i)
		if _forced_done.has(k) or phase_time < when:
			continue
		if k == "travieso" and not ctx["knockable"]:
			continue
		if k == "falsa_urgencia" and ctx["fu_present"]:
			continue
		return k
	return ""

func _choose_kind(p: int, ctx: Dictionary) -> String:
	var ev: float = C.EVENT_CHANCE[p] * (1.0 - 0.7 * relief)
	if tier >= 4 and not ctx["fu_present"] and randf() < ev * 0.45:
		return "falsa_urgencia"
	if tier >= 3 and ctx["knockable"] and randf() < ev:
		return "travieso"
	if tier >= 2 and randf() < 0.3 + 0.1 * p:
		return "impaciente"
	return "normal"

func _spawn(kind: String, p: int) -> void:
	# La carga cognitiva sube poco a poco: tradicional → permutaciones → cualquiera.
	var complexity := 0 if tier == 0 else (1 if tier == 1 else 2)
	if tier >= 2 and p <= 0 and randf() < 0.4:
		complexity = 1
	var order := DangoData.random_order(complexity)
	var patience: float = C.PATIENCE[p] * (1.0 + C.RECOVERY_PATIENCE_RELIEF * relief)
	spawn_requested.emit(kind, order, patience)

## Multiplicador para la impaciencia de los gatos (recuperación = más calma).
func impatience_scale() -> float:
	return (1.0 - C.RECOVERY_PATIENCE_RELIEF * relief) * (0.85 + 0.3 * (1.0 - stability.value))
