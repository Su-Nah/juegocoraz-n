## Reproducción en TIEMPO REAL (30 s) con cambios de BPM y aleatorización a
## mitad de la prueba. Informa voces activas, robos, reloj usado y deriva.
##   godot --headless -s res://tests/MusicRealtime.gd
extends SceneTree

const MusicPlayerScript := preload("res://scripts/music/MusicPlayer.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var mp: Node = MusicPlayerScript.new()
	root.add_child(mp)
	await process_frame
	# REC=/ruta.wav graba la mezcla real de Godot para analizarla.
	var rec_path := OS.get_environment("REC")
	var rec: AudioEffectRecord = null
	if rec_path != "":
		rec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, rec)
		rec.set_recording_active(true)
	var only := OS.get_environment("ONLY")
	if only != "":
		for id in mp.tracks:
			mp.set_instrument_enabled(id, id == only)
	mp.start()
	var t0 := Time.get_ticks_msec()
	var max_voices := 0
	var sec := 0
	var dur := int(OS.get_environment("DUR")) if OS.get_environment("DUR") != "" else 30000
	while Time.get_ticks_msec() - t0 < dur:
		await process_frame
		max_voices = maxi(max_voices, mp.active_voices())
		var s := int((Time.get_ticks_msec() - t0) / 1000)
		if s != sec:
			sec = s
			if s == 10 and OS.get_environment("FIXED") == "":
				mp.set_bpm(120.0)
			if s == 15 and OS.get_environment("FIXED") == "":
				mp.set_random_phrases_enabled(true)
				for id in ["low_guzheng", "high_guzheng", "bongos"]:
					mp.set_instrument_randomization(id, true)
			if s == 20 and OS.get_environment("FIXED") == "":
				mp.set_bpm(70.0)
			if s % 5 == 0 and (dur <= 60000 or s % 30 == 0):
				print("t=%3ds  mem %.2f MB  %s" % [s, OS.get_static_memory_usage() / 1048576.0, mp.debug_text()])
			if dur > 60000 and s > 30 and s % 40 == 0:
				mp.set_bpm([80.0, 110.0, 95.0, 130.0][(s / 40) % 4])
	if rec:
		rec.set_recording_active(false)
		rec.get_recording().save_to_wav(rec_path)
		print("GRABADO ", rec_path, " t0_musical=", mp.clock.time_at(0.0))
	var stolen := 0
	for p in mp.pools.values():
		stolen += p.stolen
	print("RESULTADO voces máx %d · robos %d · descartes presupuesto %d · eventos %d · ventana máx %d" % [max_voices, stolen, mp.budget_drops, mp.scheduler.fired_total, mp.scheduler.max_pending_seen])
	quit()
