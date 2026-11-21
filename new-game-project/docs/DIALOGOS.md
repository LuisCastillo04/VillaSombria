# Conversaciones y decisiones

Qué muestra una conversación, de dónde saca los datos, cómo se maneja, cómo se adapta a la pantalla
y cómo ampliarla. La lógica es la de siempre (`DialogueManager`); aquí se describe su interfaz.

## Qué muestra

Una sola ventana con dos modos, sobre el escenario real, que sigue en marcha (la lluvia, las farolas
y los personajes no se detienen) bajo un velo oscuro:

| Parte | Contenido |
| --- | --- |
| Siluetas | El detective a la izquierda y el interlocutor a la derecha, con el contraluz ámbar detrás de este. Quien habla se ve con su color y el otro queda atenuado; la narración apaga a los dos |
| Marco | El filete dorado de la pantalla con una banda oscura alrededor, como el paspartú de una lámina |
| Ventana | A lo ancho de la pantalla, al pie: banda de cuero oscuro con filetes dorados y esquinas de latón, y dentro un pergamino envejecido con un filete de tinta de esquinas en escuadra |
| Placa | Placa burdeos con filete dorado y extremos en punta, montada sobre el borde superior izquierdo, con el nombre de quien habla en crema entre dos rombos |

**Lectura.** El texto es lo principal: Palatino en negrita cursiva a 44 px, tinta `#24170F` sobre el
pergamino, márgenes amplios y hasta tres líneas. La narración va en cursiva redonda y tinta más suave,
sin placa. Debajo, un separador con un rombo hueco y, en la esquina inferior derecha, la pestaña
burdeos «[E] Continuar» con la tecla real en un recuadro oscuro. No hay ilustraciones ni retratos
dentro de la ventana.

**Respuestas.** La misma ventana crece hacia arriba y cambia su contenido por una columna centrada
de tarjetas: pergamino claro con borde marrón, y la señalada en burdeos con borde dorado encendido,
letra crema y una flecha. Cada una lleva el número de su tecla; las preguntas que aún no se han
hecho, un rombo a la izquierda. Al pie, un separador y «Elige con el ratón o con las teclas
numéricas» con un icono de ratón.

La placa nunca atribuye al interlocutor lo que va a decir el detective: en un interrogatorio rotula
«Tus preguntas» y en una escena, «Tus respuestas». Mientras se elige, la luz sigue en quien escucha
(en un interrogatorio, el interlocutor; en una escena, el detective), como antes del rediseño.

