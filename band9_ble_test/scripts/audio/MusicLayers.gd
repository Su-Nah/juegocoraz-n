## Música adaptativa por capas (5 AudioStreamPlayer del mismo largo, en loop y
## sincronizados) + una capa de ronroneo. Solo se controla volumen/entrada/salida.
##   activación creciente → más ritmo · alta → más instrumentos · sobrecarga → densidad
##   recuperación → la percusión sale primero · calma sostenida → agua + cuerdas
## Concepto de capas separadas heredado de Ambiente.gd de Micheladas Nancy.
extends Node

const C := preload("res://scripts/core/Config.gd")
const FILES := ["layer0_ambient", "layer1_harmony", "layer2_pulse", "layer3_rhythm", "layer4_storm"]
const NAMES := ["agua/ambiente", "armonía", "pulso", "ritmo", "tempestad"]

var gains := [0.0, 0.0, 0.0, 0.0, 0.0]
var targets := [0.0, 0.0, 0.0, 0.0, 0.0]
var purr_gain := 0.0
var _players: Array[AudioStreamPlayer] = []
var _purr: AudioStreamPlayer
var started := false

func _ready() -> void:
	for f in FILES:
		var p := AudioStreamPlayer.new()
		p.stream = _loop(_load("res://assets/audio/gen/%s.wav" % f))
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_purr = AudioStreamPlayer.new()
	_purr.stream = _loop(_load("res://assets/audio/gen/purr.wav"))
	_purr.volume_db = -80.0
	add_child(_purr)

func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null

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
	for p in _players:
		if p.stream:
			p.play()   # todas a la vez → quedan en fase
	if _purr.stream:
		_purr.play()

## level: 0..3 continuo. recovering: tendencia de recuperación. calm_sustained: calma
## sostenida del jugador. purr: 0..1 cuántos gatos ronronean.
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
		targets[0] = minf(1.0, targets[0] + 0.15)   # el agua gana espacio como recompensa
	for i in 5:
		var rate: float = C.MUSIC_RISE_RATE if targets[i] > gains[i] else C.MUSIC_FALL_RATE
		if recovering and i >= 2 and targets[i] < gains[i]:
			rate = C.MUSIC_PERC_FALL_RECOVERY * (1.4 if i == 4 else 1.0)
		gains[i] = move_toward(gains[i], targets[i], rate * dt)
		_players[i].volume_db = _db(gains[i])
	purr_gain = move_toward(purr_gain, purr, dt * 0.3)
	_purr.volume_db = _db(purr_gain * 0.5)

func _db(g: float) -> float:
	return -80.0 if g <= 0.001 else linear_to_db(g) + C.MUSIC_MASTER_DB

func set_master(g: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(g, 0.0001)))

func current_layer_name() -> String:
	var top := "silencio"
	for i in 5:
		if gains[i] > 0.3:
			top = NAMES[i]
	return top
