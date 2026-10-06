## Proveedor SIMULADO. Solo para comprobar la interfaz sin hardware.
## Completamente independiente del proveedor Bluetooth.
extends "res://scripts/providers/HeartRateProvider.gd"

var target_bpm := 72
var _timer: Timer
var _running := false

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(func(): _deliver_bpm(target_bpm))
	add_child(_timer)

func is_available() -> bool:
	return true

func connect_device() -> void:
	_running = true
	_timer.start()
	status_changed.emit("connected")
	log_message.emit("[SIMULADOR] iniciado (%d BPM)" % target_bpm)

func disconnect_device() -> void:
	_running = false
	_timer.stop()
	last_bpm = -1
	status_changed.emit("disconnected")
	log_message.emit("[SIMULADOR] detenido")

func get_connection_status() -> String:
	return "connected" if _running else "disconnected"
