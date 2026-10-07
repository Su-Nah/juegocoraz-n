## Interfaz externa mínima (UI.tscn): título, pausa real, aviso de señal y
## resultados. Durante la partida no hay HUD: todo se comunica en el mundo.
extends CanvasLayer

signal conectar()
signal simulador()
signal comenzar()
signal diagnostico()
signal continuar()
signal inicio()
signal reintentar()

const GOTA := preload("res://assets/art/agua/gota.png")
const BOLA := preload("res://assets/art/dango/bola_rosa.png")

@onready var titulo: Control = $Titulo
@onready var estado: Label = $Titulo/Margen/V/Estado
@onready var btn_comenzar: Button = $Titulo/Margen/V/Comenzar
@onready var pausa: Control = $Pausa
@onready var sin_senal: Control = $SinSenal
@onready var resultados: Control = $Resultados
@onready var contenido: VBoxContainer = $Resultados/Margen/V/Contenido
@onready var debug: Node = $Debug

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Titulo/Margen/V/Conectar.pressed.connect(func(): conectar.emit())
	btn_comenzar.pressed.connect(func(): comenzar.emit())
	$Titulo/Margen/V/Dev/Simulador.pressed.connect(func(): simulador.emit())
	$Titulo/Margen/V/Dev/Diagnostico.pressed.connect(func(): diagnostico.emit())
	$Pausa/Margen/V/Continuar.pressed.connect(func():
		ocultar_pausa()
		continuar.emit())
	$Pausa/Margen/V/Diagnostico.pressed.connect(func(): diagnostico.emit())
	$Pausa/Margen/V/Inicio.pressed.connect(func():
		ocultar_pausa()
		inicio.emit())
	$SinSenal/Reconectar.pressed.connect(func(): conectar.emit())
	$Resultados/Margen/V/Botones/Otra.pressed.connect(func(): reintentar.emit())
	$Resultados/Margen/V/Botones/Inicio.pressed.connect(func(): inicio.emit())
	ocultar_todo()

func ocultar_todo() -> void:
	titulo.visible = false
	pausa.visible = false
	sin_senal.visible = false
	resultados.visible = false

func mostrar_titulo() -> void:
	ocultar_todo()
	titulo.visible = true

func mostrar_pausa() -> void:
	pausa.visible = true

func ocultar_pausa() -> void:
	pausa.visible = false

func set_sin_senal(v: bool) -> void:
	sin_senal.visible = v

func actualizar_titulo() -> void:
	var st: String = HeartRate.web.get_connection_status()
	var txt := ""
	if not HeartRate.web.has_js_bridge():
		txt = "La pulsera solo se conecta en la versión Web (Edge/Chrome). En el editor usa el simulador."
	else:
		txt = {"disconnected": "Pulsera desconectada.", "scanning": "Buscando la pulsera…", "connecting": "Conectando…", "connected": "Pulsera conectada.", "error": "No se pudo conectar (ver Diagnóstico BLE)."}.get(st, st)
	if HeartRate.is_receiving():
		txt += "  Se siente el pulso (%s)." % HeartRate.source_label()
	elif st == "connected":
		txt += "  Esperando la primera lectura…"
	estado.text = txt
	btn_comenzar.disabled = not HeartRate.is_receiving()

## Resultados del juego (no diagnóstico): visuales, sin lenguaje clínico.
func mostrar_resultados(s: Dictionary, avg_stab: float, has_base: bool, base_hr: float) -> void:
	ocultar_todo()
	resultados.visible = true
	for ch in contenido.get_children():
		ch.queue_free()
	var stab_drops := clampi(roundi(avg_stab * 5.0 + (0.5 if s["recovery_times"].size() > 0 else 0.0)), 1, 5)
	_fila_gotas("Estabilidad", stab_drops)
	_fila("Dangos preparados", str(s["dangos"]), BOLA)
	_fila("Gatos atendidos", str(s["served"]))
	_fila("Gatos que siguieron su camino", str(s["left_on_own"]))
	_fila("Momentos de recuperación", str(s["recovery_moments"]))
	var rt: Array = s["recovery_times"]
	if rt.size() > 0:
		var avg := 0.0
		for x in rt:
			avg += x
		_fila("Tiempo para volver a la calma", "%.0f s (mejor %.0f s)" % [avg / rt.size(), rt.min()])
	_fila("Tiempo bajo presión sin desbordarse", "%.0f de %.0f s" % [s["time_pressure_ok"], s["time_pressure"]])
	_fila("Cosas que dejaste pasar", str(s["fu_ignored"] + s["falls_ignored"]))
	_fila("Veces que te detuviste", "%d  (campanilla %d · pausas espontáneas %d)" % [s["pauses"] + s["rests"], s["pauses"], s["rests"]])
	_fila("Dangos al bote (y vuelta a empezar)", str(s["discards"]))
	if has_base:
		_fila("Tu pulso de referencia", "%.0f · pico %.0f" % [base_hr, s["peak_hr"]])
	var cierre := Label.new()
	cierre.text = "No necesitabas atenderlo todo."
	cierre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cierre.add_theme_font_size_override("font_size", 22)
	cierre.add_theme_color_override("font_color", Color(0.3, 0.45, 0.45))
	contenido.add_child(cierre)

func _fila(nombre: String, valor: String, icono: Texture2D = null) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	if icono:
		var tr := TextureRect.new()
		tr.texture = icono
		tr.custom_minimum_size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	var a := Label.new()
	a.text = nombre
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Label.new()
	b.text = valor
	for l in [a, b]:
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color(0.3, 0.26, 0.28))
		h.add_child(l)
	contenido.add_child(h)

func _fila_gotas(nombre: String, n: int) -> void:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = nombre
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 22)
	a.add_theme_color_override("font_color", Color(0.3, 0.26, 0.28))
	h.add_child(a)
	for i in 5:
		var tr := TextureRect.new()
		tr.texture = GOTA
		tr.custom_minimum_size = Vector2(26, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(0.35, 0.6, 0.85) if i < n else Color(0.8, 0.8, 0.8, 0.4)
		h.add_child(tr)
	contenido.add_child(h)
