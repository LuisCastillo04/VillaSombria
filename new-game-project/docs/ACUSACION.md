# Acusación formal

Cómo funciona la hoja de acusación que abre el sargento Ortega el tercer día: qué muestra, cómo
se eligen el sospechoso y las pruebas, cómo se clasifican las pruebas por categoría, cómo se
conserva el borrador y cómo ampliarla.

## Qué muestra

Una hoja de papel envejecido dentro de un marco burdeos con filetes dorados, sobre el escenario
desenfocado y oscurecido (el mismo fondo que la inspección de evidencias):

- **Encabezado**: «ACUSACIÓN FORMAL» en versalitas, un filete con un rombo, el emblema de la
  balanza montado sobre el marco, la fotografía de la mansión prendida con un clip y una pluma
  estilográfica. No lleva ninguna referencia al sanatorio: es la hoja general de acusación.
- **Cuatro campos**, cada uno con su medallón (persona, «?», reloj, lupa), su cinta con la
  pregunta y su selector:
  - **Acuso a:** el sospechoso.
  - **Motivo:** por qué lo hizo.
  - **Oportunidad:** cómo pudo estar allí a la hora real.
  - **Medios:** cómo lo hizo.
- **La línea de Ortega**: «Ortega te escucha en silencio. Presenta tus pruebas.» o, tras una
  acusación que no se sostiene, por qué.
- **Lo que falta**: «Falta elegir: oportunidad y medios.», sólo mientras falte algo.
- **Dos botones**: «Presentar la acusación» (placa burdeos con la balanza, la acción principal) y
  «Seguir investigando» (placa carbón con la lupa).

Un campo pendiente muestra «Seleccionar sospechoso» o «Seleccionar evidencia o testimonio» en
cursiva, con el recuadro claro y el medallón oscuro. Uno elegido lleva el nombre en redonda, el
icono de su clase, filete dorado y el medallón burdeos. Ninguno de los dos estados dice si la
elección es buena. El campo que se está editando lleva el filete burdeos y el medallón iluminado.

### Lista de sospechosos

El selector del sospechoso despliega una lista propia (no el menú genérico de Godot): papel claro,
filete dorado y sombra, con el retrato, el nombre y el papel en la casa de cada uno. El elegido va
en burdeos con un rombo dorado; el que se señala con el ratón se aclara; el del teclado o el mando
lleva el contorno dorado del foco. Se abre y se cierra con un fundido y un leve desplazamiento,
sigue al selector aunque la hoja esté animándose y, si no cabe debajo, se abre encima.

### Panel lateral de pruebas

El motivo, la oportunidad y los medios abren un panel a la derecha. La hoja se desliza a la
izquierda para dejarle sitio y sigue a la vista; al cerrarlo vuelve al centro.

- **Encabezado** burdeos con el medallón del campo y su título: «Seleccionar prueba del motivo»,
  «… de la oportunidad», «… de los medios»; debajo, la pregunta del campo y un botón de cierre.
- **Buscador**: filtra por nombre o por contenido, sin distinguir mayúsculas ni tildes, y exige
  todas las palabras («22:40 bodega»). Sin coincidencias, lo dice repitiendo la búsqueda.
- **Lista desplazable**, agrupada en «Pruebas», «Testimonios» y «Deducciones» con su número, y en
  cada grupo en el orden en que se descubrió. Cada fila lleva el icono de su clase:

  | Clase | Icono | Ejemplos |
  | --- | --- | --- |
  | Documento | `documento` | Transferencia, pagaré, telegrama, crónica |
  | Carta | `carta` | Carta de Julián, carta de amor |
  | Fotografía | `fotografia` | Fotografía de Clara, recortes de prensa |
  | Objeto | `etiqueta` | Reloj, copa, llave, billete, huellas de betún |
  | Registro | `libro` | Libro de bodega, registro de la pensión, de taquilla, de la compañía, lista de invitados |
  | Informe | `carpeta` | Informe del forense |
  | Testimonio | `testigos` | «Ortega: La escena del crimen» (con el nombre corto de quien habla) |
  | Deducción | `cerebro` | «Nadie estaba en la bodega» |

