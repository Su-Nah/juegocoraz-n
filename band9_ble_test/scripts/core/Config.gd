## Configuración centralizada del vertical slice.
## Todos los tiempos, umbrales y pesos ajustables viven aquí; ningún otro
## script debería tener números "mágicos" de fisiología o dificultad.
extends RefCounted

# ---------------------------------------------------------------- FISIOLOGÍA
const HR_MIN := 35.0
const HR_MAX := 220.0
const HR_GLITCH_JUMP := 35.0          # salto (BPM) que se considera lectura errónea si es aislado
const FILTER_TAU := 5.0               # s; constante de tiempo del filtro exponencial
const SIGNAL_TIMEOUT := 12.0          # s sin lecturas = señal perdida

const BASELINE_SECONDS := 25.0        # duración nominal de la actividad tranquila
const BASELINE_MAX_SECONDS := 75.0    # si no hay datos suficientes se extiende hasta aquí
const BASELINE_MIN_SAMPLES := 8
const BASELINE_DISCARD_FIRST := 3     # primeras lecturas (asentamiento) que no cuentan
const BASELINE_SD_FLOOR := 2.0

## Activación relativa = (HR filtrada - baseline) / baseline.
## Umbral para ENTRAR a cada nivel (0 calmo, 1 activado, 2 presión, 3 tempestad).
const LEVEL_THRESHOLDS := [0.0, 0.08, 0.17, 0.28]
const LEVEL_HYSTERESIS := 0.04        # para BAJAR hay que caer este margen por debajo del umbral
const RISE_CONFIRM := 8.0             # s sostenidos para confirmar subida de nivel
const FALL_CONFIRM := 6.0             # s sostenidos para confirmar bajada de nivel
const ACTIVATION_FULL := 0.32         # activación relativa que equivale a 1.0 continuo

const TREND_WINDOW := 10.0            # s de historia para la pendiente
const RECOVERY_SLOPE := -0.15         # BPM/s; por debajo = tendencia de recuperación
const RECOVERY_FULL_SLOPE := -0.6     # BPM/s que equivale a fuerza de recuperación 1.0
const RECOVERY_START_CONFIRM := 3.0
const RECOVERY_END_CONFIRM := 4.0
const RECOVERED_REL := 0.06           # zona considerada "estable otra vez"
const RECOVERED_CONFIRM := 3.0
const ESCALATION_LIMIT := 20.0        # s en nivel 3 que se considera escalada prolongada

# ---------------------------------------------------------------- ESTABILIDAD (jugador)
const STAB_START := 0.6
const IDLE_REST_SECONDS := 4.0        # sin tocar nada este tiempo = descanso
const IDLE_GAIN := 0.05               # /s mientras dura el descanso
const PAUSE_DURATION := 4.5
const PAUSE_GAIN := 0.09              # /s durante la pausa voluntaria
const RECOVERY_GAIN := 0.05           # /s * fuerza de recuperación fisiológica
const LET_GO_GAIN := 0.07
const FU_IGNORED_GAIN := 0.05         # ignorar una falsa urgencia
const FU_REACT_LOSS := 0.03           # reaccionar a la falsa urgencia
const FRANTIC_WINDOW := 5.0
const FRANTIC_CLICKS_PER_SEC := 1.4
const FRANTIC_LOSS := 0.05            # /s mientras se trabaja frenéticamente
const STIMULI_LOSS := 0.012           # /s por cada estímulo activo por encima de 2
const HIGH_ACT_LOSS := 0.015          # /s por nivel fisiológico por encima de 1
const CALM_SUSTAIN := 10.0            # s de estabilidad alta = "calma sostenida"

