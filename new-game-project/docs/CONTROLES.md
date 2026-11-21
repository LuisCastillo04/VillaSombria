# Controles

Teclas personalizables, mando y restauración de las teclas de fábrica: qué hay, dónde vive, cómo se
guarda y cómo se prueba.

## Menú

**Controles** se abre desde la pausa. Conserva sus cuatro categorías (Movimiento, Interacción, Menús y
Otros) y lee las teclas del InputMap cada vez que se abre o cambian. Al pie de **Otros**, donde antes
había tres opciones con «Próximamente», están las tres herramientas, ya activas:

| Herramienta | Qué hace |
| --- | --- |
| Reasignar teclas | Abre la pantalla de reasignación encima de Controles |
| Jugar con mando | Abre el esquema de botones del mando; su explicación dice si hay uno conectado |
| Restaurar las teclas predeterminadas | Pregunta antes y vuelve a las teclas de fábrica; su explicación dice cuántas acciones están personalizadas |

«Dejar pasar una hora» (T) y «Cerrar el juego guardando» (Alt + F4) siguen en la lista como antes. Las
dos pantallas nuevas usan el mismo panel, pestañas, filas, teclas con filete dorado y botón «Volver»
que Controles; al cerrarlas, Controles reaparece con las teclas al día y el foco en la fila que las
abrió.

## Piezas

| Pieza | Papel |
| --- | --- |
| `InputBindings` (`scripts/input/`) | Qué acciones se reasignan, por categorías; sus teclas de fábrica; qué teclas admite cada una; validación de un juego de teclas. Sólo lógica |
| `Controls` (autoload) | Teclas vigentes aplicadas al InputMap; comprobar, asignar, intercambiar, quitar y restaurar; guardarlas en `ajustes.cfg`; dispositivo en uso; mandos conectados; navegación de los menús con el mando |
| `GamepadNavigation` (`scripts/input/`) | Traduce la cruceta y el stick izquierdo a pulsaciones limpias de `ui_up`, `ui_down`, `ui_left` y `ui_right`, con repetición |
| `InputLabels` | Nombres de teclas y botones, del teclado, del mando o del dispositivo en uso (`Device`) |
| `RebindMenu`, `RebindRow`, `KeySlotButton` | Pantalla «Reasignar teclas» |
| `GamepadMenu` | Pantalla «Jugar con mando» |
| `MenuActionRow` | Fila de menú que abre algo, con flecha dorada (las tres herramientas) |

La gestión de las entradas (`InputBindings`, `Controls`, `GamepadNavigation`) no depende de ninguna
pantalla: las pantallas sólo la presentan y escuchan sus señales.

## Teclas de fábrica

Son las del InputMap de `project.godot`, la única fuente: `InputBindings.default_keys` las lee de
`ProjectSettings`. Ningún script repite una tecla por defecto. Cambiar una en el editor de Godot cambia
también lo que recupera «Restaurar».

## Reasignar teclas

Cada acción reasignable tiene una tecla **principal** y, si se quiere, una **alternativa**. La
principal nunca queda vacía: ninguna acción se queda sin tecla.

| Categoría | Acciones | Teclas de fábrica |
| --- | --- | --- |
| Movimiento | Avanzar, Retroceder, Ir a la izquierda, Ir a la derecha | W/↑, S/↓, A/←, D/→ |
| | Correr (mantener) | Mayús |
| Interacción | Interactuar y avanzar el diálogo | E |
| Menús | Abrir o cerrar el expediente, el tablero, el mapa | J/Tab, B, M |
| Otros | Dejar pasar una hora | T |

Al pie de cada categoría se ven, sin poder elegirlas, las **teclas fijas**: pausar y volver atrás
(Esc), moverse por los menús (flechas), confirmar (Intro y Espacio), elegir una pregunta (1–9) y cerrar
el juego guardando (Alt + F4). Son fijas para que siempre se pueda navegar, confirmar y volver.

### Cambiar una tecla

