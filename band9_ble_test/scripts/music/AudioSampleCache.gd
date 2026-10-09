## Caché de samples: cada archivo se carga UNA vez (al iniciar) y se reutiliza.
## Nunca se lee/decodifica audio en el momento de tocar una nota.
extends RefCounted

var _streams := {}
var _missing := {}

func get_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		push_warning("Audio no encontrado: %s" % path)
		return null
	var s: AudioStream = load(path)
	_streams[path] = s
	return s

func preload_paths(paths: Array) -> void:
	for p in paths:
		get_stream(p)

func has(path: String) -> bool:
	return get_stream(path) != null

func size() -> int:
	return _streams.size()
