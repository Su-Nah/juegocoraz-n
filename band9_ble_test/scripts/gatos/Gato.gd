## Gato cliente. Comportamiento en código; aspecto en Gato.tscn (sprites
## blancos teñidos con la paleta). Tipos:
##   normal · impaciente · travieso (tira un ingrediente real) · falsa_urgencia
##   (hace mucho ruido al llegar pero su pedido tiene tiempo de sobra).
## Irse NO es un castigo: solo un resultado.
extends Node2D

signal left(cat: Node2D, reason: String)          # served · patience · fu_calmed
signal knock_now(cat: Node2D, ing: Node2D)
signal meowed(urgent: bool)
signal fu_reacted(cat: Node2D)

const C := preload("res://scripts/core/Config.gd")
const DangoData := preload("res://scripts/core/DangoData.gd")

## Pares [color base, color de manchas]. Edítalos en el Inspector.
@export var paletas: Array[Color] = [
	Color(0.98, 0.96, 0.92), Color(0.96, 0.72, 0.5),
	Color(0.98, 0.74, 0.48), Color(1.0, 0.9, 0.74),
	Color(0.66, 0.68, 0.74), Color(0.86, 0.87, 0.9),
	Color(0.3, 0.29, 0.33), Color(0.5, 0.48, 0.52),
	Color(0.92, 0.87, 0.78), Color(0.42, 0.34, 0.3),
]

var kind := "normal"
var order: Dictionary = {}
var patience := 40.0
var patience_max := 40.0
var seat := -1
var seat_x := 0.0
var state := "arriving"      # arriving · waiting · leaving · resting
var urgent_t := 0.0          # >0 mientras dura el escándalo de falsa urgencia
var knock_target: Node2D = null

# Lo fija Game cada frame (estado abstracto del mundo, no BPM).
var activity := 0.0          # cat_activity 0..1
var tempo := 1.0
var calm := 0.5              # estabilidad del jugador
var impatience_scale := 1.0
var tray_ready := false      # hay un dango completo en la bandeja
var tray_pos := Vector2.ZERO
var highlighted := false     # el jugador arrastra un dango cerca

var _t := 0.0
var _state_t := 0.0
var _knock_phase := "none"   # none · wait · look · paw · done
var _knock_t := 0.0
var _meow_cd := 2.0
var _blink_t := 3.0
var _say_t := 0.0
var _purring := false
var _base_y := 0.0

@onready var pose: Node2D = $Pose
@onready var cabeza: Node2D = $Pose/Cabeza
@onready var cola: Node2D = $Pose/Cola
@onready var patas: Node2D = $Patas
@onready var pedido: Node2D = $Pedido
@onready var habla: Label = $Habla

func _ready() -> void:
	patas.visible = false
	habla.modulate.a = 0.0
	pedido.visible = false

func setup(p_kind: String, p_order: Dictionary, p_patience: float, p_seat: int) -> void:
	kind = p_kind
	order = p_order
	seat = p_seat
	seat_x = C.SEATS_X[p_seat]
	patience_max = p_patience * (0.65 if kind == "impaciente" else 1.0)
	if kind == "falsa_urgencia":
		patience_max *= 1.6         # parece urgente... pero tiene tiempo de sobra
		urgent_t = C.FU_DURATION
	patience = patience_max
	position = Vector2(-90.0 if seat_x < 640.0 else 1370.0, C.COUNTER_Y)
	if kind == "travieso":
		_knock_phase = "wait"
		_knock_t = randf_range(C.KNOCK_DELAY.x, C.KNOCK_DELAY.y)
	_apply_palette(randi() % (paletas.size() / 2))
	_t = randf() * 10.0

