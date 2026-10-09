## Pruebas automáticas del sistema musical (sin depender del audio real).
##   godot --headless -s res://tests/MusicTests.gd
## Usa tiempo manual: simula frames de 60 fps y comprueba ritmo, tempo,
## sincronización, aleatorización, pausa y carga de 10 minutos.
extends SceneTree

const MusicPlayerScript := preload("res://scripts/music/MusicPlayer.gd")
const Clock := preload("res://scripts/music/MusicClock.gd")
const MT := preload("res://scripts/music/MusicTypes.gd")
const CFG := preload("res://scripts/music/MusicConfig.gd")

var fails := 0
var passes := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("  ✗ FALLO: ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame   # los nodos ya están dentro del árbol (pueden sonar)
	print("=== Pruebas del sistema musical ===")
	test_phrase_durations()
	test_conversions()
	test_event_positions()
	test_bar_sync(60.0)
	test_bar_sync(90.0)
	test_bar_sync(120.0)
	test_base_sequence()
	test_seed_reproducible()
	test_independent_randomization()
	test_dynamic_tempo()
	test_toggle_random_midbar()
	test_pause_resume()
	test_water_quantized()
	test_missing_sample()
	test_load_10_minutes()
	print("=== %d comprobaciones OK, %d fallos ===" % [passes, fails])
	quit(0 if fails == 0 else 1)

func new_player() -> Node:
	var mp: Node = MusicPlayerScript.new()
	root.add_child(mp)
	mp.ensure_built()
	mp.use_manual_time(true)
	return mp

func free_player(mp: Node) -> void:
	mp.stop()
	mp.queue_free()

## Simula `seconds` a 60 fps registrando los eventos disparados.
## changes: Array de [beat, bpm] (cambia el tempo al cruzar ese beat).
func simulate(mp: Node, seconds: float, changes: Array = [], pause_at := -1.0, pause_for := 0.0) -> Array:
	var dt := 1.0 / 60.0
	var t := 0.0
	var out: Array = []
	var ch := changes.duplicate()
	var paused_until := -1.0
	mp.start()
	while t < seconds:
		var beat: float = mp.clock.beat_at(t)
		if not ch.is_empty() and beat >= ch[0][0]:
			mp.clock.set_bpm(ch[0][1], t)
			ch.pop_front()
		if pause_at >= 0.0 and beat >= pause_at and paused_until < 0.0:
			mp.clock.pause(t)
			paused_until = t + pause_for
		if paused_until > 0.0 and t >= paused_until and mp.clock.paused:
			mp.clock.resume(t)
		for e in mp.scheduler.update(t, dt, mp.random_phrases):
			e["t"] = t
			out.append(e)
		t += dt
	return out

func phrases_by_bar(events: Array, track: String) -> Array:
	var bars := {}
	for e in events:
		if e["track"].id == track:
			bars[e["bar"]] = e["phrase"]
	var keys := bars.keys()
	keys.sort()
	return keys.map(func(k): return bars[k])

# ------------------------------------------------------------------ RITMO
func test_phrase_durations() -> void:
	print("- Ritmo: duración de las frases")
	var mp := new_player()
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		for ph in mp.tracks[id].phrases:
			var total := 0.0
			for e in ph.events:
				total += e.duration_beats
			check(absf(total - 4.0) < 1e-9, "%s frase %d dura %.6f" % [id, ph.id + 1, total])
	var hp1 = mp.tracks["high_guzheng"].phrases[0]
	check(absf(hp1.raw_duration() - 3.5) < 1e-9 and hp1.warning != "", "Guzheng agudo frase 1 debe avisar 3.5 beats")
	check(hp1.events[-1].is_rest() and absf(hp1.events[-1].duration_beats - 0.5) < 1e-9, "relleno de 0.5 beats de silencio")
	var hp4 = mp.tracks["high_guzheng"].phrases[3]
	check(hp4.warning == "" and absf(hp4.raw_duration() - 4.0) < 1e-9, "Guzheng agudo frase 4 = 4 beats exactos")
	free_player(mp)

func test_conversions() -> void:
	print("- Conversión beats → segundos")
	check(is_equal_approx(Clock.beats_to_seconds(0.25, 60.0), 0.25), "0.25 beats a 60 BPM = 0.25 s")
	check(is_equal_approx(Clock.beats_to_seconds(0.25, 120.0), 0.125), "0.25 beats a 120 BPM = 0.125 s")
	check(is_equal_approx(Clock.beats_to_seconds(4.0, 180.0), 4.0 / 3.0), "1 compás a 180 BPM = 1.333 s")
	check(is_equal_approx(Clock.seconds_to_beats(2.0, 90.0), 3.0), "2 s a 90 BPM = 3 beats")

func test_event_positions() -> void:
	print("- Posiciones de inicio de las notas")
	var mp := new_player()
	var p1 = mp.tracks["low_guzheng"].phrases[0]
	var expect := [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.0 + 1.0 / 3.0, 2.0 + 2.0 / 3.0, 3.0]
	for i in expect.size():
		check(absf(p1.events[i].beat_offset - expect[i]) < 1e-9, "Guzheng grave F1 nota %d en %.4f" % [i + 1, expect[i]])
	var b3 = mp.tracks["bongos"].phrases[2]
	var be := [0.0, 1.0, 2.0, 2.25, 2.5, 3.0]
	for i in be.size():
		check(absf(b3.events[i].beat_offset - be[i]) < 1e-9, "Bongoes F3 golpe %d en %.2f" % [i + 1, be[i]])
	check(b3.events[1].note == "bongo4" and b3.events[0].note == "bongo2", "mapeo de bongoes intacto")
	free_player(mp)

# ------------------------------------------------------------------ SINCRONIZACIÓN
func test_bar_sync(bpm: float) -> void:
	print("- Sincronización de compases a %.0f BPM (200 compases)" % bpm)
	var mp := new_player()
	mp.clock.bpm = bpm
	var secs := 200.0 * 4.0 * 60.0 / bpm
	var ev := simulate(mp, secs)
	var t0: float = mp.clock.time_at(0.0)
	var worst := 0.0
	var starts := {}
	for e in ev:
		if e["track"].id == "water":
			continue
		var expected_beat: float = e["bar"] * 4.0 + e["event"].beat_offset
		check(absf(e["beat"] - expected_beat) < 1e-9, "posición exacta en beats")
		var exp_t: float = t0 + e["beat"] * 60.0 / bpm
		worst = maxf(worst, absf(e["t"] - e["late"] - exp_t))   # late = ahora - hora objetivo
		check(e["t"] >= exp_t - 1.0 / 120.0 - 1e-6 and e["t"] < exp_t + 1.0 / 60.0, "disparado en su frame")
		if e["event"].beat_offset == 0.0:
			starts[e["bar"]] = starts.get(e["bar"], 0) + 1
	for b in [0, 1, 2, 3, 199]:
		check(starts.get(b, 0) == 3, "compás %d: los 3 instrumentos empiezan juntos en el beat %d" % [b + 1, b * 4])
	check(worst < 1e-6, "error temporal acumulado %.9f s" % worst)
	free_player(mp)

# ------------------------------------------------------------------ ALEATORIZACIÓN
func test_base_sequence() -> void:
	print("- Secuencia base (aleatorización desactivada)")
	var mp := new_player()
	mp.set_random_phrases_enabled(false)
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		mp.set_instrument_randomization(id, true)   # sin el interruptor general no cuenta
	var ev := simulate(mp, 12 * 4 * 60.0 / 90.0)
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		var seq := phrases_by_bar(ev, id).slice(0, 10)
		check(seq == [0, 1, 2, 3, 0, 1, 2, 3, 0, 1], "%s sigue 1→2→3→4: %s" % [id, str(seq.map(func(x): return x + 1))])
	free_player(mp)

func run_random(seed_v: int, ids: Array, bars: int) -> Dictionary:
	var mp := new_player()
	mp.set_random_phrases_enabled(true)
	var i := 0
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		mp.set_instrument_randomization(id, ids.has(id))
		mp.tracks[id].rng.seed = seed_v + i * 7919
		i += 1
	var ev := simulate(mp, bars * 4 * 60.0 / 90.0)
	var r := {}
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		r[id] = phrases_by_bar(ev, id).slice(0, bars - 1)
	free_player(mp)
	return r

func test_seed_reproducible() -> void:
	print("- Semilla fija (123) → misma secuencia")
	var all := ["low_guzheng", "high_guzheng", "bongos"]
	var a := run_random(123, all, 24)
	var b := run_random(123, all, 24)
	var c := run_random(456, all, 24)
	check(a == b, "seed 123 reproducible")
	check(a != c, "otra semilla produce otra secuencia")
	for id in all:
		check(a[id][0] == 0, "%s: el compás 1 usa la frase 1" % id)
		var repeats := 0
		for k in range(1, a[id].size()):
			if a[id][k] == a[id][k - 1]:
				repeats += 1
		check(repeats == 0, "%s: sin repeticiones inmediatas (AVOID_IMMEDIATE_PHRASE_REPEAT)" % id)
	print("    seed 123 · grave %s" % str(a["low_guzheng"].slice(0, 8).map(func(x): return x + 1)))
	print("    seed 123 · agudo %s" % str(a["high_guzheng"].slice(0, 8).map(func(x): return x + 1)))
	print("    seed 123 · bongo %s" % str(a["bongos"].slice(0, 8).map(func(x): return x + 1)))

func test_independent_randomization() -> void:
	print("- Aleatorización por instrumento")
	var base := [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2]
	for only in ["low_guzheng", "high_guzheng", "bongos"]:
		var r := run_random(77, [only], 16)
		for id in r:
			if id == only:
				check(r[id] != base, "solo %s varía" % only)
			else:
				check(r[id] == base, "%s sigue la secuencia base cuando solo %s es aleatorio" % [id, only])

# ------------------------------------------------------------------ TEMPO DINÁMICO
func test_dynamic_tempo() -> void:
	print("- Tempo dinámico 90 → 120 → 70 → 100 (en mitad de compás)")
	var mp := new_player()
	mp.clock.bpm = 90.0
	var changes := [[5.3, 120.0], [13.1, 70.0], [21.7, 100.0]]
	var ev := simulate(mp, 30.0, changes)
	# Sin duplicados ni saltos: cada pista recorre sus eventos en orden exacto.
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		var t = mp.tracks[id]
		var got: Array = ev.filter(func(e): return e["track"].id == id).map(func(e): return [e["bar"], e["index"]])
		var expected: Array = []
		var last_bar: int = got[-1][0]
		for bar in range(0, last_bar):
			var ph = t.phrases[bar % 4]
			for i in ph.events.size():
				if not ph.events[i].is_rest():
					expected.append([bar, i])
		check(got.slice(0, expected.size()) == expected, "%s: %d eventos sin duplicar ni saltar" % [id, expected.size()])
	# Los tres instrumentos siguen empezando juntos cada compás.
	var by_bar := {}
	for e in ev:
		if e["track"].id != "water" and e["event"].beat_offset == 0.0:
			by_bar[e["bar"]] = by_bar.get(e["bar"], []) + [e["t"]]
	var aligned := true
	for b in by_bar:
		if by_bar[b].size() == 3 and (by_bar[b].max() - by_bar[b].min()) > 1e-9:
			aligned = false
	check(aligned, "inicios de compás alineados entre instrumentos tras cada cambio de BPM")
	# El orden temporal se respeta.
	var mono := true
	for k in range(1, ev.size()):
		if ev[k]["t"] < ev[k - 1]["t"]:
			mono = false
	check(mono, "eventos en orden temporal")
	check(is_equal_approx(mp.clock.bpm, 100.0), "BPM final 100")
	free_player(mp)

func test_toggle_random_midbar() -> void:
	print("- Activar aleatorización a mitad de compás → se aplica en el siguiente")
	var mp := new_player()
	mp.tracks["low_guzheng"].rng.seed = 5
	mp.set_instrument_randomization("low_guzheng", true)
	mp.start()
	var dt := 1.0 / 60.0
	var t := 0.0
	var ev: Array = []
	while t < 40.0:
		if mp.clock.beat_at(t) >= 6.0 and not mp.random_phrases:
			mp.set_random_phrases_enabled(true)   # compás 2, beat 3
		for e in mp.scheduler.update(t, dt, mp.random_phrases):
			ev.append(e)
		t += dt
	var seq := phrases_by_bar(ev, "low_guzheng")
	check(seq[0] == 0 and seq[1] == 1, "los compases 1 y 2 no cambian (frases 1, 2)")
	check(seq.slice(2, 12) != [2, 3, 0, 1, 2, 3, 0, 1, 2, 3], "desde el compás 3 varía")
	free_player(mp)

func test_pause_resume() -> void:
	print("- Pausa y reanudación")
	var mp := new_player()
	var ev := simulate(mp, 20.0, [], 5.5, 3.0)

	var keys := {}
	var dup := false
	for e in ev:
		var k: String = "%s-%d-%d" % [e["track"].id, e["bar"], e["index"]]
		if e["track"].id != "water" and keys.has(k):
			dup = true
		keys[k] = true
	check(not dup, "sin eventos duplicados tras reanudar")
	var gap := 0.0
	for k in range(1, ev.size()):
		gap = maxf(gap, ev[k]["t"] - ev[k - 1]["t"])
	check(gap >= 2.9, "silencio durante la pausa (hueco de %.2f s)" % gap)
	var low: Array = ev.filter(func(e): return e["track"].id == "low_guzheng").map(func(e): return [e["bar"], e["index"]])
	check(low.slice(0, 10) == [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [0, 8], [0, 9]], "la frase continúa donde quedó")
	free_player(mp)

func test_water_quantized() -> void:
	print("- Gotas cuantizadas al pulso (modo musical)")
	var mp := new_player()
	var ev := simulate(mp, 60.0)
	var drops: Array = ev.filter(func(e): return e["track"].id == "water")
	check(drops.size() > 5, "%d gotas en 60 s" % drops.size())
	var on_grid := drops.all(func(e): return absf(fposmod(e["beat"], CFG.WATER_DROP_GRID_BEATS)) < 1e-6 or absf(fposmod(e["beat"], CFG.WATER_DROP_GRID_BEATS) - CFG.WATER_DROP_GRID_BEATS) < 1e-6)
	check(on_grid, "todas las gotas caen en la rejilla de %.2f beats" % CFG.WATER_DROP_GRID_BEATS)
	free_player(mp)

func test_missing_sample() -> void:
	print("- Nota sin sample: aviso, sin detener la música")
	var mp := new_player()
	check(mp.guzheng.prepare("F#3") == "exact", "F#3 usa sample exacto")
	var r: String = mp.guzheng.prepare("G3")
	check(r.begins_with("transposed"), "G3 (no existe) se transpone como respaldo: %s" % r)
	check(mp.guzheng.prepare("C8") == "missing", "C8 inexistente → missing")
	free_player(mp)

# ------------------------------------------------------------------ CARGA
func test_load_10_minutes() -> void:
	print("- Carga: 10 minutos a 60 fps (con reproducción en el pool)")
	var mp := new_player()
	var children_before := _count_players(mp)
	var cache_before: int = mp.cache.size()
	mp.start()
	var dt := 1.0 / 60.0
	var t := 0.0
	var max_pending := 0
	var max_voices := 0
	var bpms := [90.0, 120.0, 70.0, 100.0]
	var k := 0
	while t < 600.0:
		if fmod(t, 60.0) < dt:
			mp.set_bpm(bpms[k % 4])
			mp.set_random_phrases_enabled(k % 2 == 1)
			k += 1
		mp.step(t, dt)
		max_pending = maxi(max_pending, mp.scheduler.pending.size())
		max_voices = maxi(max_voices, mp.active_voices())
		t += dt
	check(_count_players(mp) == children_before, "no se crean reproductores (%d fijos)" % children_before)
	check(max_voices <= CFG.MAX_TOTAL_MUSIC_VOICES, "voces activas ≤ %d (máx %d)" % [CFG.MAX_TOTAL_MUSIC_VOICES, max_voices])
	check(max_pending <= 16, "ventana del scheduler acotada (máx %d eventos)" % max_pending)
	check(mp.cache.size() == cache_before, "caché estable (%d samples)" % cache_before)
	check(mp.scheduler.fired_total > 2000, "%d eventos reproducidos" % mp.scheduler.fired_total)
	print("    eventos %d · voces máx %d · ventana máx %d · robos %d · descartes por presupuesto %d" % [mp.scheduler.fired_total, max_voices, max_pending, _stolen(mp), mp.budget_drops])
	free_player(mp)

func _count_players(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch is AudioStreamPlayer:
			c += 1
		c += _count_players(ch)
	return c

func _stolen(mp: Node) -> int:
	var s := 0
	for p in mp.pools.values():
		s += p.stolen
	return s
