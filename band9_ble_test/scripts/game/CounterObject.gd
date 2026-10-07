## Objeto del mostrador que un gato puede derribar (taza, plato, limón).
## Mientras está en el suelo bloquea su estación (si tiene). Tras reponerlo
## hay un cooldown antes de que pueda volver a caer (evita repetición).
## La taza y el limón reutilizan sprites de Micheladas Nancy.
extends Node2D

signal fallen(obj: Node2D)
signal restored(obj: Node2D)

const C := preload("res://scripts/core/Config.gd")

var kind := "taza"
var blocks := ""            # id de estación que bloquea al caer ("te", "onigiri" o "")
var home := Vector2.ZERO
var state := "counter"      # counter · falling · floor
var cooldown := 0.0
var reserved := false       # un gato travieso ya lo eligió
var _tex: Texture2D
var _rot := 0.0
var _wobble := 0.0

func setup(p_kind: String, p_home: Vector2, p_blocks: String) -> void:
	kind = p_kind
	home = p_home
	blocks = p_blocks
	position = home
	match kind:
		"taza":
			_tex = load("res://assets/sprites/reused/vaso.png")
		"limon":
			_tex = load("res://assets/sprites/reused/limon.png")

func can_be_knocked() -> bool:
	return state == "counter" and cooldown <= 0.0

func is_on_floor() -> bool:
	return state == "floor"

func knock(dir: float) -> void:
	if state != "counter":
		return
	state = "falling"
	reserved = false
	var floor_pos := Vector2(home.x + dir * randf_range(30, 70), 585.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:x", floor_pos.x, 0.55)
	tw.tween_property(self, "position:y", floor_pos.y, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_rot", dir * randf_range(1.2, 1.9), 0.55)
	tw.chain().tween_callback(func():
		state = "floor"
		fallen.emit(self))

func restore() -> void:
	if state != "floor":
		return
	state = "counter"
	cooldown = C.OBJECT_COOLDOWN
	_rot = 0.0
	var tw := create_tween()
	tw.tween_property(self, "position", home, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	restored.emit(self)

func hit(p: Vector2) -> bool:
	return state == "floor" and p.distance_to(global_position) < 46.0

func _process(dt: float) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	_wobble += dt
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _rot, Vector2.ONE)
	match kind:
		"taza":
			if _tex:
				var h := 72.0
				var w := h * _tex.get_width() / _tex.get_height()
				draw_texture_rect(_tex, Rect2(-w / 2, -h, w, h), false)
		"limon":
			if _tex:
				var w2 := 46.0
				var h2 := w2 * _tex.get_height() / _tex.get_width()
				draw_texture_rect(_tex, Rect2(-w2 / 2, -h2, w2, h2), false)
		"plato":
			draw_set_transform(Vector2(0, -6), _rot, Vector2(1, 0.35))
			draw_circle(Vector2.ZERO, 30, Color(0.95, 0.95, 0.97))
			draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color(0.45, 0.6, 0.85), 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "floor":
		var a := 0.5 + 0.3 * sin(_wobble * 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-26, 40), "recoger", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.25, 0.25, a))