func _apply_palette(i: int) -> void:
	var base: Color = paletas[i * 2]
	var accent: Color = paletas[i * 2 + 1]
	for path in ["Pose/Cuerpo", "Pose/Cola", "Pose/Cabeza/Cara", "Pose/Cabeza/OrejaI", "Pose/Cabeza/OrejaD", "Patas/PataI", "Patas/PataD"]:
		(get_node(path) as CanvasItem).self_modulate = base
	for path in ["Pose/Cabeza/Mancha", "Pose/Pecho"]:
		(get_node(path) as CanvasItem).self_modulate = accent

func is_active() -> bool:
	return state == "waiting"

func is_urgent() -> bool:
	return state == "waiting" and urgent_t > 0.0

func is_purring() -> bool:
	return _purring

func wants(d: Dictionary) -> bool:
	return is_active() and not order.is_empty() and DangoData.equals(order, d)

# ------------------------------------------------------------ comportamiento
func _process(dt: float) -> void:
	_t += dt * tempo
	_state_t += dt
	match state:
		"arriving":
			position.x = move_toward(position.x, seat_x, dt * 240.0)
			if is_equal_approx(position.x, seat_x):
				_set_state("waiting")
				pedido.visible = not order.is_empty()
				pedido.set_order(order)
				if kind == "falsa_urgencia":
					_meow(true)
		"waiting":
			patience -= dt * impatience_scale
			pedido.ratio = patience / patience_max
			if urgent_t > 0.0:
				urgent_t -= dt
				_meow_cd -= dt
				if _meow_cd <= 0.0:
					_meow(true)
				if urgent_t <= 0.0:
					say("...♪")            # nadie corrió, y no pasó nada
					left_signal_fu_calmed()
			else:
				_update_knock(dt)
				_idle_sounds(dt)
			pedido.urgente = urgent_t > 0.0
			if patience <= 0.0:
				say("...")
				_leave("patience")
		"leaving":
			position.x += (-1.0 if seat_x < 640.0 else 1.0) * dt * 200.0
			modulate.a = move_toward(modulate.a, 0.0, dt * 0.8)
			if modulate.a <= 0.0:
				queue_free()
	_animate(dt)

func left_signal_fu_calmed() -> void:
	left.emit(self, "fu_calmed")      # no se va: solo avisa que se calmó sola

func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0

func _idle_sounds(dt: float) -> void:
	_meow_cd -= dt
	var chance := (0.01 + 0.07 * activity) * (1.6 if kind == "impaciente" else 1.0)
	if patience / patience_max < 0.3:
		chance *= 2.0
	if _meow_cd <= 0.0 and randf() < chance * dt * 4.0:
		_meow(false)

func _meow(urgent: bool) -> void:
	_meow_cd = 1.6 if urgent else 6.0
	say("¡MIAU MIAU!" if urgent else "miau")
	meowed.emit(urgent)

func say(text: String, dur: float = 1.6) -> void:
	habla.text = text
	_say_t = dur

func _update_knock(dt: float) -> void:
	if _knock_phase in ["none", "done"] or knock_target == null:
		return
	_knock_t -= dt
	match _knock_phase:
		"wait":
			if _knock_t <= 0.0:
				if knock_target.state == "listo":
					_knock_phase = "look"      # primero lo mira... (humor)
					_knock_t = 1.6
				else:
					_knock_phase = "done"
					knock_target.reservado = false
		"look":
			if _knock_t <= 0.0:
				_knock_phase = "paw"
				_knock_t = 0.5
		"paw":
			if _knock_t <= 0.0:
				_knock_phase = "done"
				knock_now.emit(self, knock_target)
				say("...", 2.2)               # y se queda sentado como si nada

## Entrega desde la bandeja. Devuelve true si era su pedido.
func receive(d: Dictionary) -> bool:
	if wants(d):
		say("♥")
		_leave("served")
		return true
	say("¿?")
	var tw := create_tween()
	tw.tween_property(cabeza, "rotation", 0.18, 0.1)
	tw.tween_property(cabeza, "rotation", -0.18, 0.15)
	tw.tween_property(cabeza, "rotation", 0.0, 0.1)
	return false

