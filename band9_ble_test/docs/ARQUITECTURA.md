# Gatos en la barra — análisis y arquitectura

## A. Arquitectura detectada (antes de este cambio)

| Capa | Archivos | Estado |
|---|---|---|
| Web Bluetooth | `web/shell.html` (bloque `HEART RATE WEB BRIDGE`), `HeartRateWebBridge.gd` | Funciona. **No se tocó.** |
| Proveedores | `HeartRateProvider.gd`, `SimulatorHeartRateProvider.gd`, autoload `HeartRate` | Funciona. Se conserva. |
| Fisiología | autoload `Physio` (`PhysiologicalState.gd`) | Ya tenía: filtro, línea base, activación relativa, histéresis, tendencia y recuperación. Se conserva y se añade `state_name()`. |
| Dirección | `ArousalDirector.gd`, `StabilitySystem.gd`, `Config.gd` | Funciona. Se adaptan las salidas y las métricas. |
| Mundo | `Stall.gd`, `Cat.gd`, `Kitchen.gd`, `CounterObject.gd`, `DishArt.gd` | **Todo dibujado por código** (`_draw`), imposible de editar en el editor. |
| Audio | `MusicLayers.gd`, `Sfx.gd`, `tools/generate_audio.py` | Funciona. La armonía usaba la escala in‑sen, cuyo semitono sonaba disonante desde el inicio. |
| Diagnóstico | `Main.tscn` + `HeartRateTest.gd` | Funciona. Se conserva. |

## B. Problemas concretos

1. Los gráficos estaban en código: no se podía cambiar un asset sin tocar scripts.
2. Había tres recetas distintas (té, onigiri, dango) con mucha complejidad y poca profundidad.
3. Los pedidos eran iconos pequeños sobre fondo blanco, así que la bola blanca se perdía.
4. La "bandeja" era una mano abstracta y no estaba claro cómo entregar.
5. El inicio era una espera pasiva y el gato del ritual aparecía y desaparecía.
6. El botón "dejar ir" convertía una decisión sutil en una acción de menú.
7. Los gatos tiraban objetos decorativos, no ingredientes útiles.
8. No había forma diegética de corregir un error.
9. Había textos tipo HUD ("Respira despacio.").
10. El botón "Pausa" era un botón de sistema, no un objeto del puesto.
11. La disonancia del koto aparecía desde el inicio.
12. Los cambios de color eran demasiado pequeños para notarse.

## C. Arquitectura propuesta (implementada)

```
HEART RATE SOURCE      Huawei Band 9 → Web Bluetooth → JS (shell.html) → JavaScriptBridge
HEART RATE PROVIDER    HeartRateWebBridge.gd / SimulatorHeartRateProvider.gd → autoload HeartRate
PHYSIOLOGICAL STATE    autoload Physio: filtrado, línea base, activación, histéresis, tendencia,
                       recuperación, state_name() = CALMA/ACTIVACIÓN/PRESIÓN/TORMENTA/RECUPERACIÓN
GAME DIRECTOR          ArousalDirector → ambient_intensity · cat_activity · event_density · audio_intensity
                       StabilitySystem → estabilidad del jugador + métricas
GAMEPLAY               Manos (input) · Bandeja · Ingrediente · Bote · Clientela/Gato · Mochi · Tutorial
VISUAL                 grupo "ambiente_reactivo": Agua, Petalos, Vapor, Cortinas, Farol, Arbol, Campanilla
                       + shaders/mood.gdshader (color ambiental)
AUDIO                  MusicLayers (5 capas + ronroneo) · Sfx
```

`Game.gd` solo coordina y difunde un diccionario (`intensidad`, `tempo`, `respiracion`, `enfasis`, `alivio`) con `call_group("ambiente_reactivo", "aplicar_ambiente", …)`. **Ningún sistema del juego toca sprites de otro sistema** y ninguno llama a JavaScript.

## D. Escenas

