# Configuración

Preferencias del jugador: qué se guarda, dónde, cómo se valida y cómo se aplica.

## Menú

Configuración se abre desde la pausa y desde el menú principal (la misma escena, `SettingsMenu`). Conserva
el panel oscuro, los filetes y ornamentos dorados, las pestañas con la seleccionada en burdeos, el botón
crema «Volver» y los fundidos; las opciones que antes decían «Próximamente» son ahora controles reales y
hay dos pestañas más, Filtros y Accesibilidad.

| Pestaña | Opciones |
| --- | --- |
| Audio | Volumen general, música, efectos, lluvia y ambiente (barras, como antes) |
| Gráficos | Pantalla completa y sincronización vertical (interruptores); modo de ventana, resolución de pantalla, calidad de sombras e iluminación y efectos y partículas (selectores) |
| Jugabilidad | Velocidad del texto (selector); avance automático de diálogos y confirmaciones (interruptores) |
| Filtros | Modo noir, sepia, frío nocturno o colores originales (tarjetas, uno a la vez); ver [FILTROS.md](FILTROS.md) |
| Accesibilidad | Tamaño de letra (selector); contraste aumentado, subtítulos y reducir movimiento (interruptores) |

Los selectores (`OptionSelector`, `scripts/ui/option_selector.gd`) son filas con el estilo de las demás:
el nombre y su explicación a la izquierda y «‹ valor ›» a la derecha; la señalada toma el fondo burdeos
y el filete dorado. Con el foco en ellos, izquierda y derecha cambian el valor (sin dar la vuelta, como
las barras de volumen) y aceptar pasa al siguiente (dando la vuelta); con el ratón, las flechas y un clic
en el valor. Arriba y abajo recorren las filas; para volver a las pestañas, izquierda desde un
interruptor o Escape (o B en el mando).

Cada control lee su preferencia al abrir la pantalla y cuando cambia (`Settings.changed`), así que la
pausa y el menú principal siempre muestran lo mismo. Con el modo en pantalla completa, el selector de
resolución se desactiva y dice cuál usa el monitor.

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

[filtros]
activo="original"

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
| `filtros` | `activo` | `original`, `noir`, `sepia`, `cold_night` |
| `accesibilidad` | `tamano_letra` | `normal`, `grande`, `muy_grande` |
| | `contraste_alto`, `subtitulos`, `movimiento_reducido` | Sí o no |
| `controles` | Teclas personalizadas de `Controls`; ver [CONTROLES.md](CONTROLES.md) | `Settings` nunca la borra; se lee y se escribe con `read_section` y `write_section` |

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
- **Lo ajeno se conserva.** Las secciones y claves que `Settings` no conoce siguen en el archivo
  después de cada escritura. Las de otros sistemas (`SettingsSchema.EXTERNAL_SECTIONS`: hoy, las teclas
  de `Controls` en `controles`) las gestiona ese sistema con `read_section` y `write_section`, que
  sustituye la sección entera y conserva el resto; las secciones de las preferencias no se pueden
  escribir así.
- **Formato anterior.** La versión 1 guardaba `volumen/*`, `pantalla/completa` y `pantalla/vsync`.
  Al leerla se migra (pantalla completa pasa a ser el modo `pantalla_completa`), se retiran las
  secciones antiguas y el archivo se reescribe con `version=2`.
- **Archivos dañados.** Si un valor no es válido, se usa el de por defecto y el archivo se reescribe
  corregido. Si el archivo entero es ilegible, se aparta una copia con el sufijo `.danado` y se
  empieza con los valores por defecto.
- **Arranque.** `Settings` lee el archivo en su `_ready`, antes de la primera escena, y aplica lo que
  depende del motor. Cada vez que lee el archivo (también con `use_file`) emite `reloaded`, y `Controls`
  vuelve a leer sus teclas.

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

## Accesibilidad

`UiAccessibility` (`scripts/settings/ui_accessibility.gd`) reúne las cuatro opciones; `Settings` aplica
el tamaño de letra y el contraste, y las pantallas consultan lo demás.

### Tamaño de letra

| Opción | Escala de la interfaz | Lienzo lógico en 16:9 |
| --- | --- | --- |
| Normal | 1 | 1920 × 1080 |
| Grande | 1,15 | 1670 × 939 |
| Muy grande | 1,3 | 1477 × 831 |

