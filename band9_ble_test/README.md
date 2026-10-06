# Band 9 BLE Test — prototipo aislado

Prueba mínima e independiente (no toca el juego principal) de la cadena:

```
Huawei Band 9 → Bluetooth LE → Web Bluetooth API → JavaScript → JavaScriptBridge → GDScript → BPM en pantalla
```

Sin servidores, sin analytics, sin APIs externas, sin cuentas y sin almacenamiento: todo ocurre en memoria entre la pulsera, el navegador y Godot.

## Estructura

```
band9_ble_test/
├── project.godot              Godot 4.3+, renderer Compatibility (WebGL 2)
├── export_presets.cfg         Preset "Web": single-thread, shell personalizado
├── Main.tscn                  Escena principal (Control + HeartRateTest.gd)
├── scripts/
│   ├── HeartRateTest.gd       Interfaz. No conoce APIs JavaScript.
│   └── providers/
│       ├── HeartRateProvider.gd             Base: señal heart_rate_received(bpm),
│       │                                    connect_device(), disconnect_device(),
│       │                                    is_available(), get_connection_status()
│       ├── HeartRateWebBridge.gd            Proveedor REAL: envuelve JavaScriptBridge
│       └── SimulatorHeartRateProvider.gd    Proveedor SIMULADO (independiente)
└── web/
    └── shell.html             Shell HTML de Godot + bridge Web Bluetooth (JS)
```

- **Todo el código Web Bluetooth** está en `web/shell.html`, en el bloque `HEART RATE WEB BRIDGE`, que expone `window.HeartRateWebBridge` (`setCallbacks`, `connectDevice`, `disconnectDevice`, `isAvailable`, `getConnectionStatus`, `getDiagnostics`).
- El JS va **dentro** del shell (y no en un `.js` aparte) porque Godot solo copia a la exportación el shell HTML, no otros archivos. Así el export es exactamente `index.html` + los archivos que genera Godot.
- `HeartRateWebBridge.gd` usa `JavaScriptBridge.get_interface()` y `JavaScriptBridge.create_callback()`. JS llama a esos callbacks con cada BPM, cada cambio de estado, cada línea de log y cada actualización del diagnóstico (JSON).
- Real y simulado tienen **paneles, contadores y colores separados** (verde = real de la Band 9, naranja = SIMULADO). Nunca se mezclan.

### Detalles Bluetooth

- No hay conexión automática: `requestDevice()` solo se ejecuta al pulsar **CONECTAR HUAWEI BAND 9**.
- Filtro: `services: ['0000180d-0000-1000-8000-00805f9b34fb']` (Heart Rate Service).
- Característica: `00002a37-0000-1000-8000-00805f9b34fb` (Heart Rate Measurement), con `startNotifications()`.
- Decodificación estándar: byte 0 = flags; bit 0 = 0 → BPM en UINT8 (byte 1); bit 0 = 1 → BPM en UINT16 little-endian (bytes 1–2).
- Al conectar se listan en el diagnóstico **todos los servicios y características accesibles** (con propiedades read/write/notify/indicate).
- Botón extra **"Explorar todos los dispositivos (diagnóstico)"**: usa `acceptAllDevices: true`. Sirve si la Band 9 no aparece con el filtro HR (por ejemplo, si no está anunciando el servicio 0x180D). Nota: Web Bluetooth solo permite ver servicios incluidos en `filters`/`optionalServices`; los servicios propietarios de Huawei no se listarán salvo que se añadan sus UUID a `OPTIONAL_SERVICES` en `shell.html`.
- Si tras activar notificaciones pasan 10 s sin datos, se muestra el error `NO_NOTIFICATIONS`.

## Requisito previo en la Band 9

La Band 9 solo expone el servicio de frecuencia cardíaca estándar si está activada la difusión: en la pulsera, **Ajustes → (Frecuencia cardíaca / Difusión de FC / "HR Data Broadcasts") → activar**. El nombre exacto del menú depende del firmware. Mientras está activa, la pulsera mide continuamente y anuncia el servicio 0x180D. Si no está activada, el selector no la mostrará con el filtro HR.

## Instalación y exportación

1. Instala **Godot 4.3 o posterior** (versión estándar, no .NET).
2. En Godot: *Importar* → selecciona `band9_ble_test/project.godot`.
3. *Editor → Administrar plantillas de exportación* → descarga las plantillas de tu versión.
4. *Proyecto → Exportar…* → preset **Web** (ya configurado):
   - Custom HTML Shell: `res://web/shell.html`
   - Thread Support: **desactivado** (single-thread: no requiere cabeceras COOP/COEP, imprescindible para itch.io y hosting simple; no hay razón técnica para usar hilos aquí)
   - Extensions Support: desactivado
   - Ruta: `build/web/index.html`