| Escena | Contenido editable |
|---|---|
| `Game.tscn` | Composición de todo (orden de dibujo = orden de los nodos) |
| `Main.tscn` | Diagnóstico BLE (sin cambios funcionales) |
| `scenes/Puesto.tscn` | Techo, postes, Cortinas, 2 Farol, Campanilla, Tablilla |
| `scenes/Barra.tscn` | Frente de la barra, 4 Ingrediente, Vapor, Agua, cojín y **Mochi** |
| `scenes/Cocina.tscn` | Mesa, Bandeja y Bote |
| `scenes/ambiente/Ambiente.tscn` | Cielo, montañas, árbol y Petalos |
| `scenes/ambiente/Agua.tscn` | Bambú, chorro, cuenco, superficie (shader), plantillas de gota y onda |
| `scenes/ambiente/Petalos.tscn`, `Vapor.tscn`, `Cortinas.tscn`, `Farol.tscn` | Efectos reutilizables (Cortinas cumple también el papel de "Viento") |
| `scenes/dango/Dango.tscn` | Palito + BolaInferior/Central/Superior + Salsa |
| `scenes/dango/DangoBola.tscn`, `Salsa.tscn` | Piezas del dango |
| `scenes/gatos/Gato.tscn` | Cuerpo, cabeza, orejas, ojos (abiertos/cerrados), cola, patas, Pedido, Habla |
| `scenes/gatos/Pedido.tscn` | Bocadillo + un `Dango.tscn` en miniatura + "!!!" |
| `scenes/cocina/Ingrediente.tscn`, `Bandeja.tscn`, `Bote.tscn`, `Campanilla.tscn`, `Tablilla.tscn` | Objetos tocables, con la zona táctil visible en el editor |
| `scenes/Tutorial.tscn` | Huella guía |
| `scenes/ui/UI.tscn` | Título, pausa, aviso de señal, resultados y panel técnico |

## E. Scripts modificados
`Game.gd` (reescrito como coordinador), `ArousalDirector.gd` (salidas abstractas y pedidos de dango), `StabilitySystem.gd` (métricas y descartes sin castigo), `Config.gd`, `PhysiologicalState.gd` (`state_name`), `Sfx.gd`, `DebugPanel.gd`, `tools/generate_audio.py` (escala consonante) y `project.godot` (nombre).

## F. Scripts conservados sin cambios
`web/shell.html`, `HeartRateWebBridge.gd`, `HeartRateProvider.gd`, `HeartRateService.gd`, `SimulatorHeartRateProvider.gd`, `HeartRateTest.gd`, `MusicLayers.gd` y `shaders/mood.gdshader`.

**Eliminados** (sustituidos por escenas): `Stall.gd`, `Cat.gd`, `Kitchen.gd`, `CounterObject.gd`, `DishArt.gd` y los sprites de Micheladas que ya no se usan.

## G. Sistemas desacoplados
- **Asset ↔ comportamiento.**
  - Las texturas de las bolas están en `resources/dango_paleta.tres` (`DangoPalette`).
  - Petalos y Vapor tienen una `textura` exportada.
  - Cortinas anima cualquier hijo `Node2D`.
  - Agua anima su `Superficie` con un shader que funciona con cualquier textura.
- **Datos ↔ visual del dango.** `DangoData` define `{lower, middle, upper, sauce}` y `Dango.set_data()` lo representa. El pedido y el dango construido usan el mismo diccionario y se comparan con `DangoData.equals`.
- **Director ↔ mundo.** El director solo publica valores entre 0 y 1; cada sistema decide cómo se ven.
- **Input ↔ gameplay.** `Manos.gd` traduce los toques y arrastres en acciones; los objetos solo exponen `hit()` y métodos de estado.

## H. Orden de implementación seguido
1. Arquitectura visual: arte en PNG individuales + escenas.
2. Sistema de dango modular (`Dango`, `DangoBola`, `Salsa`, paleta).
3. Pedidos con `Dango.tscn` en miniatura.
4. Bandeja con hueco siguiente, brillo de "listo", patas del gato y entrega por arrastre o toque.
5. Ritual + tutorial con Mochi y la huella.
6. Bote: descarte tranquilo, sin castigo.
7. Gatos: travieso que tira ingredientes reales, falsa urgencia con tiempo de sobra, sin botón "dejar ir".
8. Recuperación por no actuar (se conserva y se conecta a todo).
9. Ambiente fisiológico: agua, viento, pétalos, vapor, telas y faroles.
10. Audio: inicio consonante y disonancia leve solo en la capa de tormenta.
11. Color/saturación con rangos perceptibles.
12. Pulido UX: fuera los textos HUD; tablilla = pausa y campanilla = regulación.
13. Resultados centrados en estabilidad y recuperación.

Después de cada fase se ejecutaron la importación headless y `tests/SmokeTest.tscn`, que juega la partida entera.