Se aplica con `Window.content_scale_factor` sobre el escalado `canvas_items` que ya usaba el juego: las
letras crecen y, con ellas, los recuadros que las contienen, de modo que nada se recorta ni se monta
encima de otra cosa. Llega a todas las interfaces a la vez (menús, conversaciones, HUD, expediente,
tablero, mapa, avisos y confirmaciones) y la escena 3D no cambia. Las pantallas se maquetan con el
lienzo que queda, igual que en una ventana de otra proporción; `test_accessibility` comprueba que la
pausa, cada página de Configuración, la confirmación, la conversación al leer y al elegir, el
expediente y el tablero caben en «Muy grande».

### Contraste aumentado

`ContrastFilter` (`scripts/settings/contrast_filter.gd`) realza toda la interfaz sin rehacer ninguna
pantalla:

- **Texto**: los colores de texto de etiquetas, botones y textos enriquecidos se vuelven opacos y se
  separan del fondo. Los claros (crema, dorado, burdeos claro sobre paneles oscuros) se acercan al blanco
  cálido; los oscuros (tinta sobre pergamino), al negro. El color de lo desactivado no se toca.
- **Foco y selección**: el contorno de foco pasa a ser un filete grueso casi blanco con un halo oscuro,
  visible sobre cuero, pergamino o el escenario.
- **Lo que se crea después** (pantallas que se abren, filas nuevas) nace realzado, y si una pantalla
  cambia un color mientras está activo, se realza el nuevo (`theme_changed`).
- **Reversible**: lo que había se guarda en metadatos de cada control y vuelve al desactivarlo. En modo
  normal no se toca nada.

Los elementos que se dibujan a mano (marcos, ornamentos, la pestaña «Continuar») conservan su color.

### Subtítulos

`SubtitleBar` (`scripts/ui/subtitle_bar.gd`, capa 5 de la escena de juego) muestra, centrado sobre la
barra de controles, el texto de una voz o de un sonido narrado con el nombre de quien habla. Es lo único
que oculta la opción: el texto de las conversaciones es obligatorio para jugar y se muestra siempre en su
ventana.

El juego todavía no tiene voces, así que hoy nada pide subtítulos; no se ha inventado contenido. Cuando
las tenga, quien reproduzca una voz emitirá `EventBus.subtitle_requested(personaje, texto, segundos)`
(con 0 segundos dura lo que se tarda en leerlo). Desactivar los subtítulos retira en el acto el que haya
en pantalla.

### Reducir movimiento

Con `accesibilidad/movimiento_reducido`, `UiAccessibility.motion()` vale 0 y desaparecen las
animaciones decorativas:

| Dónde | Qué deja de moverse |
| --- | --- |
| Conversaciones | La ventana ya no sube al aparecer; las siluetas no entran deslizándose, no respiran ni se balancean; las respuestas no suben al entrar; «Continuar» no late (queda a media luz) |
| HUD | Los paneles no se deslizan al aparecer |
| Mapa | La onda del detective queda quieta y el rombo del objetivo no sube ni baja |
| Confirmaciones | La ficha no crece al aparecer |

Los fundidos se mantienen: no desplazan nada y ayudan a ver qué ha cambiado. La barra de espera del
avance automático también, porque informa.

### Navegación

Todas las opciones nuevas funcionan con ratón, teclado y mando. Los interruptores y selectores reciben el
foco en el orden de la página (arriba y abajo), los selectores cambian de valor con izquierda y derecha y
con aceptar, y la confirmación retiene el foco en sus dos botones. Con el mando, la cruceta y el stick
izquierdo mueven el foco (una vez por empujón, y repiten al mantenerlos), A acepta y B vuelve; ver
[CONTROLES.md](CONTROLES.md).

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

## Cómo comprobarlo en Godot

Abre el proyecto, ejecuta la escena principal (F5) y entra en **Configuración** desde el menú
principal o desde la pausa (Esc durante la partida).

