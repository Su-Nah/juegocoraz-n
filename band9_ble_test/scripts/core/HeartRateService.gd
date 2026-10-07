## Autoload "HeartRate". Dueño único de los proveedores de BPM.
## Web Bluetooth (Band 9) y Simulador son fuentes distintas del mismo contrato
## HeartRateProvider; el resto del juego solo escucha bpm_received.
## Nada de esto toca JavaScript: eso sigue encapsulado en HeartRateWebBridge.gd.
extends Node

signal bpm_received(bpm: int, source: String)
signal source_changed(source: String)

const WebBridge := preload("res://scripts/providers/HeartRateWebBridge.gd")
const Simulator := preload("res://scripts/providers/SimulatorHeartRateProvider.gd")

var web: WebBridge
var sim: Simulator
var active_source := "none"   # "web" | "sim" | "none"
var last_bpm := -1
var _last_msec := -1

func _ready() -> void:
	web = WebBridge.new()
	web.name = "WebBluetooth"
	add_child(web)
	sim = Simulator.new()
	sim.name = "Simulator"
	add_child(sim)
	web.heart_rate_received.connect(func(b: int): _on_bpm(b, "web"))
	sim.heart_rate_received.connect(func(b: int): _on_bpm(b, "sim"))

func set_active_source(source: String) -> void:
	if source == active_source:
		return
	active_source = source
	last_bpm = -1
	_last_msec = -1
	source_changed.emit(source)

## Datos reales de la Band 9 siempre tienen prioridad si llegan sin que se haya
## elegido explícitamente el simulador.
func _on_bpm(bpm: int, source: String) -> void:
	if active_source == "none":
		set_active_source(source)
	if source != active_source:
		return
	last_bpm = bpm
	_last_msec = Time.get_ticks_msec()
	bpm_received.emit(bpm, source)

func seconds_since_last() -> float:
	if _last_msec < 0:
		return INF
	return (Time.get_ticks_msec() - _last_msec) / 1000.0

func is_receiving() -> bool:
	return seconds_since_last() < 6.0

func source_label() -> String:
	match active_source:
		"web":
			return "Huawei Band 9 (real)"
		"sim":
			return "SIMULADOR"
	return "ninguna"
