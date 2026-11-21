# Configuración

Preferencias del jugador: qué se guarda, dónde, cómo se valida y cómo se aplica.

## Persistencia

Las preferencias se guardan en `user://ajustes.cfg`, aparte de las partidas: no dependen de ninguna
ranura y no viajan en los archivos de `user://saves/`. Las lee y las escribe el autoload `Settings`
(`scripts/autoload/settings.gd`); qué preferencias existen lo describe `SettingsSchema`
(`scripts/settings/settings_schema.gd`).

```ini
[meta]
version=2

[audio]
Master=0.8
Musica=0.8
Efectos=0.8
Ambiente=0.8

[graficos]
modo_ventana="ventana"
resolucion=Vector2i(1280, 720)
vsync=false
calidad_iluminacion="alto"
calidad_efectos="alto"

[jugabilidad]
velocidad_texto="normal"
avance_automatico=false
confirmaciones=true

[accesibilidad]
tamano_letra="normal"
contraste_alto=false
subtitulos=true
movimiento_reducido=false
```

| Sección | Preferencias | Valores |
| --- | --- | --- |
| `audio` | Volumen de `Master`, `Musica`, `Efectos` y `Ambiente` | 0 a 1 |
| `graficos` | `modo_ventana` | `ventana`, `sin_bordes`, `pantalla_completa`, `exclusiva` |
| | `resolucion` | De 1024 × 576 a 7680 × 4320 |
| | `vsync` | Sí o no |
| | `calidad_iluminacion`, `calidad_efectos` | `bajo`, `medio`, `alto` |
| `jugabilidad` | `velocidad_texto` | `lento`, `normal`, `rapido`, `instantaneo` |
| | `avance_automatico`, `confirmaciones` | Sí o no |
| `accesibilidad` | `tamano_letra` | `normal`, `grande`, `muy_grande` |
| | `contraste_alto`, `subtitulos`, `movimiento_reducido` | Sí o no |
| `controles` | Reservada para las teclas de un sistema de reasignación | `Settings` nunca la borra |

### Reglas

- **Valores por defecto.** Sin archivo, cada preferencia toma el valor de `SettingsSchema`: el aspecto
  original del juego (calidad alta), ventana de 1280 × 720, sincronización vertical desactivada,
  texto a velocidad normal y confirmaciones activadas. Leer no crea el archivo.
- **Validación.** `SettingsSchema.validate` sólo admite el tipo y los valores de cada preferencia.
  Los volúmenes fuera de rango se ajustan a 0 o 1; una opción desconocida, un tipo equivocado o una
  resolución imposible se rechazan y queda el valor anterior (al leer, el valor por defecto).
- **Cambios independientes.** `Settings.set_value(clave, valor)` valida, aplica, escribe sólo esa
  clave sobre el archivo existente y emite `Settings.changed(clave, valor)`. Repetir el valor vigente
  no escribe ni avisa.
- **Lo ajeno se conserva.** Las secciones y claves que `Settings` no conoce (por ejemplo, lo que
  guarde un sistema de reasignación en `controles`) siguen en el archivo después de cada escritura.
- **Formato anterior.** La versión 1 guardaba `volumen/*`, `pantalla/completa` y `pantalla/vsync`.
  Al leerla se migra (pantalla completa pasa a ser el modo `pantalla_completa`), se retiran las
  secciones antiguas y el archivo se reescribe con `version=2`.
- **Archivos dañados.** Si un valor no es válido, se usa el de por defecto y el archivo se reescribe
  corregido. Si el archivo entero es ilegible, se aparta una copia con el sufijo `.danado` y se
  empieza con los valores por defecto.
- **Arranque.** `Settings` lee el archivo en su `_ready`, antes de la primera escena, y aplica lo que
  depende del motor.

### Atajos que se mantienen

`Settings.volumes`, `Settings.fullscreen`, `Settings.vsync`, `set_volume`, `set_fullscreen`,
`set_vsync` y `save` siguen funcionando como antes; ahora leen y escriben las claves del esquema.

## Pantalla

`DisplaySettings` (`scripts/settings/display_settings.gd`) aplica el modo de ventana, la resolución y
la sincronización vertical a la ventana real (`get_tree().root`).

| Modo | Qué hace |
| --- | --- |
| Ventana | Ventana con barra de título, del tamaño elegido y centrada en su monitor |
| Ventana sin bordes | Igual, sin barra ni bordes; admite también el tamaño exacto del monitor |
| Pantalla completa | `Window.MODE_FULLSCREEN`: ocupa el monitor sin cambiar su modo de vídeo |
| Pantalla completa exclusiva | `Window.MODE_EXCLUSIVE_FULLSCREEN`: la ventana tiene el monitor para ella sola, con menos sobrecarga |

