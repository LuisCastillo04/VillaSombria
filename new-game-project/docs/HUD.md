# HUD de exploración

Qué muestra el HUD mientras se explora Villa Sombría, de dónde saca los datos, cuándo se ve, cómo
se adapta a la pantalla y cómo ampliarlo.

## Qué muestra

- **Arriba a la izquierda**, sobre pergamino: el icono del lugar, su nombre en burdeos y, debajo,
  la fecha y la hora en cursiva («Domingo 17 de octubre de 1948 — 08:00»).
- **Arriba a la derecha**: la cinta «OBJETIVO», una lupa y el primer objetivo pendiente del día.
  Las notificaciones (pistas, deducciones, avisos) aparecen debajo, también sobre pergamino.
- **Al pie**: una barra carbón con un sombrero y las teclas reales del juego. Sobre ella, el aviso
  de interacción («E Salir a la plaza») cuando hay algo al alcance.
- **Alrededor de la pantalla**: un marco fino dorado con escuadras en las esquinas.

Todo se dibuja en Godot sobre el escenario real: no hay imágenes de fondo ni texturas estiradas.
Los iconos son SVG propios, blancos, y se tiñen con `modulate`, como los de los menús.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `scenes/ui/hud.tscn`, `scripts/ui/hud.gd` | `Hud`: escucha `EventBus`, coloca las piezas y decide cuándo se ve |
| `scripts/ui/hud/hud_info.gd` | `HudInfo`: lee el lugar, la fecha, el objetivo y las teclas de los sistemas del juego; define las entradas de la barra (`CONTROL_HINTS`) |
| `scripts/ui/hud/hud_style.gd` | `HudStyle`: paleta, letras, medidas en el lienzo de 1920 × 1080 y tiempos |
| `scripts/ui/hud/hud_ornaments.gd` | `HudOrnaments`: rombos, escuadras, cinta y remates compartidos |
| `scripts/ui/hud/parchment_panel.gd` | `ParchmentPanel`: pergamino con borde, filete, escuadras, sombra y cinta opcional |
| `scripts/ui/hud/noir_plate.gd` | `NoirPlate`: placa carbón translúcida con filete dorado |
| `scripts/ui/hud/hud_location_panel.gd` | `HudLocationPanel`: el lugar y la fecha |
| `scripts/ui/hud/hud_objective_panel.gd` | `HudObjectivePanel`: el objetivo, con su destello |
| `scripts/ui/hud/hud_controls_bar.gd` | `HudControlsBar`: la barra de teclas contextual y adaptable |
| `scripts/ui/hud/hud_key_hint.gd` | `HudKeyHint`: una tecla (`KeyCap`) y su acción |
| `scripts/ui/hud/hud_prompt.gd` | `HudPrompt`: el aviso de interacción |
| `scripts/ui/hud/hud_toast.gd` | `HudToast`: una notificación |
| `scripts/ui/hud/cinematic_frame.gd` | `CinematicFrame`: el marco de la pantalla |
| `assets/ui/iconos/` | `tren`, `fuente`, `taza`, `mansion`, `archivo` (lugares) y `sombrero` (barra) |

La paleta es la de los menús (`MenuStyle`: carbón `#101116`, dorado `#B58B4A`, crema `#F1DEB9`,
burdeos `#8A2632`) más el pergamino `#E6D5AE` y la tinta marrón `#38281D`. Las letras salen de
`CaseFileStyle`: Palatino Linotype (con Georgia de reserva) en negrita, redonda y cursiva. El
pergamino usa el mismo shader que el expediente y las opciones de los menús, y las teclas el mismo
`KeyCap` que la pantalla de controles.

## De dónde salen los datos

El HUD no guarda estado propio ni duplica lógica: pregunta a `HudInfo`, que sólo consulta.

| Dato | Fuente | Se actualiza con |
| --- | --- | --- |
| Nombre del lugar | `name` en `data/locations.json` | `EventBus.location_changed` |
| Icono del lugar | `icon` en `data/locations.json` | `EventBus.location_changed` |
| Fecha | `title` del día en `data/story.json`, según `GameClock.day` | `EventBus.time_changed` |
| Hora | `GameClock.format_time()` | `EventBus.time_changed` |
| Objetivo | Primer pendiente de `StoryDirector.get_objectives()` | `EventBus.objectives_changed` y `time_changed` |
| Teclas | InputMap, a través de `InputLabels` | Al crear el HUD y cada vez que vuelve a aparecer |
| Algo al alcance | `EventBus.interaction_focus_changed` | Esa misma señal |
| Se puede esperar | `GameClock.is_at_limit()` | `EventBus.time_changed` |

