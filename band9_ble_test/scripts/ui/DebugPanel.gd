## Panel técnico de desarrollo (F3). NO aparece en el modo normal.
## Incluye controles del simulador: F1 secuencia de prueba, F2 detener, +/- BPM.
extends PanelContainer

var game: Node   # Game.gd
var _label: Label

func _ready() -> void:
	visible = false
	position = Vector2(10, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	add_child(_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F3:
			visible = not visible
		KEY_F1:
			HeartRate.sim.jitter = 1
			HeartRate.set_active_source("sim")
			HeartRate.sim.play_sequence()
		KEY_F2:
			HeartRate.sim.stop_sequence()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			HeartRate.sim.target_bpm = mini(200, HeartRate.sim.target_bpm + 5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			HeartRate.sim.target_bpm = maxi(40, HeartRate.sim.target_bpm - 5)

func _process(_dt: float) -> void:
	if not visible or game == null:
		return
	var d: Node = game.director
	var st: Node = game.stability
	var lines := PackedStringArray([
		"DEBUG (F3)   fuente: %s   señal: %s" % [HeartRate.source_label(), "ok" if Physio.signal_ok else "SIN SEÑAL"],
		"BPM actual: %.0f   filtrado: %.1f   baseline: %.1f (sd %.1f)" % [Physio.current_hr, Physio.filtered_hr, Physio.baseline_hr, Physio.baseline_sd],
		"activación relativa: %+.1f%%   continua: %.2f   nivel fisiológico: %d (%s)  %.0fs" % [Physio.relative_activation * 100.0, Physio.activation, Physio.activation_level, Physio.level_name(), Physio.time_in_current_state],
		"tendencia: %+.2f BPM/s   recuperando: %s (%.2f)   estab. fisiológica: %.2f" % [Physio.recovery_trend, "SÍ" if Physio.is_recovering else "no", Physio.recovery_strength, Physio.stability],
		"estabilidad jugador: %.2f   reposo: %.1fs   pausa: %s   frenético: %s" % [st.value, st.idle_time, "sí" if st.paused else "no", "SÍ" if st.is_frantic() else "no"],
		"fase: %s (%.0fs)   presión juego: %d   efectiva: %.2f   tier: %d   protección: %s" % [d.phase().get("name", "-"), d.phase_time, d.pressure_level, d.effective_pressure, d.tier, "SÍ" if d.protecting else "no"],
		"alivio: %.2f   intensidad mundo: %.2f   eventos activos: %d" % [d.relief, d.world_intensity, game.active_stimuli()],
		"música: %s   ganancias %s" % [game.music.current_layer_name(), str(game.music.gains.map(func(g): return snappedf(g, 0.01)))],
		"simulador: %d BPM %s   [F1 secuencia 60→130→70 · F2 parar · +/- 5 BPM]" % [HeartRate.sim.target_bpm, "(secuencia)" if HeartRate.sim.is_playing_sequence() else ""],
	])
	_label.text = "\n".join(lines)
