## Proveedor SIMULADO. Solo para comprobar la interfaz sin hardware.
## Completamente independiente del proveedor Bluetooth.
extends "res://scripts/providers/HeartRateProvider.gd"

## Secuencia de prueba rápida para desarrollo (no espera a la fisiología real).
const TEST_SEQUENCE := [60, 70, 80, 90, 110, 130, 100, 85, 70]

var target_bpm := 72
var jitter := 0                 # ±BPM de ruido por lectura (para probar la tolerancia del filtro)
var _timer: Timer
var _seq_timer: Timer
var _running := false
var _sequence: Array = []
var _seq_index := 0

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(func(): _deliver_bpm(target_bpm + (randi_range(-jitter, jitter) if jitter > 0 else 0)))
	add_child(_timer)
	_seq_timer = Timer.new()
	_seq_timer.timeout.connect(_next_in_sequence)
	add_child(_seq_timer)

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
	_seq_timer.stop()
	last_bpm = -1
	status_changed.emit("disconnected")
	log_message.emit("[SIMULADOR] detenido")

func get_connection_status() -> String:
	return "connected" if _running else "disconnected"

## Recorre valores (p. ej. TEST_SEQUENCE) cambiando cada step_seconds.
func play_sequence(values: Array = TEST_SEQUENCE, step_seconds: float = 8.0) -> void:
	if not _running:
		connect_device()
	_sequence = values.duplicate()
	_seq_index = 0
	target_bpm = int(_sequence[0])
	_seq_timer.start(step_seconds)
	log_message.emit("[SIMULADOR] secuencia %s cada %.0f s" % [str(_sequence), step_seconds])

func stop_sequence() -> void:
	_seq_timer.stop()

func is_playing_sequence() -> bool:
	return not _seq_timer.is_stopped()

func _next_in_sequence() -> void:
	_seq_index += 1
	if _seq_index >= _sequence.size():
		_seq_timer.stop()
		return
	target_bpm = int(_sequence[_seq_index])
