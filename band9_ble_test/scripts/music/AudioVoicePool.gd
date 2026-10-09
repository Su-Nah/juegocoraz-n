## Pool de voces preasignadas (AudioStreamPlayer reutilizados; nunca se crean
## ni destruyen por nota). Las colas de las notas suenan completas. Si el pool
## se llena, se reutiliza la voz más antigua (la más apagada), y cuando queda
## una sola libre se desvanece suavemente la más vieja para evitar cortes bruscos.
extends Node

const FADE_SECONDS := 0.06

var priority := 1
var _voices: Array[AudioStreamPlayer] = []
var _started: Array[float] = []
var _fading := {}
var stolen := 0

func setup(count: int, bus: String, p_priority: int) -> void:
	priority = p_priority
	for i in count:
		var v := AudioStreamPlayer.new()
		v.bus = bus
		add_child(v)
		_voices.append(v)
		_started.append(-INF)

func size() -> int:
	return _voices.size()

func active_count() -> int:
	var n := 0
	for v in _voices:
		if v.playing:
			n += 1
	return n

func play(stream: AudioStream, volume_db: float, pitch: float, from_position: float, now: float) -> void:
	if stream == null or _voices.is_empty():
		return
	var i := _free_index()
	if i < 0:
		i = _oldest_index()
		stolen += 1
	_cancel_fade(i)
	var v := _voices[i]
	v.stream = stream
	v.volume_db = volume_db
	v.pitch_scale = pitch
	v.play(from_position)
	_started[i] = now
	if _free_index() < 0:
		_fade_out_oldest(now, i)

## Libera la voz más antigua (lo usa el presupuesto global de voces).
func steal_oldest() -> bool:
	var i := _oldest_index()
	if i < 0 or not _voices[i].playing:
		return false
	_cancel_fade(i)
	_voices[i].stop()
	stolen += 1
	return true

func stop_all() -> void:
	for i in _voices.size():
		_cancel_fade(i)
		_voices[i].stop()

func _free_index() -> int:
	for i in _voices.size():
		if not _voices[i].playing and not _fading.has(i):
			return i
	return -1

func _oldest_index() -> int:
	var best := -1
	var t := INF
	for i in _voices.size():
		if _voices[i].playing and _started[i] < t:
			t = _started[i]
			best = i
	return best

func _fade_out_oldest(now: float, except: int) -> void:
	var best := -1
	var t := INF
	for i in _voices.size():
		if i != except and _voices[i].playing and not _fading.has(i) and _started[i] < t and now - _started[i] > 0.4:
			t = _started[i]
			best = i
	if best < 0:
		return
	var v := _voices[best]
	var tw := create_tween()
	tw.tween_property(v, "volume_db", -60.0, FADE_SECONDS)
	tw.tween_callback(func():
		v.stop()
		_fading.erase(best))
	_fading[best] = tw

func _cancel_fade(i: int) -> void:
	if _fading.has(i):
		(_fading[i] as Tween).kill()
		_fading.erase(i)
