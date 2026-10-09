## Reproductor de la pieza dinámica (Guzheng grave + Guzheng agudo + Bongoes,
## 4 frases cada uno, 4/4) y de la capa de gotas sincronizadas.
##
##                 MusicClock (único)
##                      │
##        ┌─────────────┼─────────────┬─────────┐
##   Guzheng grave  Guzheng agudo  Bongoes   Gotas
##        └─────────────┴──── MusicScheduler (ventana móvil) ──┘
##                      │
##        AudioSampleCache · AudioVoicePool (prioridades) · bus "Music"
##
## API: start() stop() pause() resume() set_bpm() set_random_phrases_enabled()
##      set_instrument_randomization() set_instrument_gain() get_current_bar/beat()
extends Node

const CFG := preload("res://scripts/music/MusicConfig.gd")
const Song := preload("res://scripts/music/SongData.gd")
const MT := preload("res://scripts/music/MusicTypes.gd")
const Clock := preload("res://scripts/music/MusicClock.gd")
const Scheduler := preload("res://scripts/music/MusicScheduler.gd")
const Cache := preload("res://scripts/music/AudioSampleCache.gd")
const Pool := preload("res://scripts/music/AudioVoicePool.gd")
const GuzhengPlayer := preload("res://scripts/music/GuzhengNotePlayer.gd")
const Variation := preload("res://scripts/music/RandomAudioVariationPlayer.gd")

const BUS := "Music"

var clock := Clock.new()
var scheduler := Scheduler.new()
var cache := Cache.new()
var guzheng: RefCounted
var tracks := {}                 # id -> MusicTrack / WaterDropTrack
var pools := {}                  # id -> AudioVoicePool
var water_variation: RefCounted
var random_phrases := CFG.ENABLE_RANDOM_PHRASES
var debug := CFG.MUSIC_DEBUG
var validation: Array = []       # líneas del informe de validación
var budget_drops := 0

# Reloj de audio: un reproductor silencioso en bucle; su posición la avanza el
# mezclador de Godot (no _process). Si el driver no avanza (p. ej. --headless con
# driver Dummy) se usa el reloj del sistema.
const CLOCK_LOOP := 4.0
var _clock_player: AudioStreamPlayer
var _loops := 0
var _last_pos := 0.0
var _last_now := 0.0
var _ticks_origin := 0
var _use_ticks := false
var _audio_probe_t := 0.0
var _manual := false
var _manual_now := 0.0
var _last_bar := -1

func _ready() -> void:
	ensure_built()

## Construye pistas, pools y caché (una sola vez). Se llama sola en _ready.
func ensure_built() -> void:
	if not tracks.is_empty():
		return
	_build()
	_setup_audio_clock()
	validate_song()

