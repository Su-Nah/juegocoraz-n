## Elige entre varias muestras (maullidos, ronroneos, gotas…) con una ligera
## variación de pitch y sin repetir la misma dos veces seguidas si hay
## alternativas. Con una sola muestra, la usa siempre (sin error).
extends RefCounted

var streams: Array = []
var avoid_last := true
var pitch_min := 1.0
var pitch_max := 1.0
var volume_db := 0.0
var rng := RandomNumberGenerator.new()
var _last := -1

func _init(cache: RefCounted, paths: Array, p_volume_db: float = 0.0, p_min: float = 1.0, p_max: float = 1.0) -> void:
	for p in paths:
		var s: AudioStream = cache.get_stream(p)
		if s:
			streams.append(s)
	volume_db = p_volume_db
	pitch_min = p_min
	pitch_max = p_max
	rng.randomize()

## [stream, pitch] o [] si no hay muestras.
func pick() -> Array:
	if streams.is_empty():
		return []
	var i := rng.randi_range(0, streams.size() - 1)
	if avoid_last and streams.size() > 1 and i == _last:
		i = (i + 1 + rng.randi_range(0, streams.size() - 2)) % streams.size()
	_last = i
	return [streams[i], rng.randf_range(pitch_min, pitch_max)]