1. Se elige un hueco con Intro, el botón de aceptar del mando o un clic.
2. Aparece «Presiona una tecla para asignarla a «…». Esc cancela.» y el hueco dice «Pulsa una tecla…».
3. La tecla siguiente es la nueva.

| Situación | Qué pasa |
| --- | --- |
| La pulsación que elige el hueco | No cuenta: la espera empieza con la siguiente pulsación |
| Una tecla mantenida | Sus repeticiones no cuentan |
| Esc, un clic o B en el mando | Cancelan sin cambiar nada; la pantalla sigue abierta |
| Mayús o Ctrl | Se toman al soltarlas, si no se pulsó otra tecla entretanto |
| Mayús o Ctrl + otra tecla | Se toma la otra tecla (no hay combinaciones) |
| Alt + F4, Alt + Tab, la tecla de Windows | No se toman: son del sistema y siguen funcionando. Alt + F4 cierra el juego guardando, como siempre |
| Un botón del mando que no sea B | Se avisa de que el mando tiene su propio esquema |
| Esc, 1–9, Alt, Windows, Impr Pant, Bloq Mayús | Reservadas: se dice para qué sirven y se sigue esperando |
| Una tecla de los menús en una acción que funciona dentro de una pantalla | Se explica y se sigue esperando (abajo) |
| La tecla ya es de esa acción en el otro hueco | Los dos huecos se intercambian; si es la principal y se pedía para la alternativa vacía, no cambia nada |
| La tecla es de otra acción | Se pregunta si se intercambian (abajo) |

Supr, Retroceso o el clic derecho quitan la alternativa del hueco señalado; la principal no se puede
quitar.

### Teclas de los menús

Las acciones que sólo sirven explorando (moverse, correr, dejar pasar una hora) pueden usar también las
flechas, Intro, Espacio, RePág y AvPág: en los menús no hacen nada. Las que también funcionan dentro de
una pantalla no pueden usar las de moverse por ella, porque allí la misma tecla haría dos cosas:

- Abrir o cerrar el expediente, el tablero o el mapa: ni flechas, ni Intro o Espacio, ni RePág o AvPág.
- Interactuar (también avanza el diálogo y confirma la pregunta señalada): ni flechas ni RePág o AvPág.
  Intro y Espacio sí, porque en el diálogo hacen lo mismo.

### Conflictos

Si la tecla ya la usa otra acción, `ConfirmDialog` pregunta:

> La tecla E ya está asignada a «Interactuar y avanzar el diálogo».
> ¿Quieres intercambiar las asignaciones?
> «Interactuar y avanzar el diálogo» pasará a usar M.

«Intercambiar» lo hace; «Cancelar», Esc o B no cambian nada. El foco empieza en «Cancelar». Si el
intercambio dejaría a la otra acción sin ninguna tecla (porque el hueco de destino estaba vacío y esa
era su única tecla), o le daría una tecla que no admite, no se ofrece: se explica y se sigue esperando
otra tecla.

## Persistencia

Las teclas son una preferencia del jugador, común a todas las partidas. Se guardan en
`user://ajustes.cfg`, sección `controles`, a través de `Settings.read_section` y `write_section`; nunca
en las ranuras de partida. Sólo se escriben las acciones que difieren de las de fábrica, con el nombre
interno de la tecla (independiente de la distribución del teclado):

```ini
[controles]
interact=["F"]
open_map=["E"]
move_forward=["W", "I"]
```

- **Al arrancar**, `Controls` lee la sección después de que `Settings` lea el archivo, y vuelve a
  leerla cada vez que `Settings` emite `reloaded` (por ejemplo, con `use_file`).
- **Cada cambio** se aplica al InputMap y se escribe en el acto. El resto del archivo se conserva, y
  guardar cualquier otra preferencia conserva las teclas.
- **Datos dañados**: una entrada con una tecla desconocida o reservada se descarta y el archivo se
  corrige; un juego incoherente (dos acciones con la misma tecla) no se aplica a medias: vuelven las de
  fábrica.
