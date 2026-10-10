## Pruebas P0/P1 en el juego real (simulador):
##  1) pulso 60 → tempo objetivo 60 · 2) basal 112 → tempo 112 · 3) 60→90→112 sin reiniciar
##  4) pérdida de señal: no hay lecturas nuevas · 5) el ritual no corta un pedido activo.
##   godot --headless res://tests/TempoFollow.tscn
extends Node

var game: Node
var fails := 0

func check(c: bool, m: String) -> void:
	print(("  ✓ " if c else "  ✗ FALLO: ") + m)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	Engine.time_scale = 4.0
	game = preload("res://Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var ml = game.music
	var mp = ml.music
	# ---- 2) basal ALTO: 112 en reposo
	game._use_simulator()
	HeartRate.sim.jitter = 0
	HeartRate.sim.target_bpm = 112
	await wait(3.0)
	game._start_ritual()
	await wait(8.0)
	print("ritual: pulso 112 · objetivo %.1f · tempo %.1f" % [ml.target_bpm(), mp.get_bpm()])
	check(absf(ml.target_bpm() - 112.0) < 1.0, "basal 112 → BPM musical objetivo 112 (no se trata como 'calma = lento')")
	check(absf(mp.get_bpm() - 112.0) < 2.0, "el tempo de la música llegó a 112")
	# ---- 5) 30 s con pedido activo: no se corta
	var mochi = game.companero
	while not mochi.is_active():
		await wait(0.5)
	game.coach.stage = "C"
	await wait(36.0)
	check(game.mode == game.Mode.RITUAL and mochi.is_active(), "tras 30 s el pedido de Mochi sigue activo y el ritual NO se corta (t=%.0f s)" % game._ritual_t)
	game.companero.receive(game.companero.order)   # se completa la entrega
	var t0 := 0.0
	while game.mode == game.Mode.RITUAL and t0 < 30.0:
		await wait(0.5)
		t0 += 0.5
	check(game.mode == game.Mode.PLAY, "al resolver el pedido, el juego avanza a la siguiente fase")
	check(not mochi.is_active(), "no se generan pedidos de práctica después de la línea base")
	# ---- 1) y 3) 60 → 90 → 112 sin reiniciar
	for bpm in [60, 90, 112]:
		var bar_before: int = mp.get_current_bar()
		var fired_before: int = mp.scheduler.fired_total
		HeartRate.sim.target_bpm = bpm
		await wait(6.0)
		print("pulso %d · objetivo %.1f · tempo %.1f · compás %d→%d" % [bpm, ml.target_bpm(), mp.get_bpm(), bar_before, mp.get_current_bar()])
		check(absf(ml.target_bpm() - bpm) < 1.0, "pulso %d → objetivo %d" % [bpm, bpm])
		check(absf(mp.get_bpm() - bpm) < 2.0, "tempo alcanzó %d" % bpm)
		check(mp.get_current_bar() >= bar_before and mp.scheduler.fired_total > fired_before, "la pieza continúa (no se reinicia)")
	# ---- 4) pérdida de señal
	var n_before: int = Physio.sample_count
	var hr_before: float = Physio.music_hr
	HeartRate.sim.disconnect_device()
	await wait(56.0)   # 14 s reales a 4x (el timeout de señal usa tiempo real)
	check(Physio.sample_count == n_before, "sin señal no entran lecturas nuevas (%d)" % Physio.sample_count)
	check(not Physio.signal_ok, "la señal se marca como perdida")
	check(absf(mp.get_bpm() - hr_before) < 2.0, "el tempo se mantiene en el último valor válido (%.1f)" % mp.get_bpm())
	print("RESULTADO: %s" % ("OK" if fails == 0 else "%d FALLOS" % fails))
	get_tree().quit(0 if fails == 0 else 1)
