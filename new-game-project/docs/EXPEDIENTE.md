# Expediente del detective

Qué muestra el expediente (tecla J), de dónde saca los datos, cómo se recorre, cómo se adapta a la
pantalla y cómo ampliarlo.

## Qué muestra

Una carpeta de cuero con una banda de pergamino arriba: la pila de fotos con su clip (la mansión
Valdés, escena del crimen), el rótulo «EXPEDIENTE 1948/17 · CASO VALDÉS», el matasellos con el sello
«VILLA SOMBRÍA · 1948» y cinco pestañas. Debajo, dos páginas de pergamino y, al pie, las ayudas de
teclado y «J Cerrar el expediente».

| Pestaña | Página izquierda | Página derecha |
| --- | --- | --- |
| Objetivos | La fecha del día y los objetivos visibles, en curso, pendientes o cumplidos; grabado de la mansión | Fecha y hora, recuento de pistas, testimonios y deducciones, foto sepia del lugar donde está el detective y las reglas del tiempo |
| Pistas | «PISTAS (N)» y las pruebas halladas, con el icono de su categoría; grabado del escritorio | Categoría, procedencia, descripción completa, deducciones en que ya se usó y su imagen, o el emblema de su categoría |
| Testimonios | «TESTIMONIOS (N)», agrupados por personaje con su retrato; grabado del interrogatorio | Quién declara, su papel, el tema, el texto completo y las deducciones en que ya sirvió; su retrato con clip |
| Sospechosos | «SOSPECHOSOS (5)» con sus retratos; grabado del Café La Luna | Relación con el caso, biografía, paradero, valoración, hipótesis del tablero, declaraciones oídas y retrato con clip |
| Deducciones | «DEDUCCIONES (N)», contradicciones y conexiones; libros y lupa | Conclusión, tipo y las pruebas y declaraciones que la sostienen |

Estados vacíos: Pistas y Testimonios muestran un emblema, un rótulo, un filete y una línea de
ayuda («Examina objetos y documentos con [E]…»). Deducciones, sin conclusiones, es una sola página
grande con el grabado del tablero, «Aún no hay deducciones.» y «Relaciona pruebas y testimonios en
el tablero [B].», y libros y una lupa en la esquina. Las teclas entre corchetes salen del InputMap.

