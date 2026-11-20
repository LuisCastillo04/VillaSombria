# Tablero de deducción

Qué muestra el tablero (tecla B), de dónde saca los datos, cómo se recorre, cómo se adapta a la
pantalla y cómo ampliarlo.

## Qué muestra

Un tablero de cuero marrón con cuatro zonas:

| Zona | Contenido |
| --- | --- |
| Encabezado | Banda de pergamino con la foto del inspector y su clip, «TABLERO DE DEDUCCIÓN», «[B] Cerrar» (con la tecla real, también se pulsa con el ratón), la ayuda «Pulsa un sospechoso para anotar tu hipótesis» y el matasellos «VILLA SOMBRÍA · 1948» del expediente |
| Sospechosos | Una ficha de pergamino por sospechoso del caso: silueta, nombre corto y valoración |
| Corcho | Las fichas de lo que el jugador ha descubierto, agrupadas en pruebas, declaraciones y deducciones, con chinchetas e hilos rojos; en la esquina, libros, tintero, pluma, cartas y una foto sepia de la mansión |
| Comparar elementos | Página de pergamino con la lupa, los dos huecos de la comparación, «Relacionar» y la respuesta |

Al pulsar un sospechoso se abre encima del corcho su **panel de hipótesis**: el título «Hipótesis
sobre …», el selector de valoración, el cuaderno donde se escribe y «Guardar hipótesis».

Todo se construye con nodos de Godot sobre la partida real: no hay capturas de fondo y los textos
son etiquetas. El corcho, el cuero y el pergamino son shaders; los adornos, SVG propios o dibujo en
código.

### Valoraciones

Son las de siempre (`Investigation.HYPOTHESIS_STATUSES`, rótulos en `JournalInfo.STATUS_LABELS`):

| Valoración | Ficha |
| --- | --- |
| Sin valorar | Pergamino y tinta |
| Sospechoso | Chincheta de latón en la esquina |
| Principal sospechoso | Valoración en burdeos y cursiva, chincheta roja |
| Descartado | Papel más apagado y la silueta tachada; el nombre y la valoración se siguen leyendo |

La **selección** es otra cosa: la ficha cuya hipótesis se está anotando se ilumina en dorado.
Elegirla nunca cambia su valoración. Un lápiz en la esquina avisa de un borrador sin guardar.

### Fichas del corcho

Cada elemento es una ficha de papel del color de su tipo (crema las pruebas, gris las
declaraciones, rosada las deducciones) con una cinta («PRUEBA», «DECLARACIÓN», «DEDUCCIÓN»), el
título, una línea breve (categoría, quién declara o tipo de deducción) y una chincheta en el borde
superior. Se inclinan un poco, siempre igual. Al elegirla se levanta, se ilumina y muestra si es
el elemento 1 o el 2.

Con menos de tres fichas, unos **huecos libres** con una cruz completan la fila. Sólo son un
indicador: no son botones, no se pueden pulsar ni dicen cuántas pruebas faltan. Sin nada
descubierto, una nota explica cómo conseguir pruebas, con la tecla real de examinar.

### Hilos

| Clase | Aspecto | Cuándo aparece |
| --- | --- | --- |
| Relación registrada | Hilo rojo tenso entre dos chinchetas | Por cada deducción ya establecida cuyas dos fichas están en el corcho (`BoardInfo.relations()`) |
| Comparación en curso | Hilo rojo claro a trazos con un nudo de latón | Entre los dos elementos elegidos; no afirma nada |
| Decorativo | Bramante pardo a trazos | Sólo entre huecos libres; no une ninguna ficha |