5. *Exportar proyecto* (desmarca "Export With Debug" para el build final si quieres).

JavaScriptBridge viene incluido en las plantillas Web oficiales; no hay que activar nada más.

## Errores posibles y qué significan

| Código (en "Último error") | Significado |
|---|---|
| `NO_WEB_BLUETOOTH` | **El navegador no soporta Web Bluetooth** (Firefox, Safari, iOS, o Chrome con la función deshabilitada). |
| `INSECURE_CONTEXT` | La página no se sirve por HTTPS ni `localhost` (p.ej. `http://192.168.x.x`). |
| `PERMISSIONS_POLICY` | **El navegador soporta Web Bluetooth, pero el iframe/página (itch.io) no permite `bluetooth`**. Se detecta con `document.permissionsPolicy/featurePolicy.allowsFeature('bluetooth')` o por un `SecurityError` de `requestDevice()`. |
| `ADAPTER_UNAVAILABLE` | Bluetooth del ordenador apagado o sin adaptador. |
| `USER_CANCELLED` | Se cerró el selector o no había ningún dispositivo compatible (estado vuelve a Desconectado). |
| `PERMISSION_DENIED` | El navegador o el sistema operativo denegó el permiso Bluetooth. |
| `GATT_CONNECT_FAILED` | Se eligió la pulsera pero no se pudo abrir la conexión GATT (fuera de alcance, ya conectada a otro equipo, etc.). |
| `SERVICE_NOT_FOUND` | **La Band 9 fue encontrada pero no expone el servicio esperado (0x180D)**. Revisa la lista de servicios descubiertos. |
| `CHAR_NOT_FOUND` | Existe el servicio HR pero no la característica 0x2A37. |
| `NOTIFY_UNAVAILABLE` | La característica no admite notificaciones o `startNotifications()` falló. |
| `NO_NOTIFICATIONS` | **La conexión funciona pero no llegan notificaciones** (10 s sin datos tras activarlas). |
| `DEVICE_DISCONNECTED` | La pulsera se desconectó sin que el usuario pulsara Desconectar (alcance, batería, difusión desactivada). |
| `UNKNOWN` | Cualquier otro error; se muestra `name: message` original del navegador. |

Además, el panel muestra siempre `Web Bluetooth disponible`, `Contexto seguro`, `Dentro de iframe` y `Permissions Policy 'bluetooth'`, que permiten distinguir los casos aunque aún no se haya pulsado Conectar.

## PRUEBAS

### PRUEBA 1 — Editor
1. Abre el proyecto en Godot y pulsa **F5**.
2. Debe aparecer la interfaz sin errores en la consola *Salida/Depurador*.
3. El diagnóstico mostrará `JavaScriptBridge: NO disponible` y en los mensajes "No es una exportación Web…": **es lo esperado** (Bluetooth solo funciona en la exportación Web).
4. Pulsa **SIMULAR BPM**: el panel naranja "(SIMULADO)" debe mostrar el valor del SpinBox una vez por segundo; cambia el valor y comprueba que se actualiza. El panel verde REAL debe seguir en `— BPM`.

### PRUEBA 2 — Web local (localhost)
1. Exporta a `build/web/`.
2. Sirve la carpeta en localhost (contexto seguro). Cualquiera de estas opciones:
   - Desde el editor: botón **Ejecutar en navegador** (icono HTML5 arriba a la derecha) — usa `http://localhost:8060`.
   - O con cualquier servidor estático, p.ej. `cd build/web && python3 -m http.server 8000` y abrir `http://localhost:8000` (solo como servidor de archivos de prueba; no forma parte de la cadena).
3. Abre en **Chrome o Edge** de escritorio actualizado (Windows, macOS, Linux o ChromeOS) o Chrome Android.
4. Comprueba en el diagnóstico: `Web Bluetooth disponible: Sí`, `Contexto seguro: Sí`, `Dentro de iframe: No`.
5. Activa la difusión de FC en la Band 9 (ver arriba).
6. Pulsa **CONECTAR HUAWEI BAND 9** → estado `Buscando dispositivo...` → aparece el **selector Bluetooth del navegador** → elige "HUAWEI Band 9-xxx".
7. Estado `Conectando...` → `Conectado`; en el diagnóstico aparecen servicios (incluido `0000180d-…`) y características (incluido `00002a37-… [notify]`), `Notificaciones: activadas`.
8. El número verde debe cambiar solo (p. ej. 72 → 71 → 73…), el contador "Actualizaciones recibidas" debe crecer y "hace X s" debe volver a ~0 en cada medición.
9. Pulsa **DESCONECTAR** → estado `Desconectado`, el BPM vuelve a `—`.