Todo se construye con nodos de Godot sobre la partida real: no hay capturas de fondo y los textos
son etiquetas. El pergamino y el cuero son shaders; los iconos, grabados y adornos, SVG propios o
dibujo en código.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/journal_ui.tscn`, `scripts/ui/journal_ui.gd` | `JournalUi`: abre y cierra, cambia de sección, atiende el teclado y pone al día la sección visible |
| `scripts/ui/journal/journal_info.gd` | `JournalInfo`: lee los datos de los sistemas del juego; no cambia nada |
| `scripts/ui/journal/journal_style.gd` | `JournalStyle`: paleta, letras, medidas en el lienzo de 1920 × 1080, tiempos y recuadros |
| `scripts/ui/journal/journal_ornaments.gd` | `JournalOrnaments`: clip de latón, ondas del matasellos, pespuntes y esquinas de la carpeta |
| `journal_folder.gd` | `JournalFolder`: la carpeta de cuero; coloca encabezado, sello, pestañas, cuerpo y pie |
| `journal_header.gd`, `journal_photo_stack.gd`, `journal_seal.gd` | Encabezado: rótulo, pila de fotos con clip y matasellos (hereda el texto en arco de `CaseStamp`) |
| `journal_tabs.gd`, `journal_tab.gd` | Pestañas con icono; compactas si no caben |
| `journal_section.gd` | `JournalSection`: base de las cinco secciones (lista a la izquierda, ficha a la derecha) |
| `journal_list_column.gd`, `journal_list.gd`, `journal_list_item.gd`, `journal_thumb.gd` | Página de la lista, la lista elegible, sus fichas y las miniaturas |
| `journal_detail.gd` | `JournalDetail`: la ficha (insignia, título, datos, recuadro de texto, foto, estado vacío) |
| `journal_page.gd`, `journal_banner.gd` | Página de pergamino con grabado opcional y la cinta burdeos de cada página |
| `journal_photo.gd` | `JournalPhoto`: fotografía sepia con marco de papel y clip |
| `journal_empty_state.gd` | `JournalEmptyState`: estados vacíos con grabado o emblema y tecla real |
| `journal_objective_card.gd` | Tarjeta de un objetivo con su casilla de estado |
| `journal_*_section.gd` | Las cinco secciones: de dónde salen sus datos y cómo se pinta su ficha |
| `assets/shaders/leather.gdshader` | Cuero de la carpeta |
| `assets/shaders/sepia_photo.gdshader` | Virado a sepia, fondo de estudio, viñeta y grano de las fotos |
| `assets/ui/expediente/` | Grabados: `cafe_la_luna`, `escritorio`, `interrogatorio`, `tablero`, `libros_lupa` |
| `assets/ui/iconos/` | Iconos nuevos: `objetivo`, `testigos`, `antifaz`, `cerebro`, `persona`, `ubicacion`, `balanza`, `microfono`, `carta`, `reloj`, `huella`, `fotografia`, `documento`, `etiqueta`, `contradiccion`, `conexion` |
| `tools/generar_grabados.py` | Genera los grabados de `assets/ui/expediente/` |

Se reutiliza lo que ya existía: el shader de pergamino, `HudOrnaments` (rombos, escuadras, cintas),
`GoldDivider`, `KeyCap`, `InputLabels`, `CinematicFrame`, el grabado de la mansión, las siluetas de
los personajes y `SavePreview` para la foto del lugar.

## De dónde salen los datos

| Dato | Fuente |
| --- | --- |
| Objetivos y su estado | `StoryDirector.get_objectives()`: el primero pendiente está en curso (el mismo del HUD) |
| Fecha y hora | `StoryDirector.get_day_title()` y `GameClock.format_time()` |
| Recuentos | `GameState.clues`, `testimonies` y `deductions` frente a `GameData` (los testimonios, sin total, para no adelantar cuántos quedan) |
| Reglas del tiempo | `DialogueManager.TOPIC_MINUTES`, `Investigation.CLUE_MINUTES`, `BoardUi.LINK_MINUTES`, `GameClock.DAY_LIMIT`, `Game.REST_LOCATION` y la tecla de `wait_time` |
| Foto del lugar | La cámara del juego, con `SavePreview`, una vez por lugar; sin ventana, el emblema del lugar |
| Pistas | `GameState.clues` (orden de hallazgo) y `data/clues.json`; la imagen sólo si la pista trae `image` |
| Testimonios | `GameState.testimonies` y `data/testimonies.json`; fecha y lugar sólo si traen `day` y `where` |
| Sospechosos | `GameData.get_suspects()`, `characters.json`, `StoryDirector.describe_whereabouts()` y `GameState.hypotheses` |
| Deducciones | `GameState.deductions` y `data/deductions.json`; las pruebas, sólo de parejas que el jugador tiene completas |
| Teclas | InputMap, a través de `InputLabels`, cada vez que se abre |

El expediente no guarda nada: después de cargar una partida enseña exactamente lo mismo. Las
valoraciones e hipótesis siguen siendo cosa del tablero y la combinación de pruebas sigue en
`Investigation.try_link`.

## Cómo se recorre

| Entrada | Efecto |
| --- | --- |
| J o Tab (`open_journal`) | Abrir y cerrar |
| Esc (`pause`) | Cerrar, sin abrir la pausa |
| ← → | Cambiar de sección, desde una ficha o desde las pestañas |
| ↑ ↓ | Elegir ficha; desde las pestañas, ↓ baja a la ficha elegida y desde la primera ficha ↑ sube a su pestaña |
| 1 a 5 | Ir directamente a una sección |
| Av Pág, Re Pág | Desplazar una ficha larga (y, en Objetivos, también la lista) |
| Ratón | Pestañas, fichas, rueda en listas y fichas, y «Cerrar el expediente» |

Al abrir sin indicar sección vuelve a la última que se miró, con la misma ficha elegida. Las
secciones se crean una vez: cambiar de pestaña sólo las muestra u oculta y `refresh()` rehace las
fichas de la lista únicamente si sus datos han cambiado. Con el expediente abierto, las señales de
`EventBus` (pistas, testimonios, deducciones, objetivos, reloj, día, lugar) ponen al día la
sección visible una sola vez por fotograma.

Mientras está abierto, el jugador está bloqueado con el motivo `expediente`: el HUD se retira y
las teclas del tablero, el mapa o la espera no hacen nada.

## Animaciones

| Momento | Efecto | Duración |
| --- | --- | --- |
| Abrir | Fundido y la carpeta crece de 97,5 % a su tamaño | 0,24 s |
| Cerrar | Fundido; una capa transparente ignora los clics mientras tanto | 0,16 s |
| Cambiar de sección | La sección nueva se funde | 0,16 s |
| Elegir una ficha | La ficha de la derecha aparece desde el 35 % de opacidad | 0,18 s |

## Tamaño de pantalla

Las medidas están en el lienzo de 1920 × 1080 con `canvas_items` y `aspect=expand`: 1280 × 720,
1366 × 768, 1600 × 900 y 1920 × 1080 ven la misma composición a distinta escala.

- La carpeta deja un margen de 86 × 46 px y no pasa de 1760 px de ancho (centrada en 21:9).
- Las pestañas se reparten por igual hasta 268 px. Si no caben, pasan a compactas; si tampoco,
  pasan por debajo del sello.
- La lista ocupa el 31 % del ancho, entre 400 y 540 px. La foto de la ficha, como mucho el 34 %
  de su página; en una página muy estrecha se retira.
- El rótulo del encabezado reduce la letra de 46 a 28 px si no cabe.
- Los grabados de las listas sólo ocupan el hueco libre bajo las fichas y desaparecen si la lista
  lo llena. Listas y fichas largas se desplazan.

Comprobado con pruebas a 16:9, 4:3, 5:4, 16:10 y 21:9, y con capturas a 1280 × 720, 1366 × 768,
1600 × 900, 1920 × 1080 y 1024 × 768.

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Imagen de una pista | Campo `image` en `data/clues.json` con la ruta de la textura |
| Fecha o lugar de un testimonio | Campos `day` y `where` en `data/testimonies.json` |
| Retrato propio de un personaje | Su `portrait` en `characters.json`; las miniaturas y la foto recortan `PORTRAIT_FACE` y `PORTRAIT_BUST` de `JournalInfo` |
| Grabado nuevo | Un SVG en `assets/ui/expediente/` (o `tools/generar_grabados.py`) y `column.art` en la sección |
| Sección nueva | Una subclase de `JournalSection` con `refresh()` y `_show_detail()`, añadida en `JournalUi._build_sections()` con su pestaña |
| Color, letra, medida o tiempo | `JournalStyle` |

## Pruebas

`tests/unit/test_journal.gd` comprueba con la escena de juego real:

- que J, Tab y Esc abren y cierran sin dejar bloqueos, sin abrir la pausa y con fundido;
- que las cinco pestañas existen con sus iconos y que el tablero sigue leyendo las valoraciones;
- que objetivos, recuentos, reglas, pistas, testimonios, sospechosos y deducciones son los de los
  sistemas del juego, que se ponen al día con el expediente abierto y que nada no descubierto
  aparece (ni fechas o lugares inventados, ni declaraciones que no se han oído);
- los estados vacíos con sus textos y las teclas reales;
- el recorrido con teclado (← → ↑ ↓, cifras, Av Pág y Re Pág) y con ratón;
- que al volver a abrir se recuerda la sección y la ficha sin rehacer la lista;
- que a 16:9, 4:3, 5:4, 16:10 y 21:9 nada se sale, se pisa o pide más sitio del que hay;
- que una partida guardada y cargada enseña el mismo expediente.

## Limitaciones

- Las siete imágenes de referencia recibidas eran la misma (Sospechosos). Las otras cuatro
  pestañas siguen la descripción escrita del encargo con el mismo lenguaje visual.
- La foto de la pila del encabezado es la mansión, no un retrato: el juego no tiene retrato de la
  víctima y no se ha inventado uno.
- Los grabados son ilustraciones de línea generadas por código, más sencillas que las de la
  referencia; para sustituirlos basta con reemplazar los SVG.
- Ninguna pista trae imagen propia ni ningún testimonio fecha o lugar: la estructura está lista,
  pero los datos no existen y no se han inventado.
- Las animaciones se revisaron con pruebas y capturas fijas, no viéndolas en movimiento.
