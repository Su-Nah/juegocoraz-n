# Gatos en la barra

Un pequeño puesto japonés de dangos con gatos en la barra. Es una experiencia de autorregulación con biofeedback: **no puedes controlar el mundo, pero puedes influir en tu respuesta ante él.** La única señal fisiológica es la frecuencia cardíaca de la Huawei Band 9:

```
Huawei Band 9 → BLE → Edge/Chrome (Web Bluetooth) → JavaScript (web/shell.html) → JavaScriptBridge
 → HeartRate → Physio → ArousalDirector + StabilitySystem → gameplay · ambiente · audio
```

No mide la respiración ni interpreta el BPM como ansiedad. Durante la partida el BPM no aparece en pantalla. El análisis completo de la arquitectura (puntos A–H) está en **`docs/ARQUITECTURA.md`**.

---

## Cómo se juega

1. Un gato pide un dango. El bocadillo muestra **el dango mismo**: tres bolas de abajo arriba y salsa si la quiere.
2. Arrastra (o toca) los cuencos de la barra: cada bola cae en el **hueco que brilla** de la bandeja (abajo → medio → arriba).
3. La olla añade **salsa**.
4. Con el dango completo, la bandeja brilla y los gatos **miran y estiran las patas**; el que lo quiere se ilusiona más. Arrastra la bandeja hasta él (o tócala).
5. ¿Salió mal? Llévalo al **bote**: la tapa se abre, cae y se cierra. Sin error, sin castigo. Haz otro.
6. La **campanilla** colgada del techo sirve para regular: durante unos segundos no produces, el mundo sigue, el puesto respira más amplio y Mochi respira contigo.
7. La **tablilla** de la derecha (o Esc) es la pausa real del juego.

**Ritual (~30 s).** Antes de abrir, Mochi, el gato compañero, te pide su dango tradicional. Una huella señala qué tocar. Mientras tanto se mide tu pulso de referencia, sin esperas, sin clientes y sin puntos. Mochi se queda toda la partida.

**Fases (~10 min).** Tranquilidad → Ritmo → Presión → Tormenta controlada → Recuperación → Prueba final → Cierre.

---

## Editar los gráficos sin tocar código

| Quiero cambiar… | Dónde |
|---|---|
| Bola verde, blanca o rosa, o la salsa | `resources/dango_paleta.tres` en el Inspector, o sobrescribe `assets/art/dango/*.png`. Afecta a **todos** los dangos, pedidos y cuencos. |
| Palito, sombra | `scenes/dango/Dango.tscn` / `DangoBola.tscn` |
| Posición de las bolas en el palito | Mueve `BolaInferior/Central/Superior` en `Dango.tscn` (la salsa está en `Salsa.tscn`) |
| Bandeja, huecos, brillo | `scenes/cocina/Bandeja.tscn` |
| Cuencos, olla de salsa | `scenes/cocina/Ingrediente.tscn` (propiedad `textura_recipiente` en cada instancia de `Barra.tscn`) |
| Bote y su tapa | `scenes/cocina/Bote.tscn` (la tapa gira desde el nodo `Tapa`) |
| Gatos | `scenes/gatos/Gato.tscn`. Las partes son PNG **blancos** que el script tiñe; los colores son pares `[base, mancha]` en `paletas` (Inspector). |
| Bocadillo del pedido | `scenes/gatos/Pedido.tscn` |
| Agua | `scenes/ambiente/Agua.tscn`. Cambia la textura de `Superficie` (el shader `agua.gdshader` la ondula, sea cual sea), `Chorro`, `Gota` u `Onda`. |
| Pétalos | `scenes/ambiente/Petalos.tscn`: `textura`, área, ritmos y viento en el Inspector |
| Telas / viento | `scenes/ambiente/Cortinas.tscn`: duplica, mueve o cambia las telas; el viento anima cualquier hijo |
| Vapor, faroles | `Vapor.tscn` y `Farol.tscn` |
| Disposición del puesto | `Puesto.tscn`, `Barra.tscn`, `Cocina.tscn`, `Ambiente.tscn` |
| Zonas táctiles | Propiedades `hit_size` / `hit_offset`; en el editor se ven como un rectángulo naranja |
| Textos y paneles | `scenes/ui/UI.tscn` |
| Tiempos, umbrales, dificultad, mezcla musical | `scripts/core/Config.gd` |

`tools/generate_art.py` y `tools/generate_audio.py` solo generan los placeholders; no hace falta volver a ejecutarlos.

---

## Sistemas

### Biofeedback (se conserva)
`Physio` aplica un filtro de 5 s y calcula la activación **relativa a tu línea base**, con 4 niveles e histéresis. Subir de nivel pide **8 s** sostenidos y bajar **6 s** (`RISE_CONFIRM`, `FALL_CONFIRM` en `Config.gd`). Un salto aislado de más de 35 BPM se descarta. La recuperación se reconoce por la **tendencia** de bajada, sin exigir volver a la línea base.

`state_name()` devuelve CALMA, ACTIVACIÓN, PRESIÓN, TORMENTA o RECUPERACIÓN.

### Director (salidas abstractas)
`ArousalDirector` publica cuatro valores y cada sistema decide cómo representarlos:

| Salida | Qué gobierna |
|---|---|
| `ambient_intensity` | agua, viento, pétalos, vapor, telas, faroles, color |
| `cat_activity` | inquietud de los gatos (tope 0.85: nunca enemigos) |
| `event_density` | llegadas y eventos |
| `audio_intensity` | capas de música |

