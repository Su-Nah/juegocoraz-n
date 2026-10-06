## Interfaz mínima de prueba: Huawei Band 9 → Web Bluetooth → JS → JavaScriptBridge → Godot.
## No conoce ninguna API JavaScript: solo usa los proveedores.
extends Control

const WebBridge := preload("res://scripts/providers/HeartRateWebBridge.gd")
const Simulator := preload("res://scripts/providers/SimulatorHeartRateProvider.gd")

const STATUS_TEXT := {
	"disconnected": ["● Desconectado", Color(0.6, 0.6, 0.6)],
	"scanning": ["● Buscando dispositivo...", Color(1.0, 0.85, 0.2)],
	"connecting": ["● Conectando...", Color(1.0, 0.6, 0.2)],
	"connected": ["● Conectado", Color(0.3, 0.9, 0.4)],
	"error": ["● Error", Color(1.0, 0.3, 0.3)],
}

var web: WebBridge
var sim: Simulator

var _status_lbl: Label
var _bpm_lbl: Label
var _last_lbl: Label
var _count_lbl: Label
var _diag_lbl: Label
var _log: TextEdit
var _sim_bpm_lbl: Label
var _sim_last_lbl: Label
var _sim_btn: Button
var _connect_btn: Button
var _explore_btn: Button
var _disconnect_btn: Button

func _ready() -> void:
	web = WebBridge.new()
	sim = Simulator.new()
	_build_ui()
	add_child(web)
	add_child(sim)

	web.heart_rate_received.connect(_on_real_bpm)
	web.status_changed.connect(_on_real_status)
	web.log_message.connect(_append_log)
	web.diagnostics_changed.connect(_on_diag)
	sim.heart_rate_received.connect(_on_sim_bpm)
	sim.log_message.connect(_append_log)

	_on_real_status("disconnected")
	_on_diag({})

func _process(_delta: float) -> void:
	_last_lbl.text = "Última actualización: " + _ago(web.last_update_msec)
	_sim_last_lbl.text = "Última actualización simulada: " + _ago(sim.last_update_msec)

func _ago(msec: int) -> String:
	if msec < 0:
		return "—"
	return "hace %.1f s" % ((Time.get_ticks_msec() - msec) / 1000.0)

# ---------------- REAL ----------------

func _on_connect_pressed() -> void:
	web.connect_device()

func _on_explore_pressed() -> void:
	web.connect_device_explore()

func _on_disconnect_pressed() -> void:
	web.disconnect_device()

func _on_real_bpm(bpm: int) -> void:
	_bpm_lbl.text = "%d BPM" % bpm
	_count_lbl.text = "Actualizaciones recibidas: %d" % web.updates_received

func _on_real_status(status: String) -> void:
	var s: Array = STATUS_TEXT.get(status, [status, Color.WHITE])
	_status_lbl.text = s[0]
	_status_lbl.add_theme_color_override("font_color", s[1])
	var busy := status in ["scanning", "connecting", "connected"]
	_connect_btn.disabled = busy
	_explore_btn.disabled = busy
	_disconnect_btn.disabled = not busy
	if status != "connected":
		_bpm_lbl.text = "— BPM"  # sin datos inventados
	_count_lbl.text = "Actualizaciones recibidas: %d" % web.updates_received

