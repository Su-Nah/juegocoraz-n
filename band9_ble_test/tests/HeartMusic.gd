## Comprueba que el corazón dirige la música (tempo y capas) en el juego real.
##   godot --headless res://tests/HeartMusic.tscn
extends Node

var game: Node
var t := 0.0
var phase := "ritual"
var log_t := 0.0

func _ready() -> void:
	Engine.time_scale = 4.0
	game = preload("res://Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game._use_simulator()
	HeartRate.sim.target_bpm = 70
	await get_tree().create_timer(2.0).timeout
	game._start_ritual()
	game.companero.order = {}            # el bot no juega: solo medimos música
	Physio.baseline_ready.connect(func(_b): phase = "calma")

func _process(dt: float) -> void:
	t += dt
	log_t += dt
	var ml = game.music
	if phase == "calma" and game.mode == game.Mode.PLAY:
		phase = "calma2"
		t = 0.0
	if phase.begins_with("calma") or phase == "sube" or phase == "baja":
		if phase == "calma2" and t > 12.0:
			phase = "sube"; t = 0.0; HeartRate.sim.target_bpm = 110
		elif phase == "sube" and t > 30.0:
			phase = "baja"; t = 0.0; HeartRate.sim.target_bpm = 70
		elif phase == "baja" and t > 30.0:
			print("FIN"); get_tree().quit()
	if log_t >= 3.0:
		log_t = 0.0
		print("%-7s t=%4.0fs HR %3d act %.2f h %.2f | BPM música %5.1f | grave %.2f agudo %.2f bongo %.2f tormenta %.2f" % [phase, t, HeartRate.sim.target_bpm, Physio.activation, ml.heart, ml.music.get_bpm(), ml._low_gain, ml.gains[1], ml.gains[2], ml.gains[4]])