- **Restaurar** retira la sección entera. Audio, gráficos, jugabilidad y accesibilidad no cambian.

## Restaurar las teclas predeterminadas

«Restaurar las teclas predeterminadas» pregunta:

> **¿RESTAURAR CONTROLES PREDETERMINADOS?**
> Se eliminarán las asignaciones personalizadas de teclado y se recuperará la configuración original.
> [Restaurar controles] [Cancelar]

El foco empieza en «Cancelar». Al confirmar, `Controls.restore_defaults` vuelve a las teclas de
`project.godot`, las aplica al InputMap, retira la sección `controles` del archivo y avisa con
`bindings_changed`; la lista de Controles se pone al día en el acto y la fila dice «Restauradas». Tras
reiniciar el juego siguen las de fábrica. Los botones del mando no se tocan: no se personalizan.

## Mando

### Esquema

Los botones son los del InputMap de `project.godot`. La pantalla «Jugar con mando» los lee de ahí, así
que lo que enseña es lo que funciona. Nombres de Xbox; con un mando de PlayStation o de Nintendo se
muestran los suyos.

| Xbox | PlayStation | Nintendo | Explorando | En los menús |
| --- | --- | --- | --- | --- |
| Stick izquierdo / cruceta | igual | igual | Moverse | Moverse por los menús y las preguntas |
| A | ✕ | B | Interactuar | Confirmar, avanzar el diálogo, elegir la pregunta |
| B | ○ | A | — | Volver atrás, cerrar el expediente, el tablero, el mapa o una pista |
| Y | △ | X | Abrir el expediente | Cerrarlo |
| X | □ | Y | Abrir el tablero | Cerrarlo |
| Vista | Create (PS5) o Share (PS4) | - | Abrir el mapa | Cerrarlo |
| Menú | Options | + | Pausa | Reanudar |
| RT (mantener) o LS | R2 o L3 | ZR o LS | Correr | — |
| RB | R1 | R | Dejar pasar una hora | Bajar la ficha del expediente |
| LB | L1 | L | — | Subir la ficha del expediente |

Ninguna acción de la exploración comparte botón con otra (`test_gamepad` lo comprueba). RB sirve para
dos cosas, pero nunca a la vez: dejar pasar una hora sólo funciona explorando y desplazar la ficha, con
el expediente abierto.

### Navegación de los menús

Godot entrega un empujón del stick como varios eventos seguidos, y cada uno contaría como una pulsación
para los scripts que leen eventos (las preguntas de una conversación, las ranuras, las pestañas del
expediente, los selectores de Configuración). Por eso la cruceta y el stick no están en `ui_up`,
`ui_down`, `ui_left` ni `ui_right`: `Controls` les pasa su estado a `GamepadNavigation` cada fotograma
y esta envía pulsaciones limpias:

- Una pulsación por empujón, y su suelta al volver al centro.
- Mantenida, se repite como una tecla: a los 0,45 s y después cada 0,12 s.
- Zona muerta con histéresis: 0,5 para empujar y 0,3 para soltar; un stick que tiembla en el borde no
  pulsa dos veces.
- La cruceta manda sobre el stick; de una diagonal cuenta el eje dominante.
- Un toque de cruceta más corto que un fotograma no se pierde.

Los botones A y B están en `ui_accept` y `ui_cancel` (Godot 4.7 no los trae por defecto), y LB y RB en
`ui_page_up` y `ui_page_down`. El foco se ve con el resaltado burdeos y el filete dorado de siempre. El
ratón sigue funcionando con el mando conectado.

### Zona muerta del movimiento

El detective camina con `Input.get_vector` sobre las acciones de movimiento, que incluyen el stick
izquierdo con una zona muerta radial de 0,25 (`deadzone` de las cuatro acciones): las desviaciones
pequeñas de un stick en reposo no lo mueven, y por encima la velocidad crece con el empuje. El gatillo
de correr tiene una zona muerta de 0,3.

