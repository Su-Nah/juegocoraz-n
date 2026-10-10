## Coach: la historia y el tutorial jugable.
##  RITUAL  A llegada · B el agua late contigo · C/D primer dango (demostraciones) ·
##          E el tempo sigue tu pulso · (fin cuando: 30 s de línea base + sin pedido activo)
##  JUEGO   F la demanda crece · G pausa y respiración · cierre.
## Las acciones aprendidas no vuelven a mostrar su demostración en la partida.
extends RefCounted

const C := preload("res://scripts/core/Config.gd")

var game: Node
var stage := "A"
var stage_t := 0.0
var learned := {}             # bola · salsa · entregar · bote · campanilla
var _said := {}
var skipped := false

func _init(p_game: Node) -> void:
	game = p_game

func reset() -> void:
	stage = "A"
	stage_t = 0.0
	_said = {}
	skipped = false
	# `learned` se conserva durante la sesión: no repetimos demos ya dominadas.

func learn(action: String) -> void:
	learned[action] = true

## Demos pendientes (true = todavía hay que mostrar la animación).
func demos() -> Dictionary:
	var d := {}
	for a in ["bola", "salsa", "entregar", "bote"]:
		d[a] = not learned.get(a, false)
	return d

func _go(s: String) -> void:
	stage = s
	stage_t = 0.0

# ------------------------------------------------------------------ RITUAL
func update_ritual(dt: float) -> void:
	stage_t += dt
	var ui = game.ui
	var mochi = game.companero
	match stage:
		"A":
			ui.guia("Llegas a la barra de Mochi. Aquí se preparan dangos para los gatos.")
			if stage_t > 5.0:
				_go("B")
		"B":
			var src: String = "tu pulso" if HeartRate.active_source == "web" else "el pulso SIMULADO"
			ui.guia("Escucha el agua: cada gota es un latido de %s. La música seguirá ese ritmo." % src)
			ui.resaltar_pulso(true)
			if stage_t > 7.0:
				ui.resaltar_pulso(false)
				mochi.pedir(preload("res://scripts/core/DangoData.gd").traditional(true))
				_go("C")
		"C":
			if not mochi.is_active():
				_go("E")
				return
			var step: String = game.tutorial.guiar(mochi.order, mochi, game.manos, demos())
			ui.guia(_texto_paso(step, mochi.order))
		"E":
			ui.guia("¡Bien! Ahora escucha: el tempo de la música es tu pulso. Si tu corazón se acelera, la barra también.")
			ui.resaltar_pulso(true)
			game.tutorial.ocultar()
			if stage_t > 7.0:
				ui.resaltar_pulso(false)
				_go("listo")
		"listo":
			# Practica tranquila hasta completar la línea base; nunca se corta un pedido.
			if mochi.is_active():
				var step2: String = game.tutorial.guiar(mochi.order, mochi, game.manos, demos())
				ui.guia(_texto_paso(step2, mochi.order))
			else:
				game.tutorial.ocultar()
				ui.guia("Preparando la barra… (midiendo tu pulso en reposo)")

## El ritual termina SOLO si: pasó el tiempo de línea base, el tutorial llegó al
## final (o se saltó) y NO hay un pedido en curso ni algo en la mano.
func ritual_done(baseline_time_ok: bool) -> bool:
	if not baseline_time_ok:
		return false
	if not (stage == "listo" or skipped):
		return false
	return not game.companero.is_active() and not game.manos.is_dragging()

## ¿Puede Mochi pedir otro dango de práctica? (no después del tiempo de línea base)
func may_order_more(baseline_time_ok: bool) -> bool:
	return not baseline_time_ok and not skipped

const NOMBRES := {"verde": "VERDE ▲", "blanca": "BLANCA ■", "rosa": "ROSA ●"}

func _texto_paso(step: String, order: Dictionary) -> String:
	var receta := "Mochi pide: abajo %s · centro %s · arriba %s%s." % [NOMBRES[order["lower"]], NOMBRES[order["middle"]], NOMBRES[order["upper"]], " · CON SALSA ≈" if order["sauce"] else " · sin salsa"]
	match step:
		"bote":
			return "No salió igual. Arrastra la bandeja al BOTE (o toca el bote) y empieza otro. Está bien."
		"bola":
			return receta + "\nArrastra la bola del cuenco hasta la bandeja (o toca el cuenco)."
		"salsa":
			return receta + "\nToca la olla para añadir la salsa."
		"entregar":
			return "¡Listo! Arrastra la bandeja hasta Mochi (o toca la bandeja)."
	return receta

# ------------------------------------------------------------------ JUEGO
func update_play(dt: float) -> void:
	stage_t += dt
	var ui = game.ui
	var d = game.director
	var waiting: int = game.clientela.active_count()
	if d.phase_index == 1 and not _said.has("F1"):
		_said["F1"] = true
		ui.guia("Llegan más gatos. Cada uno muestra su dango en el bocadillo.", 5.0)
	# G: la demanda supera lo que dos manos pueden atender.
	if not _said.has("G") and (d.phase_index >= 2 or waiting >= 3):
		_said["G"] = true
		ui.guia("Son más pedidos de los que caben en dos manos. No tienes que atenderlos todos.\nToca la CAMPANILLA para parar y respirar. El mundo sigue; tú eliges el ritmo.", 9.0)
	if _said.has("G") and not learned.get("campanilla", false) and stage_t < 30.0 + 9.0:
		game.tutorial.demo_click(game.campanilla.global_position + Vector2(0, 75))
	elif _said.has("G") and not _said.has("G_off"):
		_said["G_off"] = true
		game.tutorial.ocultar()
	if d.phase().get("id", "") == "cierre" and not _said.has("cierre"):
		_said["cierre"] = true
		ui.guia("La barra cierra. Los pedidos nunca se acaban: hoy elegiste cuáles atender.", 8.0)

func on_regulation() -> void:
	if not learned.get("campanilla", false):
		learned["campanilla"] = true
		game.tutorial.ocultar()
		game.ui.guia("Respira. Los gatos esperan, el agua sigue. Nada se rompe por parar.", 6.0)