func _build() -> void:
	var seed_base: int = CFG.RANDOM_SEED
	var i := 0
	for inst in Song.INSTRUMENTS:
		var t := MT.MusicTrack.new()
		t.id = inst["id"]
		t.name = inst["name"]
		t.kind = inst["kind"]
		t.priority = inst["priority"]
		t.beats_per_bar = CFG.BEATS_PER_BAR
		t.avoid_repeat = CFG.AVOID_IMMEDIATE_PHRASE_REPEAT
		var rows: Array = inst["phrases"]
		for p in rows.size():
			t.phrases.append(MT.MusicPhrase.from_rows(p, rows[p], float(CFG.BEATS_PER_BAR), t.name))
		if seed_base != 0:
			t.rng.seed = seed_base + i * 7919
		else:
			t.rng.randomize()
		match t.id:
			"low_guzheng":
				t.randomize = CFG.RANDOMIZE_LOW_GUZHENG
				t.volume_db = CFG.LOW_GUZHENG_VOLUME_DB
				t.timing_variation_beats = CFG.GUZHENG_TIMING_VARIATION_BEATS
			"high_guzheng":
				t.randomize = CFG.RANDOMIZE_HIGH_GUZHENG
				t.volume_db = CFG.HIGH_GUZHENG_VOLUME_DB
				t.timing_variation_beats = CFG.GUZHENG_TIMING_VARIATION_BEATS
			"bongos":
				t.randomize = CFG.RANDOMIZE_BONGOS
				t.volume_db = CFG.BONGO_VOLUME_DB
		tracks[t.id] = t
		scheduler.tracks.append(t)
		i += 1
	var w := MT.WaterDropTrack.new()
	w.enabled = CFG.ENABLE_RANDOM_WATER_DROPS
	w.mode = CFG.WATER_DROP_MODE
	w.grid = CFG.WATER_DROP_GRID_BEATS
	w.min_s = CFG.WATER_DROP_MIN_INTERVAL
	w.max_s = CFG.WATER_DROP_MAX_INTERVAL
	w.volume_db = CFG.WATER_DROP_VOLUME_DB
	if seed_base != 0:
		w.rng.seed = seed_base + 99991
	else:
		w.rng.randomize()
	tracks["water"] = w
	scheduler.tracks.append(w)
	scheduler.clock = clock
	scheduler.lookahead = CFG.SCHEDULE_AHEAD_SECONDS
	clock.bpm = CFG.BPM
	clock.beats_per_bar = CFG.BEATS_PER_BAR
	w.bpm = CFG.BPM
	# Carga previa (fuera del momento crítico).
	guzheng = GuzhengPlayer.new(cache, CFG.GUZHENG_DIR)
	cache.preload_paths(CFG.BONGO_SAMPLES.values())
	water_variation = Variation.new(cache, CFG.VARIATIONS["water"], 0.0, 0.94, 1.06)
	var bus := BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"
	_add_pool("low_guzheng", CFG.MAX_LOW_GUZHENG_VOICES, bus, 3)
	_add_pool("high_guzheng", CFG.MAX_HIGH_GUZHENG_VOICES, bus, 3)
	_add_pool("bongos", CFG.MAX_BONGO_VOICES, bus, 2)
	_add_pool("water", CFG.MAX_WATER_VOICES, bus, 1)

func _add_pool(id: String, n: int, bus: String, prio: int) -> void:
	var p := Pool.new()
	p.name = "Voces_" + id
	add_child(p)
	p.setup(n, bus, prio)
	pools[id] = p

# ------------------------------------------------------------------ VALIDACIÓN
## Comprueba duraciones de todas las frases y que cada nota/sample exista.
func validate_song() -> Array:
	validation.clear()
	var ok := true
	for id in ["low_guzheng", "high_guzheng", "bongos"]:
		var t = tracks[id]
		for ph in t.phrases:
			var raw: float = ph.raw_duration()
			var mark := "✓" if absf(raw - CFG.BEATS_PER_BAR) < MT.EPS else "⚠"
			validation.append("%s frase %d = %.3f beats %s" % [t.name, ph.id + 1, raw, mark])
			if ph.warning != "":
				push_warning("[Música] " + ph.warning)
				ok = false
			for e in ph.events:
				if e.is_rest():
					continue
				if t.kind == "guzheng":
					var r: String = guzheng.prepare(e.note)
					if r != "exact":
						validation.append("  %s → %s" % [e.note, r])
				elif not cache.has(CFG.BONGO_SAMPLES.get(e.note, "")):
					push_warning("Missing bongo sample: %s" % e.note)
					validation.append("  %s → missing" % e.note)
	var rep: Dictionary = guzheng.report()
	var exact := rep.values().count("exact")
	validation.append("Guzheng: %d notas con sample exacto, %d transpuestas, %d ausentes" % [exact, rep.values().filter(func(v): return String(v).begins_with("transposed")).size(), rep.values().count("missing")])
	if debug:
		print("[Música] Validación de la canción:\n  " + "\n  ".join(validation))
	elif not ok:
		print("[Música] Validación con avisos (MUSIC_DEBUG = true para el detalle).")
	return validation

