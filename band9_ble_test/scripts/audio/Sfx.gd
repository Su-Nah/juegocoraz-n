## Autoload "Sfx". Sonidos de un disparo con un pool de reproductores.
## Patrón reutilizado de Micheladas Nancy (scripts/SFX.gd): pool para que dos
## sonidos simultáneos no se corten y carga segura (_cargar) que no truena si
## falta un archivo.
extends Node

const CANTIDAD_PLAYERS := 12
const DIR := "res://assets/audio/gen/"
const CFG := preload("res://scripts/music/MusicConfig.gd")
const Cache := preload("res://scripts/music/AudioSampleCache.gd")
const Variation := preload("res://scripts/music/RandomAudioVariationPlayer.gd")

var _variations := {}   # grupo -> RandomAudioVariationPlayer (maullidos…)

var _players: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _sounds := {}

func _ready() -> void:
	for i in CANTIDAD_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in ["plim", "crash", "coin", "pop", "tuk", "bell", "chime"]:
		_sounds[n] = _cargar(DIR + n + ".wav")
	var cache := Cache.new()
	_variations["meow"] = Variation.new(cache, CFG.VARIATIONS["meow"], CFG.MEOW_VOLUME_DB, CFG.MEOW_PITCH_MIN, CFG.MEOW_PITCH_MAX)
	_variations["meow_urgent"] = Variation.new(cache, CFG.VARIATIONS["meow_urgent"], CFG.URGENT_MEOW_VOLUME_DB, CFG.MEOW_PITCH_MIN, CFG.MEOW_PITCH_MAX)

func _cargar(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)

func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _sounds.get(sound)
	if stream == null:
		return
	var p := _players[_siguiente]
	_siguiente = (_siguiente + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Una muestra al azar del grupo (sin repetir la última) con pitch ligeramente variado.
func play_variation(group: String, extra_db: float = 0.0) -> void:
	if not _variations.has(group):
		return
	var pk: Array = _variations[group].pick()
	if pk.is_empty():
		return
	play_stream(pk[0], _variations[group].volume_db + extra_db, pk[1])

func play_stream(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	var p := _players[_siguiente]
	_siguiente = (_siguiente + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
