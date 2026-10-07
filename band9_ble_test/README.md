# Neko Yatai — vertical slice

Un puesto de comida pequeño, con estética japonesa *cute* y gatos como clientes. Parece un juego de gestión, pero el verdadero reto es cómo respondes a la presión. La única señal fisiológica real es la **frecuencia cardíaca de la Huawei Band 9**, que llega por la cadena que ya funcionaba:

```
Huawei Band 9 → BLE → Web Bluetooth → JavaScript (web/shell.html) → JavaScriptBridge
  → HeartRateWebBridge.gd → HeartRate (autoload) → Physio (estado fisiológico)
  → ArousalDirector + StabilitySystem → gatos · cocina · puesto · música · shader
```

El juego no mide la respiración, solo la sugiere. Tampoco interpreta ningún BPM como "ansiedad": trabaja con **activación relativa a tu propio baseline**, con su tendencia y con la recuperación.

---

## Estructura

```
band9_ble_test/
├── Game.tscn                      ESCENA PRINCIPAL (juego)
├── Main.tscn                      Diagnóstico BLE (la prueba original, conservada)
├── project.godot                  autoloads HeartRate, Physio, Sfx · 1280x720 · Compatibility
├── export_presets.cfg             Web, single-thread, shell personalizado (sin cambios funcionales)
├── web/shell.html                 Bridge Web Bluetooth (SIN CAMBIOS)
├── scripts/
│   ├── providers/                 HeartRateProvider · HeartRateWebBridge (sin cambios) · Simulator
│   ├── core/
│   │   ├── Config.gd              TODAS las constantes ajustables (umbrales, tiempos, mezclas)
│   │   ├── HeartRateService.gd    autoload HeartRate: dueño de los proveedores, fuente activa
│   │   └── PhysiologicalState.gd  autoload Physio: filtro, baseline, activación, tendencia
│   ├── game/
│   │   ├── Game.gd                flujo TITLE → BASELINE → PLAY → RESULTS, input, mundo
│   │   ├── ArousalDirector.gd     fases, presión adaptativa, protección, alivio, spawns
│   │   ├── StabilitySystem.gd     estabilidad del jugador + métricas de la sesión
│   │   ├── Cat.gd                 gatos (normal, impaciente, travieso, falsa urgencia, residente)
│   │   ├── CounterObject.gd       taza/plato/limón derribables con cooldown
│   │   ├── Kitchen.gd             estaciones té/onigiri/dango + bandeja + vapor
│   │   ├── Stall.gd               el puesto que "respira" + gota por latido
│   │   └── DishArt.gd             iconos vectoriales de los platillos
│   ├── audio/MusicLayers.gd       5 capas sincronizadas + ronroneo
│   ├── audio/Sfx.gd               sonidos one-shot (pool)
│   ├── ui/DebugPanel.gd           panel técnico (F3)
│   └── HeartRateTest.gd           UI del diagnóstico BLE (ahora usa el autoload)
├── shaders/mood.gdshader          capa visual adaptativa
├── assets/audio/gen/*.wav         audio placeholder generado (tools/generate_audio.py)
├── assets/sprites/reused/         vaso.png y limon.png de Micheladas Nancy
├── tests/SmokeTest.tscn           prueba automática de toda la partida (no se exporta)
├── tools/generate_audio.py        generador de audio (herramienta de desarrollo, no se exporta)
└── docs/BLE_TEST.md               documentación original de la prueba BLE / itch.io
```

## Archivos

**Creados:** `Game.tscn`, `scripts/core/*`, `scripts/game/*`, `scripts/audio/*`, `scripts/ui/DebugPanel.gd`, `shaders/mood.gdshader`, `assets/audio/gen/*`, `assets/sprites/reused/*`, `tools/generate_audio.py`, `tests/SmokeTest.*` y este README.

**Modificados:**
- `project.godot`: escena principal `Game.tscn`, autoloads, 1280×720 con `canvas_items`.
- `export_presets.cfg`: solo amplía la exclusión de `tools/`, `tests/` y `docs/`.
- `SimulatorHeartRateProvider.gd`: añade la secuencia de prueba y el *jitter*; la interfaz es la misma.
- `HeartRateTest.gd`: usa los proveedores del autoload en vez de crear los suyos y tiene un botón "Volver al juego".
- `README.md`: el anterior se movió a `docs/BLE_TEST.md`.