- **Barra de desplazamiento** burdeos sobre un carril de tinta, con flechas en los extremos.
- **Vista previa**: título completo, clase y hasta cuatro líneas de la descripción de lo que se
  señala o tiene el foco, para recordar qué dice sin salir de la acusación.
- **Pie** con las teclas reales de volver y elegir, leídas del InputMap.

La elección actual del campo va en burdeos; nada viene elegido de antemano. Elegir una fila
actualiza sólo ese campo y cierra el panel. Si la categoría no tiene nada descubierto, el panel lo
dice sin adelantar qué hay que buscar: «Todavía no has reunido pruebas ni testimonios que expliquen
por qué alguien querría matarlo. Sigue investigando: examina los lugares e interroga a los
sospechosos.»

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/accusation_ui.tscn` | La escena: fondo, hoja con sus contenedores (encabezado, campos, separador, Ortega, lo que falta, botones), panel lateral, lista de sospechosos y escudo |
| `scripts/ui/accusation_ui.gd` | `AccusationUi`: coordina apertura y cierre, listas, elecciones, presentación, Escape por niveles y la composición |
| `scripts/ui/accusation/accusation_style.gd` | `AccusationStyle`: paleta, letras, medidas, tiempos, recuadros, botones, filas, barra y buscador |
| `scripts/ui/accusation/accusation_info.gd` | `AccusationInfo`: lee sospechosos, opciones y borrador y les da forma para la interfaz; textos fijos |
| `scripts/ui/accusation/accusation_sheet.gd` | `AccusationSheet`: papel, marco, filetes, volutas, escuadras y cerco de café |
| `scripts/ui/accusation/accusation_header.gd` | `AccusationHeader`: rótulo en versalitas, filete, emblema, foto y pluma |
| `scripts/ui/accusation/accusation_field.gd` | `AccusationField`: un campo (datos exportados en la escena) |
| `scripts/ui/accusation/accusation_field_heading.gd` | `AccusationFieldHeading`: medallón y cinta de un campo |
| `scripts/ui/accusation/accusation_selector.gd` | `AccusationSelector`: el selector con su texto, icono, flecha y estados |
| `scripts/ui/accusation/accusation_suspect_list.gd` | `AccusationSuspectList`: la lista desplegable de sospechosos |
| `scripts/ui/accusation/accusation_evidence_panel.gd` | `AccusationEvidencePanel`: el panel lateral (hereda la hoja) |
| `scripts/ui/accusation/accusation_list_row.gd` | `AccusationListRow`: fila de las dos listas |
| `scripts/ui/accusation/accusation_verdict.gd` | `AccusationVerdict`: la línea de Ortega con su fundido |
| `scripts/ui/accusation/accusation_plate_button.gd` | `AccusationPlateButton`: las placas de los dos botones |
| `scripts/core/evidence_categories.gd` | `EvidenceCategories`: la clasificación deductiva y la clase de cada elemento |
| `data/evidence_categories.json` | Los datos de la clasificación |
| `assets/ui/acusacion/` | Flechas de la barra de desplazamiento |

Se reutilizan el pergamino (`parchment.gdshader`), el fondo desenfocado de las evidencias
(`evidence_backdrop.gdshader`), la foto con clip del expediente (`JournalPhoto`), sus miniaturas
(`JournalThumb`), los adornos de `HudOrnaments`, `EvidenceOrnaments`, `DialogueOrnaments` y
`BoardOrnaments`, los iconos de `assets/ui/iconos/`, las teclas (`KeyCap`, `InputLabels`), las
letras de `CaseFileStyle` y los sonidos de interfaz (`ui_abrir`, `ui_cerrar`, `ui_mover` al mover el
foco, `click` al elegir y `acusacion_fallida`).

La presentación no conoce las reglas: los datos los da `Investigation` y la clasificación
`EvidenceCategories`; `AccusationInfo` sólo les da forma.

## Clasificación deductiva

`data/evidence_categories.json` dice, para cada pista, testimonio y deducción del caso, a qué
categorías de la acusación pertenece (`motive`, `opportunity`, `means`, las mismas claves de las
reglas de `story.json`) y, para las pistas, su clase. `EvidenceCategories` lo interpreta
(`Category.MOTIVE`, `OPPORTUNITY`, `MEANS`; `categories_of`, `belongs`, `type_of`).
`Investigation.get_accusation_options(categoría)` devuelve lo **descubierto** que pertenece a la
categoría, en el orden del tablero y sin repetir. Los textos siguen en `clues.json`,
`testimonies.json` y `deductions.json`: aquí no se duplican.

Cada elemento se clasificó leyendo su texto, no sólo su título. Un elemento está en dos categorías
sólo cuando su contenido responde a las dos preguntas (14 de 58).

### Criterios

- **Motivo**: conflictos, dinero y deudas, relaciones, familia, secretos, amenazas y lo que alguien
  ganaba o temía.
- **Oportunidad**: coartadas, horas, lugares, entradas y salidas, desplazamientos, accesos y quién
  vio a quién.
- **Medios**: objetos, pruebas físicas, el informe forense, instrumentos, huellas, manipulación de
  objetos y el procedimiento.

### Pistas

| Pista | Clase | Categorías | Por qué |
| --- | --- | --- | --- |
| Carta de Julián Valdés | Carta | Motivo | Tenía miedo de lo que iba a confirmar: alguien tenía razones para callarlo |
| Crónica del aniversario | Documento | Motivo | Julián llevaba semanas investigando en el archivo |
| Lista de invitados | Registro | Oportunidad | Quién estaba en la casa esa noche |
| Reloj de sobremesa parado | Objeto | Oportunidad, medios | Fija la hora de la muerte y es un objeto manipulado |
| Copa de brandy recién lavada | Objeto | Medios | El vehículo del veneno, lavado después |
| Huellas de betún | Objeto | Oportunidad, medios | Un acceso por la puerta de servicio y una huella física |
| Billete de tren de Elena | Objeto | Motivo | Elena pensaba dejar a su marido |
| Carta de amor de Marcos | Carta | Motivo, oportunidad | Un romance que el padre iba a castigar y una cita en la ropería tras la cena |
| Fotografía de Clara | Fotografía | Motivo | Una hija en un sanatorio |
| Libro de bodega | Registro | Oportunidad | Nada anotado después de las 22:40 |
| Llave del reloj del despacho | Objeto | Medios | El único instrumento para mover las agujas |
| Pagaré de Marcos | Documento | Motivo, oportunidad | Una deuda, firmada a las 23:00 en el café |
| Registro de la pensión | Registro | Oportunidad | Irene en la pensión a las 22:40 y a las 23:00 |
| Telegrama devuelto | Documento | Motivo, oportunidad | «Tengo el nombre», dictado vivo a las 22:50 |
| Registro de taquilla | Registro | Oportunidad | Elena en la estación a las 23:05 |
| Transferencia de la Compañía Cormorán | Documento | Motivo | Dinero para «C. R.» |
| Registro de la Compañía Cormorán | Registro | Motivo | Una sociedad fantasma para mover dinero |
| Informe del forense | Informe | Medios | Cianuro en el brandy |
| Recortes de prensa | Fotografía | Motivo, medios | Lo que Julián descubrió y el mismo reloj parado en cada muerte |

### Testimonios

| Testimonio | Categorías | Por qué |
| --- | --- | --- |
| Ortega: La escena del crimen | Oportunidad, medios | Puerta cerrada por dentro; el reloj roto a sus pies |
| Ortega: La puerta de servicio | Oportunidad | Un segundo acceso que usa el personal |
| Elena: Coartada | Oportunidad | Dice que no salió de su alcoba |
| Elena: Costumbres de Julián | Oportunidad, medios | Anselmo subía el brandy a las once cada noche |
| Elena: La invitada | Motivo | Un secreto de Julián |
| Elena: La huida | Motivo, oportunidad | Iba a dejarlo; a las 23:05 compraba un billete |
| Elena: La hija de Anselmo | Motivo | Julián le negó el dinero del tratamiento |
| Marcos: Coartada | Oportunidad | Dice que no salió de su cuarto |
| Marcos: La discusión | Motivo | Su padre le negó dinero delante del servicio |
| Marcos: La verdad de esa noche | Oportunidad | En el café hasta pasadas las doce |
| Marcos: Lucía | Motivo | Su padre iba a echarla |
| Marcos: Los relojes de la casa | Medios | Sólo Anselmo toca los relojes |
| Lucía: El hallazgo | Oportunidad, medios | Subió a las 23:40; la bandeja del brandy ya no estaba |
| Lucía: Coartada | Oportunidad | En la cocina y doblando ropa |
| Lucía: La escalera de servicio | Oportunidad | Vio subir a Anselmo al despacho a las once |
| Anselmo: Coartada | Oportunidad | Servía el cava a las 22:15 |
| Anselmo: Después del brindis | Oportunidad | Dice que estuvo en la bodega de once a 23:40 |
| Anselmo: El brandy de esa noche | Oportunidad, medios | Niega haber entrado y haber subido el brandy |
| Anselmo: Los relojes | Medios | Sólo él tiene las llaves de los relojes |
| Anselmo: Clara | Motivo | Su hija en el sanatorio |
| Irene: Su identidad | Motivo | Oculta quién es |
| Irene: La reunión en el despacho | Oportunidad | Con Julián de diez a diez y diez |
| Irene: Después de la cena | Oportunidad | De vuelta en la pensión antes de las once |
| Irene: Su verdadero nombre | Motivo, medios | Su hermana murió junto a un reloj parado |
| Rosa: Marcos en el café | Oportunidad | Marcos en el café de 22:30 a pasadas las doce |
| Rosa: La huésped | Oportunidad | Irene volvió a las 22:40 y cenó a las once |
| Eusebio: El telegrama | Oportunidad | Julián vivo a las 22:50 |
| Eusebio: La señora Valdés | Oportunidad | Elena en la taquilla a las 23:05 |
| Hilario: Las visitas de Julián | Motivo | Julián investigaba sociedades mercantiles |

### Deducciones

| Deducción | Categorías | Por qué |
| --- | --- | --- |
| El reloj miente | Oportunidad, medios | La hora era falsa y alguien movió las agujas |
| Una coartada para la hora equivocada | Oportunidad | La coartada de Anselmo sólo cubre las 22:15 |
| Marcos no estaba en su cuarto | Motivo, oportunidad | Mintió por sus deudas y estaba en el café |
| La jaqueca de Elena | Oportunidad | Estaba en la estación |
| Una amiga que nadie conoce | Motivo | Irene vino con otro propósito |
| La entrada de servicio | Oportunidad | El asesino entró y salió por la puerta de servicio |
| Una sola mano en el reloj | Medios | La llave del reloj y quien la maneja |
| El brandy que nunca se sirvió | Medios | El brandy se sirvió y Anselmo lo niega |
| Nadie estaba en la bodega | Oportunidad | La coartada de la bodega cae |
| Cuarenta mil razones | Motivo | El dinero de Cormorán pagó el tratamiento de Clara |

### Recuento

| Categoría | Total | Pistas | Testimonios | Deducciones | Aceptadas por las reglas | Alternativas que no se sostienen |
| --- | --- | --- | --- | --- | --- | --- |
| Motivo | 22 | 10 | 9 | 3 | 3 | 19 |
| Oportunidad | 34 | 9 | 19 | 6 | 4 | 30 |
| Medios | 16 | 6 | 7 | 3 | 4 | 12 |

Sin clasificar, cada campo ofrecía los 58 elementos; ahora ofrece entre 16 y 34 de lo descubierto.
La oportunidad sigue siendo la lista más larga (casi todos los testimonios son coartadas u horas):
por eso el panel tiene buscador y agrupa por clase.

### La dificultad no cambia

- Las listas no dependen del sospechoso elegido ni de la respuesta correcta.
- Cada categoría mezcla las respuestas aceptadas con muchas que no se sostienen pero tienen
  sentido: el pagaré de Marcos, el billete de Elena, la fotografía de Clara o el testimonio de
  Anselmo sobre su hija en el motivo; la llave del reloj, las huellas de betún o los relojes de
  Marcos en los medios.
- Nada se resalta por ser correcto: el burdeos sólo marca lo que el jugador eligió.
- Sólo aparece lo descubierto.
- Las reglas (`Investigation.evaluate_accusation` y el bloque `accusation` de `story.json`) no se
  han tocado. Las pruebas comprueban que cada respuesta aceptada está en su categoría.

## Borrador de la acusación

Cada elección se anota enseguida en `GameState.accusation_draft` a través de
`Investigation.set_accusation_choice(campo, valor)`, que la valida (un sospechoso del caso; un
elemento descubierto y de esa categoría) y avisa con `EventBus.accusation_draft_changed`. El
borrador no depende de «Seguir investigando»: ese botón sólo cierra la hoja, nunca presenta nada
ni cuenta un intento.

| Momento | Qué pasa con el borrador |
| --- | --- |
| Cambiar cualquier campo | Se anota al momento |
| «Seguir investigando», Esc o cerrar la hoja | Se conserva |
| Volver a abrir la acusación | La hoja recupera las cuatro elecciones |
| Descubrir algo nuevo | Aparece en su campo la próxima vez que se abra el panel |
| Acusación que no se sostiene | Se conserva para corregirla; cuenta un intento |
| Acusación correcta | Se conserva durante la confrontación |
| Marca `caso_resuelto` (final de la confrontación) | Se vacía (`Investigation.CASE_SOLVED_FLAG`) |
| Partida nueva (`GameState.reset`) | Empieza vacío |

`Investigation.get_accusation_draft()` devuelve siempre los cuatro campos (vacío si no hay
elección) y sólo con elecciones válidas. `clean_accusation_draft(datos, descubiertos)` aplica las
mismas reglas a datos cualesquiera, y es lo que usa la carga de partidas.

## Guardado

El borrador viaja dentro de la sección `state` de siempre, con identificadores estables (nunca la
posición en una lista), y sólo con los campos rellenos:

```json
"state": { "...": "...", "accusation_draft": {"suspect": "anselmo", "motive": "transferencia"} }
```

- Se guarda con el guardado manual, el autoguardado y el guardado al salir, en la ranura activa:
  cada ranura tiene el suyo y nunca se crea una ranura nueva.
- Cambiar el borrador cuenta como progreso sin guardar, así que salir del juego lo guarda (o pide
  ranura) como cualquier otro cambio. No pide autoguardados propios: el de la conversación con
  Ortega espera a que se cierre la hoja y lo incluye, y lo mismo el siguiente cambio de lugar.
- Al cargar, `SaveFormat` se queda sólo con lo que sigue valiendo con lo que esa partida había
  descubierto y descarta el resto con un aviso en la consola. Un borrador ausente (partidas
  anteriores) o dañado deja el formulario vacío; nunca impide cargar ni cambia la versión del
  formato.

## Cómo se maneja

| Acción | Teclado y mando | Ratón |
| --- | --- | --- |
| Abrir un campo | Intro / A sobre su selector | Clic en el selector |
| Moverse | Flechas, cruceta o stick (las teclas de `ui_*`) | — |
| Elegir | Intro / A | Clic en la fila |
| Buscar | Escribir una letra mientras se recorre la lista la lleva al buscador; arriba desde la primera fila | Clic en el buscador |
| Cerrar la lista o el panel | Esc / B | La cruz, un clic fuera de la lista o en el fondo |
| Cerrar la hoja | Esc / B con nada abierto, o «Seguir investigando» | «Seguir investigando» |

- **Escape por niveles**: primero cierra la lista o el panel abierto y devuelve el foco a su campo;
  sólo con nada abierto cierra la hoja. Funciona con la tecla de pausa y con la de volver.
- Las teclas de navegación, aceptar y volver nunca se desvían al buscador, aunque se hayan
  reasignado a una letra; escribiendo en el buscador, una tecla de pausa reasignada a una letra
  escribe esa letra.
- Al abrir, el foco va al primer campo pendiente (o a «Presentar la acusación» si está todo).
- Con una lista abierta, el foco no sale de ella; el formulario sigue visible y responde al ratón
  (otro campo cambia el contenido del panel; el mismo campo lo cierra).
- «Presentar la acusación» está desactivado (y no toma el foco) mientras falte un campo.
- Mientras la hoja está abierta el detective no se mueve ni interactúa (bloqueo `acusacion`, el
  mismo que cambia la música); con la pregunta de salida o una confirmación en pantalla, Escape es
  suyo.

## Tamaño de pantalla

La hoja (880 × 1010) y el panel (600 × 880) tienen un tamaño de diseño en el lienzo de 1920 × 1080.
Si la ventana o el tamaño de letra de Accesibilidad no dan para los dos juntos con su margen, se
escalan a la vez, con la misma escala con el panel abierto o cerrado: nunca se salen de la
pantalla ni cambian de tamaño al abrir el panel. Sin panel, la hoja va centrada; con él, el
conjunto se centra y el panel entra desde la derecha. Comprobado con capturas a 1920 × 1080,
1600 × 900 con letra grande, 1024 × 768 y 2560 × 1080, y con pruebas a tamaño normal y «Muy
grande».

## Cómo ampliarlo

- **Una pista, testimonio o deducción nueva**: añadirla en `data/evidence_categories.json` con sus
  categorías (y su clase si es una pista). Las pruebas fallan si un elemento del caso no está
  clasificado o si una respuesta aceptada por `story.json` no está en su categoría.
- **Una clase nueva**: añadirla a `EvidenceCategories.TYPES` y su icono y nombre a
  `AccusationStyle.TYPE_ICONS` y `TYPE_NAMES`.
- **Textos**: `AccusationInfo` (títulos del panel, avisos) y la escena (rótulos de los campos).
- **Capturas**: `tests/visual/captura.gd` admite `--open=accusation` con `--borrador`, `--campo`,
  `--buscar`, `--bajar` y `--presentar`.

## Pruebas

| Archivo | Cubre |
| --- | --- |
| `test_evidence_categories` | Todo el caso clasificado con claves y clases válidas, solución alcanzable, alternativas incorrectas en cada categoría (también contra otros sospechosos), elementos ajenos fuera, sólo lo descubierto, sin duplicados |
| `test_accusation_draft` | Elecciones válidas e inválidas, cambiar y vaciar, listas que no dependen del sospechoso, vaciado al resolver el caso y en una partida nueva, guardar y cargar, ranuras independientes, progreso sin guardar y autoguardado, partidas sin borrador y borradores dañados |
| `test_accusation_ui` | Con la escena de juego real: hoja vacía y bloqueo, Esc sin abrir la pausa, lista de sospechosos (los cinco, retratos, teclado, Esc, clic fuera), panel por campo (títulos, sólo su categoría, nada elegido de antemano, nada sin descubrir, grupos, iconos, títulos cortos y vista previa), elegir y cerrar, Esc por niveles, cruz y clic en el fondo, cambio de campo, teclado, búsqueda, escribir para buscar, categoría vacía, «Seguir investigando» con pruebas nuevas, acusación incompleta, fallida y correcta, composición centrada y con panel, letra «Muy grande» |
| `test_board` | La acusación fallida y la correcta, como antes, con la nueva interfaz |
| `persistencia/reinicio` | Un borrador a medias se guarda, se cierra el proceso y se recupera en la hoja en otro |

## Limitaciones

- El panel no recuerda la búsqueda ni el desplazamiento entre aperturas: empieza siempre limpio.
- Un elemento queda en la categoría que dicen los datos aunque el jugador lo use con otra
  intención; para eso existe la regla de que esté sólo donde su contenido lo justifica.
- La clasificación no cambia nada del tablero ni del expediente.