- **La resolución lógica no cambia.** El lienzo sigue siendo de 1920 × 1080 con `canvas_items` y
  `expand`: la interfaz y la escena se escalan con la ventana sin deformarse. Lo que cambia es el
  tamaño de la ventana.
- **Resoluciones ofrecidas.** En los modos con ventana, las habituales (`STANDARD_SIZES`) que caben
  en la zona útil del monitor donde está la ventana, descontando la barra de título. En los de
  pantalla completa manda la resolución del monitor: Godot 4 no cambia el modo de vídeo del sistema.
  La resolución elegida se guarda y vuelve al regresar a un modo con ventana.
- **Nada se sale de la pantalla.** Una resolución que no cabe (por ejemplo, guardada en otro monitor)
  baja a la mayor que sí cabe (`DisplaySettings.fit`), y la ventana nunca baja de 1024 × 576
  (`MIN_WINDOW`), tampoco al arrastrar sus bordes.
- **Confirmación.** Los cambios de modo y de resolución pasan por `Settings.request_display_change`:
  se aplican sin guardarlos y `ConfirmDialog` pregunta «¿Mantener esta pantalla?» con 15 s de cuenta
  atrás. «Mantener» los guarda; «Restaurar», Escape o el fin de la cuenta vuelven a lo anterior.
  Mientras hay uno pendiente, otro se rechaza, y si el juego se cierra entonces, el archivo conserva
  lo anterior.
- **Pantalla completa y modo de ventana son la misma preferencia.** `Settings.fullscreen` es «el modo
  es uno de pantalla completa»; el interruptor y el selector leen y escriben `graficos/modo_ventana`,
  así que no pueden contradecirse.
- **Sincronización vertical.** `DisplayServer.window_set_vsync_mode` con `VSYNC_ENABLED` o
  `VSYNC_DISABLED`, aplicada al momento. El tope de 60 FPS del proyecto se mantiene en los dos casos.
  Sigue desactivada por defecto (ver «Rendimiento» en `ESTADO_PROYECTO.md`).
- **Arranque.** El volumen y la sincronización vertical se aplican en el `_ready` de `Settings`; la
  ventana, un instante después, cuando ya se sabe qué escena arranca. Las escenas de `res://tests/`
  fijan su propia ventana con `--resolution` y no reciben el modo guardado; cualquier otra puede
  pedirlo con el argumento `-- --respetar-ventana`.

## Calidad gráfica

`GraphicsQuality` (`scripts/settings/graphics_quality.gd`) aplica dos niveles independientes, **Bajo**,
**Medio** y **Alto**. Alto es el aspecto original del juego: los valores del proyecto y lo que cada
escenario pide al crear sus luces.

### Sombras e iluminación

| | Bajo | Medio | Alto |
| --- | --- | --- | --- |
| Sombra de la luz exterior | No | Sí | Sí |
| Sombras de farolas y lámparas que las piden | No | Sí, de dos caras (`SHADOW_DUAL_PARABOLOID`) | Sí, cúbicas (`SHADOW_CUBE`) |
| Atlas de sombras (direccional y de luces) | ¼ del del proyecto | ½ | El del proyecto |
| Suavizado de las sombras | Duro | Duro | El del proyecto |
| Resplandor de las luces (`glow`) | No | Sí | Sí |

Ninguna luz se apaga ni pierde intensidad: las farolas, las ventanas y las lámparas iluminan lo mismo
en los tres niveles, así que lo que hay que ver para jugar se sigue viendo.

### Efectos y partículas

| | Bajo | Medio | Alto |
| --- | --- | --- | --- |
| Gotas de lluvia (`RainEffect`) | 270 | 540 | 900 |
| Capas de ruido de la niebla (`noir_post.gdshader`) | 2 | 3 | 4 |
| Grano de película | No | Sí | Sí |

La calidad sólo cambia lo que se dibuja: sigue lloviendo en los mismos lugares, el sonido de la lluvia
no cambia, la cantidad de niebla del exterior es la misma (con menos capas se compensa la suma) y ni el
reloj ni la historia dependen de ella. La viñeta se mantiene en todos los niveles.

### Cómo se aplica

Las luces (`LocationBase.add_point_light` y la luz exterior de `Atmosphere`), los entornos, la lluvia y
el postproceso se registran al crearse en un grupo, guardando lo que pedía su escenario, y toman el nivel
vigente. Al cambiar de nivel se ajustan todos los del árbol en el acto, sin recrear nada; la lluvia sólo
se reinicia si cambia su cantidad, y su preproceso la vuelve a llenar sin un hueco. Los atlas y los
filtros son del servidor de dibujo y de la ventana principal.