Todo se dibuja en Godot sobre la partida: no hay capturas de fondo y los textos son etiquetas
editables. El cuero y el pergamino son los shaders del expediente y del tablero.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/dialogue_ui.tscn`, `scripts/ui/dialogue_ui.gd` | `DialogueUi`: escucha `DialogueManager`, pasa de la lectura a la elección, reparte las entradas y anima la ventana |
| `scripts/ui/dialogue/dialogue_style.gd` | `DialogueStyle`: paleta, letras, medidas en el lienzo de 1920 × 1080 y tiempos |
| `scripts/ui/dialogue/dialogue_frame.gd` | `DialogueFrame`: la ventana de cuero y pergamino, común a los dos modos |
| `scripts/ui/dialogue/dialogue_speaker_plate.gd` | `DialogueSpeakerPlate`: la placa con el nombre o el rótulo de las respuestas |
| `scripts/ui/dialogue/dialogue_text.gd` | `DialogueText`: escritura progresiva, páginas y voz de la narración |
| `scripts/ui/dialogue/dialogue_continue_button.gd` | `DialogueContinueButton`: la pestaña «Continuar» |
| `scripts/ui/dialogue/dialogue_choices.gd` | `DialogueChoices`: la lista de respuestas, su selección y su desplazamiento |
| `scripts/ui/dialogue/dialogue_choice_item.gd` | `DialogueChoiceItem`: una tarjeta de respuesta |
| `scripts/ui/dialogue/dialogue_choice_hint.gd` | `DialogueChoiceHint`: el pie de las respuestas |
| `scripts/ui/dialogue/dialogue_controls.gd` | `DialogueControls`: qué entradas avanzan, eligen y confirman, y sus rótulos desde el InputMap |
| `scripts/ui/dialogue/dialogue_cast.gd` | `DialogueCast`: las siluetas, su iluminación, la respiración y el contraluz |
| `scripts/ui/dialogue/dialogue_ornaments.gd` | `DialogueOrnaments`: placa, pestaña, esquinas en escuadra y de latón, degradados |

Se reutilizan `CinematicFrame` (marco de la pantalla, ahora con `band_color` y `emphasis`),
`GoldDivider` (con rombo hueco, `hollow`), `HudOrnaments`, `MenuStyle.keycap_box`,
`JournalStyle.style_scroll`, `InputLabels` y los shaders `leather`, `parchment` e
`interrogation_backlight`. El icono `assets/ui/iconos/raton.svg` es nuevo.

## De dónde salen los datos

La interfaz no guarda nada ni copia la conversación: lo que muestra llega por las señales de
`DialogueManager` (`opened`, `line_shown`, `options_shown`, `closed`) y lo que elige el jugador vuelve
con `DialogueManager.advance()` y `choose()`, que deciden qué pasa después.

| Dato | Fuente |
| --- | --- |
| Texto | La línea `t` de `data/dialogues/`, sin tocar |
| Quién habla | La línea `s`; `narrador` es la narración |
| Nombre de la placa | `name` en `data/characters.json` (`GameData.get_character_name`) |
| Silueta | `portrait` en `data/characters.json` (SVG o PNG) |
| Respuestas, su orden y sus identificadores | `options_shown` (`id`, `label`, `asked`) |
| Rótulo de las respuestas | «Tus preguntas» si el menú incluye `DialogueManager.EXIT_OPTION` (un interrogatorio), «Tus respuestas» si no (una escena) |
| Tecla de «Continuar» | La primera de `interact` en el InputMap (o de `ui_accept`), con `InputLabels`, cada vez que se abre |

## Cómo se maneja

| Entrada | Lectura | Respuestas |
| --- | --- | --- |
| E (`interact`), Intro o Espacio (`ui_accept`) | Completa la página; después pasa de página o a la siguiente intervención | Confirma la señalada |
| Clic izquierdo | Igual que E, en cualquier punto | Elige la tarjeta pulsada |
| ↑ ↓ (`ui_up`, `ui_down`) | — | Recorren las respuestas; de la última se vuelve a la primera |
| 1 a 9 (fila superior o teclado numérico) | — | Eligen esa respuesta |
| Mover el ratón | Sobre «Continuar», la aviva | Señala la tarjeta, sin elegirla |
| Rueda | — | Desplaza la lista |

- Una pulsación hace una sola cosa: nunca completa el texto y avanza a la vez, y las repeticiones
  de una tecla mantenida no cuentan.
- Durante 0,3 s tras aparecer las respuestas no se acepta confirmar con una tecla ni con un clic,
  para que una pulsación de más al terminar de leer no haga la primera pregunta. Los números sí.
- El ratón sólo señala al moverse: si las respuestas aparecen bajo un cursor quieto, el foco sigue
  donde lo deja el teclado.
- Al volver al menú, el foco regresa a la respuesta elegida. Al cerrar, la conversación suelta el
  foco y deja de aceptar clics mientras se desvanece.
- Todas estas teclas se consumen en la conversación. El jugador está bloqueado con el motivo
  `dialogo`, así que el expediente, el tablero, el mapa, la pausa y la espera no se abren, y la E
  que cierra la conversación no vuelve a abrirla.

### Textos largos

`DialogueText` reparte en páginas un texto que no cabe en tres líneas. Corta donde la propia
etiqueta parte las líneas con su ancho real, así que cada página empieza en la palabra siguiente a la
anterior: se lee todo, en orden y sin repetir. Las líneas se calculan con el texto completo
(`VC_CHARS_AFTER_SHAPING`), de modo que las palabras no saltan de renglón mientras se escriben. Si
cambia el ancho de la ventana, el texto se reparte de nuevo sin perder lo leído. La letra no se
reduce para que quepa más.

Con el contenido actual del caso ninguna línea necesita más de dos renglones; la paginación queda
para textos futuros o pantallas más estrechas.

## Animaciones

| Momento | Efecto | Duración |
| --- | --- | --- |
| Abrir | El velo y el marco se funden, las siluetas llegan desde los lados y la ventana sube 70 px | 0,45 s |
| Primera intervención | Empieza a escribirse cuando la ventana ya casi ha llegado | 0,22 s de espera |
| Escritura | 48 letras por segundo, una tecla cada tres y una pausa breve tras un punto o una coma | — |
| Cambio de quien habla | El nombre de la placa se apaga y se enciende; el tinte de las siluetas y el contraluz cambian | 0,1 s + 0,2 s; 0,2 s |
| Texto completo | «Continuar» late despacio | 1,1 s por latido |
| Lectura ↔ respuestas | El contenido se funde y el borde superior, con la placa, sube o baja hasta su altura | 0,3 s |
| Respuestas | Entran escalonadas con un fundido y una subida corta | 0,2 s, 0,035 s entre una y otra |
| Señalar | Transición de pergamino a burdeos, borde dorado y flecha | 0,14 s |
| Confirmar | La tarjeta elegida destella | 0,22 s |
| Cerrar | Todo se desvanece mientras la ventana baja un poco | 0,25 s |

Lo de dentro de la ventana está anclado a su pie y recortado por ella, así que al cambiar de altura
nada se mueve bajo el cursor ni se sale. Una escena que empieza en el mismo instante en que termina
otra (la confrontación da paso al epílogo) sigue desde donde estaba, sin apagarlo todo.

## Tamaño de pantalla

Las medidas están en el lienzo de 1920 × 1080 con `canvas_items` y `aspect=expand`: 1280 × 720,
1366 × 768, 1600 × 900 y 1920 × 1080 ven la misma composición a distinta escala.

- La ventana deja 56 px a los lados y 44 px abajo, sin pasar de 1808 px de ancho: en 21:9 queda
  centrada en una zona 16:9, como el HUD.
- Las siluetas se anclan a los lados de esa zona 16:9 y al pie, siempre por detrás de la ventana.
- Las respuestas ocupan el ancho útil hasta 1460 px. La ventana crece con ellas sin pasar del 52 %
  del alto, para que las caras de las siluetas sigan a la vista; desde cinco respuestas las tarjetas
  se compactan y, si aun así no caben, la lista se desplaza y sigue a la señalada.
- Las respuestas largas se parten en líneas y su tarjeta crece.

Comprobado con pruebas a 16:9, 4:3, 5:4, 16:10 y 21:9, y con capturas a 1280 × 720, 1366 × 768,
1600 × 900 y 1920 × 1080.

## Convivencia con el resto del juego

- La conversación es la capa 6: por encima del HUD (2) y por debajo de la inspección (7), el
  expediente y el tablero (8), la acusación (9), el cierre (15), la pausa (20) y la salida (50).
- El HUD de exploración se retira mientras dura (bloqueo `dialogo`) y vuelve al terminar. Sus avisos
  tienen capa propia: durante una conversación suben por encima de ella y se centran arriba, entre
  las dos siluetas, para que una pista o un testimonio conseguidos hablando se lean.
- Guardar sigue bloqueado durante una conversación (`SaveSystem.get_save_blocker`) y al cerrar el
  juego se guarda el estado de antes de empezarla, como antes. La interfaz no añade nada a las
  partidas: lo dicho y lo conseguido son marcas, pistas y testimonios de `GameState`.
- Con la pregunta de salida en pantalla (X o Alt + F4) el árbol se pausa y la conversación no
  recibe teclas.

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Personaje nuevo | Su entrada en `characters.json` (`name`, `portrait`) y su archivo en `data/dialogues/`: la placa y la silueta salen solas |
| Expresiones | Cada personaje tiene hoy una silueta. Para variantes, un campo opcional por línea que `DialogueCast.set_speaker` traduzca a otra textura |
| Velocidad del texto | `DialogueText.characters_per_second` (por defecto `DialogueStyle.CHARACTERS_PER_SECOND`); la opción prevista de Configuración la leería de `Settings` |
| Líneas por página | `DialogueStyle.TEXT_LINES` |
| Rótulos de las respuestas | `DialogueChoices.TOPICS_HEADING` y `REPLIES_HEADING` |
| Voces | Como prevé la arquitectura, un campo por línea; `DialogueUi._on_line_shown` es donde reproducirla |
| Mandos | `DialogueControls` decide qué avanza, elige y confirma, e `InputLabels` qué nombre se muestra |
| Android | Las tarjetas son botones y «Continuar» avanza con un toque, que llega como un clic; no hay controles táctiles propios |
| Color, letra, medida o tiempo | `DialogueStyle` |

## Pruebas

`tests/unit/test_dialogue_ui.gd` comprueba con la escena de juego real y entradas como las del
jugador:

- que la placa lleva el nombre de `characters.json`, que se ilumina la silueta de quien habla con la
  textura de sus datos y que el texto es el de los datos, sin cambios;
- que la ventana sólo contiene texto y controles (ningún retrato) y queda por delante de las siluetas;
- la escritura: la primera pulsación completa, la segunda avanza una sola intervención, el clic
  equivale a la tecla y «Continuar» late sólo con el texto entero;
- los cambios de voz de una escena (placa, luz, silueta y narración);
- la paginación: todas las palabras, en orden y sin repetir, cada página cabe y pasar de página no
  salta intervenciones; con menos ancho se reparte de nuevo;
- que las respuestas son las de `DialogueManager`, en su orden, numeradas y sin cambios, y que elegir
  una entrega su pista y su testimonio y la retira del menú según los datos;
- los rótulos «Tus preguntas» y «Tus respuestas», y la luz mientras se elige;
- flechas con vuelta al principio, teclas numéricas (también del teclado numérico), ratón que señala
  sin elegir, clic que elige, la protección tras aparecer las respuestas y el foco al volver;
- listas largas compactas y desplazables, y respuestas largas que se parten en líneas;
- el cierre: control devuelto, foco suelto, ventana desvanecida y HUD de vuelta; que la E que cierra
  no reabre; que ninguna tecla abre otra pantalla; los avisos por encima; y las escenas encadenadas;
- que no se guarda a mitad de una conversación y que lo conseguido hablando sobrevive a guardar y
  cargar;
- que «Continuar» sigue una reasignación de `interact`;
- que a 16:9, 4:3, 5:4, 16:10 y 21:9 la ventana, la placa, el texto, la pestaña, la lista y la ayuda
  caben sin pisarse y las caras de las siluetas quedan a la vista.

`tests/visual/captura.gd` admite `--escena=id` y `--pasos=a,a,2` (avanzar y elegir) para fotografiar
una conversación en cualquier momento.

## Diferencias con la referencia y limitaciones

- En la referencia de las respuestas la placa dice «Eusebio Pardo». Aquí dice «Tus preguntas» o «Tus
  respuestas»: las opciones son frases del detective y no deben atribuirse al interlocutor.
- Se mantiene el contraluz ámbar con persianas detrás del interlocutor, que la referencia no muestra:
  es el sistema de iluminación que ya tenía el juego. Ahora se templa mientras el interlocutor escucha.
- Las esquinas del marco de la pantalla son las escuadras del HUD, no volutas.
- La marca de las preguntas nuevas pasa de «●» a un rombo. Las réplicas de las escenas la siguen
  llevando, como antes, porque `DialogueManager` las envía con `asked: false`.
- Las animaciones se revisaron con pruebas y capturas fijas, no viéndolas en movimiento; no se ha
  probado con un mando real ni se ha escuchado el sonido de la escritura.