# ------------------------------------------------------------------ RELOJ DE AUDIO
func _setup_audio_clock() -> void:
	var silent := AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_8_BITS
	silent.mix_rate = 11025
	silent.data = PackedByteArray()
	silent.data.resize(int(CLOCK_LOOP * 11025))
	silent.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silent.loop_end = int(CLOCK_LOOP * 11025)
	_clock_player = AudioStreamPlayer.new()
	_clock_player.stream = silent
	_clock_player.volume_db = -80.0
	# Siempre por el mezclador de Godot (en Web el modo "sample" no actualizaría la posición).
	_clock_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_clock_player)
	_ticks_origin = Time.get_ticks_usec()

func now() -> float:
	if _manual:
		return _manual_now
	var t: float
	if _use_ticks or not _clock_player.playing:
		t = (Time.get_ticks_usec() - _ticks_origin) / 1000000.0
	else:
		var pos := _clock_player.get_playback_position()
		if pos < _last_pos - CLOCK_LOOP * 0.5:
			_loops += 1
		_last_pos = pos
		t = _loops * CLOCK_LOOP + pos + AudioServer.get_time_since_last_mix()
	_last_now = maxf(_last_now, t)   # nunca hacia atrás
	return _last_now

## Para pruebas: tiempo controlado manualmente (sin audio real).
func use_manual_time(on: bool) -> void:
	_manual = on

# ------------------------------------------------------------------ API
func start() -> void:
	ensure_built()
	if clock.running:
		return
	scheduler.reset()
	_last_bar = -1
	if not _manual:
		_clock_player.play()
		_loops = 0
		_last_pos = 0.0
		_last_now = 0.0
		_ticks_origin = Time.get_ticks_usec()
		_audio_probe_t = 0.0
	clock.start(now() + 0.05)   # pequeño margen para el primer golpe

func stop() -> void:
	clock.stop()
	scheduler.reset()
	for p in pools.values():
		p.stop_all()
	if _clock_player:
		_clock_player.stop()
	_last_bar = -1

func pause() -> void:
	clock.pause(now())

func resume() -> void:
	clock.resume(now())

func is_playing() -> bool:
	return clock.running and not clock.paused

func set_bpm(bpm: float) -> void:
	clock.set_bpm(bpm, now())
	tracks["water"].bpm = clock.bpm

func get_bpm() -> float:
	return clock.bpm

## Se aplica en el SIGUIENTE compás (la frase en curso no se corta).
func set_random_phrases_enabled(on: bool) -> void:
	random_phrases = on

func set_instrument_randomization(id: String, on: bool) -> void:
	if tracks.has(id) and tracks[id] is MT.MusicTrack:
		tracks[id].randomize = on

func set_instrument_enabled(id: String, on: bool) -> void:
	if tracks.has(id):
		tracks[id].enabled = on

## Mezcla adaptativa 0..1 (la usa MusicLayers según el estado del juego).
func set_instrument_gain(id: String, g: float) -> void:
	if tracks.has(id):
		tracks[id].gain = clampf(g, 0.0, 1.0)

func get_current_bar() -> int:
	return clock.bar_at(now()) + 1           # compases desde 1 (para leer)

func get_current_beat() -> float:
	return clock.beat_in_bar(now()) + 1.0    # 1.0 … 4.999

func current_phrase(id: String) -> int:
	return tracks[id].phrase_for_bar(clock.bar_at(now())) + 1

# ------------------------------------------------------------------ BUCLE
func _process(dt: float) -> void:
	if _manual or not clock.running:
		return
	_probe_audio_clock(dt)
	step(now(), dt)

## El driver de audio no avanza (headless/Dummy, contexto Web suspendido…):
## tras 1 s sin movimiento se usa el reloj del sistema.
func _probe_audio_clock(dt: float) -> void:
	if _use_ticks or not _clock_player.playing:
		return
	_audio_probe_t += dt
	if _audio_probe_t > 1.0 and _loops == 0 and _clock_player.get_playback_position() < 0.5:
		# Cambia de fuente de tiempo CONSERVANDO la posición musical
		# (sin reiniciar frases ni repetir eventos ya programados).
		var beat := clock.beat_at(now())
		_use_ticks = true
		_last_now = 0.0
		_ticks_origin = Time.get_ticks_usec()
		clock.start(now(), beat)
		if debug:
			print("[Música] El reloj de audio no avanza: se usa el reloj del sistema.")

