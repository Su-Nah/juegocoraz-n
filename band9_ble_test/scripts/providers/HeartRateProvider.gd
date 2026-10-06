## Interfaz base común para cualquier fuente de BPM.
## Cada proveedor es independiente: los datos reales y simulados nunca se mezclan.
extends Node

signal heart_rate_received(bpm: int)
signal status_changed(status: String)
signal log_message(text: String)

const SOURCE_NAME := "base"

var updates_received := 0
var last_bpm := -1
var last_update_msec := -1

func is_available() -> bool:
	return false

func connect_device() -> void:
	pass

func disconnect_device() -> void:
	pass

func get_connection_status() -> String:
	return "disconnected"

func _deliver_bpm(bpm: int) -> void:
	updates_received += 1
	last_bpm = bpm
	last_update_msec = Time.get_ticks_msec()
	heart_rate_received.emit(bpm)