| Opción | Qué hacer | Qué debe pasar |
| --- | --- | --- |
| Pantalla completa | Activa el interruptor | La ventana ocupa el monitor y aparece «¿Mantener esta pantalla?» con 15 s; sin contestar, vuelve a la ventana. El selector de modo muestra «Pantalla completa» mientras tanto |
| Modo de ventana | Cambia a «Sin bordes» y confirma | Ventana sin barra de título, centrada; el interruptor de pantalla completa sigue apagado |
| Resolución | Elige otra con la ventana en modo ventana | La ventana cambia de tamaño y se centra; en pantalla completa el selector se desactiva y dice la del monitor |
| Sincronización vertical | Actívala | Se aplica al momento; en este portátil puede bajar mucho la tasa de fotogramas (ver «Rendimiento» en `ESTADO_PROYECTO.md`) |
| Sombras e iluminación | Pon «Bajo» en la plaza | Desaparecen las sombras de farolas, árboles y bancos y el resplandor; las luces siguen iluminando |
| Efectos y partículas | Pon «Bajo» en la plaza | Llueve menos denso y la niebla es más simple; sigue lloviendo |
| Filtros | Elige «Modo noir» | El escenario de detrás pasa al blanco y negro al momento y el menú no cambia de color; ver [FILTROS.md](FILTROS.md) |
| Velocidad del texto | Elige «Lento» y habla con Eusebio en la estación | El texto se escribe más despacio; con «Instantáneo» aparece entero |
| Avance automático | Actívalo y abre una conversación | Bajo «Continuar» se llena un filete y la línea pasa sola; en las preguntas se detiene |
| Confirmaciones | Pulsa T explorando | Con ellas, «¿Quieres dejar pasar una hora?»; sin ellas, pasa la hora en el acto |
| Tamaño de letra | Elige «Muy grande» | Toda la interfaz crece al momento; abre la pausa, el expediente (J), el tablero (B) y el mapa (M) |
| Contraste aumentado | Actívalo | Textos más nítidos y un contorno de foco blanco y grueso al moverte con las flechas |
| Subtítulos | Desactívalos | No cambia nada visible hoy: no hay voces (ver «Limitaciones») |
| Reducir movimiento | Actívalo y abre una conversación | La ventana y las siluetas aparecen sin deslizarse y no respiran; «Continuar» no late |

Cierra el juego y vuelve a abrirlo: todo sigue como lo dejaste. Las preferencias están en
`%APPDATA%\Godot\app_userdata\Villa Sombría\ajustes.cfg`.

## Limitaciones

- **Resolución en pantalla completa.** Godot 4 no cambia el modo de vídeo del monitor, ni en pantalla
  completa exclusiva: ahí manda la resolución del monitor y el selector lo explica.
- **Subtítulos sin contenido.** El juego no tiene voces; la opción y la barra están listas para cuando
  las tenga, pero hoy nada pide subtítulos.
- **Contraste aumentado.** Realza texto y foco; los elementos dibujados a mano (marcos, ornamentos,
  fondos de pergamino) conservan su color.
- **Tamaño de letra.** Escala toda la interfaz, no sólo las letras: es la forma de que nada se recorte.
  Las siluetas de las conversaciones mantienen su tamaño.
- **Sincronización vertical en este portátil.** Con doble GPU, hasta un proyecto vacío cae a unos 5 FPS
  con ella al lanzarlo desde la terminal; por eso sigue desactivada por defecto.
- **Mando real.** Las pruebas envían eventos de mando con `Input.parse_input_event`, el mismo camino que
  uno real, pero no se ha probado con uno físico; ver [CONTROLES.md](CONTROLES.md).

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

`tests/unit/test_accessibility.gd` comprueba la escala de la interfaz de cada tamaño de letra, que en
«Muy grande» caben la pausa, cada página de Configuración, la confirmación, la conversación, el
expediente y el tablero; que el contraste aumentado realza texto y foco, llega a lo que se crea después,
respeta lo desactivado y se deshace sin rastro; los subtítulos (mostrar, ocultar en el acto, sin tocar
las conversaciones, sonidos sin hablante, duración); el movimiento reducido en las conversaciones; y que
todo persiste.

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

`tests/unit/test_visual_filters.gd` comprueba los filtros de color; ver [FILTROS.md](FILTROS.md).

`tests/unit/test_settings.gd` comprueba los valores por defecto, las categorías, la validación, la
escritura de una sola clave sin perder el resto del archivo, la corrección de valores dañados, la
migración del formato anterior, la recarga como en un nuevo arranque y que las preferencias no se
guardan en las partidas. Las pruebas usan `user://pruebas_guardado/ajustes.cfg`
(`TestCase.reset_test_settings`) y nunca tocan los ajustes del jugador.

El caso del archivo ilegible se comprobó a mano con la misma prueba: el motor imprime un `ERROR:` al
analizarlo y `verificar.ps1` tomaría esa línea por un fallo, así que no forma parte de la batería.
