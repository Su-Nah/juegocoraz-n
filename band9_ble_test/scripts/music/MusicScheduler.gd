## Programador con ventana móvil. Solo mantiene los eventos de los próximos
## SCHEDULE_AHEAD segundos. Los eventos guardan su BEAT (no su segundo): si el
## BPM cambia, su hora se recalcula → no se pierden ni se duplican.
extends RefCounted

var clock: RefCounted
var tracks: Array = []           # MusicTrack / WaterDropTrack
var lookahead := 0.12
var pending: Array = []          # eventos dentro de la ventana
var fired_total := 0
var max_pending_seen := 0

func reset() -> void:
	pending.clear()
	fired_total = 0
	for t in tracks:
		t.reset()

## Devuelve los eventos que deben sonar ya. `frame_dt` permite disparar un
## evento si caería antes del próximo frame (minimiza el jitter); el retraso
## real se devuelve en "late" para compensarlo al iniciar el sample.
func update(now: float, frame_dt: float, random_global: bool) -> Array:
	if not clock.running or clock.paused:
		return []
	var horizon: float = clock.beat_at(now + lookahead)
	for t in tracks:
		var guard := 0
		while guard < 32:
			guard += 1
			var e: Dictionary = t.peek(random_global)
			if e.is_empty() or e["beat"] > horizon:
				break
			pending.append(t.take(random_global))
	max_pending_seen = maxi(max_pending_seen, pending.size())
	var fire_until := now + frame_dt * 0.5
	var out: Array = []
	var keep: Array = []
	for e in pending:
		var at: float = clock.time_at(e["beat"])
		if at <= fire_until:
			e["late"] = now - at
			out.append(e)
		else:
			keep.append(e)
	pending = keep
	fired_total += out.size()
	return out
