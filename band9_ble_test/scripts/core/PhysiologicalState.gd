## Autoload "Physio". Convierte BPM crudos en un estado fisiológico abstracto.
##   BPM → filtro temporal → relativo al baseline → tendencia → nivel con histéresis
## No interpreta ningún valor como "ansiedad": solo activación relativa a la persona.
extends Node

signal physiological_state_changed()          # ~1 Hz
signal activation_changed(level: int)
signal recovery_started()
signal recovery_ended()
signal recovery_strength_changed(strength: float)
signal stability_changed(value: float)
signal baseline_ready(baseline: float)

const C := preload("res://scripts/core/Config.gd")

var current_hr := 0.0
## BPM para el TEMPO musical: sigue al pulso ACTUAL (no al basal) con un filtro
## corto por lectura válida (Config.MUSIC_HR_SMOOTH). Solo cambia con lecturas nuevas.
var music_hr := 0.0
var filtered_hr := 0.0
var baseline_hr := 0.0
var baseline_sd := 0.0
var has_baseline := false
var relative_activation := 0.0   # (filtrada - baseline) / baseline
var activation := 0.0            # 0..1 continuo
var activation_level := 0        # 0..3 con histéresis y confirmación temporal
var recovery_trend := 0.0        # pendiente BPM/s (negativa = bajando)
var recovery_strength := 0.0     # 0..1
var is_recovering := false
var stability := 1.0             # estabilidad fisiológica 0..1 (poca activación y poca deriva)
var time_in_current_state := 0.0
var signal_ok := false
var sample_count := 0

var collecting_baseline := false
var _baseline_samples: Array[float] = []
var _last_sample_msec := -1
var _glitch_pending := false
var _candidate_level := 0
var _candidate_time := 0.0
var _history: Array[Vector2] = []   # (t, filtered) a 1 Hz
var _tick := 0.0
var _t := 0.0
var _rec_on := 0.0
var _rec_off := 0.0

func _ready() -> void:
	HeartRate.bpm_received.connect(_on_bpm)
	HeartRate.source_changed.connect(func(_s): _reset_signal())

func _reset_signal() -> void:
	sample_count = 0
	_history.clear()
	_last_sample_msec = -1

func _on_bpm(bpm: int, _source: String) -> void:
	var b := float(bpm)
	if b < C.HR_MIN or b > C.HR_MAX:
		return
	# Un salto enorme aislado se descarta; si se repite, era real.
	if sample_count > 0 and absf(b - current_hr) > C.HR_GLITCH_JUMP and not _glitch_pending:
		_glitch_pending = true
		return
	_glitch_pending = false
	current_hr = b
	sample_count += 1
	_last_sample_msec = Time.get_ticks_msec()
	if sample_count == 1:
		filtered_hr = b
	music_hr = b if music_hr <= 0.0 else lerpf(music_hr, b, C.MUSIC_HR_SMOOTH)
	if collecting_baseline:
		_baseline_samples.append(b)

# ------------------------------------------------------------ BASELINE
func start_baseline() -> void:
	collecting_baseline = true
	_baseline_samples.clear()

func baseline_sample_count() -> int:
	return maxi(0, _baseline_samples.size() - C.BASELINE_DISCARD_FIRST)

## Media y desviación de las lecturas tranquilas, descartando el asentamiento
## inicial y valores a más de 2 desviaciones.
func finish_baseline() -> bool:
	var s: Array[float] = []
	s.assign(_baseline_samples.slice(C.BASELINE_DISCARD_FIRST))
	if s.size() < C.BASELINE_MIN_SAMPLES:
		return false
	collecting_baseline = false
	var m := _mean(s)
	var sd := _sd(s, m)
	var trimmed: Array[float] = []
	trimmed.assign(s.filter(func(v): return absf(v - m) <= 2.0 * maxf(sd, C.BASELINE_SD_FLOOR)))
	if trimmed.size() >= C.BASELINE_MIN_SAMPLES:
		m = _mean(trimmed)
		sd = _sd(trimmed, m)
	baseline_hr = m
	baseline_sd = maxf(sd, C.BASELINE_SD_FLOOR)
	has_baseline = true
	filtered_hr = lerpf(filtered_hr, m, 0.5)
	activation_level = 0
	_candidate_level = 0
	time_in_current_state = 0.0
	baseline_ready.emit(baseline_hr)
	return true

