## La pieza, como DATOS. Cada fila: [duración en beats, nota o sample].
## "REST" = silencio. Para añadir una frase, añade otra lista; para un nuevo
## instrumento, añade otra entrada en INSTRUMENTS (ver README).
extends RefCounted

## Tresillo exacto. En la partitura aparece como 0.3333; se usa 1/3 para que
## las frases sumen exactamente 4 beats (corrección técnica, mismas notas).
const T := 1.0 / 3.0

const LOW_GUZHENG := [
	[[0.25, "F#3"], [0.25, "D#3"], [0.25, "C#3"], [0.25, "D#3"], [0.5, "A#2"], [0.5, "C#2"], [T, "G#2"], [T, "A#2"], [T, "G#2"], [1.0, "F#2"]],
	[[0.5, "D#2"], [0.5, "C#2"], [1.0, "F#2"], [0.25, "F#2"], [0.25, "G#2"], [0.25, "D#2"], [0.25, "F#2"], [1.0, "C#2"]],
	[[0.5, "D#3"], [0.5, "C#3"], [0.5, "F#3"], [0.5, "D#3"], [0.5, "C#3"], [0.5, "A#2"], [1.0, "C#3"]],
	[[1.0, "A#2"], [0.75, "G#2"], [0.25, "F#2"], [T, "G#2"], [T, "F#2"], [T, "D#2"], [1.0, "F#2"]],
]

const HIGH_GUZHENG := [
	# Suma 3.5 beats: la validación lo avisa y añade 0.5 de silencio al final.
	[[1.0, "C#5"], [1.0, "A#4"], [0.25, "D#5"], [0.25, "C#5"], [1.0, "A#4"]],
	[[0.5, "G#4"], [0.5, "C#5"], [0.5, "A#4"], [0.5, "A#4"], [0.5, "A#4"], [0.5, "F#4"], [1.0, "A#4"]],
	[[1.0, "D#5"], [1.0, "A#4"], [1.0, "F#5"], [1.0, "D#4"]],
	[[1.0, "C#5"], [0.5, "A#4"], [0.5, "G#4"], [1.0, "G#4"], [0.5, "REST"], [0.5, "F#4"]],
]

## bongo1 = agudo · bongo2 = intermedio · bongo3 = grave intermedio · bongo4 = grave
const BONGOS := [
	[[0.5, "bongo3"], [0.5, "bongo4"], [0.5, "bongo4"], [0.5, "bongo1"], [0.5, "bongo3"], [0.5, "bongo3"], [1.0, "bongo1"]],
	[[1.0, "bongo2"], [1.0, "bongo3"], [0.5, "bongo2"], [0.5, "bongo2"], [1.0, "bongo1"]],
	[[1.0, "bongo2"], [1.0, "bongo4"], [0.25, "bongo3"], [0.25, "bongo3"], [0.5, "bongo3"], [1.0, "bongo3"]],
	[[1.0, "bongo1"], [0.5, "bongo2"], [0.5, "bongo3"], [0.5, "bongo2"], [0.5, "bongo3"], [1.0, "bongo2"]],
]

## id · nombre · frases · tipo de sonido · prioridad de voz (mayor = se conserva)
const INSTRUMENTS := [
	{"id": "low_guzheng", "name": "Guzheng grave", "phrases": LOW_GUZHENG, "kind": "guzheng", "priority": 3},
	{"id": "high_guzheng", "name": "Guzheng agudo", "phrases": HIGH_GUZHENG, "kind": "guzheng", "priority": 3},
	{"id": "bongos", "name": "Bongoes", "phrases": BONGOS, "kind": "bongo", "priority": 2},
]
