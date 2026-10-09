## Mezcla de audio del juego, separada en buses:
##   Ambient : ambiente (agua/viento/aves) siempre presente + tormenta de hojas
##             → independientes del reloj musical (no se reinician con el BPM).
##   Music   : MusicPlayer (Guzheng grave/agudo + Bongoes + gotas, reloj común).
##   SFX     : ronroneos y ráfagas de viento aleatorios (variaciones).
## El estado del juego (nivel 0..3) decide CUÁNTO suena cada capa:
##   calma → agua + guzheng · activación → entra el pulso (bongoes) ·
##   presión/tormenta → más bongoes y tormenta · recuperación → la percusión sale primero.
extends Node

const C := preload("res://scripts/core/Config.gd")
const CFG := preload("res://scripts/music/MusicConfig.gd")
const MusicPlayerScript := preload("res://scripts/music/MusicPlayer.gd")
const Variation := preload("res://scripts/music/RandomAudioVariationPlayer.gd")
## Columnas de C.MUSIC_MIX: [ambiente, armonía(guzheng), pulso, ritmo, tormenta]
const NAMES := ["agua/ambiente", "guzheng", "pulso", "ritmo", "tormenta"]

var gains := [0.0, 0.0, 0.0, 0.0, 0.0]
var targets := [0.0, 0.0, 0.0, 0.0, 0.0]
var purr_gain := 0.0
var music: Node                       # MusicPlayer
var started := false
var _ambient: AudioStreamPlayer
var _storm: AudioStreamPlayer
var _sfx: AudioStreamPlayer           # ronroneo / viento (una voz cada uno basta)
var _wind: AudioStreamPlayer
var _purrs: RefCounted
var _winds: RefCounted
var _purr_t := 1.0
var _wind_t := 6.0