**Sin tocar:** `web/shell.html` y `HeartRateWebBridge.gd`, es decir, toda la parte de Web Bluetooth y JavaScriptBridge.

> Por qué `HeartRateTest.gd` usa ahora el autoload: `setCallbacks()` en JS solo admite un destinatario. Si el diagnóstico creara su propio bridge le "robaría" los callbacks al juego. Con un único dueño, la conexión con la Band 9 sobrevive al pasar del juego al diagnóstico y viceversa.

## Qué se reutilizó de Micheladas Nancy

Se inspeccionaron `Main.gd`, `GameManager.gd`, `CustomerSpawner.gd`, `CharacterDB.gd`, `SFX.gd`, `Ambiente.gd`, los shaders y los assets. Se reutilizó solo lo que ahorraba tiempo:

| Elemento | Uso en Neko Yatai |
|---|---|
| Sistema de *slots + paciencia por cliente* (`Main.gd`: `paciencia_actual/maxima`, `_resolver_slot`) | Base de `Cat.gd` y de los asientos de `Game.gd`. Cambia su significado: irse es un **resultado**, no un fracaso, y no hay penalización. |
| Generación de pedido aleatorio (`CustomerSpawner.generar_pedido_aleatorio`) | Simplificado en `ArousalDirector._spawn`: 1–2 platillos y complejidad por *tier*. |
| `SFX.gd`: pool de reproductores + `_cargar()` seguro | `scripts/audio/Sfx.gd`. |
| `Ambiente.gd`: separar música/ambiente en capas | Concepto base de `MusicLayers.gd`, ahora adaptativo. |
| `vaso.png`, `limon.png` | Objetos que los gatos derriban. |

**Descartado, con motivo:**
- Los `.wav` de Micheladas son **punteros Git‑LFS de 130 bytes** sin audio real.
- La cumbia y el ruido de la calle no encajan con la estética.
- Los personajes, las fuentes graffiti y el fondo son de otra estética.
- No se usaron la extorsión, los finales morales ni el dinero como objetivo principal.
- Los shaders de líquido no aportan nada aquí.

---

## Cómo funciona cada sistema

### BPM → sistema fisiológico
`HeartRateWebBridge` emite `heart_rate_received(bpm)` y `HeartRate` reenvía como `bpm_received(bpm, source)` solo los datos de la **fuente activa** (Band 9 o simulador; nunca se mezclan). `Physio` escucha esa señal. Ningún gato, objeto o sistema de música toca JavaScript.

### Baseline (actividad tranquila previa)
Al pulsar **Comenzar**, el puesto aún está cerrado:
- Un gato residente dormita en el mostrador (puedes acariciarlo y ronronea).
- Sale vapor de la tetera, cae una gota por latido en el cuenco y los farolillos se encienden poco a poco: ese es el indicador de progreso, sin números.
- Solo aparecen dos textos: "Antes de abrir el puesto…" y "Vamos a empezar despacio.".

Durante unos `BASELINE_SECONDS = 25 s` (el tiempo solo corre si llega señal) se guardan las lecturas. Después:
- Se descartan las 3 primeras (asentamiento).
- Se calculan la media y la desviación.
- Se descartan los valores a más de 2 desviaciones y se recalcula.

El resultado queda en `baseline_hr` y `baseline_sd` (con un mínimo de 2). Se necesitan al menos 8 lecturas válidas.

### Activación
1. **Filtro exponencial** temporal (`FILTER_TAU = 5 s`), independiente de cada cuánto llegue un dato. Un salto aislado de más de 35 BPM se descarta como lectura errónea.
2. `relative_activation = (filtrada − baseline) / baseline`. Así, 85 BPM no significa lo mismo para todos.
3. `activation` continua de 0 a 1, donde un +32 % equivale a 1.
4. `activation_level` 0–3 con umbrales +8 %, +17 % y +28 %. Para bajar de nivel hay una **histéresis** de −4 %.
5. Hay **confirmación temporal**: para subir hacen falta 8 s sostenidos y para bajar 6 s (`RISE_CONFIRM`, `FALL_CONFIRM`). Una variación de 1–2 BPM no cambia nada.