Al cargar una partida, la escena de juego emite `time_changed` y `objectives_changed`
(`_notify_state`), así que el HUD muestra el progreso guardado sin pasos especiales.

## Cuándo se ve

El lugar, el objetivo, la barra y el aviso forman el grupo `Exploration`, que sólo se ve mientras
el jugador tiene el control. En cuanto hay un bloqueo (`GameState.lock_player`: conversación,
inspección de una pista, transición entre lugares, descanso, expediente, tablero, acusación,
cierre del caso, pausa y las pantallas que se abren sobre ella), el grupo se desvanece; al
liberarse el último, vuelve. El HUD se entera por `EventBus.player_locks_changed`, que `GameState`
emite sólo cuando cambia el conjunto de bloqueos: no se consulta nada en cada fotograma.

- La primera aparición espera a que termine el fundido de entrada (`Hud.FIRST_REVEAL_DELAY`). Si
  justo entonces empieza una escena (la introducción, o la de un lugar al cargar), el HUD no llega
  a asomar.
- Los cambios de bloqueo de un mismo fotograma se agrupan: al terminar una transición se libera el
  control y puede empezar en el acto la escena del lugar sin que el HUD parpadee.
- Un objetivo que cambia con el HUD oculto (lo normal: se cumplen hablando) hace destellar la
  cinta cuando el HUD vuelve.
- Las notificaciones y el marco no pertenecen al grupo: una pista hallada en una conversación se
  sigue anunciando. Las notificaciones tienen su propia capa (`Notices`): durante una conversación
  sube por encima de ella (`HudStyle.NOTICES_OVER_DIALOGUE_LAYER`) y las centra arriba, entre las dos
  siluetas; al terminar vuelven a la capa del HUD y a su sitio bajo el objetivo. Ver
  [DIALOGOS.md](DIALOGOS.md).

Para que una pantalla nueva oculte el HUD basta con que bloquee al jugador con su propio motivo.

## Animaciones

| Momento | Efecto | Duración |
| --- | --- | --- |
| Aparecer | Fundido; los paneles de arriba bajan y la barra sube 14 px | 0,45 s |
| Desaparecer | Fundido | 0,22 s |
| Cambio de lugar a la vista | El contenido se funde, se actualiza y reaparece | 0,16 s + 0,38 s |
| Cambio de lugar en una transición | El HUD se retira con el fundido a negro y vuelve con el lugar nuevo | — |
| Avance del reloj | Sólo la línea de la fecha se funde | 0,16 s + 0,38 s |
| Objetivo nuevo | El texto se funde y la cinta y la lupa destellan | 1,4 s |
| Aviso de interacción | Fundido | 0,16 s / 0,12 s |
| Notificación | Fundido de entrada, 3,6 s visible y fundido de salida | 0,25 s / 0,4 s |

Todas son `Tween` de los propios nodos: no hay `_process` en el HUD. Se detienen con la pausa,
salvo el fundido del grupo de exploración, que avanza aunque el árbol esté en pausa para poder
retirarse mientras aparece el menú.

## Tamaño de pantalla

Las medidas están en el lienzo lógico de 1920 × 1080. El proyecto estira con `canvas_items` y
`aspect=expand`, de modo que 1280 × 720, 1366 × 768, 1600 × 900 y 1920 × 1080 ven la misma
composición a distinta escala; lo que cambia de verdad el espacio es la proporción.

- El HUD ocupa la pantalla menos un margen de 56 px a los lados, sin pasar de 1808 px de ancho:
  en una ultrapanorámica (21:9) queda centrado en una zona 16:9 y no obliga a mirar a las
  esquinas. El marco sí sigue los bordes de la pantalla.
- El panel del objetivo mide 520 px y cede ancho (hasta 380) antes de pisar el del lugar; su texto
  se parte en las líneas necesarias y el panel crece hacia abajo.
- El nombre del lugar reduce la letra de 40 a 28 px si no cabe en 470 px y, si aun así no cabe,
  termina en puntos suspensivos.
