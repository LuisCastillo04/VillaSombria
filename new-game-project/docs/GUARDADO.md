# Sistema de guardado

Cómo se guardan, validan y restauran las partidas de Villa Sombría, cómo funciona la ranura
activa, qué pasa al cerrar el juego y cómo ampliarlo.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/autoload/save_system.gd` | Autoload `SaveSystem`: secciones, ranuras, ranura activa, flujo único de escritura, autoguardado y carga |
| `scripts/autoload/exit_manager.gd` | Autoload `ExitManager`: cierre controlado (X, Alt + F4, botones de salida) |
| `scripts/save/save_file.gd` | `SaveFile`: escritura atómica de texto y de bytes, lectura, borrado y huellas SHA-256 |
| `scripts/save/save_format.gd` | `SaveFormat`: formato, versión, validación y migraciones |
| `scripts/save/save_preview.gd` | `SavePreview`: imagen real de la escena para cada ranura |
| `scenes/ui/save_slots_menu.tscn` | `SaveSlotsMenu`: expediente de guardar y cargar, usado por la pausa, el menú principal y la salida |
| `scenes/ui/save_slot_row.tscn` | `SaveSlotRow`: una ranura del expediente |
| `scripts/ui/case_file_*.gd`, `case_stamp.gd`, `title_flourish.gd` | Estilo y adornos del expediente |
| `scenes/ui/save_indicator.tscn` | Autoload `SaveIndicator`: indicador animado de guardado |
| `scripts/core/game.gd` | Registra la posición del detective y la cámara para las imágenes, y restaura la partida con la escena ya construida |

`SaveSystem` no conoce la interfaz: los menús, el indicador y `ExitManager` sólo llaman a su API
y escuchan sus señales.

## Dónde se guardan las partidas

En `user://saves/`, que en Windows es:

```text
%APPDATA%\Godot\app_userdata\Villa Sombría\saves\
```

La ruta es la misma en el editor y en el juego exportado.

| Archivo | Contenido |
| --- | --- |
| `manual_1.json` … `manual_5.json` | Las cinco ranuras |
| `manual_N.jpg` | Imagen de la partida de esa ranura |
| `ranura_activa.cfg` | Ranura activa y huella de su versión, para la sesión siguiente |
| `*.tmp`, `*.bak` | Escritura en curso o interrumpida; sólo existen un instante |
| `.importada_v1`, `.importada_auto` | Marcas de que ya se importaron partidas de versiones anteriores |
| `auto_1.json` … `auto_3.json` | Autoguardados de la versión anterior; se conservan sin tocar |

Las ranuras se llaman `manual_N` por compatibilidad con las partidas ya guardadas, aunque hoy
reciben tanto guardados manuales como automáticos. Cualquier otro identificador se rechaza, así
que no se puede leer ni escribir fuera de la carpeta. El número de ranuras está en
`SaveSystem.SLOT_COUNT`.

Las pruebas y las herramientas usan `user://pruebas_guardado/` y nunca tocan las partidas del
jugador.

## La ranura activa

Es la única fuente de verdad sobre a qué ranura pertenece la partida en curso:

- **Guardar con éxito** en una ranura (a mano, en un autoguardado o al salir) la convierte en la
  activa.
- **Cargar** una ranura la convierte en la activa.
- **Empezar una partida nueva** deja la partida sin ranura activa.
- **Eliminar** la ranura activa la libera.
- **Seleccionar o leer** ranuras en un menú no cambia nada.

Se guarda en `ranura_activa.cfg` junto con la huella (`save_id`) de la versión del archivo que
conoce el juego. **Continuar** retoma la ranura activa si sigue siendo válida y, si no, la
partida más reciente.

Antes de sobrescribir la ranura activa sin que el jugador la haya elegido (autoguardado o
salida), `SaveSystem.check_active_slot()` comprueba que en disco siga esa versión. Si la ranura
está dañada o la cambió otro proceso, deja de ser la activa y no se escribe en ella. Las partidas
anteriores a la huella no la tienen y se aceptan igualmente.

## Un solo flujo de escritura

El guardado manual (`save_to_slot`), el autoguardado (`autosave`) y el guardado al salir
(`save_for_exit`) terminan en `_begin_write`. Sólo cambian la ranura de destino y el origen que
se anota en los metadatos:

1. Se toma el estado de todas las secciones y se valida con las mismas reglas que al cargar:
   nunca se escribe una partida que no se podría reconstruir.
