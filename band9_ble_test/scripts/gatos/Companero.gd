## Mochi, el gato compañero. Está desde el ritual inicial y acompaña toda la
## partida: enseña (pide el primer dango), observa, se relaja con el jugador y,
## si la activación se mantiene alta, MODELA la calma: se sienta, cierra los
## ojos, ronronea, mueve lento la cola y a veces dice algo muy breve.
extends "res://scripts/gatos/Gato.gd"

const FRASES := ["Despacio...", "Puedes tomarte tu tiempo.", "Mm. Ya llegará."]

var modelando_calma := 0.0      # s restantes del "momento de calma"
var _alta_t := 0.0
var _cd := 20.0

func setup_companero() -> void:
	kind = "companero"
	order = {}
	seat = -1
	state = "resting"
	_apply_palette(0)

func _ready() -> void:
	super._ready()
	setup_companero()

func pedir(d: Dictionary) -> void:
	order = d
	state = "waiting"
	patience = 9999.0
	patience_max = 9999.0
	pedido.visible = true
	pedido.set_order(d)

func receive(d: Dictionary) -> bool:
	if wants(d):
		say("♥ prrr", 2.0)
		order = {}
		pedido.visible = false
		patas.visible = false
		state = "resting"
		left.emit(self, "served")
		return true
	say("¿?")
	return false

func pet() -> void:
	say("prrr ♥", 2.0)

func _process(dt: float) -> void:
	# Mochi no se va nunca; ignora la paciencia.
	if state == "waiting":
		patience = patience_max
	_update_recordatorio(dt)
	super._process(dt)
	pedido.ratio = 1.0
	if modelando_calma > 0.0:
		_purring = true
		pose.scale = Vector2(1.08, 0.92)
		cola.rotation = 1.15 + sin(_t * 0.6) * 0.15
		for e in ["Pose/Cabeza/OjoI", "Pose/Cabeza/OjoD"]:
			get_node(e + "/Abierto").visible = false
			get_node(e + "/Cerrado").visible = true
		pose.position.y = sin(_t * 0.6) * 2.0   # respira lento, visible

## Recordatorio diegético: no es un texto de sistema, es Mochi haciendo algo.
func _update_recordatorio(dt: float) -> void:
	_cd -= dt
	modelando_calma = maxf(0.0, modelando_calma - dt)
	if Physio.has_baseline and Physio.activation_level >= C.COMPANION_REMIND_LEVEL:
		_alta_t += dt
	else:
		_alta_t = maxf(0.0, _alta_t - dt * 2.0)
	if _alta_t >= C.COMPANION_REMIND_AFTER and _cd <= 0.0 and modelando_calma <= 0.0:
		_cd = C.COMPANION_REMIND_COOLDOWN
		modelando_calma = 9.0
		if randf() < 0.65:
			get_tree().create_timer(2.5).timeout.connect(func(): say(FRASES.pick_random(), 3.0))

## Durante la regulación voluntaria, Mochi respira contigo.
func acompanar_regulacion(segundos: float) -> void:
	modelando_calma = maxf(modelando_calma, segundos)
