## Autoload "Sfx". Sonidos de un disparo con un pool de reproductores.
## Patrón reutilizado de Micheladas Nancy (scripts/SFX.gd): pool para que dos
## sonidos simultáneos no se corten y carga segura (_cargar) que no truena si
## falta un archivo.
extends Node

const CANTIDAD_PLAYERS := 12
const DIR := "res://assets/audio/gen/"

var _players: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _sounds := {}

func _ready() -> void:
	for i in CANTIDAD_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in ["plim", "meow", "meow_urgent", "crash", "coin", "pop", "tuk", "bell", "chime"]:
		_sounds[n] = _cargar(DIR + n + ".wav")

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