### Diferencia medida

Plaza a 1920 × 1080 en el portátil de desarrollo (GTX 1650 Ti), con `tests/visual/rendimiento.tscn` y el
mismo nivel en las dos opciones. El tiempo de GPU es el que mide el propio servidor de dibujo, que no
depende del tope de fotogramas.

| Nivel | GPU por fotograma | Primitivas | Llamadas de dibujado | Memoria de vídeo |
| --- | --- | --- | --- | --- |
| Alto | 6,99 ms | 139.146 | 267 | 344 MB |
| Medio | 6,12 ms | 62.602 | 262 | 282 MB |
| Bajo | 4,11 ms | 14.757 | 207 | 233 MB |

```powershell
godot --path . --resolution 1920x1080 res://tests/visual/rendimiento.tscn -- --location=plaza --iluminacion=bajo --efectos=bajo
```

## Conversaciones

`DialogueUi` lee `jugabilidad/velocidad_texto` y `jugabilidad/avance_automatico` al crearse y escucha
`Settings.changed`, así que un cambio se nota en el acto, también a mitad de una intervención.
`DialogueManager` y los datos de las conversaciones no cambian.

### Velocidad del texto

| Opción | Letras por segundo |
| --- | --- |
| Lento | 24 |
| Normal | 48 (la de siempre) |
| Rápido | 96 |
| Instantáneo | Cada página aparece entera |

- Las pausas breves tras un punto o una coma se mantienen en las tres velocidades con escritura.
- La primera pulsación sigue completando la página y la siguiente avanza: una pulsación nunca hace
  dos cosas.
- Con el texto instantáneo, durante 0,15 s después de aparecer una página la pulsación no cuenta
  (`DialogueStyle.INSTANT_ADVANCE_GUARD`): dos pulsaciones seguidas no se saltan una intervención
  sin haberla visto.
- Si se cambia a instantáneo mientras se escribe, lo que falta aparece en el acto.

### Avance automático

1. La intervención se escribe a la velocidad elegida.
2. Cuando la página se lee entera, empieza la espera: el tiempo de leerla a 22 letras por segundo,
   menos lo que se tardó en escribirla, más 1,2 s; entre 1,2 y 8 s (`DialogueStyle.auto_hold`).
3. Un filete dorado bajo «Continuar» se llena mientras tanto.
4. Al terminar, pasa a la página o a la intervención siguiente, igual que la tecla de avanzar.

- **Nunca elige una respuesta.** Con las preguntas o las respuestas en pantalla la cuenta se detiene
  y la decisión espera al jugador, el tiempo que haga falta.
- La tecla de avanzar (E, Intro o el botón de aceptar del mando) sigue funcionando y no espera.
- Activarlo con una página ya leída empieza a contar; desactivarlo para la cuenta.
- Cerrar la conversación (por la historia o porque termina) detiene la cuenta, y con el juego en
  pausa (la pregunta de salida) la cuenta no avanza.

## Confirmaciones

`jugabilidad/confirmaciones` («Preguntar antes de acciones como dejar pasar una hora») decide si se
pregunta antes de las acciones **opcionales**. Hoy lo es dejar pasar una hora:

- **Activadas** (por defecto): la tecla de `wait_time` (la que tenga asignada en el InputMap; hoy T)
  abre «¿Quieres dejar pasar una hora?» con la hora actual y la resultante, «Confirmar» y «Cancelar».
  Mientras se pregunta, el detective no se mueve (bloqueo `confirmacion`) y ninguna otra tecla abre
  una pantalla. Confirmar deja pasar la hora con el aviso de siempre; cancelar, Escape o el botón de
  cancelar del mando no hacen nada.
- **Desactivadas**: la hora pasa en el acto, como antes.
- A las 23:30 no hay nada que confirmar: se avisa de que hay que descansar, como siempre.

Las confirmaciones **críticas** no dependen de la preferencia y se hacen siempre: sobrescribir o
eliminar una partida (`SaveSlotsMenu`), salir sin guardar (`ExitManager`) y mantener un cambio de
pantalla. El guardado automático y el cierre seguro con la X o Alt + F4 no cambian.

Para hacer opcional otra acción: `if await ConfirmDialog.ask_optional(título, pregunta): ...`. Si la
acción destruye algo, usa `ConfirmDialog.ask`, que pregunta siempre.

## Ventana de confirmación