Los hilos pasan por detrás del papel: no se dibujan donde cruzarían una ficha o un rótulo, salvo en
la franja superior de sus propias fichas, junto a la chincheta, donde no hay texto. Con una ficha
elegida, sus hilos se avivan, los demás se apagan y las fichas relacionadas avivan su chincheta.
Una deducción nueva tiende su hilo poco a poco y su ficha destella.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/board_ui.tscn`, `scripts/ui/board_ui.gd` | `BoardUi`: abre y cierra, atiende el teclado, lleva la selección, pide la relación a `Investigation.try_link`, anota hipótesis y guarda los borradores |
| `scripts/ui/board/board_info.gd` | `BoardInfo`: lee sospechosos, elementos, fichas de comparación y relaciones dibujables; no cambia nada |
| `board_style.gd` | `BoardStyle`: paleta, letras, medidas en el lienzo de 1920 × 1080, tiempos, botones, selector, cuaderno y cintas |
| `board_ornaments.gd` | `BoardOrnaments`: chinchetas, hilos, nudos, huecos libres y cercos de café |
| `board_frame.gd`, `board_header.gd` | `BoardFrame` (cuero, banda y reparto del espacio) y `BoardHeader` (foto, rótulo, cerrar y ayuda) |
| `board_suspect_row.gd`, `board_suspect_card.gd` | Fila desplazable y ficha de sospechoso |
| `board_canvas.gd`, `board_evidence_card.gd` | `BoardCanvas` (corcho, grupos, reparto, huecos, rincón decorativo) y la ficha de cada elemento |
| `board_connections.gd` | `BoardConnections`: los tres tipos de hilo, por detrás del papel |
| `board_comparison_panel.gd`, `board_comparison_slot.gd` | Columna de comparación y sus huecos |
| `board_hypothesis_editor.gd` | `BoardHypothesisEditor`: el panel de hipótesis |
| `assets/shaders/cork.gdshader` | Corcho con gránulos, poros, motas y sombra del marco |
| `assets/ui/tablero/` | Marcas del selector (`radio_si`, `radio_no`), flecha (`desplegable`) y el grabado `rincon_escritorio` |
| `tools/generar_grabados.py` | Genera también `rincon_escritorio.svg` |

Se reutiliza lo que ya existía: los shaders de cuero, pergamino y sepia, `JournalStyle`,
`JournalOrnaments` (clip, ondas, pespuntes, esquinas), `JournalSeal`, `JournalPhoto`,
`JournalPage`, `HudOrnaments`, `HudToast`, `GoldDivider`, `InputLabels`, `CinematicFrame`, el
grabado de la mansión y las siluetas de los personajes.

## De dónde salen los datos

| Dato | Fuente |
| --- | --- |
| Sospechosos | `GameData.get_suspects()` (marca `suspect` de `characters.json`), en ese orden |
| Valoración e hipótesis | `GameState.hypotheses`, leídas con `Investigation.get_hypothesis()` |
| Fichas del corcho | `Investigation.get_board_items()`: pistas, testimonios y deducciones del jugador, en orden de hallazgo |
| Comparación | `Investigation.get_item()`, el `where` de la pista, el personaje que declara y `JournalInfo.related_deductions()` |
| Relación | `Investigation.try_link()`; una nueva avanza el reloj `BoardUi.LINK_MINUTES` |
| Hilos | `GameState.deductions` y las parejas de `deductions.json` con las dos fichas a la vista |
| Teclas | InputMap, a través de `InputLabels`, cada vez que se abre |

Las hipótesis se anotan con `Investigation.set_hypothesis()`, que sólo admite sospechosos del caso
y valoraciones conocidas, recorta la nota a `SaveFormat.MAX_NOTE_LENGTH` y emite
`EventBus.hypothesis_changed`. Se guardan con la partida dentro de la sección `state` de siempre:
el tablero no añade nada al formato de guardado. El expediente lee lo mismo, así que las
valoraciones, las notas y las deducciones coinciden en los dos.

### Borradores

Si el jugador cierra el panel con cambios sin guardar (la cruz, Esc, otro sospechoso o cerrar el
tablero), lo escrito queda como borrador en `BoardUi` y la ficha lleva un lápiz. Al volver, el panel
lo recupera, avisa de que no está guardado y ofrece «Descartar cambios». Los borradores duran lo que
dura la partida en curso y nunca se escriben en el archivo: lo que llega a la partida es sólo lo que
se guarda a propósito.

## Cómo se recorre

| Entrada | Efecto |
| --- | --- |
| B (`open_board`) | Abrir y cerrar; con el panel de hipótesis abierto, la B se escribe en la nota |
| Esc (`pause`) | Cierra el panel de hipótesis; si no hay, el tablero, sin abrir la pausa |
| Flechas | Recorren las fichas del corcho y los sospechosos |
| Intro o Espacio | Elige o suelta la ficha; en un sospechoso, abre su hipótesis |
| Tab | En el panel, pasa del selector al cuaderno y a «Guardar hipótesis» |
| Ctrl + Intro | Guarda la hipótesis |
| Ratón | Fichas, sospechosos, cruz de cada hueco, «Relacionar», «[B] Cerrar», rueda en el corcho y en los textos largos |

Al abrir, el foco va a la primera ficha del corcho (o al primer sospechoso). Al cerrar el panel de
hipótesis, vuelve a la ficha del sospechoso que lo abrió. Mientras está abierto, el jugador está
bloqueado con el motivo `tablero`: el HUD se retira y las demás teclas del juego no hacen nada.

## Animaciones

| Momento | Efecto | Duración |
| --- | --- | --- |
| Abrir | Fundido y el tablero crece de 97,5 % a su tamaño | 0,24 s |
| Cerrar | Fundido; una capa transparente ignora los clics mientras tanto | 0,16 s |
| Elegir un sospechoso | Brillo dorado y el panel de hipótesis sube y aparece | 0,14 s y 0,18 s |
| Elegir una ficha | Se levanta un poco y se ilumina | 0,14 s |
| Deducción nueva | La respuesta se estampa, el hilo se tiende y la ficha nueva destella | 0,32 s, 0,7 s y 1,1 s |
| Sin relación | La respuesta tiembla un instante | 0,22 s |
| Guardar hipótesis | La ficha destella y aparece un aviso sobre el corcho | 0,7 s y 2,4 s |

Abrir y cerrar seguido es seguro: cada fundido cancela el anterior y el cierre sólo oculta el
tablero si sigue cerrado al terminar.

## Tamaño de pantalla

Las medidas están en el lienzo de 1920 × 1080 con `canvas_items` y `aspect=expand`: 1280 × 720,
1366 × 768, 1600 × 900 y 1920 × 1080 ven la misma composición a distinta escala.

- El tablero deja un margen de 64 × 34 px y no pasa de 1800 px de ancho (centrado en 21:9).
- La comparación ocupa el 27 % del ancho, entre 380 y 500 px; el corcho, el resto.
- Las fichas de sospechosos se reparten el ancho; por debajo de 270 px se compactan (silueta más
  estrecha y valoración en dos líneas) y, si aun así no caben, la fila se desplaza.
- Las fichas del corcho forman una cuadrícula centrada que se ajusta al ancho; si no caben en alto,
  el corcho se desplaza. El rincón decorativo se retira si el corcho es muy bajo.
- El panel de hipótesis mide como mucho 640 × 620 y se ajusta al corcho.
- El rótulo reduce la letra de 44 a 30 px y la ayuda se recorta si no caben.

Comprobado con pruebas a 16:9, 4:3, 5:4, 16:10 y 21:9, y con capturas a 1280 × 720, 1366 × 768,
1600 × 900, 1920 × 1080 y 1440 × 1080.

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Sospechoso nuevo | `"suspect": true` en su entrada de `characters.json`; su ficha sale sola |
| Deducción nueva | `data/deductions.json`; el tablero la acepta y dibuja su hilo sin tocar código |
| Valoración nueva | `Investigation.HYPOTHESIS_STATUSES` y su rótulo en `JournalInfo.STATUS_LABELS`; su aspecto, en `BoardSuspectCard.set_status()` |
| Tipo de elemento nuevo | `KIND_LABELS` y `GROUPS` de `BoardInfo` y su papel, cinta y chincheta en `BoardStyle` |
| Filtros del corcho | `BoardCanvas._arrange()` reparte por grupos: habría que saltar en él los grupos ocultos y ocultar sus fichas |
| Grabado del rincón | Sustituir `assets/ui/tablero/rincon_escritorio.svg` (o cambiarlo en `tools/generar_grabados.py`) |
| Pantalla táctil | Las fichas son botones normales; el panel ya se cierra con su cruz, sin teclado |
| Color, letra, medida o tiempo | `BoardStyle` |

## Pruebas

`tests/unit/test_board.gd` y `tests/unit/test_board_ui.gd` comprueban con la escena de juego real:

- que B, Esc y «[B] Cerrar» abren y cierran sin bloqueos ni pausa, con fundido, y que abrir y
  cerrar seguido no deja estados a medias;
- que los sospechosos y sus valoraciones salen de los datos y del estado, que caben más y que
  elegir uno no cambia su valoración;
- guardar una hipótesis (también con Ctrl + Intro), su reflejo en la ficha y en el expediente, los
  borradores al cerrar, cambiar de sospechoso o cerrar el tablero, y el límite de la nota;
- que el corcho sólo muestra lo descubierto, agrupado, y que los huecos libres sólo son un indicador;
- los hilos: sólo deducciones registradas con sus dos fichas a la vista, la comparación en curso a
  trazos y el resaltado de las relaciones de la ficha elegida;
- la comparación con el ratón y los cuatro resultados (nueva, ya conocida, sin relación y falta un
  elemento), el tiempo que cuesta y la deducción en el expediente;
- el recorrido con el teclado y el foco al abrir y al cerrar el panel;
- que la decoración no recibe el ratón y que, cerrado, el tablero no roba teclas;
- que a 16:9, 4:3, 5:4, 16:10 y 21:9 nada se sale, se pisa o se recorta;
- que una partida guardada y cargada enseña las mismas valoraciones, hipótesis, deducciones e hilos.

`Investigation.set_hypothesis()` tiene su prueba en `tests/unit/test_investigation.gd`.
`tests/visual/captura.gd` admite `--pistas`, `--hipotesis`, `--seleccion`, `--relacionar`,
`--editar` y `--desplegar` para fotografiar el tablero en cualquier estado.

## Limitaciones

- La foto del encabezado es la silueta del inspector, no un retrato: el juego no tiene retratos.
- El rincón del corcho es un grabado de línea generado por código, más sencillo que la ilustración
  de la referencia; para cambiarlo basta con sustituir el SVG.
- La referencia une con hilo rojo la prueba con los huecos libres. Aquí ese hilo sería una relación
  falsa, así que entre huecos libres sólo hay bramante decorativo, que no toca ninguna ficha.
- Con el panel de hipótesis abierto, la B se escribe en la nota y no cierra el tablero (Esc sí).
- Las animaciones se revisaron con pruebas y capturas fijas, no viéndolas en movimiento, y no se ha
  probado con un mando real.