func _mean(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(1.0, a.size())

func _sd(a: Array[float], m: float) -> float:
	var t := 0.0
	for v in a:
		t += (v - m) * (v - m)
	return sqrt(t / maxf(1.0, a.size()))

# ------------------------------------------------------------ PROCESO
func _process(dt: float) -> void:
	_t += dt
	signal_ok = _last_sample_msec >= 0 and (Time.get_ticks_msec() - _last_sample_msec) / 1000.0 < C.SIGNAL_TIMEOUT
	if sample_count == 0:
		return
	# Filtro exponencial independiente de la frecuencia de muestreo.
	filtered_hr += (current_hr - filtered_hr) * (1.0 - exp(-dt / C.FILTER_TAU))
	var ref := baseline_hr if has_baseline else filtered_hr
	relative_activation = (filtered_hr - ref) / maxf(ref, 1.0)
	activation = clampf(relative_activation / C.ACTIVATION_FULL, 0.0, 1.0)
	time_in_current_state += dt
	if has_baseline:
		_update_level(dt)

	_tick += dt
	if _tick >= 1.0:
		_tick -= 1.0
		_history.append(Vector2(_t, filtered_hr))
		while _history.size() > 0 and _t - _history[0].x > C.TREND_WINDOW:
			_history.pop_front()
		recovery_trend = _slope()
		_update_recovery()
		var new_stab := clampf(1.0 - 0.6 * activation - 0.4 * clampf(absf(recovery_trend) / 1.0, 0.0, 1.0), 0.0, 1.0)
		stability = lerpf(stability, new_stab, 0.3)
		stability_changed.emit(stability)
		physiological_state_changed.emit()

## Nivel objetivo según umbrales (subir) e histéresis (bajar), confirmado en el tiempo.
func _update_level(dt: float) -> void:
	var target := activation_level
	while target < 3 and relative_activation >= C.LEVEL_THRESHOLDS[target + 1]:
		target += 1
	if target == activation_level:
		while target > 0 and relative_activation < C.LEVEL_THRESHOLDS[target] - C.LEVEL_HYSTERESIS:
			target -= 1
	if target == activation_level:
		_candidate_level = activation_level
		_candidate_time = 0.0
		return
	if target != _candidate_level:
		_candidate_level = target
		_candidate_time = 0.0
	_candidate_time += dt
	var need: float = C.RISE_CONFIRM if target > activation_level else C.FALL_CONFIRM
	if _candidate_time >= need:
		activation_level = target
		_candidate_time = 0.0
		time_in_current_state = 0.0
		activation_changed.emit(activation_level)

func _slope() -> float:
	var n := _history.size()
	if n < 4:
		return 0.0
	var sx := 0.0
	var sy := 0.0
	for p in _history:
		sx += p.x
		sy += p.y
	var mx := sx / n
	var my := sy / n
	var num := 0.0
	var den := 0.0
	for p in _history:
		num += (p.x - mx) * (p.y - my)
		den += (p.x - mx) * (p.x - mx)
	return num / den if den > 0.0 else 0.0

## Se reconoce la TENDENCIA de bajada mientras aún se está por encima del baseline;
## no se exige volver al baseline.
func _update_recovery() -> void:
	var elevated := relative_activation > C.RECOVERED_REL or activation_level > 0
	var raw := 0.0
	if elevated and recovery_trend < 0.0:
		raw = clampf((-recovery_trend - 0.05) / (-C.RECOVERY_FULL_SLOPE - 0.05), 0.0, 1.0)
	var prev := recovery_strength
	recovery_strength = lerpf(recovery_strength, raw, 0.4)
	if absf(recovery_strength - prev) > 0.02:
		recovery_strength_changed.emit(recovery_strength)
	var on_cond := elevated and recovery_trend <= C.RECOVERY_SLOPE
	if not is_recovering:
		_rec_on = _rec_on + 1.0 if on_cond else 0.0
		if _rec_on >= C.RECOVERY_START_CONFIRM:
			is_recovering = true
			_rec_off = 0.0
			recovery_started.emit()
	else:
		var off_cond := recovery_trend > C.RECOVERY_SLOPE * 0.3 or not elevated
		_rec_off = _rec_off + 1.0 if off_cond else 0.0
		if _rec_off >= C.RECOVERY_END_CONFIRM:
			is_recovering = false
			_rec_on = 0.0
			recovery_ended.emit()

## Estado legible: CALMA · ACTIVACIÓN · PRESIÓN · TORMENTA · RECUPERACIÓN.
func state_name() -> String:
	if is_recovering:
		return "RECUPERACIÓN"
	return ["CALMA", "ACTIVACIÓN", "PRESIÓN", "TORMENTA"][clampi(activation_level, 0, 3)]

func level_name(level: int = -1) -> String:
	var l := activation_level if level < 0 else level
	return ["calmo", "activado", "presión", "tempestad"][clampi(l, 0, 3)]
