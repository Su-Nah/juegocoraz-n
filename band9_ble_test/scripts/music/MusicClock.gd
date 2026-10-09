## Reloj musical único. La posición se guarda como (beat de anclaje, tiempo de
## anclaje): beat(t) = anchor_beat + (t - anchor_time) * BPM / 60.
## Cambiar el BPM re-ancla en el instante actual → la posición musical
## (compás, beat) se conserva y no se acumula error sumando floats.
extends RefCounted

var bpm := 90.0
var beats_per_bar := 4
var running := false
var paused := false
var _anchor_beat := 0.0
var _anchor_time := 0.0
var _paused_beat := 0.0

static func beats_to_seconds(beats: float, p_bpm: float) -> float:
	return beats * 60.0 / p_bpm

static func seconds_to_beats(seconds: float, p_bpm: float) -> float:
	return seconds * p_bpm / 60.0

func start(now: float, at_beat: float = 0.0) -> void:
	running = true
	paused = false
	_anchor_beat = at_beat
	_anchor_time = now

func stop() -> void:
	running = false
	paused = false
	_anchor_beat = 0.0

func beat_at(now: float) -> float:
	if not running:
		return 0.0
	if paused:
		return _paused_beat
	return _anchor_beat + (now - _anchor_time) * bpm / 60.0

func time_at(beat: float) -> float:
	return _anchor_time + (beat - _anchor_beat) * 60.0 / bpm

func set_bpm(new_bpm: float, now: float) -> void:
	new_bpm = clampf(new_bpm, 20.0, 300.0)
	if running and not paused:
		_anchor_beat = beat_at(now)
		_anchor_time = now
	elif paused:
		_anchor_beat = _paused_beat
	bpm = new_bpm

func pause(now: float) -> void:
	if running and not paused:
		_paused_beat = beat_at(now)
		paused = true

func resume(now: float) -> void:
	if running and paused:
		_anchor_beat = _paused_beat
		_anchor_time = now
		paused = false

func bar_at(now: float) -> int:
	return int(floor(beat_at(now) / beats_per_bar))

func beat_in_bar(now: float) -> float:
	return fposmod(beat_at(now), float(beats_per_bar))
