## Fuente de agua (caño de bambú + cuenco). Señal ambiental principal:
##  calma → superficie lisa, chorro fino · intensidad → ondas rápidas y más caudal
##  recuperación → vuelve gradualmente a la calma.
## Cada latido cae una gota (emit_drop) con su onda: el cuerpo "habla", sin alarma.
## Sustituye las texturas de los Sprite2D y todo sigue funcionando.
extends "res://scripts/ambiente/AmbientReactive.gd"

@onready var _chorro: Sprite2D = $Chorro
@onready var _onda: Sprite2D = $Onda          # plantilla
@onready var _gota: Sprite2D = $Gota          # plantilla
var _mat: ShaderMaterial
var _t := 0.0
var _amp := 0.0

func _ready() -> void:
	_onda.visible = false
	_gota.visible = false

func _process(dt: float) -> void:
	_t += dt * tempo
	_amp = move_toward(_amp, intensidad * (1.0 - 0.6 * alivio), dt * 0.3)
	if _mat:
		_mat.set_shader_parameter("amplitud", lerpf(0.004, 0.035, _amp))
		_mat.set_shader_parameter("velocidad", lerpf(0.3, 2.2, _amp) * tempo)
	_chorro.scale.x = lerpf(0.6, 1.4, _amp) + sin(_t * 9.0) * 0.06 * (0.3 + _amp)
	_chorro.modulate.a = 0.75 + 0.2 * sin(_t * 5.0)

func emit_drop() -> void:
	var g := _gota.duplicate() as Sprite2D
	g.visible = true
	add_child(g)
	var tw := create_tween()
	tw.tween_callback(func():
		g.queue_free()
		_ripple())

func _ripple() -> void:
	var o := _onda.duplicate() as Sprite2D
	o.visible = true
	o.scale = Vector2(0.2, 0.2)
	add_child(o)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(o, "scale", Vector2(1.2, 1.2), 1.1)
	tw.tween_property(o, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(o.queue_free)
