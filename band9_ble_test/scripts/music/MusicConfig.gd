## =====================================================================
##  CONFIGURACIÓN MUSICAL — el único archivo que normalmente hay que tocar.
##  Cambia true/false o los números y vuelve a ejecutar el juego.
## =====================================================================
extends RefCounted

# ---------------------------------------------------------------- TEMPO
const BPM := 66.0                     # tempo de partida (calma). El corazón lo sube hacia BPM_MAX.

# ---------------------------------------------------------------- EL CORAZÓN DIRIGE LA MÚSICA
## Intensidad cardíaca h (0..1) = activación relativa a TU línea base (Physio.activation).
## Tempo musical = lerp(BPM_MIN, BPM_MAX, h * HEART_TEMPO_INFLUENCE).
const BPM_MIN := 66.0                 # tempo en calma
const BPM_MAX := 104.0                # tempo máximo permitido
const HEART_TEMPO_INFLUENCE := 1.0    # 0 = el corazón no cambia el tempo · 1 = recorrido completo
const TEMPO_SLEW_BPM_PER_SEC := 3.0   # cuán rápido sigue el tempo al corazón (suave)
## ETAPAS (h = intensidad cardíaca 0..1, activación relativa a tu línea base):
##   1 agua · 2 +guzheng agudo · 3 +guzheng grave · 4 +bongoes
## Cada capa ENTRA al superar su umbral y SALE al bajar de (umbral - LAYER_HYSTERESIS).
## Se avanza/retrocede UNA etapa cada vez, siempre en este orden (nunca bongoes antes que guzheng).
const HIGH_GUZHENG_ENTER := 0.15
const LOW_GUZHENG_ENTER := 0.35
const BONGOS_ENTER := 0.55
const STORM_ENTER := 0.80             # tormenta de hojas (ambiente), aparte de las etapas
const LAYER_HYSTERESIS := 0.08
## Fundidos de cada capa (segundos). Se pueden invertir a mitad sin saltos.
const LAYER_FADE_IN_SECONDS := 2.5
const LAYER_FADE_OUT_SECONDS := 2.5

# ---------------------------------------------------------------- FRASES ALEATORIAS
## Interruptor general. Si es false, NINGÚN instrumento aleatoriza
## (aunque su opción individual esté en true): compás 1→frase 1, 2→2, 3→3, 4→4, 5→1…
const ENABLE_RANDOM_PHRASES := false
## Por instrumento (solo cuentan si ENABLE_RANDOM_PHRASES = true).
const RANDOMIZE_LOW_GUZHENG := false
const RANDOMIZE_HIGH_GUZHENG := false
const RANDOMIZE_BONGOS := false
const AVOID_IMMEDIATE_PHRASE_REPEAT := true   # no repetir la misma frase dos compases seguidos
const RANDOM_SEED := 0                        # 0 = aleatorio; otro número = secuencia reproducible

# ---------------------------------------------------------------- GOTAS DE AGUA
const ENABLE_RANDOM_WATER_DROPS := true
const WATER_DROP_MODE := "musical"            # "musical" (cuantizadas al pulso) o "free"
const WATER_DROP_VOLUME_DB := -3.0            # sube este número para oírlas más
const WATER_DROP_MIN_INTERVAL := 0.8          # segundos entre gotas (mín.)
const WATER_DROP_MAX_INTERVAL := 2.5          # segundos entre gotas (máx.)
const WATER_DROP_GRID_BEATS := 0.5            # en modo musical: caen en corcheas

# ---------------------------------------------------------------- VOLÚMENES (dB)
## dB: -5 dB es MÁS FUERTE que -15 dB. Cada -6 dB ≈ la mitad de fuerte.
const MUSIC_MASTER_DB := -4.0                 # bus "Music" completo
const SFX_MASTER_DB := 0.0                    # bus "SFX" completo
const LOW_GUZHENG_VOLUME_DB := -12.0
const HIGH_GUZHENG_VOLUME_DB := -13.0
const BONGO_VOLUME_DB := -4.0     # samples cortos: necesitan más nivel que el guzheng
const MEOW_VOLUME_DB := -11.0
const URGENT_MEOW_VOLUME_DB := -8.0
const PURR_VOLUME_DB := -12.0
const AMBIENT_VOLUME_DB := -18.0              # agua/viento/aves: siempre presente
const STORM_VOLUME_DB := -14.0                # tormenta de hojas (según intensidad)
const WIND_GUST_VOLUME_DB := -16.0

# ---------------------------------------------------------------- DEPURACIÓN
const MUSIC_DEBUG := false                    # true = valida/imprime compás, frases y voces

# =====================================================================
#  Ajustes internos (normalmente no hace falta tocarlos)
# =====================================================================
const BEATS_PER_BAR := 4
## La mezcla sigue al estado del juego (calma: agua+guzheng; activación: entran bongos…).
## false = los tres instrumentos siempre a volumen completo.
const ADAPTIVE_MIX := true
const SCHEDULE_AHEAD_SECONDS := 0.12          # ventana de programación anticipada
const MAX_LOW_GUZHENG_VOICES := 8
const MAX_HIGH_GUZHENG_VOICES := 6
const MAX_BONGO_VOICES := 4
const MAX_WATER_VOICES := 3
const MAX_TOTAL_MUSIC_VOICES := 18
## Microvariación (0 = precisión total).
const GUZHENG_VELOCITY_VARIATION := 0.08      # ±8 % de intensidad
const GUZHENG_TIMING_VARIATION_BEATS := 0.0
const GUZHENG_PITCH_VARIATION := 0.0
const MEOW_PITCH_MIN := 0.95
const MEOW_PITCH_MAX := 1.05
const PURR_PITCH_MIN := 0.97
const PURR_PITCH_MAX := 1.03

const GUZHENG_DIR := "res://assets/audio/guzheng/"
const BONGO_SAMPLES := {
	"bongo1": "res://assets/audio/gen/bongo1.wav",   # agudo
	"bongo2": "res://assets/audio/gen/bongo2.wav",   # intermedio
	"bongo3": "res://assets/audio/gen/bongo3.wav",   # grave intermedio
	"bongo4": "res://assets/audio/gen/bongo4.wav",   # grave
}
const VARIATIONS := {
	"meow": ["res://assets/audio/gen/meow.wav", "res://assets/audio/gen/meow2.wav", "res://assets/audio/gen/meow3.wav", "res://assets/audio/gen/meow4.wav"],
	"meow_urgent": ["res://assets/audio/gen/meow_urgent.wav", "res://assets/audio/gen/meow_urgent2.wav", "res://assets/audio/gen/meowurgent3.wav"],
	"purr": ["res://assets/audio/gen/purr.wav", "res://assets/audio/gen/purr2.wav", "res://assets/audio/gen/purr3.wav", "res://assets/audio/gen/purr4.wav"],
	"water": ["res://assets/audio/gen/waterdop1.wav", "res://assets/audio/gen/waterdrop2.wav", "res://assets/audio/gen/waterdrop3.wav", "res://assets/audio/gen/waterdrop4.wav", "res://assets/audio/gen/waterdrop5.wav"],
	"wind": ["res://assets/audio/gen/windwoosh.wav"],
}