- **La dificultad tiene límites:**
  - sube un escalón solo tras 14 s estable;
  - con activación de nivel 3 **no sube**;
  - si ese nivel se sostiene 10 s, **protege** (baja la presión).
- **La recuperación da un `alivio` real:** llegadas más espaciadas, más paciencia, menos eventos, animaciones más lentas, menos capas y color más suave.
- **La complejidad de los pedidos es gradual:**
  - primero el dango tradicional (con o sin salsa);
  - después las permutaciones de los tres colores;
  - después cualquiera de las 54 combinaciones;
  - con más pedidos simultáneos según la fase.

### Gatos
- **Normal.**
- **Impaciente:** cola rápida y más maullidos.
- **Travieso:** mira un cuenco de la barra y lo tira.
  - El ingrediente **queda inutilizable**: o lo recoges, o **vuelve solo en 10 s** (podía esperar).
  - Después tiene **25 s de cooldown** antes de poder caer otra vez.
- **Falsa urgencia:** "¡MIAU MIAU!" con "!!!", pero su pedido tiene **más** paciencia que el resto. Si no reaccionas se calma sola.

**Ninguno tiene botón "dejar ir"**: si esperas, el gato se va con un "..." y ya. Con estabilidad alta los gatos cierran los ojos, se acomodan y ronronean.

### Mochi, el compañero
Enseña en el ritual, se queda en su cojín y se deja acariciar. Si tu activación se mantiene alta 12 s, **modela la calma**: se sienta, cierra los ojos, respira lento, ronronea y a veces dice "Despacio..." o "Puedes tomarte tu tiempo.". Lo hace como mucho cada 45 s.

### Recuperación por no actuar
Si no tocas nada durante 4 s, la estabilidad sube. No aparece ningún texto: lo notas en los gatos, la música y el agua.

### Estabilidad
**Suma** con:
- descansos y la campanilla
- la recuperación fisiológica
- dejar que la falsa urgencia se calme sola
- dejar que un ingrediente vuelva solo
- aceptar que un gato se vaya cuando no estabas frenético

**Resta** con:
- clics frenéticos
- muchos estímulos a la vez
- activación alta sostenida

**El bote nunca resta.**

### Ambiente que respira
`Game.gd` difunde `intensidad`, `tempo`, `respiracion` (ciclo lento de 10 s), `enfasis` y `alivio` a todos los nodos del grupo `ambiente_reactivo`:

| Elemento | Calma | Activación / presión |
|---|---|---|
| Agua | superficie casi lisa | ondas más rápidas y amplias, chorro más grueso |
| Pétalos | pocos y lentos | más pétalos, más viento |
| Telas | balanceo amplio y lento | más rápido |

Los faroles y el vapor siguen el ciclo de respiración. **Cada latido es una gota** que cae al cuenco con su onda y un "plim" suave. No hay flashes.

### Color
El shader `mood.gdshader` mueve juntos saturación, contraste, brillo, matiz y viñeta:
- **Calma:** pastel luminoso.
- **Presión:** más saturación y contraste, y luz más dorada.
- **Recuperación:** vuelve y se abre.

No es "azul = calma / rojo = ansiedad".

### Audio
- **Música:** pieza dinámica en 4/4 con Guzheng grave, Guzheng agudo y Bongoes (4 frases cada uno), todos con **un solo reloj musical**. Lleva programación anticipada, pool de voces y caché.
- **Gotas de agua:** sincronizadas al pulso.
- **Separados del reloj musical:** el ambiente y la tormenta (bus Ambient) y los maullidos y ronroneos variados (bus SFX).

Todo se configura en **`scripts/music/MusicConfig.gd`**: BPM, aleatorización por instrumento, gotas, volúmenes y depuración. La documentación completa está en **`docs/MUSICA.md`**.

### Resultados (métricas del juego, no clínicas)
- estabilidad, mostrada con gotas
- dangos preparados
- gatos atendidos
- gatos que siguieron su camino
- momentos de recuperación y tiempo para volver a la calma
- tiempo bajo presión sin desbordarse
- cosas que dejaste pasar
- veces que te detuviste
- dangos al bote
- pulso de referencia

Cierra con "No necesitabas atenderlo todo."

---

## Ejecutar y probar

**Editor (Godot 4.3+):** F5 → *Simulador (desarrollo)* → *Abrir el puesto*.
- **F3:** panel técnico (BPM, línea base, estado, salidas del director, capas).
- **F1:** secuencia de BPM simulada. **F2:** pararla. **+ / −:** ajustar el BPM simulado.

**Pruebas de música:** `godot --headless -s res://tests/MusicTests.gd` (ritmo, tempo, sincronización, aleatorización, pausa, carga) y `godot --headless -s res://tests/MusicRealtime.gd` (30 s en tiempo real).

**Prueba automática:** `godot --headless res://tests/SmokeTest.tscn`. Juega la partida completa con un bot que construye dangos (por toques y arrastres), se equivoca y usa el bote, toca la campanilla y deja ir gatos. Debe terminar en `SMOKE OK`.

**Web local con la Band 9:**
1. Activa la difusión de FC en la pulsera (ver `docs/BLE_TEST.md`).
2. *Proyecto → Exportar → Web* → `build/web/`.
3. Sírvelo en `localhost` y ábrelo en **Edge**.
4. *Conectar Huawei Band 9* → elegir la pulsera → *Abrir el puesto*.

**Netlify (HTTPS):** arrastra `build/web/` a *Deploy manually*. La exportación es de un solo hilo y no usa iframe, así que no hace falta configurar cabeceras.

**Diagnóstico BLE:** botón en el título o en el menú de pausa. Conserva la conexión al volver.