### Recuperación
- Cada segundo se calcula la pendiente (regresión lineal) de la HR filtrada en los últimos 10 s.
- Si sigues **por encima del baseline** y la pendiente es ≤ −0.15 BPM/s durante 3 s, se emite `recovery_started`. Se detecta la **tendencia**: no hace falta volver al baseline.
- `recovery_strength` (0–1) crece con la pendiente; −0.6 BPM/s equivale a 1.
- Además, `StabilitySystem` mide los episodios: desde el pico hasta volver a la zona estable (+6 %) durante 3 s. Esto da el **tiempo de recuperación** de la pantalla final.

### Estabilidad (variable interna, no es HUD)
Empieza en 0.6.

**Sube con:**
- No tocar nada durante 4 s (+0.05/s mientras dura).
- La pausa voluntaria (+0.09/s).
- La recuperación fisiológica (+0.05/s × fuerza).
- Dejar ir a un gato (+0.07).
- Ignorar una falsa urgencia (+0.05).

**Baja con:**
- Clics frenéticos, más de 1.4 por segundo en 5 s (−0.05/s).
- Acumular más de 2 estímulos activos (−0.012/s por cada uno).
- Activación fisiológica sostenida de nivel 2 o más.
- Reaccionar a una falsa urgencia (−0.03).

**El conflicto productividad / estabilidad:** hacer clic repetido en una estación acelera la preparación (+25 % por clic), pero el ritmo frenético cuesta estabilidad.

### Dificultad (ArousalDirector)
- **Fases condensadas** (~6 min más el baseline): Tranquilidad → Ritmo → Presión → Tempestad controlada → Recuperación → Última prueba → Cierre. Cada fase define un rango de presión (`pmin`–`pmax`) y una complejidad mínima.
- **Maestría:** si llevas 14 s con estabilidad ≥ 0.5 y sin activación extrema, el juego sube un escalón de presión (si la fase lo permite) y un *tier* de complejidad. Los tiers son:
  - 0: un pedido
  - 1: dos pedidos
  - 2: gato impaciente
  - 3: objeto derribado
  - 4: falsa urgencia
  - 5: combinaciones
- **Techo y protección:** con nivel fisiológico 3 **no sube nada**. Si ese nivel dura 10 s, el juego **protege**: baja la presión un escalón hasta que vuelvas a nivel ≤ 1.
- **Alivio:** la recuperación fisiológica, la pausa, la protección y la fase de recuperación generan un `relief` (0–1). Con él:
  - las llegadas son más espaciadas (×1.9)
  - hay más paciencia (+45 %)
  - hay menos eventos (−70 %)
  - las animaciones van más lentas, la música abre espacio y el shader se suaviza
- **BPM moderado** suma hasta media unidad de presión percibida, nunca en protección.
- **Eventos garantizados:** cada fase asegura sus eventos clave. Hay un travieso en Presión, Tempestad y Última, y una falsa urgencia en Presión y Última, así que la slice siempre los muestra.

### Gatos
- **normal**: pide 1–2 platillos.
- **impaciente**: tiene ~35 % menos paciencia, la cola se mueve rápido, echa las orejas atrás y maúlla más.
- **travieso**:
  - mira el objeto de al lado, lo derriba con la pata (sonido) y se queda sentado ("...")
  - el objeto bloquea su estación hasta que lo recoges: la taza bloquea el té y el plato el onigiri
  - después de recogerlo hay 20 s de cooldown antes de que pueda volver a caer
- **falsa urgencia**:
  - "¡MIAU MIAU!" con "!!!" temblando, pero **no tiene pedido ni prisa real**
  - si lo ignoras 8 s se calma, ronronea "♪" y se va (estabilidad +)
  - si lo atiendes solo quería mimos (estabilidad −, y perdiste tiempo)
- **Reacción a tu estabilidad:**
  - `agitation` se calcula con la intensidad, la estabilidad baja y el alivio, y controla el balanceo, la cola y los maullidos
  - con estabilidad alta (> 0.72) y poca agitación, los gatos cierran los ojos, se acomodan (más bajitos) y **ronronean**; el ronroneo suena como capa de audio
