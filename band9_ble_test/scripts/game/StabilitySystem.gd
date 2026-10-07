## Estabilidad del jugador: variable interna (no es una barra de HUD) que mezcla
## la recuperación fisiológica con CÓMO responde el jugador (parar, dejar ir,
## ignorar falsas urgencias) frente a trabajar frenéticamente.
## También registra las métricas de la sesión para la pantalla final.
extends Node

signal stability_changed(value: float)
signal rest_started()        # 4 s sin tocar nada
signal pause_started()
signal pause_ended()

const C := preload("res://scripts/core/Config.gd")

var value := C.STAB_START
var idle_time := 0.0
var paused := false
var pause_left := 0.0
var calm_time := 0.0          # s seguidos con estabilidad alta
var _clicks: Array[float] = []
var _t := 0.0
var _resting := false

# ---- métricas de la sesión
var stats := {}
var _escalation_time := 0.0
var _episode := {}            # episodio de activación elevada en curso

func reset() -> void:
	value = C.STAB_START
	idle_time = 0.0
	paused = false
	calm_time = 0.0
	_clicks.clear()
	_escalation_time = 0.0
	_episode = {}
	stats = {
		"money": 0, "served": 0, "let_go": 0, "left_on_own": 0,
		"pauses": 0, "rests": 0, "fu_ignored": 0, "fu_reacted": 0,
		"objects_restored": 0, "recovery_times": [], "peak_hr": 0.0,
		"time_pressure_ok": 0.0, "time_pressure": 0.0, "stab_sum": 0.0, "stab_samples": 0,
		"duration": 0.0,
	}

func _ready() -> void:
	reset()

## Cualquier clic del jugador en el mundo.
func register_action() -> void:
	_clicks.append(_t)
	if _resting:
		_resting = false
	idle_time = 0.0

func is_frantic() -> bool:
	return _clicks.size() / C.FRANTIC_WINDOW >= C.FRANTIC_CLICKS_PER_SEC

func start_pause() -> bool:
	if paused:
		return false
	paused = true
	pause_left = C.PAUSE_DURATION
	stats["pauses"] += 1
	pause_started.emit()
	return true

func let_go() -> void:
	stats["let_go"] += 1
	_bump(C.LET_GO_GAIN)

func false_urgency_ignored() -> void:
	stats["fu_ignored"] += 1
	_bump(C.FU_IGNORED_GAIN)

func false_urgency_reacted() -> void:
	stats["fu_reacted"] += 1
	_bump(-C.FU_REACT_LOSS)

func _bump(d: float) -> void:
	value = clampf(value + d, 0.0, 1.0)
	stability_changed.emit(value)

## active_stimuli: gatos esperando + objetos caídos + falsas urgencias.
## pressure_level: presión actual del director (para métricas).
func tick(dt: float, active_stimuli: int, pressure_level: int) -> void:
	_t += dt
	while _clicks.size() > 0 and _t - _clicks[0] > C.FRANTIC_WINDOW:
		_clicks.pop_front()
	idle_time += dt
	var d := 0.0
	if paused:
		pause_left -= dt
		d += C.PAUSE_GAIN
		idle_time = 0.0
		if pause_left <= 0.0:
			paused = false
			pause_ended.emit()
	elif idle_time >= C.IDLE_REST_SECONDS:
		if not _resting:
			_resting = true
			stats["rests"] += 1
			rest_started.emit()
		d += C.IDLE_GAIN
	if Physio.is_recovering:
		d += C.RECOVERY_GAIN * Physio.recovery_strength
	if is_frantic():
		d -= C.FRANTIC_LOSS
	d -= C.STIMULI_LOSS * maxi(0, active_stimuli - 2)
	d -= C.HIGH_ACT_LOSS * maxi(0, Physio.activation_level - 1)
	value = clampf(value + d * dt, 0.0, 1.0)
	stability_changed.emit(value)
	calm_time = calm_time + dt if value >= 0.72 and not is_frantic() else 0.0
	_track_metrics(dt, pressure_level)

func _track_metrics(dt: float, pressure_level: int) -> void:
	stats["duration"] += dt
	stats["stab_sum"] += value * dt
	stats["stab_samples"] += dt
	if Physio.signal_ok:
		stats["peak_hr"] = maxf(stats["peak_hr"], Physio.current_hr)
	# Tiempo bajo presión sin escalada prolongada.
	_escalation_time = _escalation_time + dt if Physio.activation_level >= 3 else 0.0
	if pressure_level >= 2:
		stats["time_pressure"] += dt
		if _escalation_time < C.ESCALATION_LIMIT:
			stats["time_pressure_ok"] += dt
	# Episodios: pico → vuelta a zona estable = tiempo de recuperación.
	var rel := Physio.relative_activation
	if _episode.is_empty():
		if Physio.has_baseline and rel >= C.LEVEL_THRESHOLDS[2]:
			_episode = {"peak": Physio.filtered_hr, "peak_t": _t, "stable_for": 0.0}
	else:
		if Physio.filtered_hr > _episode["peak"]:
			_episode["peak"] = Physio.filtered_hr
			_episode["peak_t"] = _t
		_episode["stable_for"] = _episode["stable_for"] + dt if rel < C.RECOVERED_REL else 0.0
		if _episode["stable_for"] >= C.RECOVERED_CONFIRM:
			var rt: float = _t - _episode["stable_for"] - _episode["peak_t"]
			stats["recovery_times"].append(maxf(0.0, rt))
			_episode = {}

func average_stability() -> float:
	return stats["stab_sum"] / maxf(1.0, stats["stab_samples"])