Para servir por HTTPS en la red local en lugar de localhost necesitas un certificado de confianza; con `http://IP` obtendrás `INSECURE_CONTEXT`.

### PRUEBA 3 — Navegadores
| Navegador | Esperado |
|---|---|
| Chrome / Edge escritorio (Win/macOS/ChromeOS) | Soportado. |
| Chrome / Edge Linux | Soportado, pero puede requerir activar `chrome://flags/#enable-experimental-web-platform-features` y BlueZ actualizado. |
| Chrome Android | Soportado (requiere permisos de Bluetooth/ubicación cercanos para Chrome). |
| Opera / Brave | Basados en Chromium; Brave lo desactiva por defecto (`brave://flags/#brave-web-bluetooth-api`). |
| Firefox, Safari, cualquier navegador iOS | `NO_WEB_BLUETOOTH`. |

Anota versión de navegador (aparece en el diagnóstico) y resultado de cada paso.

### PRUEBA 4 — itch.io
1. Comprime **el contenido** de `build/web/` (con `index.html` en la raíz del ZIP).
2. itch.io → *Upload new project* → *Kind of project*: **HTML** → sube el ZIP → marca *This file will be played in the browser*.
3. Opciones de embed: tamaño 1100×760 (o activa *Fullscreen button*). **No** marques *SharedArrayBuffer support* (no es necesario: export single-thread).
4. Guarda (puede ser borrador/privado) y abre la página del juego en Chrome/Edge.
5. Observa el diagnóstico **antes** de pulsar nada: `Dentro de iframe: Sí` y el valor de `Permissions Policy 'bluetooth'`.
6. Pulsa **CONECTAR HUAWEI BAND 9** y registra exactamente qué pasa. Abre también DevTools (F12 → Console) y copia cualquier error de Permissions Policy.

Resultado esperado probable: el juego de itch.io se ejecuta en un iframe de otro origen (`*.hwcdn.net` / `html-classic.itch.zone`) y, salvo que itch.io incluya `allow="bluetooth"` en ese iframe, Chrome bloquea el acceso → `PERMISSIONS_POLICY`. El prototipo **no intenta esquivarlo**; muestra el error tal cual. Si ocurre, la conclusión es que Web Bluetooth no es viable embebido en itch.io y habría que hospedar el build en una página propia con HTTPS (GitHub Pages, Netlify…) o abrirlo fuera del iframe.

## RESULTADO DE LA PRUEBA

| Etapa | Se considera exitosa si… |
|---|---|
| Editor | La escena arranca sin errores de script y el simulador muestra BPM naranjas marcados "SIMULADO" que siguen al SpinBox. |
| Shell / JavaScriptBridge | En el navegador, el log muestra `Bridge listo. Web Bluetooth=Sí…` (prueba que JS → Godot funciona) y **no** aparece "window.HeartRateWebBridge no existe". |
| Web Bluetooth | `Web Bluetooth disponible: Sí`, `Contexto seguro: Sí`. |
| Selector | Al pulsar Conectar aparece el selector nativo del navegador y lista la Band 9. |
| Conexión BLE | Estado `Conectado`; aparecen servicios/características y `0000180d…` / `00002a37… [notify]`. |
| Notificaciones | `Notificaciones: activadas (recibiendo)`; no aparece `NO_NOTIFICATIONS`. |
| Entrega a Godot | El BPM verde grande cambia solo (72, 71, 73, 74, 72…) sin recargar, el contador sube y "Última actualización" se reinicia con cada medición. Los valores coinciden con los del log JS (`HR #n: … BPM`). |
| itch.io | Éxito = mismo comportamiento que en local. Resultado igualmente válido (negativo) = `PERMISSIONS_POLICY` con el mensaje exacto, que confirma que el bloqueo es del iframe y no del navegador ni de la pulsera. |

**Criterio principal:** Conectar → selector → Band 9 → conexión BLE → mediciones en JS → JavaScriptBridge → GDScript → BPM actualizándose continuamente en la interfaz Godot.