func _ready() -> void:
	music = MusicPlayerScript.new()
	music.name = "MusicPlayer"
	add_child(music)
	var amb_bus := _bus("Ambient")
	_ambient = _player(_loop(music.cache.get_stream("res://assets/audio/gen/layer0_ambient.wav")), amb_bus)
	_storm = _player(_loop(music.cache.get_stream("res://assets/audio/gen/layer4_storm.wav")), amb_bus)
	_sfx = _player(null, _bus("SFX"))
	_wind = _player(null, _bus("SFX"))
	_purrs = Variation.new(music.cache, CFG.VARIATIONS["purr"], CFG.PURR_VOLUME_DB, CFG.PURR_PITCH_MIN, CFG.PURR_PITCH_MAX)
	_winds = Variation.new(music.cache, CFG.VARIATIONS["wind"], CFG.WIND_GUST_VOLUME_DB, 0.9, 1.1)
	for b in [["Music", CFG.MUSIC_MASTER_DB], ["SFX", CFG.SFX_MASTER_DB]]:
		var idx := AudioServer.get_bus_index(b[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, b[1])

func _bus(n: String) -> String:
	return n if AudioServer.get_bus_index(n) >= 0 else "Master"

func _player(s: AudioStream, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p

func _loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s

func start() -> void:
	if started:
		return
	started = true
	for p in [_ambient, _storm]:
		if p.stream:
			p.play()
	music.start()

## EL CORAZÓN DIRIGE LA MÚSICA. `level` = intensidad cardíaca h * 3 (h = Physio.activation,
## activación relativa a la línea base, ya filtrada y protegida contra lecturas erróneas).
##   h bajo  → solo agua (etapa 1), tempo BPM_MIN
##   h sube  → el tempo acelera; etapas: +guzheng agudo → +guzheng grave → +bongoes
##   h baja  → el tempo vuelve a calmarse y las capas salen (fundidos LAYER_FADE_*).
var heart := 0.0                      # h suavizado
var _on := {"storm": false}
var stage := 1                        # 1 agua · 2 +agudo · 3 +grave · 4 +bongoes
var _stage_t := 0.0
var _bpm := CFG.BPM_MIN

func update(dt: float, level: float, _recovering: bool, _calm_sustained: bool, purr: float) -> void:
	heart = move_toward(heart, clampf(level / 3.0, 0.0, 1.0), dt * 0.5)
	var h := heart
	# Etapas en orden estricto, una por paso, con histéresis.
	var enter := [0.0, 0.0, CFG.HIGH_GUZHENG_ENTER, CFG.LOW_GUZHENG_ENTER, CFG.BONGOS_ENTER]
	_stage_t += dt
	if _stage_t >= CFG.LAYER_FADE_IN_SECONDS:   # una etapa termina de entrar antes de la siguiente
		if stage < 4 and h >= enter[stage + 1]:
			stage += 1
			_stage_t = 0.0
		elif stage > 1 and h < enter[stage] - CFG.LAYER_HYSTERESIS:
			stage -= 1
			_stage_t = 0.0
	_on["storm"] = h >= CFG.STORM_ENTER or (_on["storm"] and h >= CFG.STORM_ENTER - CFG.LAYER_HYSTERESIS)
	# [ambiente, guzheng agudo, bongoes, (bongoes), tormenta]; el guzheng grave va aparte.
	var all := not CFG.ADAPTIVE_MIX
	targets = [1.0, 1.0 if (stage >= 2 or all) else 0.0, 1.0 if (stage >= 4 or all) else 0.0,
		1.0 if (stage >= 4 or all) else 0.0, 1.0 if _on["storm"] else 0.0]
	for i in 5:
		gains[i] = _fade(gains[i], targets[i], dt)
	_low_gain = _fade(_low_gain, 1.0 if (started and (stage >= 3 or all)) else 0.0, dt)
	_ambient.volume_db = CFG.AMBIENT_VOLUME_DB          # siempre presente, sin reinicios
	_storm.volume_db = _db(gains[4]) + CFG.STORM_VOLUME_DB
	music.set_instrument_gain("low_guzheng", _low_gain)
	music.set_instrument_gain("high_guzheng", gains[1])
	music.set_instrument_gain("bongos", gains[2])
	# Tempo: sigue al corazón con suavidad, sin reiniciar la pieza (MusicClock re-ancla).
	var target_bpm := lerpf(CFG.BPM_MIN, CFG.BPM_MAX, clampf(h * CFG.HEART_TEMPO_INFLUENCE, 0.0, 1.0))
	_bpm = move_toward(_bpm, target_bpm, dt * CFG.TEMPO_SLEW_BPM_PER_SEC)
	if started and absf(_bpm - music.get_bpm()) > 0.25:
		music.set_bpm(_bpm)
	_update_variations(dt, purr)

var _low_gain := 0.0

## Fundido lineal desde el valor ACTUAL: reversible a mitad sin saltos, un solo control por capa.
func _fade(cur: float, target: float, dt: float) -> float:
	var secs: float = CFG.LAYER_FADE_IN_SECONDS if target > cur else CFG.LAYER_FADE_OUT_SECONDS
	return move_toward(cur, target, dt / maxf(secs, 0.01))

## Ronroneos (muestras variadas mientras haya gatos ronroneando) y ráfagas de
## viento ocasionales cuando la tormenta está presente.
func _update_variations(dt: float, purr: float) -> void:
	purr_gain = move_toward(purr_gain, purr, dt * 0.3)
	_purr_t -= dt
	if started and purr_gain > 0.05 and _purr_t <= 0.0:
		_purr_t = randf_range(2.0, 3.4)
		_play_variation(_sfx, _purrs, linear_to_db(purr_gain))
	_wind_t -= dt
	if started and gains[4] > 0.3 and _wind_t <= 0.0:
		_wind_t = randf_range(6.0, 14.0)
		_play_variation(_wind, _winds, linear_to_db(gains[4]))

func _play_variation(p: AudioStreamPlayer, v: RefCounted, extra_db: float) -> void:
	var pk: Array = v.pick()
	if pk.is_empty():
		return
	p.stream = pk[0]
	p.pitch_scale = pk[1]
	p.volume_db = v.volume_db + extra_db
	p.play()

func _db(g: float) -> float:
	return -80.0 if g <= 0.001 else linear_to_db(g)

func current_layer_name() -> String:
	var top := "silencio"
	for i in 5:
		if gains[i] > 0.3:
			top = NAMES[i]
	return top
