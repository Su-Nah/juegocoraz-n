# Sistema musical dinámico

```
                 MusicClock (único reloj · posición en beats)
                        │
     ┌──────────────────┼──────────────────┬──────────────┐
 Guzheng grave     Guzheng agudo        Bongoes      Gotas de agua
  4 frases           4 frases           4 frases     (cuantizadas)
     └──────────── MusicScheduler (ventana móvil 0,12 s) ───┘
                        │
   AudioSampleCache · AudioVoicePool (prioridades) · bus "Music"

 Independientes del reloj: ambiente y tormenta (bus "Ambient"),
 ronroneos, maullidos y viento (bus "SFX").
```

## Archivos

| Archivo | Qué hace |
|---|---|
| `scripts/music/MusicConfig.gd` | **El único archivo de ajustes**: BPM, aleatorización, gotas, volúmenes, depuración. |
| `scripts/music/SongData.gd` | La partitura **como datos**: `[duración_en_beats, nota]`. |
| `scripts/music/MusicTypes.gd` | `MusicEvent`, `MusicPhrase` (valida y rellena con silencio), `MusicTrack` (elige la frase al inicio de cada compás), `WaterDropTrack`. |
| `scripts/music/MusicClock.gd` | El reloj único. Guarda un *ancla* (beat, tiempo), de modo que cambiar el BPM no mueve la posición musical. |
| `scripts/music/MusicScheduler.gd` | Programación anticipada con ventana móvil. |
| `scripts/music/AudioSampleCache.gd` | Carga cada sample **una vez**. |
| `scripts/music/AudioVoicePool.gd` | Voces preasignadas y reutilizadas, con robo de la voz más antigua y fundido corto. |
| `scripts/music/GuzhengNotePlayer.gd` | Busca el sample de cada nota: primero el exacto; si falta, transpone la nota más cercana (como respaldo); si no hay nada cerca, avisa `Missing Guzheng sample: X`. |
| `scripts/music/RandomAudioVariationPlayer.gd` | Elige entre maullidos, ronroneos o gotas sin repetir el último y con un pitch ligeramente variado. |
| `scripts/music/MusicPlayer.gd` | Junta todo. API: `start/stop/pause/resume/set_bpm/set_random_phrases_enabled/set_instrument_randomization/get_current_bar/get_current_beat`. |
| `scripts/audio/MusicLayers.gd` | Ambiente y tormenta (independientes del reloj), mezcla adaptativa de los instrumentos, ronroneos y ráfagas de viento. |
| `default_bus_layout.tres` | Buses `Music`, `Ambient` y `SFX`. |
| `assets/audio/guzheng/*.wav` | Banco de notas de guzheng (`F#3` → `Fs3.wav`). |
| `tools/render_guzheng.py` + `tools/data/E5_Guzheng.json` | Generan el banco a partir del análisis de la nota E5. Se ejecutan **una vez**, fuera del juego. |
| `tests/MusicTests.gd`, `tests/MusicRealtime.gd` | Pruebas automáticas. |

## Guía rápida

1. **Cambiar el BPM:** `MusicConfig.gd` → `const BPM := 90.0`. Durante el juego: `music_player.set_bpm(110.0)`.
2. **Activar la aleatorización:** `ENABLE_RANDOM_PHRASES := true` y, además, la opción de cada instrumento.
3. **Solo el guzheng grave:** `ENABLE_RANDOM_PHRASES := true` y `RANDOMIZE_LOW_GUZHENG := true` (los otros dos en `false`).
4. **Solo el guzheng agudo:** `ENABLE_RANDOM_PHRASES := true` y `RANDOMIZE_HIGH_GUZHENG := true`.
5. **Solo los bongoes:** `ENABLE_RANDOM_PHRASES := true` y `RANDOMIZE_BONGOS := true`.
   - Con `RANDOM_SEED := 123` (o cualquier número distinto de 0) la secuencia se repite igual en cada ejecución.
   - `AVOID_IMMEDIATE_PHRASE_REPEAT` evita repetir la misma frase en dos compases seguidos.