### Teclado o mando

`Controls` sabe qué usa el jugador: la última pulsación de un botón o un empuje claro de un stick (desde
0,5) pasa a «mando»; una tecla, un clic o un movimiento del ratón de más de 6 píxeles vuelve a «teclado
y ratón». Lo lee de `Window.window_input`, antes de que ninguna pantalla consuma la pulsación, y avisa
con `input_device_changed`. Al cambiar:

- La barra del HUD y el aviso de interacción muestran los botones del mando («A Interactuar»).
- «Continuar» de las conversaciones dice «[A] Continuar», y la ayuda de las preguntas, «Elige con la
  cruceta o el stick y confirma con A».
- El pie del expediente y la cabecera del tablero cambian de rótulos.

La lista de Controles enseña siempre el teclado, y «Jugar con mando», siempre el mando.

### Conexión y desconexión

- **Al arrancar**, se toma el primer mando conectado para los nombres de los botones.
- **Al conectar** uno durante la partida, el HUD avisa «Mando conectado» con su nombre.
- **Al desconectar** el que se usaba: se suelta lo que tenía pulsado (el detective no sigue andando
  solo y un menú no sigue bajando), los rótulos vuelven al teclado, el HUD avisa «Mando desconectado» y,
  si se estaba explorando, la partida se pausa. No se bloquea nada: el teclado y el ratón siguen.

### Una pulsación, una acción

- A es a la vez confirmar e interactuar. Al volver a explorar, `Game` quita el foco a cualquier botón
  de la interfaz, para que A no pulse a la vez un botón olvidado de una pantalla.
- Cada pantalla consume la pulsación que la cierra: la A que cierra una conversación no vuelve a
  abrirla, y la B que cierra el expediente no llega a la pausa.
- Los botones del mando no repiten al mantenerlos; la navegación sí, a su ritmo.

## Lo que se conserva

- **Dejar pasar una hora** usa la acción `wait_time`, reasignable como las demás. Con las confirmaciones
  activadas pregunta antes, con la tecla o el botón que tenga.
- **Cerrar el juego guardando** sigue en `ExitManager`: la X y Alt + F4 llegan como petición de cierre
  de la ventana, no como teclas, y no dependen de la reasignación. Durante la espera de una tecla,
  Alt + F4 no se toma como asignación; si aparece la pregunta de salida, la espera termina y el teclado
  vuelve a ella.
- Guardado manual y automático, conversaciones, expediente, tablero, mapa, pausa, configuración,
  transiciones y efectos no cambian. Las pantallas que se cerraban con Esc se cierran también con B.

## Cómo probarlo en Godot

Ejecuta la escena principal (F5), empieza o carga una partida y abre la pausa (Esc) → **Controles** →
**Otros**.

| Qué | Cómo | Qué debe pasar |
| --- | --- | --- |
| Reasignar | «Reasignar teclas» → Interacción → el hueco de E → pulsa F | La fila dice F y «Personalizada»; Esc, «Volver» y en la partida F interactúa |
| Conflicto | En Menús, el hueco de M → pulsa E | Pregunta si se intercambian; «Intercambiar» deja el mapa en E e interactuar en M |
| Cancelar | Elige un hueco y pulsa Esc | «Cambio cancelado», sin cambios |
| Persistencia | Cierra el juego y vuelve a abrirlo | Las teclas siguen como las dejaste |
| Mando | Conecta un mando y pulsa cualquier botón | Avisa «Mando conectado» y la barra del HUD muestra sus botones |
| Esquema | «Jugar con mando» | Botones por situaciones, con los nombres del mando conectado |
| Desconexión | Desconecta el mando explorando | Avisa «Mando desconectado», la partida se pausa y el teclado sigue |
| Restaurar | «Restaurar las teclas predeterminadas» → «Restaurar controles» | La lista vuelve a W, E, J...; tras reiniciar, también |

Las teclas personalizadas están en `%APPDATA%\Godot\app_userdata\Villa Sombría\ajustes.cfg`, sección
`[controles]`.