func step(t_now: float, dt: float) -> void:
	if _manual:
		_manual_now = t_now
	var fired: Array = scheduler.update(t_now, dt, random_phrases)
	for e in fired:
		_play_event(e, t_now)
	if debug:
		var bar := clock.bar_at(t_now)
		if bar != _last_bar and bar >= 0:
			_last_bar = bar
			print("BAR %d  Low: frase %d · High: frase %d · Bongos: frase %d · voces %d/%d · BPM %.0f" % [bar + 1,
				tracks["low_guzheng"].phrase_for_bar(bar) + 1, tracks["high_guzheng"].phrase_for_bar(bar) + 1,
				tracks["bongos"].phrase_for_bar(bar) + 1, active_voices(), CFG.MAX_TOTAL_MUSIC_VOICES, clock.bpm])

func _play_event(e: Dictionary, t_now: float) -> void:
	var t = e["track"]
	if not t.enabled or t.gain <= 0.01:
		return
	var stream: AudioStream = null
	var pitch := 1.0
	var vol: float = t.volume_db + linear_to_db(t.gain)
	match t.kind:
		"guzheng":
			var r: Array = guzheng.resolve(e["event"].note)
			stream = r[0]
			pitch = r[1]
			var vel: float = e["event"].velocity
			if CFG.GUZHENG_VELOCITY_VARIATION > 0.0:
				vel = clampf(vel * (1.0 + randf_range(-CFG.GUZHENG_VELOCITY_VARIATION, CFG.GUZHENG_VELOCITY_VARIATION)), 0.05, 1.0)
			vol += linear_to_db(vel)
			if CFG.GUZHENG_PITCH_VARIATION > 0.0:
				pitch *= 1.0 + randf_range(-CFG.GUZHENG_PITCH_VARIATION, CFG.GUZHENG_PITCH_VARIATION)
		"bongo":
			stream = cache.get_stream(CFG.BONGO_SAMPLES.get(e["event"].note, ""))
			vol += linear_to_db(e["event"].velocity)
		"water":
			var pk: Array = water_variation.pick()
			if pk.is_empty():
				return
			stream = pk[0]
			pitch = pk[1]
	if stream == null:
		return
	var pool = pools[t.id]
	if not _admit(pool.priority):
		budget_drops += 1
		return
	# Compensa el retraso de disparo empezando el sample unos ms más adelante.
	var late: float = e.get("late", 0.0)
	var from := clampf(late, 0.0, 0.04) if late > 0.004 else 0.0
	pool.play(stream, vol, pitch, from, t_now)

## Presupuesto global: si se alcanza, se sacrifica primero la voz de menor prioridad
## (gotas → bongoes); el guzheng se preserva. Nunca hay voces ilimitadas.
func _admit(prio: int) -> bool:
	if active_voices() < CFG.MAX_TOTAL_MUSIC_VOICES:
		return true
	var order := pools.values()
	order.sort_custom(func(a, b): return a.priority < b.priority)
	for p in order:
		if p.priority < prio and p.steal_oldest():
			return true
	return false

func active_voices() -> int:
	var n := 0
	for p in pools.values():
		n += p.active_count()
	return n

func total_voices() -> int:
	var n := 0
	for p in pools.values():
		n += p.size()
	return n

func debug_text() -> String:
	return "BPM %.0f · compás %d · beat %.2f · frases L%d H%d B%d · voces %d/%d · eventos en ventana %d · samples %d · aleatorio %s · reloj %s" % [
		clock.bpm, get_current_bar(), get_current_beat(), current_phrase("low_guzheng"), current_phrase("high_guzheng"),
		current_phrase("bongos"), active_voices(), CFG.MAX_TOTAL_MUSIC_VOICES, scheduler.pending.size(), cache.size(),
		"sí" if random_phrases else "no", "sistema" if _use_ticks else "audio"]
