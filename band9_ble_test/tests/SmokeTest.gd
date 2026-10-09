## Prueba automática de humo: juega "Gatos en la barra" completo a 10x con el
## simulador y un bot que hace dangos (toques y arrastres), se equivoca a veces
## (y usa el bote), toca la campanilla y deja que algunos gatos se vayan.
##   godot --headless res://tests/SmokeTest.tscn
##   SHOTS=/ruta xvfb-run godot res://tests/SmokeTest.tscn   (con capturas)
extends Node

const GameScene := preload("res://Game.tscn")
const DangoData := preload("res://scripts/core/DangoData.gd")

var game: Node
var seen := {}
var _bot_t := 0.0
var _shot_t := 0.0
var _shot_n := 0
var _seq := [70, 72, 74, 80, 88, 95, 102, 110, 115, 112, 104, 96, 88, 80, 76, 74, 74, 80, 90, 100, 108, 100, 90, 80, 75, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74, 74]

func _ready() -> void:
	Engine.time_scale = 10.0
	game = GameScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game._use_simulator()
	await get_tree().create_timer(3.0).timeout
	_shot()
	game._start_ritual()
	game.director.phase_changed.connect(func(i, ph): print("FASE ", i, " ", ph["name"], "  estado=", Physio.state_name(), " presion=", game.director.pressure_level))
	game.director.challenge_raised.connect(func(_t): seen["reto"] = true)
	game.director.protection_changed.connect(func(a): if a: seen["proteccion"] = true)
	Physio.recovery_started.connect(func(): seen["recuperacion"] = true)
	Physio.baseline_ready.connect(func(b):
		print("BASELINE ", snappedf(b, 0.1), " (ritual servido: ", game._ritual_served, ")")
		seen["ritual"] = game._ritual_served > 0
		HeartRate.sim.play_sequence(_seq, 15.0))
	game.manos.descartado.connect(func(): seen["bote"] = true)
	game.manos.entregado.connect(func(_c): seen["entrega"] = true)
	game.clientela.se_fue.connect(func(_c): seen["se_fue"] = true)

func _shot() -> void:
	var dir := OS.get_environment("SHOTS")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	_shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, _shot_n])

func _process(dt: float) -> void:
	if game == null:
		return
	_shot_t += dt
	if _shot_t >= 25.0:
		_shot_t = 0.0
		_shot()
	if game.mode == game.Mode.RESULTS and not seen.has("done"):
		seen["done"] = true
		_shot()
		print("RESULTADOS ", game.stability.stats)
		print("VISTO ", seen.keys())
		var mp = game.music.music
		print("MÚSICA ", mp.debug_text(), " · eventos ", mp.scheduler.fired_total, " · buses ", AudioServer.bus_count)
		seen["musica"] = mp.scheduler.fired_total > 50 and AudioServer.get_bus_index("Music") >= 0
		var need := ["ritual", "entrega", "bote", "travieso", "falsa_urgencia", "recuperacion", "reto", "se_fue", "musica"]
		var missing := need.filter(func(k): return not seen.has(k) or not seen[k])
		print("SMOKE ", "OK" if missing.is_empty() else "FALTA " + str(missing))
		get_tree().quit(0 if missing.is_empty() else 1)
		return
	for c in game.clientela.cats():
		if c.is_urgent():
			seen["falsa_urgencia"] = true
		if c._knock_phase == "done":
			seen["travieso"] = true
	if game.mode != game.Mode.PLAY and game.mode != game.Mode.RITUAL:
		return
	_bot_t += dt
	if _bot_t < 0.8:
		return
	_bot_t = 0.0
	_bot_step()

func _bot_step() -> void:
	var m = game.manos
	var b = game.bandeja
	if game.stability.paused:
		return
	if randf() < 0.02:
		game.tap_at(game.campanilla.global_position + Vector2(0, 75))   # regulación
		return
	# En la fase de Presión, si aún ningún gato se ha ido, el bot deja esperar
	# (comprueba que irse no es un castigo y que el juego sigue).
	if game.mode == game.Mode.PLAY and game.director.phase_index == 2 and not seen.has("se_fue"):
		return
	var target: Node2D = null
	if game.companero.is_active():
		target = game.companero
	else:
		var w: Array = game.clientela.waiting()
		if w.size() > 2 and randf() < 0.5:
			return                       # a veces no reacciona a todo
		for c in w:
			if not c.is_urgent():
				target = c
				break
	if target == null:
		return
	var order: Dictionary = target.order
	var d: Dictionary = b.data()
	var n := DangoData.ball_count(d)
	for i in n:
		if d[DangoData.SLOTS[i]] != order[DangoData.SLOTS[i]]:
			game.tap_at(game.bote.global_position)   # descartar y seguir
			return
	if d["sauce"] and not order["sauce"]:
		game.tap_at(game.bote.global_position)
		return
	if n < 3:
		var want: String = order[DangoData.SLOTS[n]]
		if randf() < 0.06:
			want = DangoData.COLORS.pick_random()     # error humano
		_take(want)
	elif order["sauce"] and not d["sauce"]:
		_take("salsa")
	elif randf() < 0.5:
		game.tap_at(b.global_position + Vector2(0, -40))
	else:
		# arrastre real: bandeja → gato
		game.press_at(b.global_position + Vector2(0, -40))
		m.move(target.global_position + Vector2(0, -60))
		m.release(target.global_position + Vector2(0, -60))

func _take(id: String) -> void:
	for ing in game.ingredientes:
		if ing.ingredient_id == id:
			if ing.is_on_floor():
				game.tap_at(ing.get_node("Visual").global_position)
			elif ing.usable():
				if randf() < 0.5:
					game.tap_at(ing.global_position + Vector2(0, -30))
				else:
					game.press_at(ing.global_position + Vector2(0, -30))
					game.manos.move(game.bandeja.next_slot_global())
					game.manos.release(game.bandeja.next_slot_global())
			return
