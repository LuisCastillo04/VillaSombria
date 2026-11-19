# Sistema de guardado

Cómo se guardan, validan y restauran las partidas de Villa Sombría, y cómo ampliarlo.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/autoload/save_system.gd` | Autoload `SaveSystem`: secciones, ranuras, sesión, guardado en segundo plano, autoguardado y carga |
| `scripts/save/save_file.gd` | `SaveFile`: escritura atómica con temporal y copia, lectura y borrado |
| `scripts/save/save_format.gd` | `SaveFormat`: formato, versión, validación y migraciones |
| `scenes/ui/save_slots_menu.tscn` | `SaveSlotsMenu`: lista de ranuras para guardar y cargar, usada por la pausa y el menú principal |
| `scenes/ui/save_indicator.tscn` | Autoload `SaveIndicator`: indicador animado de guardado |
| `scripts/core/game.gd` | Registra la posición del detective y restaura la partida cuando la escena está construida |

`SaveSystem` no conoce la interfaz: los menús y el indicador sólo llaman a su API y escuchan sus
señales.

## Dónde se guardan las partidas

En `user://saves/`, que en Windows es:

```text
%APPDATA%\Godot\app_userdata\Villa Sombría\saves\
```

La ruta es la misma en el editor y en el juego exportado.

| Archivo | Contenido |
| --- | --- |
| `manual_1.json` … `manual_5.json` | Ranuras manuales |
| `auto_1.json` … `auto_3.json` | Ranuras automáticas |
| `*.json.tmp` | Escritura en curso; sólo existe un instante |
| `*.json.bak` | Versión anterior mientras se sustituye; sólo queda si la escritura se interrumpió |
| `.importada_v1` | Marca de que la partida de la versión 1 ya se importó |

Las ranuras tienen identificadores fijos (`manual_N`, `auto_N`). Cualquier otro identificador se
rechaza, así que no se puede leer ni escribir fuera de esa carpeta. El número de ranuras se cambia
en `SaveSystem.MANUAL_SLOTS` y `SaveSystem.AUTO_SLOTS`.

Las pruebas y las herramientas de captura usan `user://pruebas_guardado/` y nunca tocan las
partidas del jugador.

## Formato

JSON legible con cuatro claves:

```json
{
  "format": "villa_sombria.partida",
  "version": 2,
  "meta": {"slot": "manual_2", "kind": "manual", "saved_at": 1794970477.4, "reason": "manual"},
  "sections": {
    "state": {"flags": [], "clues": [], "testimonies": [], "deductions": [], "asked_topics": [],
              "hypotheses": {}, "location_id": "mansion", "spawn_id": "desde_plaza",
              "accusation_attempts": 0, "play_seconds": 812.3},
    "clock": {"day": 2, "minutes": 870},
    "player": {"location_id": "mansion", "position": [1.2, 0.1, 5.7], "yaw": 2.0}
  }
}
```

- `meta.saved_at`: segundos Unix en UTC, con decimales. El menú lo muestra en hora local.
- `meta.reason`: por qué se guardó (`manual`, `lugar`, `pista`, `deduccion`, `evento`, `escena`,
  `interrogatorio`, `nuevo_dia`, `salida`, `importada`).
