# Inspección de evidencias

Qué se ve al examinar una prueba en el escenario, de dónde salen los datos, cómo se maneja, cómo se
adapta a la pantalla y cómo añadir evidencias o plantillas nuevas.

## Qué muestra

Al pulsar E (o A en el mando) junto a una prueba, el escenario se desenfoca y oscurece y aparece el
documento dentro de un marco dorado con volutas en las esquinas. Arriba a la izquierda, una placa
burdeos con el icono y el tipo de evidencia; abajo, montado sobre el marco, el único control:
«[E] Cerrar». La primera vez que se registra la prueba, «Evidencia obtenida» aparece arriba y se
desvanece solo.

| Plantilla | Placa | Pruebas | Qué dibuja |
| --- | --- | --- | --- |
| Carta (`carta`) | Carta personal | `carta_amor` | Pliego desplegado con pliegues en cruz, mancha de humedad y cerco de taza; lugar arriba a la derecha, «Lucía:» con trazo rojo, cuerpo manuscrito, firma con rúbrica, violetas prensadas y la nota del misal escrita a máquina |
| Periódico (`periodico`) | Periódico / Crónica | `periodico_aniversario` | Plana de *El Eco de Villa Sombría* doblada en cuatro y mordida: cabecera con viñeta y lema, número, fecha y precio, titular, subtítulo, dos columnas justificadas, foto nocturna de la mansión en trama y «Hallada en: Quiosco de la plaza» |
| Ficha (`ficha`) | Evidencia / Objeto (o Documento, Fotografía, Carta, Huella según la categoría) | `reloj_despacho`, las siete pruebas ilustradas y cualquier otra prueba | Cartulina doblada: tipo en rojo, título, «Hallada en», descripción a máquina y, a la derecha, la ilustración de la prueba (ver [Ilustraciones de la ficha](#ilustraciones-de-la-ficha)) o el emblema de su categoría |

La ficha es la plantilla por defecto: las pruebas sin plantilla propia se examinan en ella con sus
datos de siempre. Siete de ellas traen además su ilustración en `presentation.art`.

Nada es una captura con el texto incrustado. El papel, el fondo y la impresión del periódico son
shaders; el marco, las placas, los filetes y los trazos de pluma se dibujan en código; las
ilustraciones son imágenes sueltas (SVG o PNG con fondo transparente) colocadas desde los datos; y
todo lo que se lee son etiquetas con los textos de `data/clues.json`, también los nombres de la
lista de invitados.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/clue_inspector.tscn`, `scripts/ui/clue_inspector.gd` | `ClueInspector`, el componente general: abre y cierra, registra la prueba y deja pasar su tiempo, bloquea al jugador, atiende teclado, mando y ratón, coloca las piezas y lanza el aviso |
| `scripts/ui/evidence/evidence_info.gd` | `EvidenceInfo`: lee la prueba de `GameData`, elige la plantilla, la placa y el icono y crea el documento; no cambia nada |
| `evidence_style.gd` | `EvidenceStyle`: paleta, letras, medidas, tiempos y el ajuste de textos largos |
| `evidence_document.gd` | `EvidenceDocument`: base de las plantillas (papel, capa de tinta, etiquetas e imágenes en su tamaño de diseño) |
| `evidence_letter.gd`, `evidence_newspaper.gd`, `evidence_record_card.gd` | Las tres plantillas; la ficha coloca además la ilustración de `presentation.art` sin tapar los textos y la hace asentarse al abrir |
| `evidence_guest_list.gd` | `EvidenceGuestList`: el papel de la lista de invitados con los nombres de los datos, las casillas marcadas, el añadido a mano y la pinza |
| `evidence_paper.gd` | `EvidencePaper`: la hoja con su sombra; cada plantilla elige pliegues, manchas y rasgados |
| `evidence_tag.gd` | `EvidenceTag`: tira de papel escrita a máquina («Hallada en», la nota del misal) |
| `evidence_frame.gd`, `evidence_header_plate.gd`, `evidence_close_button.gd`, `evidence_notice.gd` | Marco, placa del encabezado, botón «Cerrar» y aviso «Evidencia obtenida» |
| `evidence_ornaments.gd` | Volutas, filetes acabados en caracol y placas de esquinas cortadas |
| `assets/shaders/evidence_paper.gdshader` | Papel: manchas, fibras, motas de óxido, pliegues, mancha de humedad, cerco de taza, borde rasgado y quemado, sombra |
| `assets/shaders/evidence_backdrop.gdshader` | El escenario desenfocado y oscurecido detrás del documento |
| `assets/shaders/evidence_newsprint.gdshader` | Trama de imprenta: foto nocturna (cielo, muros oscuros, ventanas encendidas) o viñeta entintada |
| `assets/ui/evidencias/` | `reloj_sobremesa.svg` y `flores_violetas.svg`, generados con `tools/generar_evidencias.py`; las siete ilustraciones PNG, extraídas con `tools/extraer_ilustraciones.py`; `lista_invitados_pinza.svg`, hecha a mano |
| `tools/extraer_ilustraciones.py`, `referencias/evidencias/` | La herramienta de extracción y las siete capturas de referencia de las que sale el arte |
| `assets/ui/iconos/periodico.svg` | Icono nuevo de la placa del periódico |

Se reutiliza lo que ya existía: `HudOrnaments`, `DialogueOrnaments`, `KeyCap`, `InputLabels`,
`CaseFileStyle`, los iconos de `assets/ui/iconos/`, el grabado de la mansión (foto y viñeta del
periódico) y la clase `Engraving` de `tools/generar_grabados.py`.

## De dónde salen los datos

Todo sale de `data/clues.json`; no hay otra base de datos de pistas. Los campos de siempre (`name`,
`category`, `where`, `description`, `prompt`) no cambian, así que el expediente, el tablero y los
diálogos leen lo mismo que antes. Dos campos opcionales añaden la presentación:

- `image`: ilustración de la prueba. Ya lo leía el expediente; ahora lo usa también la ficha. El
  reloj lo trae.
- `presentation`: plantilla (`template`) y textos propios de ella.

| Plantilla | Campos de `presentation` |
| --- | --- |
| `carta` | `salutation`, `body`, `signature`, `note` (dato del investigador, fuera del mensaje) y `ornament` (SVG de la esquina) |
| `periodico` | `masthead`, `tagline`, `issue`, `date`, `price`, `headline`, `subheadline`, `columns` (lista), `image` (foto) y `vignette` (viñeta de la cabecera) |
| `ficha` | Ninguno: usa `name`, `category`, `where`, `description` e `image` |

`header` e `icon` dentro de `presentation` cambian la placa de una prueba concreta.

Decisiones sobre el contenido:

- **La carta no lleva fecha.** La referencia ponía «14 de octubre de 1948», pero el juego no fecha la
  carta en ningún sitio y no se inventa. Arriba a la derecha queda sólo el lugar donde se halló.
- **El misal no está en el mensaje.** «Está doblada dentro de un misal» es la observación del
  investigador: va en una tira escrita a máquina, aparte de lo que escribió Marcos.
- **El periódico es del sábado 16 de octubre de 1948**, el día de la cena (el 16 de octubre de 1948
  fue sábado). La referencia decía «17 de octubre» y «celebró anoche»; la pista de siempre dice «del
  sábado» y «esta noche, cena privada», y eso es lo que se mantiene. Las columnas sólo cuentan lo que
  ya sabía la pista (y los socios del banco que figuran en la lista de invitados). El número del
  diario, el lema y el precio son decorativos y no contradicen nada.
- **El reloj marca las 10:15** en la esfera, que son las 22:15 de la descripción. El generador dibuja
  las agujas a partir de esa hora (`HORA_DEL_RELOJ`).

Una prueba de `test_evidence` comprueba que el cuerpo de la carta, el encabezado, la cabecera y el
titular del periódico aparecen en la descripción que lee el expediente, para que nunca diverjan.

## Ilustraciones de la ficha

Siete pruebas llevan en la ficha una ilustración propia, a la derecha, como en las referencias del
propietario (`referencias/evidencias/`, fuera del proyecto de Godot):

| Prueba | Ilustración | Archivo |
| --- | --- | --- |
| `huellas_betun` | Cuatro pares de huellas de zapato en diagonal, en tinta plana y translúcida | `huellas_betun.png` |
| `foto_clara` | Fotografía sepia de 1948, inclinada, con el letrero «SANATORIO DE SANTA CLARA», bordes gastados y sombra | `foto_clara.png` |
| `lista_invitados` | Hojas apiladas con escudo, encabezado y fecha, sujetas con una pinza de latón; los invitados se escriben con los datos (ver abajo) | `lista_invitados.png`, `lista_invitados_pinza.svg` |
| `billete_tren` | Billete del Ferrocarril Nacional en diagonal: La Capital, Dom. 17, 07:40, N.º 04873 | `billete_tren.png` |
| `libro_bodega` | Libro de cuero con esquinas doradas, lomo con nervios, cinta roja y etiqueta «Registro» | `libro_bodega.png` |
| `llave_reloj` | Llave de latón con la etiqueta «Despacho» colgada de un cordel | `llave_reloj.png` |
| `copa_lavada` | Copa balón vacía y limpia, con gotas de agua junto al pie y su sombra | `copa_lavada.png` |

**Origen.** Son las ilustraciones de las propias referencias, separadas del pergamino con
`tools/extraer_ilustraciones.py` (`uv run --no-project --with pillow --with numpy --with scipy
python tools/extraer_ilustraciones.py [id...]`). La herramienta modela el papel que hay debajo de
cada objeto y despeja su color y su opacidad, de modo que sobre el pergamino del juego se ven como en
la referencia, con sus sombras, y sin el título, el subrayado ni el texto de la interfaz de la
captura. No se ha descargado nada: todo sale de las imágenes del propietario.

**Datos.** Bloque `presentation` de la prueba en `clues.json`, con la plantilla `ficha`:

| Campo de `art` | Qué hace |
| --- | --- |
| `image` | Ruta de la ilustración (PNG o SVG) |
| `center` | Centro, `[x, y]`, en el tamaño de diseño de la ficha (1500 × 900) |
| `width` | Ancho en ese mismo tamaño; el alto sale de la proporción de la imagen |
| `rotation` | Giro en grados (opcional; las siete ya vienen giradas en la imagen) |

El campo `image` de siempre no cambia: sigue siendo la foto del expediente (el reloj). Las siete
pruebas no lo usan, así que el expediente las sigue enseñando con el emblema de su categoría.

**Nunca tapa un texto.** Antes de colocarla, la ficha mide lo que ocupan el tipo, el título, «Hallada
en» y la línea más larga de la descripción, y encoge la ilustración hacia su centro (hasta el 55 %)
mientras alguna parte opaca suya caiga a menos de 12 unidades de un texto o se salga de los filetes
de la cartulina. Se miran los píxeles opacos, no el rectángulo: la llave puede acercarse al título
por donde su imagen es transparente. Con títulos y descripciones más largos se aparta sola.

**Entrada.** Al abrir la hoja, la ilustración aparece 0,08 s después y en 0,42 s pasa del 95 % a su
tamaño y de 1,5° de giro a derecha, como si se asentara sobre el papel. Con «Reducir movimiento»
sólo aparece. El resto de la apertura y el cierre (fundido, escala y fondo oscurecido) es el de
siempre.

### Lista de invitados

Los nombres de la referencia («Don Ricardo Valdés», «Doña Isabel Valdés») no existen en la historia:
la familia es Julián, la víctima y anfitrión, su esposa Elena y su hijo Marcos. Por eso la lista no
es una imagen con los nombres escritos: el papel trae el escudo, «Lista de invitados» y «Cena —
Sábado, 16 de octubre», y `EvidenceGuestList` escribe encima los datos de
`presentation.guest_list`:

| Campo | Qué es |
| --- | --- |
| `guests` | Invitados en orden: `name` y, opcionalmente, `note` (la función entre paréntesis) |
| `added` | El añadido a mano por Julián, al final: otra letra, tinta azul negra y subrayado rojo |
| `clip` | La pinza de latón que sujeta las hojas |

La lista es: Doña Elena Valdés, Don Marcos Valdés, Lic. Andrés Cortés (Notario), Dr. Esteban Rivas,
Don Mauricio Escalante, Don Felipe Aguirre y Don Tomás Olmedo (Banco), y a mano, «Srta. Irene Vidal
(invitada personal)». Así casa con la descripción («la familia, el notario, el doctor y varios
socios del banco») y con lo que dice Elena («Julián la añadió a la lista»). El notario, el doctor y
los socios no tenían nombre en el juego: los de la referencia no contradicen nada y se conservan;
Olmedo se añadió para que los socios sean «varios». Todas las casillas van marcadas, como en la
referencia. Caben ocho filas; con más, avisa y escribe las que caben.

La pinza de la referencia estaba cortada por el borde de la captura: `lista_invitados_pinza.svg` es
una pinza completa dibujada a mano que la tapa.

### Decisiones sobre las referencias

- **Textos de la interfaz.** Todo lo que se lee en la ficha sale de `clues.json`, no de las capturas.
  Por eso se mantienen «Office del mayordomo» (la referencia de la llave decía «Despacho del
  mayordomo»), «tablero del office» (decía «tablero del mayordomo») y «socios del banco. Al final»
  (la referencia tenía una coma).
- **Billete y libro.** Lo escrito en ellos es parte del dibujo y coincide con los datos: destino La
  Capital, domingo 17, 07:40; etiqueta «Registro» en la cubierta del libro de bodega.
- **Copa.** La referencia ya la dibujaba vacía (sólo el brillo ámbar del cristal), como pide la pista.

## Cómo se maneja

| Entrada | Efecto |
| --- | --- |
| E o Intro (`interact`, `ui_accept`); A en el mando | Cerrar, una vez soltada la tecla con la que se examinó |
| Esc (`pause`, `ui_cancel`); B o Menú en el mando | Cerrar, sin abrir la pausa |
| Clic en «Cerrar» | Cerrar |

- **La pulsación que examina no cierra.** Si la tecla de interactuar sigue pulsada al abrirse la hoja,
  ni ella ni sus repeticiones la cierran: hay que soltarla y volver a pulsar.
- **El jugador queda bloqueado** con el motivo `inspeccion` (`GameState.lock_player`): no camina, el
  HUD se retira y las teclas del expediente, el tablero, el mapa o la espera no hacen nada. Al cerrar
  todo vuelve como estaba. Si la partida se cierra con la hoja abierta, el bloqueo se libera.
- **La tecla del botón sale del InputMap** (`InputLabels`): una reasignación o el mando se ven sin
  tocar nada. El botón no toma el foco, para que el botón de aceptar del mando no lo pulse solo.
- No hay flechas ni botones para pasar de una prueba a otra: no es un inventario. Las pruebas
  registradas se consultan en el expediente (J) y en el tablero (B).

## «Evidencia obtenida»

| Fase | Duración |
| --- | --- |
| Espera tras abrir la hoja | 0,12 s |
| Entrada: fundido y descenso de 14 px (sin descenso con «Reducir movimiento») | 0,45 s |
| A la vista | 2,5 s (`ClueInspector.notice_seconds`, editable en el inspector del nodo) |
| Salida: fundido | 0,6 s |

- Sólo aparece cuando `Investigation.discover_clue` registra la prueba por primera vez. Releerla,
  cargar una partida o examinar una prueba conocida no lo muestra.
- Al cerrar la hoja antes de tiempo se corta y desaparece con ella.
- Es una única pieza que se reutiliza: volver a mostrarlo reinicia la animación, nunca apila otro.
- Ocupa un hueco que el marco reserva siempre, así que no mueve ni encoge el documento. Si no cabe
  centrado (pantallas estrechas), sus filetes se acortan o se aparta a la derecha de la placa.
- La inspección registra la prueba con `Investigation.discover_clue(id, false)`, sin el aviso
  «Pista registrada» del HUD, para no anunciar dos veces el mismo hallazgo. Las pistas que se reciben
  en una conversación siguen avisándose en el HUD.

## Tamaño de pantalla

Cada plantilla se diseña en su propio tamaño (1500 × 900 la ficha y el periódico, 1420 × 900 la
carta) y el documento entero se escala para caber entre el aviso y el botón, sin pasar de 1,2 veces
su tamaño. Así ningún texto se sale ni se pisa, y el papel conserva su proporción. Los textos largos
(una descripción extensa, un titular de dos líneas) reducen su letra dentro de la plantilla.

Con «Grande» o «Muy grande» en Accesibilidad, el marco, la placa, el aviso y el botón conservan su
tamaño normal: si crecieran, el documento, que ya ocupa todo el sitio, tendría que encoger. Con
cualquier tamaño de letra, el documento se ve igual de grande.

La trama del periódico no baja de unos 3,4 píxeles de pantalla por punto, para que no forme un
damero en pantallas pequeñas.

Comprobado con pruebas a 16:9, 4:3, 5:4, 21:9 y con la letra «Muy grande», y con capturas a
1280 × 720, 1920 × 1080 y 1024 × 768.

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Presentación propia para otra prueba | Su bloque `presentation` en `clues.json` con una plantilla existente (otra carta, otro periódico) |
| Ilustración de una prueba | Campo `image` con la ruta de un SVG o PNG; la ficha y el expediente la muestran |
| Ilustración sólo para la ficha, con su sitio y tamaño | `presentation.art` (`image`, `center`, `width`, `rotation`) con plantilla `ficha` |
| Extraer otra ilustración de una captura | Su entrada en `ITEMS` de `tools/extraer_ilustraciones.py` (recuadro, umbrales, zonas excluidas) y la captura en `referencias/evidencias/` |
| Cambiar la lista de invitados | `presentation.guest_list` en `clues.json` (hasta ocho filas) |
| Plantilla nueva (fotografía, telegrama, registro...) | Una subclase de `EvidenceDocument` con `get_design_size`, `get_template_id`, `_build` y, si traza líneas, `_draw_ink`; su entrada en `EvidenceInfo.TEMPLATES` y en `EvidenceInfo.create_document` |
| Placa de una categoría | `EvidenceInfo.RECORD_HEADERS` o `header` e `icon` en la presentación |
| Arte definitivo | Sustituir los SVG de `assets/ui/evidencias/` con el mismo nombre, o apuntar `image` y `ornament` a otros archivos |
| Duración del aviso | `notice_seconds` del nodo `ClueInspector` en `game.tscn` (o `EvidenceStyle.NOTICE_HOLD`) |
| Color, letra, medida o tiempo | `EvidenceStyle` |

## Letras

Son del sistema, como en el resto del juego, y cada familia lleva detrás otras parecidas y una
genérica:

| Uso | Familias, por orden |
| --- | --- |
| Carta, cuerpo | Vladimir Script, French Script MT, Edwardian Script ITC, Lucida Handwriting, Segoe Script |
| Carta, encabezado y firma | Edwardian Script ITC, Vladimir Script, French Script MT, Lucida Handwriting, Segoe Script |
| Periódico | Century Schoolbook, Georgia, Times New Roman |
| Ficha, título | Century Schoolbook, Bookman Old Style, Georgia |
| Ficha, texto | Courier New (la máquina de escribir del expediente) |
| Placas y aviso | Palatino Linotype, Book Antiqua, Georgia (las de todo el juego) |
| Lista de invitados | Edwardian Script ITC (los invitados) y Vladimir Script (el añadido de Julián), con las mismas alternativas que la carta |

Vladimir Script, Edwardian Script ITC y Century Schoolbook vienen con Microsoft Office, no con
Windows. En un equipo sin Office, la carta se escribe con Segoe Script y el periódico con Georgia,
que sí vienen con Windows 10 y 11: se lee igual, pero se parece menos a la referencia.

## Pruebas

`tests/unit/test_evidence.gd` comprueba con la escena de juego real:

- que la carta, el periódico y el reloj se abren en su plantilla, con su placa, su icono y «[E]
  Cerrar», y con los textos de `clues.json` (sin fecha en la carta, el misal fuera del mensaje, la
  crónica del sábado 16, la ilustración del reloj sin tapar la descripción);
- que las 19 pruebas se pueden examinar sin dejar bloqueos y que las presentaciones coinciden con
  las descripciones del expediente;
- que el aviso sólo aparece al registrar, sin «Pista registrada» repetido, dura 2,5 s o lo que se
  configure, se va sin cerrar la hoja ni mover el documento, se corta al cerrar y no vuelve al
  releer ni tras guardar y cargar;
- que las pistas recibidas hablando siguen avisándose en el HUD;
- que la E con la que se examina no cierra hasta soltarla, que Esc cierra sin abrir la pausa y que
  el ratón cierra con el botón;
- que el jugador no camina ni abre el expediente mientras lee, que todo vuelve al cerrar y que el
  expediente lista la prueba;
- que el botón muestra la tecla reasignada y que liberar la partida con la hoja abierta no deja el
  bloqueo;
- que todo cabe a 16:9, 4:3, 5:4, 21:9 y con la letra más grande, y que el documento se ve del mismo
  tamaño con cualquier tamaño de letra;
- que las siete pruebas ilustradas se abren en la ficha con la imagen de sus datos, dentro de la
  cartulina, sin el emblema genérico, sin tapar ningún texto (también con títulos y descripciones
  más largos) y conservando casi todo su tamaño;
- que la lista de invitados escribe los nombres de los datos en orden, todos marcados, con el
  añadido que cita la pista y apellidos de personajes de la historia, sin Julián, y con la pinza;
- que la ilustración se asienta al abrir y, con «Reducir movimiento», sólo aparece.

Las pruebas del aviso y de la tecla mantenida se validaron con mutaciones: hacer que la hoja se
pudiera cerrar nada más abrirse y que el aviso sonara siempre las hizo fallar. Las de las
ilustraciones también: llevar la copa encima de la descripción y cambiar el nombre añadido a la
lista las hizo fallar.

`test_journal` comprueba además que el expediente enseña la ilustración del reloj como fotografía.

Capturas: `tests/visual/captura.tscn` con `--open=clue:id` (si la prueba es nueva aparece el aviso;
con `--pistas=id` se relee sin él).

## Limitaciones

- **Arte provisional.** El reloj y las violetas son grabados generados por código, más sencillos que
  los de las referencias; la foto del periódico es el grabado de la mansión impreso en trama, no una
  fotografía. Para sustituirlos basta con reemplazar los SVG.
- **Resolución de las siete ilustraciones.** Tienen la de las capturas (entre 400 y 760 píxeles de
  lado): a 1920 × 1080 se ven casi a un píxel por píxel; a más resolución la ficha crece hasta 1,2
  veces y se suavizan un poco. Para más nitidez habría que extraerlas de capturas más grandes.
- **Extracción.** Donde el objeto se confunde con el papel, la herramienta tuvo que ayudarse de
  límites a mano (el polígono del billete, el ojo de la llave, las zonas de la interfaz que asomaban);
  el billete perdió el cerco de café de la referencia, que el papel del juego ya dibuja en otro sitio.
- **Lista de invitados.** El encabezado y la fecha van en la imagen; los nombres, con letras de
  Office (sin Office, Segoe Script). A 1280 × 720 los nombres se ven pequeños: se leen, pero cuesta.
  La pinza es un dibujo vectorial propio, más sencillo que el latón de la referencia.
- **Letras.** Las manuscritas y la del periódico dependen de Office (ver [Letras](#letras)); no se
  han incluido archivos de fuentes para no meter recursos de terceros.
- **El marco no se ve más fino con la letra grande**: sus filetes se dibujan en el lienzo lógico y
  ganan algo de grosor; las placas y el botón sí conservan su tamaño.
- **Movimiento.** Las animaciones se revisaron con pruebas y capturas fijas, no viéndolas jugando;
  tampoco con un mando real.
- La captura a 21:9 no se pudo hacer con ventana en este equipo (el monitor mide 1920 px); la
  proporción la cubren las pruebas.