2. Se marca la escritura en curso (`is_busy()`) y se emite `save_started`.
3. Se fotografía la escena (ver [Imágenes](#imágenes-de-las-partidas)); tarda dos fotogramas.
4. Un hilo de `WorkerThreadPool` escribe primero la imagen y después la partida, ambas de forma
   atómica: temporal, relectura, copia de la versión anterior y sustitución.
5. Se emite `save_finished(ranura, ok, mensaje)`. Si salió bien, la ranura pasa a ser la activa.

Mientras hay una escritura, las demás se rechazan (guardado manual), se reintentan
(autoguardado) o esperan (salida); nunca hay dos a la vez. Leer la ranura que se está escribiendo
espera a que termine, y al cerrar el juego también se espera.

## Formato

JSON legible:

```json
{
  "format": "villa_sombria.partida",
  "version": 2,
  "meta": {
    "slot": "manual_2", "kind": "auto", "reason": "pista",
    "saved_at": 1794970477.4, "save_id": "9f2c41d07a1be3c5",
    "preview": {"file": "manual_2.jpg", "sha256": "…64 cifras hexadecimales…"}
  },
  "sections": {
    "state": {"flags": [], "clues": [], "testimonies": [], "deductions": [], "asked_topics": [],
              "conversations": {"elena/coartada": {"variants": {"base": {"count": 1, "order": 0,
                                "day": 1, "minutes": 620, "gained": {"testimonies": ["t_elena_jaqueca"]}}}}},
              "seen_topics": ["elena/coartada#base"],
              "hypotheses": {}, "accusation_draft": {"suspect": "anselmo"},
              "location_id": "mansion", "spawn_id": "desde_plaza",
              "accusation_attempts": 0, "play_seconds": 812.3},
    "clock": {"day": 2, "minutes": 870},
    "player": {"location_id": "mansion", "position": [1.2, 0.1, 5.7], "yaw": 2.0}
  }
}
```

- `kind`: origen del último guardado, `manual` o `auto` (autoguardado y salida).
- `reason`: `manual`, `lugar`, `pista`, `deduccion`, `evento`, `escena`, `interrogatorio`,
  `nuevo_dia`, `salida` o `importada`.
- `saved_at`: segundos Unix en UTC; el menú los muestra en hora local.
- `save_id` y `preview` son opcionales: las partidas anteriores no los tienen y siguen siendo
  válidas, sin cambiar la versión del formato.
- `accusation_draft` también es opcional: guarda, con identificadores, lo último elegido en cada
  campo de la acusación. Al cargar se descarta lo que ya no vale y, si falta o está dañado, el
  formulario empieza vacío; ver [ACUSACION.md](ACUSACION.md#guardado).
- `conversations` y `seen_topics` también lo son: el registro de los interrogatorios (qué pregunta y
  variante se completó, cuántas veces, cuándo y qué entregó) y lo que ya apareció en cada menú. Las
  partidas anteriores los rehacen con `asked_topics` y lo que tienen, sin inventar conversaciones;
  ver [DIALOGOS_INTELIGENTES.md](DIALOGOS_INTELIGENTES.md#guardado).

Lo que muestra el expediente (lugar, día, hora, tiempo de juego, pistas) sale de las secciones;
no se guarda por duplicado.

## Validación, versiones y compatibilidad

`SaveFormat.parse` devuelve `OK`, `EMPTY`, `CORRUPT` o `INCOMPATIBLE` (versión más reciente o
lugar que ya no existe). Se comprueban tipos y rangos, y lo recuperable se corrige sin inventar
datos: se quitan pistas, testimonios o deducciones que ya no existen, la posición inválida se
descarta (el detective aparece en la entrada) y una referencia de imagen dudosa se ignora. Si el
archivo principal no sirve pero queda una copia de una escritura interrumpida, se usa la copia.

**Versiones anteriores.** Cada versión se convierte paso a paso en `SaveFormat._migrate`. La
primera vez que se usan las ranuras:

- la partida de la versión 1 (`user://partida.json`) se copia a la primera ranura libre;
- de los autoguardados de la versión anterior (`auto_N.json`), el más reciente y válido se copia
  a la primera ranura libre.

Las copias se marcan como importadas y los archivos originales no se modifican ni se borran.

## Secciones

```gdscript
SaveSystem.register_section("clave", funcion_que_devuelve_un_diccionario, funcion_que_lo_recibe)
```

| Sección | Quién la registra | Contenido |
| --- | --- | --- |
| `state` | `SaveSystem`, sobre `GameState` | Marcas, pistas, testimonios, deducciones, preguntas hechas y su registro, preguntas vistas, hipótesis, borrador de la acusación, lugar, intentos de acusación, tiempo jugado |
| `clock` | `SaveSystem`, sobre `GameClock` | Día y minuto del calendario |
| `player` | `Game` | Lugar, posición y orientación del detective |
| `map` | `TownMap` | Lugares del mapa que el detective ya ha pisado; ver [MAPA.md](MAPA.md#guardado) |

El juego no tiene un inventario aparte: las pistas del expediente cumplen esa función y se
guardan en `state`. Al cargar, las secciones se restauran en el orden en que se registraron; una
sección que el archivo no incluye recibe un diccionario vacío.

### Qué no se guarda

Lo que se reconstruye a partir del estado guardado: la posición de los personajes (sus rutinas),
las puertas (condiciones sobre marcas y pistas), los objetivos (condiciones de `story.json`), las
pistas ya examinadas en el escenario, las escenas que no deben repetirse y los eventos por hora ya
ocurridos (marcas), y el clima, la luz, la música y la cámara (lugar y hora).

## Guardado manual

Pausa (Esc) → **Guardar partida** → expediente «GUARDAR PARTIDA» → elegir ranura → **Guardar**.

- Si la ranura está ocupada, se pide confirmación antes de sustituirla.
- La ranura en la que se guarda pasa a ser la activa: los autoguardados siguientes van a ella.
- La acción se desactiva, con el motivo, si `get_save_blocker()` lo impide: sin partida en curso,
  con una escritura en marcha, en una conversación o escena, en una transición, con un panel
  abierto o con el caso cerrado.

## Guardado automático

`SaveSystem` pide un autoguardado (`request_autosave`) en estos eventos:

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

1. Escribe **sólo en la ranura activa**, nunca crea ranuras ni toca otras.
2. Agrupa las peticiones seguidas: escribe `autosave_delay` (1,5 s) después de la última.
3. Deja `autosave_min_interval` (30 s) desde el último guardado, salvo en un punto de control.
4. Espera a un momento seguro (sin conversación, escena, transición ni panel abierto); en pausa
   la espera se detiene.
5. Descarta la petición si la partida no avanzó (la posición y el tiempo jugado no cuentan).
6. **Sin ranura activa** no escribe en ninguna: avisa una vez por sesión de que hay que guardar en
   una ranura (Esc › Guardar partida). La pausa también lo indica.

## Cerrar el juego: X, Alt + F4 y botones de salida

`ExitManager` desactiva `SceneTree.auto_accept_quit` y atiende `NOTIFICATION_WM_CLOSE_REQUEST`,
por donde llegan la X de la ventana y Alt + F4. «Salir» del menú principal, «Guardar y volver al
menú» de la pausa y la vuelta al menú tras cerrar el caso llaman a `ExitManager.request_exit`,
porque `SceneTree.quit()` no genera una petición de cierre.

1. Las peticiones repetidas se ignoran mientras hay una en curso.
2. `SaveSystem.save_for_exit()` espera a la escritura en curso y a que termine una transición.
3. Escribe en la ranura activa por el flujo único y espera el resultado. En mitad de una
   conversación guarda el estado de justo antes de empezarla, porque a media conversación puede
   estar a medio aplicar.
4. Sólo si se guardó, o no había nada que guardar (sin partida, partida nueva sin avanzar o caso
   cerrado), sale.
5. Si la partida **no tiene ranura activa**, pausa y pregunta: *Elegir ranura* (abre el
   expediente; tras guardar, sale), *Salir sin guardar* o *Cancelar*.
6. Si la escritura **falla**, no sale: ofrece *Reintentar*, *Salir sin guardar* o *Cancelar*.

**Límite.** Un cierre forzado (el administrador de tareas, `taskkill /F`), un fallo grave o un
corte de corriente no pasan por la petición de cierre: se conserva el último guardado completo, y
la escritura atómica evita que quede un archivo a medias.

## Imágenes de las partidas

Cada guardado lleva una imagen real de la escena:

- `SavePreview` crea un `SubViewport` que comparte el mundo 3D, con una copia de la cámara del
  juego y el mismo postproceso noir. Por eso la pausa, el expediente, el HUD y los diálogos no
  aparecen nunca, aunque estén abiertos.
- Se escribe como `manual_N.jpg` (384 × 216) antes que la partida, y la partida guarda su nombre
  y su huella SHA-256. Al sobrescribir se sustituyen las dos; al eliminar, también la imagen.
- Al mostrarla se comprueba la huella: una imagen dañada, ajena o desfasada se trata como
  ausente y la ranura muestra un marcador. Las texturas se leen una vez y se vuelven a comprobar
  si el archivo cambia.
- Sin ventana (`--headless`) no se puede renderizar: la partida se guarda sin imagen.

## Expediente de guardar y cargar

Reproduce las capturas de referencia: hoja de pergamino con hojas apiladas detrás, marco de
madera con filetes dorados, grabado de la mansión, sello «EXPEDIENTE DEL CASO», título con
filigranas, pestaña burdeos con la acción principal («Cargar» o «Guardar») y botones de madera
«Eliminar» y «Volver». Cada ranura muestra número, imagen, lugar, fecha del guardado, día y hora
del caso, tiempo de juego, pistas encontradas y si es la activa; las vacías y dañadas se
distinguen a simple vista. Todo está hecho con nodos Control, estilos, un sombreador y SVG
propios.

| Entrada | Efecto |
| --- | --- |
| Clic | Selecciona la ranura |
| Doble clic | Carga una partida válida (sólo al cargar) |
| Flechas arriba y abajo, cruceta | Recorren las cinco ranuras; la selección sigue al foco |
| Tab y Mayús + Tab | Ranura, acción principal, «Eliminar», «Volver», saltando lo desactivado |
| Intro, botón de aceptar | Ejecuta el control enfocado; sobre una ranura, la acción principal |
| Escape, botón de cancelar | Cierra la confirmación y después el expediente |

Al abrirlo, la ranura activa queda seleccionada y con el foco. Lo desactivado no acepta el foco,
el foco no sale de una confirmación abierta y vuelve a donde estaba al cerrarla. Las acciones
confirmadas quedan ligadas a la ranura que nombraba el mensaje. El mando usa las acciones `ui_*`
de Godot, sin tocar el mapa de controles del juego.

## Carga y restauración

1. El expediente llama a `SaveSystem.request_load(ranura)`, que valida el archivo; si falla, lo
   explica y no cambia nada.
2. La partida queda pendiente y se abre `scenes/main/game.tscn`. Desde la pausa se vuelve a crear
   la escena; si había progreso sin guardar, antes se pide confirmación.
3. `Game._ready`, con todos sus nodos listos: registra la sección `player` y la cámara, recoge la
   partida, aplica las secciones, construye el escenario guardado, coloca al detective donde
   estaba, actualiza la interfaz y abre la sesión con `begin_session`, que convierte la ranura en
   la activa.

## Indicador

`SaveIndicator` muestra un reloj de bolsillo en la esquina inferior derecha: «Guardando…», luego
«Partida guardada» o «Error al guardar» con el motivo, y el origen («Ranura 2», «Autoguardado ·
ranura 2», «Al salir · ranura 2»). Sólo confirma cuando `SaveSystem` lo hace, hay una única
instancia y queda por debajo de los diálogos modales.

## Señales y API

| Señal de `SaveSystem` | Cuándo |
| --- | --- |
| `save_started(slot_id)` | Empieza una escritura |
| `save_finished(slot_id, ok, message)` | Termina; `message` explica el fallo |
| `slot_deleted(slot_id)`, `slots_changed` | Cambia el contenido de las ranuras |
| `active_slot_changed(slot_id)` | Cambia la ranura activa (`""` si no hay) |

| Función | Uso |
| --- | --- |
| `save_to_slot(id)` | Guardado manual; la ranura pasa a ser la activa si sale bien |
| `autosave(motivo)`, `request_autosave(motivo, punto_de_control)` | Autoguardado en la ranura activa |
| `save_for_exit()` | Guardado al salir (corrutina); devuelve el estado |
| `get_active_slot()`, `check_active_slot()`, `get_continue_slot()` | Ranura activa |
| `read_slot(id)`, `get_slot_info(id)`, `list_slots()`, `get_slot_preview(id)` | Leer sin aplicar |
| `request_load(id)`, `take_pending_load()`, `apply_sections(secciones)` | Cargar |
| `delete_slot(id)` | Eliminar la partida y su imagen |
| `get_save_blocker()`, `has_unsaved_progress()`, `is_busy()` | Estado actual |
| `begin_session(dueño, documento)`, `end_session(dueño)` | Los llama la escena de juego |

`ExitManager.request_exit(Target.QUIT | Target.MAIN_MENU)` es la única entrada para salir.
`SaveSlotsMenu` emite `closed` y `load_ready(slot_id)`.

## Cómo ampliarlo

**Una variable narrativa nueva** (una decisión, una escena vista, un objetivo): usa una marca
desde `data/` con `"effects": {"flags": [...]}`. `GameState.flags` se guarda entero; no hace
falta tocar el guardado.

**Un sistema con estado propio**, por ejemplo un inventario con cantidades:

1. Dale `to_dict()` y `from_dict(data)`, y haz que `from_dict({})` deje el estado inicial.
2. Regístralo con `register_section`: un autoload declarado después de `SaveSystem` en su
   `_ready`; un nodo de escena en su `_ready`, retirándolo en `_exit_tree` con
   `unregister_section(clave, self)`.
3. Si sus datos pueden invalidar una partida, añade sus comprobaciones en `SaveFormat.validate`.
4. Si no cuenta como avance, añade su clave a `SaveSystem.NON_PROGRESS_SECTIONS`.
5. Añade una prueba de ida y vuelta en `tests/unit/test_save_slots.gd`.

**Cambiar la estructura de una sección:** sube `SaveFormat.VERSION` y añade el paso en
`_migrate`.

**Un punto de autoguardado nuevo:** llama a `SaveSystem.request_autosave("motivo")`, con `true`
si debe guardarse sin esperar la separación mínima.

## Limitaciones conocidas

- **No se ha generado un `.exe`**: faltan las plantillas de exportación. La X y Alt + F4 se
  probaron con el juego ejecutándose en el motor del editor, con ventana real.
- **Cierres forzados**: ver [Cerrar el juego](#cerrar-el-juego-x-alt--f4-y-botones-de-salida).
- **Sin ranura activa no hay autoguardado**: una partida nueva no se guarda sola hasta que el
  jugador elige ranura; se le avisa en el juego, en la pausa y al salir.
- **A media conversación** se guarda el estado previo a ella, no el de ese instante.
- **Los personajes** reaparecen donde marca su rutina para esa hora, no en su posición exacta.
- **Partidas importadas**: la de la versión 1 no tiene tiempo jugado («sin registrar»); ninguna
  importada tiene imagen hasta que se vuelve a guardar en su ranura.
- **Tipografía**: se usan fuentes del sistema (Georgia, con alternativas); en otro equipo el
  aspecto puede variar ligeramente.

## Pruebas

```powershell
powershell -File tools\verificar.ps1              # sin ventana
powershell -File tools\verificar.ps1 -ConVentana  # además, imágenes y cierre real de la ventana
```

| Prueba | Cubre |
| --- | --- |
| `test_save_format` | Escritura atómica de texto y bytes, recuperación, validación, versiones, migración, referencias de imagen |
| `test_save_slots` | Restauración completa, independencia, sobrescritura, borrado, autoguardado sólo en la activa, ranura cambiada por fuera, importaciones, partida nueva limpia |
| `test_active_slot` | Ranura activa al guardar, cargar, reiniciar, eliminar y empezar de nuevo; «Continuar» |
| `test_autosave` | Agrupación, descarte sin avance, momentos seguros, separación, punto de control, sin ranura activa |
| `test_exit` | X y Alt + F4 (petición de cierre), salida sin ranura, fallo de escritura, peticiones repetidas, conversación en curso |
| `test_save_menus` | Guardar, sobrescribir, cancelar, eliminar y cargar desde la pausa y el menú principal |
| `test_save_navigation` | Teclado, mando, doble clic, foco y confirmaciones |
| `test_save_indicator` | Indicador: éxito, fallo real, instancia única |
| `persistencia/reinicio` | Guardar, cerrar el proceso y cargar en otro |
| `visual/vista_previa` (ventana) | La imagen es la escena guardada y no incluye la pausa |
| `tools/probar_cierre.ps1` (ventana) | Cerrar con WM_CLOSE (X) o con Alt + F4 enviado a la ventana: guarda en la activa y no toca otra ranura |
