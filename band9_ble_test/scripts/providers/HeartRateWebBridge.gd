## HeartRateWebBridge: proveedor REAL (Huawei Band 9 vía Web Bluetooth).
## Solo habla con window.HeartRateWebBridge (definido en web/shell.html)
## mediante JavaScriptBridge. No contiene ninguna API Bluetooth.
extends "res://scripts/providers/HeartRateProvider.gd"

signal diagnostics_changed(diag: Dictionary)

var _js: JavaScriptObject = null
var _status := "disconnected"
var diagnostics: Dictionary = {}
# Las referencias a los callbacks DEBEN mantenerse vivas o JS dejará de poder llamarlas.
var _cb_hr: JavaScriptObject
var _cb_status: JavaScriptObject
var _cb_log: JavaScriptObject
var _cb_diag: JavaScriptObject

func _ready() -> void:
	if not OS.has_feature("web"):
		log_message.emit("No es una exportación Web: JavaScriptBridge no disponible (normal en el editor).")
		return
	_js = JavaScriptBridge.get_interface("HeartRateWebBridge")
	if _js == null:
		log_message.emit("ERROR: window.HeartRateWebBridge no existe. ¿Se exportó con web/shell.html como Custom HTML Shell?")
		return
	_cb_hr = JavaScriptBridge.create_callback(_on_js_hr)
	_cb_status = JavaScriptBridge.create_callback(_on_js_status)
	_cb_log = JavaScriptBridge.create_callback(_on_js_log)
	_cb_diag = JavaScriptBridge.create_callback(_on_js_diag)
	_js.setCallbacks(_cb_hr, _cb_status, _cb_log, _cb_diag)

func has_js_bridge() -> bool:
	return _js != null

func is_available() -> bool:
	return _js != null and bool(_js.isAvailable())

## Debe llamarse directamente desde el handler del botón (activación de usuario).
func connect_device() -> void:
	_request(false)

## Modo diagnóstico: muestra TODOS los dispositivos BLE cercanos.
func connect_device_explore() -> void:
	_request(true)

func _request(explore_all: bool) -> void:
	if _js == null:
		log_message.emit("No se puede conectar: no hay bridge JavaScript.")
		return
	updates_received = 0
	last_bpm = -1
	last_update_msec = -1
	_js.connectDevice(explore_all)

func disconnect_device() -> void:
	if _js:
		_js.disconnectDevice()

func get_connection_status() -> String:
	return _status

func _on_js_hr(args: Array) -> void:
	_deliver_bpm(int(args[0]))

func _on_js_status(args: Array) -> void:
	_status = str(args[0])
	if _status != "connected":
		last_bpm = -1  # nunca mostrar un BPM viejo como si fuera actual
	status_changed.emit(_status)

func _on_js_log(args: Array) -> void:
	log_message.emit(str(args[0]))

func _on_js_diag(args: Array) -> void:
	var parsed = JSON.parse_string(str(args[0]))
	if parsed is Dictionary:
		diagnostics = parsed
		diagnostics_changed.emit(diagnostics)
