## Traduce una nota ("F#3") al sample del banco de Guzheng.
## 1) sample exacto (assets/audio/guzheng/Fs3.wav) → sin cambiar el pitch.
## 2) si falta: la nota disponible más cercana, transpuesta (solo como respaldo).
## 3) si no hay nada cerca: aviso "Missing Guzheng sample: F#3" y la música sigue.
extends RefCounted

const NAMES := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
const MAX_TRANSPOSE := 7       # semitonos máximos para el respaldo

var cache: RefCounted
var dir := ""
var _resolved := {}            # nota -> [stream, pitch, modo]
var _available := {}           # midi -> path
var _warned := {}

func _init(p_cache: RefCounted, p_dir: String) -> void:
	cache = p_cache
	dir = p_dir
	for midi in range(24, 97):
		var path := dir + file_name(midi_to_name(midi))
		if ResourceLoader.exists(path):
			_available[midi] = path

static func note_to_midi(note: String) -> int:
	var name := note.substr(0, note.length() - 1)
	if not NAMES.has(name) or not note.right(1).is_valid_int():
		return -1
	return 12 * (int(note.right(1)) + 1) + NAMES[name]

static func midi_to_name(midi: int) -> String:
	var keys := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return "%s%d" % [keys[midi % 12], midi / 12 - 1]

static func file_name(note: String) -> String:
	return note.replace("#", "s") + ".wav"

## Prepara (carga) una nota de antemano. Devuelve "exact", "transposed:<nota>" o "missing".
func prepare(note: String) -> String:
	if _resolved.has(note):
		return _resolved[note][2]
	var midi := note_to_midi(note)
	var res := [null, 1.0, "missing"]
	if _available.has(midi):
		res = [cache.get_stream(_available[midi]), 1.0, "exact"]
	elif midi >= 0:
		var best := -1
		for m in _available:
			if absi(m - midi) <= MAX_TRANSPOSE and (best < 0 or absi(m - midi) < absi(best - midi)):
				best = m
		if best >= 0:
			res = [cache.get_stream(_available[best]), pow(2.0, (midi - best) / 12.0), "transposed:" + midi_to_name(best)]
	_resolved[note] = res
	if res[2] == "missing" and not _warned.has(note):
		_warned[note] = true
		push_warning("Missing Guzheng sample: %s" % note)
	elif String(res[2]).begins_with("transposed") and not _warned.has(note):
		_warned[note] = true
		push_warning("Guzheng %s no tiene sample exacto: se transpone desde %s" % [note, String(res[2]).substr(11)])
	return res[2]

## [stream, pitch] o [null, 1.0] si falta.
func resolve(note: String) -> Array:
	if not _resolved.has(note):
		prepare(note)
	return _resolved[note]

func report() -> Dictionary:
	var r := {}
	for n in _resolved:
		r[n] = _resolved[n][2]
	return r