func _on_diag(d: Dictionary) -> void:
	var yn := func(v): return "Sí" if v else "No"
	var lines := PackedStringArray()
	if not web.has_js_bridge():
		lines.append("JavaScriptBridge: NO disponible (ejecutando en editor o sin shell personalizado)")
	lines.append("Web Bluetooth disponible: %s" % yn.call(d.get("web_bluetooth", false)))
	lines.append("Contexto seguro (HTTPS/localhost): %s" % yn.call(d.get("secure_context", false)))
	lines.append("Dentro de iframe: %s" % yn.call(d.get("in_iframe", false)))
	lines.append("Permissions Policy 'bluetooth': %s" % d.get("permissions_policy", "—"))
	lines.append("Navegador: %s" % d.get("browser", "—"))
	lines.append("Estado de conexión: %s" % d.get("status", web.get_connection_status()))
	lines.append("Dispositivo: %s" % _or_dash(d.get("device_name", "")))
	lines.append("Identificador (Web Bluetooth id): %s" % _or_dash(d.get("device_id", "")))
	lines.append("Servicio HR: %s" % d.get("hr_service", "0000180d-0000-1000-8000-00805f9b34fb"))
	lines.append("Característica HR: %s" % d.get("hr_characteristic", "00002a37-0000-1000-8000-00805f9b34fb"))
	lines.append("Notificaciones: %s" % d.get("notifications", "no"))
	lines.append("Actualizaciones recibidas (JS): %d" % int(d.get("updates", 0)))
	var bpm = d.get("bpm")
	lines.append("BPM actual (JS): %s" % ("—" if bpm == null or web.get_connection_status() != "connected" else str(int(bpm))))
	lines.append("Timestamp última actualización: %s" % _or_dash(d.get("last_update", "")))
	var services: Array = d.get("services", [])
	lines.append("Servicios descubiertos (%d):" % services.size())
	for s in services:
		lines.append("   • " + str(s))
	var chars: Array = d.get("characteristics", [])
	lines.append("Características descubiertas (%d):" % chars.size())
	for c in chars:
		lines.append("   • " + str(c))
	var err: String = d.get("last_error", "")
	lines.append("Último error: %s" % (("[%s] %s" % [d.get("last_error_code", ""), err]) if err != "" else "ninguno"))
	_diag_lbl.text = "\n".join(lines)

func _or_dash(v) -> String:
	return "—" if v == null or str(v) == "" else str(v)

# ---------------- SIMULADOR ----------------

func _on_sim_toggle() -> void:
	if sim.get_connection_status() == "connected":
		sim.disconnect_device()
		_sim_btn.text = "SIMULAR BPM"
		_sim_bpm_lbl.text = "— BPM (SIMULADO)"
	else:
		sim.connect_device()
		_sim_btn.text = "DETENER SIMULACIÓN"

func _on_sim_bpm(bpm: int) -> void:
	_sim_bpm_lbl.text = "%d BPM (SIMULADO) · %d actualizaciones" % [bpm, sim.updates_received]

func _append_log(text: String) -> void:
	_log.text += text + "\n"
	_log.scroll_vertical = _log.get_line_count()

# ---------------- UI ----------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	margin.add_child(cols)

	# Columna izquierda: datos reales + simulador
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)

	left.add_child(_label("HUAWEI BAND 9 — BLE TEST", 24))
	left.add_child(_label("Estado:", 14))
	_status_lbl = _label("● Desconectado", 20)
	left.add_child(_status_lbl)

	_connect_btn = _button("CONECTAR HUAWEI BAND 9", _on_connect_pressed)
	left.add_child(_connect_btn)
	_explore_btn = _button("Explorar todos los dispositivos (diagnóstico)", _on_explore_pressed)
	left.add_child(_explore_btn)

	left.add_child(_label("Frecuencia cardíaca — REAL (Band 9)", 14))
	_bpm_lbl = _label("— BPM", 56)
	_bpm_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	left.add_child(_bpm_lbl)
	_last_lbl = _label("Última actualización: —", 14)
	left.add_child(_last_lbl)
	_count_lbl = _label("Actualizaciones recibidas: 0", 14)
	left.add_child(_count_lbl)

	_disconnect_btn = _button("DESCONECTAR", _on_disconnect_pressed)
	left.add_child(_disconnect_btn)

	left.add_child(HSeparator.new())
	var sim_title := _label("SIMULADOR (datos FALSOS, solo prueba de interfaz)", 14)
	sim_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	left.add_child(sim_title)
	var sim_row := HBoxContainer.new()
	var spin := SpinBox.new()
	spin.min_value = 30
	spin.max_value = 220
	spin.value = sim.target_bpm
	spin.suffix = "BPM"
	spin.value_changed.connect(func(v): sim.target_bpm = int(v))
	sim_row.add_child(spin)
	_sim_btn = _button("SIMULAR BPM", _on_sim_toggle)
	sim_row.add_child(_sim_btn)
	left.add_child(sim_row)
	_sim_bpm_lbl = _label("— BPM (SIMULADO)", 22)
	_sim_bpm_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	left.add_child(_sim_bpm_lbl)
	_sim_last_lbl = _label("Última actualización simulada: —", 12)
	left.add_child(_sim_last_lbl)

	# Columna derecha: diagnóstico + log
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_label("DIAGNÓSTICO", 18))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_diag_lbl = _label("", 13)
	_diag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_diag_lbl)
	right.add_child(_label("Mensajes JavaScript / Bluetooth", 14))
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("font_size", 12)
	right.add_child(_log)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(cb)
	return b