## Pruebas

| Archivo | Qué comprueba |
| --- | --- |
| `tests/unit/test_controls.gd` | Teclas de fábrica de project.godot, asignar sin tocar el mando, alternativa, conflictos e intercambio, ninguna acción sin tecla, teclas reservadas y de los menús, restaurar, guardado en `ajustes.cfg`, reinicio, datos dañados e incoherentes |
| `tests/unit/test_rebind_menu.gd` | La pantalla con pulsaciones reales: la tecla que elige no cuenta, repeticiones, Esc y clic cancelan, Ctrl al soltar, Alt + F4, reservadas, conflicto con intercambio y con cancelación, intercambio imposible, Supr, navegación, una tecla nueva en la partida y cerrar la ventana durante la espera |
| `tests/unit/test_gamepad.gd` | Cada acción con su botón sin compartirlo, zona muerta, una pulsación por empujón y repetición, pausa y Configuración con el stick, A y B, confirmaciones, el detective con el stick, expediente, tablero y mapa con sus botones, conversación con A y la cruceta, rótulos que siguen al dispositivo, nombres por fabricante, conexión y desconexión, pantalla del esquema |
| `tests/unit/test_controls_menu.gd` | Las tres herramientas sin «Próximamente», navegación hasta ellas, reasignar y el esquema encima de Controles, restaurar con su pregunta y sin tocar otras preferencias |
| `tests/persistencia/controles.tscn` | En tres procesos: personalizar; comprobar al arrancar y restaurar; comprobar al arrancar que siguen las de fábrica (lo ejecuta `verificar.ps1`) |

`tests/visual/captura.tscn` admite `--open=reasignar:n`, `--open=mando:n`, `--open=restaurar`,
`--esperar-tecla=accion[:hueco]` y `--mando[=xbox|playstation|nintendo]`.

Las pruebas envían los eventos del mando con `Input.parse_input_event`, el mismo camino que los de un
mando real, y simulan la conexión con `Controls.handle_connection_change`. **No se han probado con un
mando físico.**

## Limitaciones

- **Mando físico.** Todo lo del mando está probado con eventos simulados. Falta comprobar con mandos
  reales de Xbox, PlayStation y Nintendo: la detección del nombre, los gatillos (algunos mandos
  genéricos los dan como botones) y la sensación de la zona muerta y de la repetición.
- **Botones del mando fijos.** No se reasignan; «Restaurar» sólo afecta al teclado.
- **Sin combinaciones.** Cada acción usa teclas sueltas (Ctrl o Mayús solas sí).
- **Nombres de teclas.** Se muestran con la distribución del teclado del jugador, pero se guardan por
  posición física: en un teclado AZERTY, la tecla que se ve como «Z» es la que el archivo llama «W».
- **Teclas de fábrica nuevas.** Si una versión futura cambia una tecla de fábrica y choca con una
  personalizada, el juego de teclas guardado deja de ser coherente y se vuelve a las de fábrica.

## Ampliaciones

| Ampliación | Qué tocar |
| --- | --- |
| Acción reasignable nueva | Crearla en el InputMap (con su botón del mando), añadirla a `InputBindings.ACTIONS` y a las filas de `ControlsMenu.CATEGORIES` y `GamepadMenu.CATEGORIES` |
| Categoría nueva | Añadirla a `InputBindings.CATEGORIES` y a `ControlsMenu.CATEGORIES` |
| Reasignar el mando | Guardar los botones en otra sección (p. ej. `controles_mando`), aplicar sólo los eventos de mando en `InputBindings.apply` y reutilizar `RebindMenu` con otra espera |
| Otra disposición de botones | Añadirla a `InputLabels.STYLE_NAMES`, `BUTTON_NAMES`, `TRIGGER_NAMES` y a `style_for` |
| Elegir la disposición a mano | Una preferencia en `SettingsSchema` que lea `Controls.get_gamepad_style` antes que el nombre del mando |
