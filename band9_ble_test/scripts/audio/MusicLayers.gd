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

## level: 0..3 continuo · recovering · calm_sustained · purr: 0..1 gatos ronroneando
func update(dt: float, level: float, recovering: bool, calm_sustained: bool, purr: float) -> void:
	var lo := clampi(floori(level), 0, 3)
	var hi := mini(lo + 1, 3)
	var f := level - lo
	for i in 5:
		targets[i] = lerpf(C.MUSIC_MIX[lo][i], C.MUSIC_MIX[hi][i], f)
	if calm_sustained:
		for i in 5:
			targets[i] = minf(targets[i], C.MUSIC_CALM_MIX[i]) if i >= 2 else maxf(targets[i], C.MUSIC_CALM_MIX[i])
	if recovering:
		targets[0] = minf(1.0, targets[0] + 0.15)
	for i in 5:
		var rate: float = C.MUSIC_RISE_RATE if targets[i] > gains[i] else C.MUSIC_FALL_RATE
		if recovering and i >= 2 and targets[i] < gains[i]:
			rate = C.MUSIC_PERC_FALL_RECOVERY * (1.4 if i == 4 else 1.0)
		gains[i] = move_toward(gains[i], targets[i], rate * dt)
	# Ambiente: siempre presente (no depende del estado ni del BPM).
	_ambient.volume_db = CFG.AMBIENT_VOLUME_DB
	_storm.volume_db = _db(gains[4]) + CFG.STORM_VOLUME_DB
	# Instrumentos del reloj musical.
	if CFG.ADAPTIVE_MIX:
		music.set_instrument_gain("low_guzheng", maxf(gains[1], 0.35))
		music.set_instrument_gain("high_guzheng", gains[1])
		music.set_instrument_gain("bongos", maxf(gains[2], gains[3]))
	else:
		for id in ["low_guzheng", "high_guzheng", "bongos"]:
			music.set_instrument_gain(id, 1.0)
	_update_variations(dt, purr)

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