- `sections`: una entrada por sección registrada; ver [Secciones](#secciones).

Lo que aparece en los menús (lugar, día, hora, tiempo jugado, número de pistas) se deduce de las
secciones al leer el archivo; no se guarda por duplicado.

## Escritura segura

`SaveFile.write_atomic`:

1. Escribe en `ranura.json.tmp` y lo relee para comprobar que el contenido es exacto.
2. Renombra el archivo anterior a `ranura.json.bak`.
3. Renombra el temporal a `ranura.json`.
4. Borra la copia.

Si el proceso muere entre los pasos 2 y 3, la siguiente lectura restaura la copia. Si el archivo
principal está dañado pero queda una copia válida, se usa la copia.

Antes de escribir, `SaveSystem` valida el documento con las mismas reglas que al cargar: nunca se
escribe una partida que después no se podría reconstruir.

La escritura se hace en un hilo de `WorkerThreadPool`. Mientras dura, `is_busy()` es verdadero, se
rechazan otros guardados y el borrado de esa ranura, y leer esa ranura espera a que termine. Al
cerrar el juego también se espera a la escritura en curso.

## Validación y versiones

`SaveFormat.parse` devuelve un estado:

| Estado | Significado | En los menús |
| --- | --- | --- |
| `OK` | Se puede cargar | Datos de la partida |
| `EMPTY` | No hay archivo | «Vacía» |
| `CORRUPT` | JSON roto, estructura o tipos incorrectos | «Dañada»; se puede eliminar |
| `INCOMPATIBLE` | Versión más reciente o lugar que no existe en esta versión | «Incompatible»; se puede eliminar |

Se comprueban los tipos de cada campo, que el día y la hora estén en rango y que el lugar exista.
Lo recuperable se corrige sin inventar datos: se quitan pistas, testimonios o deducciones que ya no
existen en `data/`, los duplicados y las hipótesis mal formadas, y si la posición del detective no
es válida se descarta y aparece en la entrada del lugar.

**Versiones.** `SaveFormat.VERSION` es la versión actual. Cada versión antigua se convierte paso a
paso en `SaveFormat._migrate`. La versión 1 era el antiguo `user://partida.json`, con `state` y
`clock` y sin metadatos; se convierte usando la fecha de modificación del archivo y sin tiempo
jugado, porque no lo registraba.

La primera vez que se usan las ranuras, la partida de la versión 1 se copia a la primera ranura
manual libre, marcada como «importada». El archivo original no se modifica ni se borra.

## Secciones

Cada sistema aporta su parte del estado con dos funciones:

```gdscript
SaveSystem.register_section("clave", funcion_que_devuelve_un_diccionario, funcion_que_lo_recibe)
```

| Sección | Quién la registra | Contenido |
| --- | --- | --- |
| `state` | `SaveSystem`, sobre `GameState` | Marcas, pistas, testimonios, deducciones, preguntas hechas, hipótesis, lugar, intentos de acusación y tiempo jugado |
| `clock` | `SaveSystem`, sobre `GameClock` | Día y minuto del calendario |
| `player` | `Game` | Lugar, posición y orientación del detective |

Al cargar, las secciones se restauran en el orden en que se registraron. Una sección que el archivo
no incluye recibe un diccionario vacío, de modo que los sistemas nuevos arrancan con su estado por
defecto al cargar partidas antiguas.

### Qué no se guarda

Lo que se puede reconstruir a partir del estado guardado:

| Dato | Se reconstruye desde |
| --- | --- |
| Personajes y su posición | Rutinas de `schedules.json` según día y hora |
| Puertas abiertas o cerradas | Condiciones de cada salida sobre marcas y pistas |
| Objetivos y su progreso | Condiciones de `story.json` |
| Pistas ya examinadas en el escenario | `GameState.clues` |
| Escenas que no deben repetirse | Marcas que ponen las propias escenas y condiciones de `on_enter` |
| Eventos por hora ya ocurridos | Marcas `evento_*` |
| Clima, luz, música, cámara | Lugar y hora |

No se puede guardar durante una conversación, una escena o una transición, así que nunca hay que
restaurar una a medias.

## Ranuras

- **Manuales (5).** Sólo las escribe el jugador desde la pausa. Nunca se sobrescriben solas.
- **Automáticas (3).** Las escribe el autoguardado. Rotación (`SaveSystem.next_autosave_slot`):
  primero una vacía; si no hay, una dañada o incompatible; si no, la más antigua.

Las ranuras son independientes: cada archivo contiene todo lo necesario y borrar uno no afecta al
resto. Una partida nueva empieza con `GameState.reset()` y `GameClock.reset()` y no lee ninguna
ranura. Sus autoguardados comparten la rotación con los de partidas anteriores, de modo que con el
tiempo sustituyen a los más antiguos; las ranuras manuales no se tocan.

Cerrar el caso no borra ninguna partida. Después de `caso_resuelto` no se guarda, así que
«Continuar» retoma el último guardado anterior al desenlace.

## Guardado manual

Pausa → **Guardar partida** → lista de las cinco ranuras manuales → elegir ranura → **Guardar
aquí** o **Sobrescribir**.

- Sobrescribir y eliminar piden confirmación.
- Cada ranura muestra lugar, día y hora del caso, fecha del guardado, tiempo jugado y pistas.
- El resultado aparece en la lista y en el indicador.
- La acción se desactiva y se explica el motivo si `SaveSystem.get_save_blocker()` lo impide.

`get_save_blocker()` impide guardar si no hay partida en curso, ya hay una escritura, hay una
conversación o escena activa, el caso está cerrado, hay una transición o el jugador tiene abierto
cualquier panel que no sea la pausa.

**Guardar y volver al menú** hace un autoguardado con motivo `salida` y espera a que termine. Si la
escritura falla, no sale: avisa y deja salir sin guardar con una segunda pulsación.

## Guardado automático

Los autoguardados se piden con `SaveSystem.request_autosave(motivo, punto_de_control)`.
`SaveSystem` lo hace por sí mismo al recibir estos eventos:

| Evento | Motivo | Punto de control |
| --- | --- | --- |
| `EventBus.location_changed` | `lugar` | No |
| `EventBus.clue_discovered` | `pista` | No |
| `EventBus.deduction_made` | `deduccion` | No |
| `EventBus.flag_set` | `evento` | No |
| `DialogueManager.closed` sin interlocutor | `escena` | No |
| `DialogueManager.closed` con un personaje | `interrogatorio` | No |
| `EventBus.day_changed` | `nuevo_dia` | Sí |

Política:

1. Las peticiones seguidas se agrupan: se escribe `autosave_delay` (1,5 s) después de la última.
2. Entre un guardado y el siguiente autoguardado pasan al menos `autosave_min_interval` (30 s),
   salvo en un punto de control. Una petición que llega antes no se pierde: se aplaza.
3. Si el momento no es seguro (conversación, escena, transición o panel abierto), se vuelve a
   comprobar cada segundo. Con el juego en pausa la espera se detiene.
4. Si la partida no ha avanzado desde el último guardado o carga, la petición se descarta. La
   posición del detective y el tiempo jugado no cuentan como avance.
5. Sin partida en curso, o con el caso cerrado, no se guarda y lo pendiente se descarta.

## Carga y restauración

1. El menú llama a `SaveSystem.request_load(ranura)`, que lee y valida el archivo. Si falla, el
   menú muestra el motivo y no cambia nada.
2. La partida validada queda pendiente y se abre `scenes/main/game.tscn`. Desde la pausa se vuelve
   a crear la escena; si había progreso sin guardar, antes se pide confirmación.
3. `Game._ready`, con todos sus nodos ya listos:
   1. registra la sección `player`;
   2. recoge la partida con `take_pending_load()`;
   3. aplica las secciones: estado, calendario y posición pendiente;
   4. construye el escenario guardado, que coloca al detective en la entrada;
   5. aplica la posición y orientación guardadas, que así no se pierden;
   6. actualiza la interfaz y abre la sesión con `begin_session`;
   7. hace el fundido y comprueba las escenas de entrada, que no se repiten si sus marcas ya están.

**Continuar** carga la ranura válida más reciente, manual o automática (`find_latest_slot`).

## Señales y API

Señales de `SaveSystem`:

| Señal | Cuándo |
| --- | --- |
| `save_started(slot_id)` | Empieza una escritura |
| `save_finished(slot_id, ok, message)` | Termina una escritura; `message` explica el fallo |
| `slot_deleted(slot_id)` | Se eliminó una ranura |
| `slots_changed` | Cambió el contenido de alguna ranura |

`SaveSlotsMenu` emite `closed` y `load_ready(slot_id)`; quien lo abrió decide el cambio de escena.

| Función | Uso |
| --- | --- |
| `save_to_slot(id, motivo)` | Empieza a guardar; devuelve `{ok, error}` y el resultado llega con `save_finished` |
| `autosave(motivo)` | Guarda ya en la ranura automática que toca |
| `request_autosave(motivo, punto_de_control)` | Pide un autoguardado según la política |
| `read_slot(id)`, `get_slot_info(id)`, `list_slots(tipo)` | Leer sin aplicar |
| `request_load(id)`, `take_pending_load()`, `apply_sections(secciones)` | Cargar |
| `delete_slot(id)` | Eliminar |
| `find_latest_slot()` | Partida para «Continuar» |
| `get_save_blocker()`, `has_unsaved_progress()`, `is_busy()` | Estado actual |
| `begin_session(dueño)`, `end_session(dueño)` | Los llama la escena de juego |

## Cómo ampliarlo

**Una variable narrativa nueva** (una decisión, una escena vista, un objetivo): usa una marca. Los
diálogos, eventos y deducciones ya las ponen desde `data/` con `"effects": {"flags": [...]}`, y
`GameState.flags` se guarda entero. No hace falta tocar el código del guardado.

**Un sistema con estado propio**, por ejemplo un inventario con cantidades:

1. Dale `to_dict()` y `from_dict(data)`, y haz que `from_dict({})` deje el estado inicial.
2. Regístralo: un autoload declarado después de `SaveSystem` lo hace en su `_ready`, y un nodo de
   escena, en su `_ready`, retirándolo en `_exit_tree` con `unregister_section(clave, self)`.
3. Si sus datos pueden invalidar una partida, añade sus comprobaciones en `SaveFormat.validate`.
4. Si no cuenta como avance de la partida, añade su clave a `SaveSystem.NON_PROGRESS_SECTIONS`.
5. Añade una prueba de ida y vuelta en `tests/unit/test_save_slots.gd`.

**Cambiar la estructura de una sección existente:** sube `SaveFormat.VERSION` y añade en
`_migrate` el paso que convierte la versión anterior. Las partidas antiguas se seguirán cargando.

**Un punto de autoguardado nuevo:** llama a `SaveSystem.request_autosave("motivo")`, o con
`true` si debe guardarse sin esperar la separación mínima, y añade el texto del motivo a
`SaveSlotsMenu.REASON_LABELS`.

## Limitaciones conocidas

- **Cerrar la ventana no guarda.** Se conserva el último guardado; se pierde lo hecho desde el
  último autoguardado. «Guardar y volver al menú» sí guarda.
- **No se guarda a mitad de una conversación.** El autoguardado espera a que termine.
- **Los personajes no conservan su posición exacta:** reaparecen donde marca su rutina para esa
  hora, que es como funcionaba ya al cambiar de lugar.
- **La partida importada de la versión 1** no tiene tiempo jugado: se muestra «sin registrar», y el
  que se acumule después no incluye el anterior. Si las cinco ranuras manuales están ocupadas, la
  importación espera a que quede una libre.
- **Las partidas de una versión más reciente** se muestran como incompatibles y no se cargan.
- **Las ranuras no tienen nombre propio:** se identifican por número, lugar y fecha.
- **El corte durante una escritura** se ha probado simulando los archivos que quedarían, no matando
  el proceso.

## Pruebas

`tools/verificar.ps1` ejecuta todas las pruebas y, además, guarda en un proceso de Godot y carga
en otro nuevo (`tests/persistencia/reinicio.tscn`), como al cerrar y volver a abrir el juego.

| Archivo | Cubre |
| --- | --- |
| `test_save_format` | Escritura atómica, recuperación desde la copia, archivos rotos, versiones, tipos, referencias, migración |
| `test_save_slots` | Restauración completa, posición, tiempo jugado, independencia, sobrescritura, borrado, rotación, «Continuar», operaciones simultáneas, bloqueos, identificadores inválidos, importación, partida nueva limpia |
| `test_autosave` | Agrupación, descarte sin avance, espera a escenas y paneles, separación mínima, punto de control, caso cerrado, cambio de lugar real |
| `test_save_indicator` | Aparición, confirmación sólo tras éxito, fallo real de escritura, reinicio de la animación, instancia única |
| `test_save_menus` | Guardar, sobrescribir, eliminar y cargar desde la pausa y el menú principal; aviso de progreso sin guardar; ranuras vacías y dañadas |
| `test_save` | Ida y vuelta del caso, archivos dañados e incompatibles, reanudación, «Continuar» |
| `persistencia/reinicio` | Guardar, cerrar el proceso, abrir otro y cargar desde el menú principal |

La prueba de reinicio se validó con una mutación: cambiar una pista en el archivo guardado entre
las dos fases la hace fallar.

Los menús y el indicador también se revisaron con capturas:

```powershell
godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/img.png --open=save
```

Valores de `--open`: `save` y `saving`/`saved` en partida, y `load` junto con `--menu`.
