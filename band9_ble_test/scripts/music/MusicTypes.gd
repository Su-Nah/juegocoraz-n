## Estructuras de la canción: MusicEvent, MusicPhrase, MusicTrack y WaterDropTrack.
## Todo está en BEATS; los segundos los calcula MusicClock con el BPM actual.
extends RefCounted

const EPS := 0.001

class MusicEvent:
	var beat_offset := 0.0       # desde el inicio del compás
	var duration_beats := 0.0
	var note := ""               # "F#3", "bongo2"… o "REST"
	var velocity := 1.0
	var metadata := {}

	func is_rest() -> bool:
		return note == "REST"


class MusicPhrase:
	var id := 0
	var duration_beats := 0.0
	var events: Array = []       # MusicEvent
	var warning := ""

	## Construye una frase a partir de filas [duración, nota]. Si dura menos que
	## un compás, lo avisa y completa con silencio; si dura más, lo avisa.
	static func from_rows(p_id: int, rows: Array, expected: float, label: String) -> MusicPhrase:
		var ph := MusicPhrase.new()
		ph.id = p_id
		var t := 0.0
		for r in rows:
			var e := MusicEvent.new()
			e.beat_offset = t
			e.duration_beats = float(r[0])
			e.note = String(r[1])
			ph.events.append(e)
			t += e.duration_beats
		if t < expected - EPS:
			ph.warning = "%s frase %d = %.3f beats (se esperaban %.1f): se añade %.3f de silencio" % [label, p_id + 1, t, expected, expected - t]
			var rest := MusicEvent.new()
			rest.beat_offset = t
			rest.duration_beats = expected - t
			rest.note = "REST"
			rest.metadata = {"padding": true}
			ph.events.append(rest)
			t = expected
		elif t > expected + EPS:
			ph.warning = "%s frase %d = %.3f beats: EXCEDE el compás de %.1f (las notas que sobran se descartan)" % [label, p_id + 1, t, expected]
			ph.events = ph.events.filter(func(e): return e.beat_offset < expected - EPS)
		ph.duration_beats = expected
		return ph

	func raw_duration() -> float:
		var t := 0.0
		for e in events:
			if not e.metadata.get("padding", false):
				t += e.duration_beats
		return t


class MusicTrack:
	var id := ""
	var name := ""
	var kind := ""                # "guzheng" · "bongo"
	var priority := 1
	var phrases: Array = []       # MusicPhrase
	var enabled := true
	var volume_db := 0.0
	var gain := 1.0               # mezcla adaptativa (0..1)
	var randomize := false        # aleatorización propia (además del interruptor general)
	var avoid_repeat := true
	var timing_variation_beats := 0.0
	var rng := RandomNumberGenerator.new()
	var beats_per_bar := 4

	var _bar := -1
	var _idx := 0
	var _phrase := 0
	var _last_phrase := -1
	var _next: Dictionary = {}
	var phrase_by_bar := {}       # historial corto (depuración)

	func reset() -> void:
		_bar = -1
		_idx = 0
		_last_phrase = -1
		_next = {}
		phrase_by_bar.clear()

	## Frase para un compás. Se decide UNA vez, al entrar al compás.
	func choose_phrase(bar: int, random_global: bool) -> int:
		var n := phrases.size()
		if not (random_global and randomize) or n <= 1:
			return bar % n
		if bar == 0:
			return 0
		var p := rng.randi_range(0, n - 1)
		if avoid_repeat and p == _last_phrase:
			p = (p + 1 + rng.randi_range(0, n - 2)) % n
		return p

	## Próximo evento sonoro (salta silencios) sin consumirlo.
	func peek(random_global: bool) -> Dictionary:
		if _next.is_empty():
			_next = _advance(random_global)
		return _next

	func take(random_global: bool) -> Dictionary:
		var e := peek(random_global)
		_next = {}
		return e

	func _advance(random_global: bool) -> Dictionary:
		for _guard in 64:
			if _bar < 0 or _idx >= phrases[_phrase].events.size():
				_bar += 1
				_idx = 0
				_phrase = choose_phrase(_bar, random_global)
				_last_phrase = _phrase
				phrase_by_bar[_bar] = _phrase
				phrase_by_bar.erase(_bar - 16)
			var ev: MusicEvent = phrases[_phrase].events[_idx]
			_idx += 1
			if ev.is_rest():
				continue
			# Posición absoluta = compás * 4 + desplazamiento: sin acumular error.
			var beat := float(_bar * beats_per_bar) + ev.beat_offset
			if timing_variation_beats > 0.0:
				beat += rng.randf_range(-timing_variation_beats, timing_variation_beats)
			return {"beat": beat, "bar": _bar, "phrase": _phrase, "index": _idx - 1, "event": ev, "track": self}
		return {}

	func phrase_for_bar(bar: int) -> int:
		return phrase_by_bar.get(bar, -1)


## Gotas de agua: capa propia, sincronizada al MusicClock.
## musical = posiciones cuantizadas a la rejilla; free = segundos libres.
class WaterDropTrack:
	var id := "water"
	var kind := "water"
	var priority := 1
	var enabled := true
	var gain := 1.0
	var volume_db := 0.0
	var mode := "musical"
	var grid := 0.5
	var min_s := 1.2
	var max_s := 4.0
	var bpm := 90.0
	var rng := RandomNumberGenerator.new()
	var _last := 0.0
	var _next: Dictionary = {}

	func reset() -> void:
		_last = 0.0
		_next = {}

	func peek(_r: bool) -> Dictionary:
		if _next.is_empty():
			var beats := rng.randf_range(min_s, max_s) * bpm / 60.0
			var b := _last + beats
			if mode == "musical":
				b = ceilf(b / grid - 0.0001) * grid
			_last = b
			_next = {"beat": b, "bar": int(b / 4.0), "phrase": -1, "index": 0, "event": null, "track": self}
		return _next

	func take(r: bool) -> Dictionary:
		var e := peek(r)
		_next = {}
		return e