# ---------------------------------------------------------------- DIRECTOR
## Fases condensadas. duration en s; pmin/pmax = rango de presión del juego; min_tier =
## complejidad mínima que la fase garantiza; force = eventos que la fase garantiza.
const DURATION_SCALE := 1.0
const PHASES := [
	{"id": "calma", "name": "Tranquilidad", "duration": 50.0, "pmin": 0, "pmax": 0, "min_tier": 0, "force": []},
	{"id": "ritmo", "name": "Ritmo", "duration": 55.0, "pmin": 0, "pmax": 1, "min_tier": 1, "force": []},
	{"id": "presion", "name": "Presión", "duration": 70.0, "pmin": 1, "pmax": 2, "min_tier": 3, "force": ["knock", "false_urgency"]},
	{"id": "tormenta", "name": "Tempestad controlada", "duration": 70.0, "pmin": 2, "pmax": 3, "min_tier": 4, "force": ["knock"]},
	{"id": "recuperacion", "name": "Recuperación", "duration": 45.0, "pmin": 0, "pmax": 1, "min_tier": 1, "force": []},
	{"id": "ultima", "name": "Última prueba", "duration": 60.0, "pmin": 2, "pmax": 3, "min_tier": 5, "force": ["false_urgency", "knock"]},
	{"id": "cierre", "name": "Cierre", "duration": 18.0, "pmin": 0, "pmax": 0, "min_tier": 0, "force": [], "no_spawn": true},
]
const MASTERY_SECONDS := 14.0         # s estable bajo la presión actual para subir un escalón
const MASTERY_STABILITY := 0.5
const PROTECT_LEVEL := 3              # nivel fisiológico a partir del cual ya no se sube
const PROTECT_SECONDS := 10.0         # s en ese nivel para empezar a proteger (bajar presión)
const MAX_TIER := 5
## Complejidad: 0 un pedido · 1 dos pedidos · 2 gato impaciente · 3 objeto derribado ·
## 4 falsa urgencia · 5 combinaciones.

## Parámetros por nivel de presión del juego (índice 0..3).
const MAX_CATS := [1, 2, 3, 4]
const SPAWN_INTERVAL := [10.0, 7.0, 5.0, 3.8]
const PATIENCE := [34.0, 28.0, 22.0, 18.0]
const EVENT_CHANCE := [0.0, 0.25, 0.45, 0.6]
const COMPLEX_CHANCE := [0.0, 0.25, 0.4, 0.5]
const PHYSIO_PRESSURE_BONUS := 0.5    # BPM moderado/alto suma hasta media presión (nunca en protección)
const RECOVERY_SPAWN_SLOWDOWN := 0.9  # intervalo * (1 + este * alivio)
const RECOVERY_PATIENCE_RELIEF := 0.45
const PAUSE_SPAWN_SLOWDOWN := 0.6

# ---------------------------------------------------------------- GATOS / OBJETOS / COCINA
const SEATS_X := [250.0, 490.0, 730.0, 970.0]
const COUNTER_Y := 430.0
const FU_DURATION := 8.0              # s que dura el escándalo de la falsa urgencia
const KNOCK_DELAY := Vector2(3.0, 7.0)
const OBJECT_COOLDOWN := 20.0         # s tras reponer un objeto antes de que pueda volver a caer
const PREP_TIME := 3.0                # s de preparación automática
const PREP_CLICK_BOOST := 0.25        # cada clic extra adelanta la preparación (productividad frenética)
const HAND_CAPACITY := 2
const PRICE := 3

# ---------------------------------------------------------------- MÚSICA (ganancia lineal por nivel)
## Columnas: [ambiente, armonía, pulso, ritmo, tempestad]
const MUSIC_MIX := [
	[1.0, 0.75, 0.0, 0.0, 0.0],
	[0.85, 0.75, 0.65, 0.0, 0.0],
	[0.65, 0.7, 0.8, 0.7, 0.0],
	[0.55, 0.6, 0.85, 0.9, 0.75],
]
const MUSIC_CALM_MIX := [1.0, 0.85, 0.0, 0.0, 0.0]
const MUSIC_RISE_RATE := 0.25         # ganancia/s al entrar capas
const MUSIC_FALL_RATE := 0.18
const MUSIC_PERC_FALL_RECOVERY := 0.6 # en recuperación la percusión sale primero y rápido
const MUSIC_MASTER_DB := -6.0

# ---------------------------------------------------------------- VISUAL
const BREATH_PERIOD := 10.0           # s; ciclo de "respiración" del puesto (pista opcional)
const MOOD_LERP := 0.35               # velocidad de transición del shader (por s)
const HINT_BREATH_COOLDOWN := 45.0