## Tocar a un gato que hace escándalo (sin llevarle nada): solo quería atención.
func pet() -> void:
	if is_urgent():
		urgent_t = 0.0
		say("prrr")
		fu_reacted.emit(self)
	else:
		say("miau?")

func _leave(reason: String) -> void:
	if state == "leaving":
		return
	pedido.visible = false
	patas.visible = false
	_set_state("leaving")
	if knock_target and knock_target.state == "listo":
		knock_target.reservado = false
	left.emit(self, reason)

# ------------------------------------------------------------ animación (sobre nodos)
func _animate(dt: float) -> void:
	var urgent := is_urgent()
	var waiting := state == "waiting"
	_purring = (waiting and not urgent and calm > 0.72 and activity < 0.35) or state == "resting"
	var bob_speed := 1.2 + 2.5 * activity
	var bob_amp := 1.5 + 3.0 * activity
	if urgent:
		bob_speed = 14.0
		bob_amp = 6.0
	var squash := 0.06 if _purring else 0.0
	pose.position.y = sin(_t * bob_speed) * bob_amp
	pose.scale = Vector2(1.0 + squash, 1.0 - squash)
	var tail_speed := 1.0 + 4.0 * activity + (4.0 if kind == "impaciente" else 0.0)
	cola.rotation = 1.15 + sin(_t * tail_speed) * (0.2 + 0.5 * activity) * (0.5 if _purring else 1.0)
	# Ojos: cerrados al ronronear o parpadeando
	_blink_t -= dt
	if _blink_t <= -0.15:
		_blink_t = randf_range(2.5, 5.0) * (2.0 if calm > 0.7 else 1.0)
	var closed := _purring or _blink_t < 0.0
	for e in ["Pose/Cabeza/OjoI", "Pose/Cabeza/OjoD"]:
		get_node(e + "/Abierto").visible = not closed
		get_node(e + "/Cerrado").visible = closed
	# Mirada: al objeto que va a tirar, o a la bandeja si hay dango listo
	var look := Vector2.ZERO
	if knock_target and _knock_phase in ["look", "paw"]:
		look = Vector2(signf(knock_target.global_position.x - global_position.x) * 5.0, 3.0)
	elif waiting and tray_ready:
		look = (tray_pos - global_position).normalized() * 4.0
	cabeza.get_node("OjoI").position = Vector2(-14, -4) + look
	cabeza.get_node("OjoD").position = Vector2(14, -4) + look
	# Patas: tirar el ingrediente, o estirarlas hacia un dango listo (affordance de entrega)
	if knock_target and _knock_phase == "paw":
		patas.visible = true
		var dir := signf(knock_target.global_position.x - global_position.x)
		var reach := absf(knock_target.global_position.x - global_position.x) - 30.0
		var k := 1.0 - _knock_t / 0.5
		$Patas/PataI.position = Vector2(dir * (30.0 + reach * k), -4)
		$Patas/PataD.visible = false
	elif waiting and tray_ready and not urgent:
		patas.visible = true
		$Patas/PataD.visible = true
		var reach2 := 8.0 + 6.0 * sin(_t * 4.0) + (10.0 if highlighted else 0.0)
		$Patas/PataI.position = Vector2(-22, -4 + (-reach2 if wants_hint() else 0.0) * 0.6)
		$Patas/PataD.position = Vector2(22, -4 - reach2 * (1.0 if wants_hint() else 0.4))
	else:
		patas.visible = false
	scale = Vector2.ONE * (1.06 if highlighted else 1.0)
	# Habla
	_say_t -= dt
	habla.modulate.a = clampf(_say_t, 0.0, 1.0)

## Si el dango de la bandeja es justo el suyo, se ilusiona más.
var tray_matches := false
func wants_hint() -> bool:
	return tray_matches

# ------------------------------------------------------------ toques
func hit(p: Vector2) -> bool:
	var l := p - global_position
	return Rect2(-62, -175, 124, 180).has_point(l) or (pedido.visible and Rect2(-60, -290, 120, 150).has_point(l))
