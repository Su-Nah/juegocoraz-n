## Prueba automática de humo (headless): juega la vertical slice completa a 10x
## con el simulador y un "bot" sencillo. Uso:
##   godot --headless res://tests/SmokeTest.tscn
extends Node

const GameScene := preload("res://Game.tscn")
var game: Node
var seen := {}
var _bot_t := 0.0
var _seq := [70, 72, 74, 80, 88, 95, 102, 110, 115, 112, 104, 96, 88, 80, 76, 74, 74, 80, 90, 100, 108, 100, 90, 80, 75]

func _ready() -> void:
	Engine.time_scale = 10.0
	game = GameScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game._use_simulator()
	await get_tree().create_timer(3.0).timeout
	game._start_baseline()
	game.director.phase_changed.connect(func(i, ph): print("FASE ", i, " ", ph["name"], "  physio_lvl=", Physio.activation_level, " pressure=", game.director.pressure_level))
	game.director.challenge_raised.connect(func(t): seen["challenge"] = true)
	game.director.protection_changed.connect(func(a): if a: seen["protect"] = true)
	Physio.recovery_started.connect(func(): seen["recovery"] = true)
	Physio.baseline_ready.connect(func(b):
		print("BASELINE ", b, " sd ", Physio.baseline_sd)
		HeartRate.sim.play_sequence(_seq, 15.0))

var _shot_t := 0.0
var _shot_n := 0

## SHOTS=dir guarda capturas (requiere ejecutar con pantalla, p.ej. xvfb-run).
func _shots(dt: float) -> void:
	var dir := OS.get_environment("SHOTS")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	_shot_t += dt
	if _shot_t >= 30.0 or (game.mode == game.Mode.RESULTS and not seen.has("shot_results")):
		if game.mode == game.Mode.RESULTS:
			seen["shot_results"] = true
		_shot_t = 0.0
		_shot_n += 1
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, _shot_n])

func _process(dt: float) -> void:
	if game == null:
		return
	_shots(dt)
	if game.mode == game.Mode.RESULTS and not seen.has("done") and (OS.get_environment("SHOTS") == "" or seen.has("shot_results")):
		seen["done"] = true
		print("RESULTADOS ", game.stability.stats)
		print("VISTO ", seen.keys())
		var ok := seen.has("knock") and seen.has("fu") and seen.has("recovery") and seen.has("challenge") and seen.has("let_go")
		print("SMOKE ", "OK" if ok else "FALTA ALGO")
		get_tree().quit(0 if ok else 1)
		return
	if game.mode != game.Mode.PLAY:
		return
	for c in game.seats:
		if c == null:
			continue
		if c.is_urgent():
			seen["fu"] = true
		if c._knock_phase == "done":
			seen["knock"] = true
	if game.stability.stats["let_go"] > 0:
		seen["let_go"] = true
	_bot_t += dt
	if _bot_t < 0.7:
		return
	_bot_t = 0.0
	_bot_step()


func _bot_step() -> void:
	var k = game.kitchen
	# 1) recoger objetos caídos
	for o in game.objects:
		if o.is_on_floor():
			game.click_at(o.global_position)
			return
	# 2) a veces pausa / deja ir
	if randf() < 0.04:
		game._on_pause_pressed()
		return
	var waiting := []
	for c in game.seats:
		if c != null and c.state == "waiting":
			waiting.append(c)
	if waiting.size() >= 2 and (randf() < 0.15 or game.stability.stats["let_go"] == 0):
		var c0 = waiting[0]
		game.click_at(c0.global_position + Vector2(0, 28))
		return
	# 3) entregar
	for c in waiting:
		for item in k.hand:
			if c.order.has(item):
				game.click_at(c.global_position + Vector2(0, -80))
				return
	if k.hand.size() >= 2:
		game.click_at(k.HAND_POS)
		return
	# 4) recoger listos / empezar preparaciones necesarias
	for c in waiting:
		for item in c.order:
			var i = k.STATIONS.find(item)
			if k.progress[i] >= 1.0 or k.progress[i] < 0.0:
				game.click_at(Vector2(k.STATION_X[i], k.STATION_Y))
				return