- **Dejar ir:** botón "dejar ir" bajo cada gato. Se despide ("miau~") y aparece "se fue · está bien". Si se acaba la paciencia, aparece "El cliente se fue." en gris neutro. No hay pantalla de fracaso ni penalización.

### Pausa de 4 segundos (sin tocar nada)
`StabilitySystem` mide el tiempo sin clics, y mover el ratón no cuenta. A partir de 4 s se cuenta un **descanso** y la estabilidad sube mientras dure. Eso hace que:
- los gatos se calmen y ronroneen
- la música pierda percusión
- el shader se suavice

No aparece ningún texto ni puntuación.

### Pausa / regulación voluntaria
Botón **Pausa** o tecla **Espacio** durante 4.5 s. **No pausa el juego**:
- los gatos siguen y la paciencia sigue corriendo
- la cocina queda deshabilitada: no produces
- aparece "Respira despacio."
- los farolillos y las cortinas amplían su ciclo lento de respiración
- la música baja a la mitad de nivel
- llegan menos clientes

### Respiración (sin sensor)
El puesto tiene un ciclo lento de 10 s (`BREATH_PERIOD`) que siguen los farolillos (se expanden y contraen), las cortinas y el vapor (sube más en la "inspiración"). Es una pista opcional que nunca da instrucciones en segundos. Bajo presión puede aparecer "Respira despacio." o "Haz una pausa.", como mucho cada 45 s.

### Música (MusicLayers)
Hay cinco loops de 12.8 s, arrancados a la vez y siempre sincronizados:

| Capa | Contenido |
|---|---|
| 0 | agua, viento y pájaros |
| 1 | armonía de koto (escala in‑sen) |
| 2 | pulso: bongó discreto |
| 3 | ritmo: shaker, ostinato y bongós |
| 4 | tempestad: taiko, trémolo disonante y ráfagas |

El nivel continuo (intensidad del mundo × 3) interpola la tabla `MUSIC_MIX`:
- **Activación creciente:** entra el pulso.
- **Activación alta:** entra el ritmo.
- **Sobrecarga:** entra la tempestad.
- **Recuperación:** la percusión y la tempestad salen **primero y rápido**, y el agua gana +0.15 como recompensa. El orden es tempestad → percusión → viento/agua → silencio relativo.
- **Calma sostenida** (estabilidad alta durante 10 s): solo quedan agua, cuerdas y ronroneo.

### Shader (mood.gdshader)
Es una capa de pantalla que ajusta poco a poco varios parámetros a la vez: matiz, saturación, contraste, brillo, tinte y viñeta.

| Estado | Efecto |
|---|---|
| Calma | Tinte verde‑azulado, saturación 0.85, más luz. |
| Activación / presión | Más contraste y saturación, y el matiz se desplaza ~7° hacia cálido. |
| Recuperación | Vuelve a la calma, con menos contraste y menos viñeta. |

Además, la cámara deriva unos pocos píxeles con la intensidad y se queda quieta en la recuperación. **Nada pulsa con cada latido.**

### Latido diegético
Por cada latido cae **una gota** desde el caño de bambú al cuenco, con onda y un "plim" suave:
- volumen −20 dB
- notas de una escala pentatónica
- **más bajo** cuando sube la activación, para que nunca suene alarmante

**El BPM nunca aparece durante la partida.** Solo se ve en la pantalla final (tu referencia y tu pico) y en el panel técnico.

### Pantalla final
**DINERO**, **CLIENTES ATENDIDOS** y **ESTABILIDAD** en estrellas, más:
- ventas
- clientes atendidos, dejados ir y que se fueron solos
- veces que te detuviste (pausas y descansos)
- falsas urgencias que dejaste pasar
- tiempo bajo presión sin escalada prolongada (nivel 3 durante menos de 20 s seguidos)
- tiempo de recuperación (media, mejor y episodios)
- pulso de referencia y pico

Termina con "No necesitabas salvarlo todo." y, si dejaste ir a alguien, "Dejar ir también fue una decisión.".

---

## Ejecutar y probar