`ConfirmDialog` (autoload, `scripts/autoload/confirm_dialog.gd`, capa 45) es la pregunta común: título,
texto, «Confirmar» y «Cancelar» (con otros rótulos si se piden) en la ficha de pergamino de las
preguntas de salida y de las ranuras.

```gdscript
if await ConfirmDialog.ask("TÍTULO", "¿Pregunta?", {"confirm_text": "Sí", "focus": "confirm"}):
	hacer_la_accion()
```

- Opciones: `confirm_text`, `cancel_text`, `focus` (`"confirm"` o `"cancel"`, por defecto cancelar),
  `timeout` (segundos hasta contestar «cancelar» solo) y `timeout_text` (con `%d`).
- Ratón, teclado y mando: el foco no sale de los dos botones; izquierda y derecha pasan de uno a otro,
  aceptar pulsa el señalado y Escape (o cancelar en el mando) contesta «cancelar». Al cerrarse, el foco
  vuelve al control que tenía antes.
- Funciona con el árbol en pausa, y la cuenta atrás también avanza.
- La pausa, el menú principal y las pantallas de menú (`MenuScreen`) le ceden Escape mientras está
  abierta; ella se lo cede a la pregunta de salida de `ExitManager` (X o Alt + F4), que va por encima.

## Añadir una preferencia

1. Descríbela en `SettingsSchema.DEFINITIONS` con su tipo, su valor por defecto y lo que admite; si
   es una lista cerrada, añade el nombre visible de cada valor a `LABELS`.
2. Quien la use la lee con `Settings.get_value("seccion/nombre")` y escucha `Settings.changed`.
3. Si depende del motor (ventana, calidad, escala), aplícala en `Settings._apply_key`.

## Pruebas

`tests/unit/test_display.gd` comprueba qué resoluciones se ofrecen según el monitor, cómo se ajusta lo
que no cabe, que el interruptor y el selector son la misma preferencia, la confirmación (mantener,
restaurar, Escape, cuenta atrás, también en pausa, un solo cambio a la vez), el foco dentro de la
pregunta y que Escape no cierra la configuración de detrás.

`tests/unit/test_confirmations.gd` comprueba, con la escena de juego real y entradas como las del
jugador, que esperar pregunta antes con las confirmaciones activadas (aceptar, cancelar, Escape, una
sola pregunta a la vez, sin abrir otras pantallas), que no pregunta con ellas desactivadas, que sigue la
tecla asignada a `wait_time`, el límite del día y que las confirmaciones críticas no dependen de la
preferencia. `tests/visual/captura.tscn -- --open=esperar` fotografía la pregunta.

`tests/unit/test_dialogue_settings.gd` comprueba que cada velocidad llega a la escritura, que lento
tarda más que rápido, que el texto instantáneo aparece entero y no se salta intervenciones con dos
pulsaciones, el cambio de velocidad en mitad de una intervención, que el avance automático espera lo
que hay que leer y pasa solo, que nunca elige una respuesta, que se puede activar y desactivar a mitad
de la conversación, que la tecla sigue funcionando y que se detiene al cerrar.

`tests/unit/test_graphics_quality.gd` comprueba con la escena de juego real que Alto es el aspecto
original, qué reduce cada nivel, que ninguna luz se apaga, que el cambio llega a lo que ya existe y a los
escenarios que se cargan después, que la lluvia no se duplica ni deja de caer y que el reloj no cambia.
`tests/visual/captura.tscn` admite `--ajustes=graficos/calidad_iluminacion=bajo;graficos/calidad_efectos=bajo`
para comparar los niveles en imágenes.

`tests/visual/pantalla.tscn` lo comprueba con la ventana real (hace falta pantalla):

```powershell
godot --path . --resolution 1280x720 res://tests/visual/pantalla.tscn
```

Aplica cada modo y tamaño, compara el estado real de la ventana (modo, tamaño, posición, VSync) y
repite el flujo de Configuración: un cambio sin contestar vuelve a lo anterior y uno confirmado se
guarda.

`tests/unit/test_settings.gd` comprueba los valores por defecto, las categorías, la validación, la
escritura de una sola clave sin perder el resto del archivo, la corrección de valores dañados, la
migración del formato anterior, la recarga como en un nuevo arranque y que las preferencias no se
guardan en las partidas. Las pruebas usan `user://pruebas_guardado/ajustes.cfg`
(`TestCase.reset_test_settings`) y nunca tocan los ajustes del jugador.

El caso del archivo ilegible se comprobó a mano con la misma prueba: el motor imprime un `ERROR:` al
analizarlo y `verificar.ps1` tomaría esa línea por un fallo, así que no forma parte de la batería.