6. **Volumen de las gotas:** `WATER_DROP_VOLUME_DB` (súbelo para oírlas más). También puedes cambiar:
   - `WATER_DROP_MIN_INTERVAL` y `WATER_DROP_MAX_INTERVAL`;
   - `WATER_DROP_MODE`: `"musical"`, que cae en corcheas (`WATER_DROP_GRID_BEATS`), o `"free"`.
7. **Añadir o cambiar frases:** en `SongData.gd`, edita las listas `LOW_GUZHENG`, `HIGH_GUZHENG` o `BONGOS`. Cada frase es `[[duración, "nota"], …]` y `"REST"` es un silencio. Puedes añadir una quinta frase: el secuenciador usa tantas como haya.
8. **Cambiar samples:**
   - Guzheng: guarda tu grabación como `assets/audio/guzheng/Fs3.wav` (el `#` se escribe `s`). Si existe el archivo exacto, se usa sin cambiar el pitch.
   - Bongoes: `BONGO_SAMPLES` en `MusicConfig.gd`.
   - Maullidos, ronroneos, gotas y viento: `VARIATIONS`.
9. **Añadir un quinto instrumento:**
   1. Escribe sus frases en `SongData.gd`.
   2. Añade una entrada en `INSTRUMENTS` con `{"id", "name", "phrases", "kind", "priority"}`.
   3. Si su `kind` es nuevo, añade un `match` en `MusicPlayer._play_event()` y un pool con `_add_pool()`.
10. **Cambiar el compás:** `BEATS_PER_BAR` en `MusicConfig.gd`. Las frases se validan contra ese valor y todas las posiciones son `compás × BEATS_PER_BAR + desplazamiento`.
11. **Cómo funciona el scheduler:**
    - Cada frame, cada pista mete en `pending` los eventos cuyo beat cae dentro de los próximos `SCHEDULE_AHEAD_SECONDS`. Nunca hay más que unos pocos: el máximo medido fue 5.
    - Un evento se dispara si su hora caería antes del siguiente frame. El retraso real (`late`) se compensa empezando el sample unos milisegundos más adelante.
    - Los eventos guardan su **beat**, no su segundo. Por eso un cambio de BPM recalcula la hora de lo que está en la ventana sin perder ni duplicar nada.
    - La frase de cada compás se decide una sola vez, al entrar al compás. Activar la aleatorización a mitad de un compás tiene efecto en el siguiente.
12. **Cómo se evita saturar la CPU:**
    - Todo se carga al iniciar (caché) y las voces están preasignadas: 8 guzheng grave, 6 agudo, 4 bongoes y 3 gotas, con un tope total de 18.
    - No hay síntesis ni FFT durante el juego.
    - Con el presupuesto lleno se sacrifica primero la voz de menor prioridad: gotas, luego bongoes; el guzheng se conserva.
13. **Modo debug:**
    - `MUSIC_DEBUG := true` imprime la validación completa y, en cada compás: `BAR n · Low: frase · High: frase · Bongos: frase · voces · BPM`.
    - El panel F3 del juego muestra siempre: BPM, compás, beat, frases actuales, voces, eventos en ventana, samples cargados y qué reloj se está usando.

## Reloj de audio

La hora musical sale de un `AudioStreamPlayer` silencioso en bucle: posición de reproducción + `AudioServer.get_time_since_last_mix()`. Esa posición la avanza el mezclador de Godot, no `_process`. Además:
- Este reproductor se fuerza a pasar por el mezclador (`PLAYBACK_TYPE_STREAM`).
- Si la posición no avanza durante 1 s, se usa el reloj del sistema **conservando la posición musical**. Esto pasa con algunos drivers o si el navegador suspende el audio.
- Si el juego se pausa (tablilla o Esc), el reloj de audio se detiene y la música continúa exactamente donde estaba.

## Mezcla adaptativa

Con `ADAPTIVE_MIX := true`, el estado del juego decide cuánto suena cada instrumento:
- **Calma:** agua y guzheng; el guzheng grave nunca baja del 35 %.
- **Activación:** entran los bongoes.
- **Recuperación:** los bongoes salen primero.

Con `false`, los tres instrumentos suenan siempre al 100 %.