- La barra reparte las teclas por todo su ancho. Si no caben, pasa a una versión compacta (letra
  y huecos menores) y, si tampoco, oculta las entradas de mayor `priority`, empezando por la de
  más a la derecha. Moverse, Interactuar y Pausa (prioridad 0) nunca se ocultan.
- Ninguna pieza recibe el ratón ni el foco (`MOUSE_FILTER_IGNORE`, `FOCUS_NONE`) y el HUD no lee
  entradas, así que nunca interfiere con el teclado, el ratón o el mando.

Comprobado con capturas a 1280 × 720, 1366 × 768, 1600 × 900, 1920 × 1080, 1024 × 768 (4:3) y
2560 × 1080 (21:9), y con pruebas a 16:9, 4:3, 5:4, 16:10 y 21:9.

## Convivencia con otras pantallas

- El HUD es la capa 2: por debajo de diálogos (6), inspección (7), expediente y tablero (8),
  acusación (9), cierre (15), pausa (20), fundido (30), indicador de guardado (40) y salida (50).
  Sólo el postproceso (capa 1) queda debajo; el HUD no recibe la niebla, la viñeta ni el grano.
  Las notificaciones suben a la capa 7 mientras dura una conversación.
- El indicador de guardado (`SaveIndicator`) sube por encima de la barra mientras existe el HUD
  (`set_bottom_margin`) y vuelve a su esquina al salir de la partida.
- Las imágenes de las ranuras se siguen haciendo sin interfaz (ver [GUARDADO.md](GUARDADO.md)).

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Tecla nueva en la barra | Una entrada en `CONTROL_HINTS` de `hud_info.gd`, con su `priority`. La tecla sale del InputMap |
| Lugar nuevo | Su `icon` en `data/locations.json` y el SVG en `assets/ui/iconos/` (blanco, `viewBox` 64). Sin icono se usa `mapa` |
| Pantalla que oculte el HUD | Que bloquee al jugador con `GameState.lock_player("motivo")` |
| Color, letra, medida o tiempo | `HudStyle` |
| Reasignación de teclas | Tras cambiar el InputMap, `Hud.refresh_controls()`; el HUD también relee las teclas cada vez que reaparece, por ejemplo al cerrar la pausa |
| Mandos o Android | `InputLabels` decide qué nombre se muestra; ahí se añaden los botones del mando. Para pantallas táctiles, la barra puede ocultarse o sustituirse sin tocar el resto: es una pieza independiente que no lee entradas |
| Otro panel | Un `ParchmentPanel` o un `NoirPlate` dentro de `Exploration`, colocado en `Hud._layout()` |
| Ocultar el marco | Quitar el nodo `Frame` de `hud.tscn` o ajustar su `inset` |

## Pruebas

`tests/unit/test_hud.gd` comprueba con la escena de juego real:

- que cada lugar tiene un icono que existe, y que un icono desconocido cae en el de reserva;
- que el lugar, la fecha y el objetivo son los de `GameData`, `GameClock` y `StoryDirector`, y que
  cambian con el reloj, con un día nuevo y al cumplir un objetivo;
- que el HUD se retira y vuelve en las transiciones, las conversaciones, la pausa y el mapa, y que
  un objetivo cambiado durante una conversación se anuncia al volver;
- que la barra muestra el InputMap, sigue una tecla reasignada, quita una acción sin tecla, se
  enciende y se apaga según el estado y conserva lo imprescindible al estrecharse;
- que a 16:9, 4:3, 5:4, 16:10 y 21:9 ninguna pieza se sale ni se pisa y el objetivo se lee entero;
- que nada del HUD recibe el ratón o el foco, que las pantallas completas quedan por encima, que
  las notificaciones no pasan de cuatro y que el indicador de guardado no tapa la barra.

## Limitaciones

- Las animaciones se revisaron con pruebas y capturas fijas, no viéndolas en movimiento.
- El destello del objetivo y los fundidos no tienen sonido.
- La referencia llama «Tablón» a la tecla B; el juego la llama «Tablero» en el objetivo del día 2,
  en el expediente y en Controles, y el HUD mantiene ese nombre.
- La barra muestra sólo la primera tecla de cada acción (J y no Tab para el expediente); todas
  aparecen en Configuración › Controles.