### Editor (Godot 4.3+, estándar, no .NET)
1. Importa `band9_ble_test/project.godot`.
2. **F5**: aparece el título.
3. Pulsa **Simulador (desarrollo)** y luego **Comenzar**.
4. **F3** abre el panel técnico con: BPM actual y filtrado, baseline, activación, nivel, tendencia, estabilidad, fase, presión, *tier*, protección, alivio, capa musical, eventos activos y fuente del BPM.
5. Controles del simulador:
   - **F1**: secuencia 60→70→80→90→110→130→100→85→70 (8 s por paso)
   - **F2**: parar la secuencia
   - **+ / −**: ±5 BPM
   - con **F1** justo después del baseline se ven la subida, la protección y la recuperación en menos de 2 minutos

### Prueba automática (opcional)
```
godot --headless res://tests/SmokeTest.tscn
```
Juega la partida completa a 10× con el simulador y un bot. Termina con `SMOKE OK` si se vieron: derribo, falsa urgencia, recuperación, subida de reto y dejar ir.

### Web local con la Band 9
1. Activa en la pulsera la **difusión de frecuencia cardíaca** (ver `docs/BLE_TEST.md`).
2. *Proyecto → Exportar → Web* (preset ya configurado) → `build/web/`.
3. Sirve por `localhost` (botón "Ejecutar en navegador" del editor, o cualquier servidor estático) y abre en **Edge o Chrome**.
4. **Conectar Huawei Band 9** → elige la pulsera → espera "Recibiendo señal" → **Comenzar**.
5. **Diagnóstico BLE** abre la pantalla técnica original (servicios, características, errores). "← Volver al juego" conserva la conexión.

### Netlify (HTTPS)
1. Exporta a `build/web/`.
2. En Netlify: *Add new site → Deploy manually* → arrastra la carpeta `build/web`. También puedes usar `netlify deploy --dir=build/web --prod`.
3. Abre la URL `https://…netlify.app` en Edge o Chrome.

La exportación es **single‑thread**, así que no necesita cabeceras COOP/COEP. Netlify sirve la página como documento principal (no en un iframe), así que la Permissions Policy no bloquea Bluetooth, al contrario de lo que pasa en itch.io.

### Checklist de la vertical slice (criterio de éxito)
| # | Qué observar |
|---|---|
| 1–3 | Edge → Conectar → selector → Band 9 → "Recibiendo señal (Huawei Band 9 (real))" |
| 4 | Comenzar → gato dormido, vapor, gotas por latido, farolillos que se encienden; ~25 s |
| 5–6 | "El puesto abre." Las llegadas aumentan por fases; con F3, la presión sube solo cuando estás estable |
| 7–9 | Gato impaciente; un gato mira la taza o el plato y lo tira (estación "falta un objeto"); "¡MIAU MIAU!" con "!!!" |
| 10 | "dejar ir" → "se fue · está bien", sin castigo |
| 11 | 4 s sin tocar → los gatos cierran los ojos y ronronean, la percusión baja |
| 12–13 | Pausa / Espacio → "Respira despacio.", farolillos y cortinas más amplios, cocina en pausa, el mundo sigue |
| 14–15 | Al bajar tu pulso: F3 muestra "recuperando: SÍ", hay menos llegadas y el mundo se desacelera |
| 16 | Las capas entran y salen (F3 "música: …") |
| 17–18 | El puesto respira; los gatos se calman con tu estabilidad |
| 19 | Fase "Última prueba" (F3) |
| 20 | Pantalla final con estabilidad y recuperación por encima del dinero |

## Limitaciones conocidas (honestas)
- **Audio placeholder sintetizado** (koto Karplus‑Strong, percusión, maullidos sintéticos). Funciona y respeta la arquitectura. Para mejorarlo, sustituye los `.wav` de `assets/audio/gen/` por grabaciones con **el mismo nombre**; las capas deben durar lo mismo entre sí.
- **Arte vectorial** dibujado por código: es rápido de iterar y se puede reemplazar por sprites sin tocar la lógica.
- **Umbrales fisiológicos iniciales razonables, no validados.** Ajústalos en `Config.gd` tras probar con personas reales.
- La pantalla de diagnóstico conserva su diseño de 1100×760; se escala dentro de 1280×720.
