# Arquitectura de Villa Sombría

Godot 4.7, GDScript tipado y sin complementos. El proyecto está en `new-game-project/`.

## Principios

- **La historia son datos.** Personajes, pistas, diálogos, rutinas y reglas viven en `data/`.
  Se puede escribir un caso nuevo sin tocar el código.
- **La lógica no depende de la interfaz.** `DialogueManager` e `Investigation` funcionan sin
  pantallas, y por eso el caso completo se puede probar de forma automática.
- **El mundo se declara en código.** Cada escenario es una escena mínima cuyo script describe
  su geometría con kits reutilizables, sin modelos externos.
- **Señales para desacoplar.** Los sistemas emiten por `EventBus` y la interfaz escucha.

## Carpetas

| Carpeta | Contenido |
| --- | --- |
| `data/` | Historia y reglas en JSON |
| `assets/siluetas/` | Siluetas SVG de las conversaciones |
| `assets/shaders/` | Empedrado, brillo, contraluz, postproceso y pergamino |
| `assets/ui/` | Grabado de la mansión, silueta del pueblo, iconos SVG de los menús, del expediente y de los lugares del HUD, perilla de volumen e interruptor; `assets/ui/expediente/`, los grabados sepia del expediente; `assets/ui/tablero/`, el rincón del corcho y las marcas del selector del tablero |
| `scenes/main/` | Menú principal y escena de juego |
| `scenes/actors/` | Detective y NPC |
| `scenes/world/locations/` | Los cinco escenarios y el campo de pruebas |
| `scenes/ui/` | Interfaz |
| `scripts/autoload/` | Sistemas globales |
| `scripts/core/` | Escena de juego, condiciones y efectos |
| `scripts/save/` | Formato de las partidas, escritura segura e imagen de cada ranura |
| `scripts/settings/` | Esquema de las preferencias del jugador y lo que las aplica, filtros visuales incluidos; ver [CONFIGURACION.md](CONFIGURACION.md) y [FILTROS.md](FILTROS.md) |
| `scripts/input/` | Teclas reasignables y navegación de los menús con el mando; ver [CONTROLES.md](CONTROLES.md) |
| `scripts/map/` | Calibración, zonas y lugares del mapa del pueblo |
| `scripts/actors/` | Modelo procedural, NPC y rutinas |
| `scripts/player/` | Controlador, cámara y detector de interacción |
| `scripts/world/` | Kits de construcción, interactivos y escenarios |
| `scripts/ui/` | Interfaz; `scripts/ui/map/`, la vista, la ilustración y los símbolos del mapa; `scripts/ui/hud/`, las piezas del HUD; `scripts/ui/journal/`, las piezas y secciones del expediente; `scripts/ui/board/`, las piezas del tablero de deducción; `scripts/ui/dialogue/`, las piezas de las conversaciones |
| `tests/unit/` | Pruebas automatizadas |
| `tests/persistencia/` | Guardar y cargar en otro proceso; cierre real de la ventana |
| `tests/visual/` | Herramientas de captura y de rendimiento |
| `tools/` | Verificación y generación de siluetas y de los grabados del expediente |

## Autoloads

| Nombre | Responsabilidad |
| --- | --- |
| `EventBus` | Señales globales |
| `GameData` | Carga los JSON de `data/` |
| `GameState` | Estado guardable: marcas, pistas, testimonios, deducciones e hipótesis |
| `GameClock` | Día y hora; el tiempo sólo avanza con acciones del jugador |
| `Investigation` | Registro sin duplicados, deducciones, hipótesis validadas (`get_hypothesis`, `set_hypothesis`) y evaluación de la acusación |
| `DialogueManager` | Flujo de conversaciones y escenas, sin interfaz |
| `StoryDirector` | Objetivos, eventos por hora, escenas al entrar en un lugar, descanso |
| `SaveSystem` | Cinco ranuras en `user://saves/`, ranura activa, flujo único de escritura, autoguardado y carga; ver [GUARDADO.md](GUARDADO.md) |
| `SaveIndicator` | Indicador animado de guardado, por encima de cualquier escena |
| `ExitManager` | Cierre controlado: la X, Alt + F4 y los botones de salida guardan antes de salir |
| `ConfirmDialog` | Ventana de confirmación común, con cuenta atrás opcional; ver [CONFIGURACION.md](CONFIGURACION.md) |
| `Settings` | Preferencias del jugador por categorías (audio, gráficos, jugabilidad, filtros, accesibilidad, controles) en `user://ajustes.cfg`, validadas con `SettingsSchema`; ver [CONFIGURACION.md](CONFIGURACION.md) |
| `Controls` | Teclas del jugador aplicadas al InputMap y guardadas en `ajustes.cfg`, conflictos, restaurar, dispositivo en uso, mandos conectados y navegación de los menús con el mando; ver [CONTROLES.md](CONTROLES.md) |
| `AudioManager` | Sonido sintetizado al arrancar |
| `TownMap` | Mapa del pueblo: lugares, calibración, posición del detective en el mapa y lugares visitados; ver [MAPA.md](MAPA.md) |

## Escenas

`scenes/main/main_menu.tscn` es la escena principal. Instancia la plaza real con su lluvia y
una cámara propia, y pone encima la interfaz en un `CanvasLayer`: el fondo nunca es una imagen.
El panel translúcido es `MenuFrame` y cada opción es un `MenuOptionButton`, una tarjeta de
pergamino con icono que se resalta en burdeos al señalarla con el ratón, el teclado o el mando.
Los dos se dibujan en código con la paleta y las tipografías de `CaseFileStyle`, y los botones
reutilizan el shader de pergamino del expediente. «Continuar» muestra el día y la hora de la
ranura que retomaría y, sin partidas, queda atenuado y fuera de la navegación.

La pausa (`scenes/ui/pause_menu.tscn`) usa los mismos componentes sobre el escenario congelado.
Configuración y Controles son pantallas propias que se abren encima de la pausa o del menú
principal; ver [Menús](#menús).

`scenes/main/game.tscn` contiene:

```text
Game
├── WorldRoot          escenario activo, sustituido al cambiar de lugar
├── Player
├── CameraRig          cámara ortográfica
├── PostFx             capa 1, bajo toda la interfaz: niebla, filtro de color, viñeta y grano
├── Hud                lugar, objetivo, teclas y avisos; ver HUD.md
├── Subtitles          subtítulos opcionales de voces y sonidos; ver CONFIGURACION.md
├── DialogueUi         conversaciones: siluetas, lectura y respuestas; ver DIALOGOS.md
├── ClueInspector
├── JournalUi          expediente: carpeta, pestañas y cinco secciones; ver EXPEDIENTE.md
├── BoardUi            tablero: sospechosos, corcho, comparación e hipótesis; ver TABLERO.md
├── AccusationUi
├── PauseMenu
├── CaseClosedUi
└── ScreenFade
```

## Clases principales

- `LocationBase`: base de los escenarios. Registra puntos de aparición y marcadores, y coloca
  a los NPC según su rutina.
- `MeshBatcher`: fusiona primitivas de caras planas en una malla por capa, con colores de
  vértice. Un escenario completo son tres mallas como máximo.
- `BuildingKit`, `PropsKit`, `InteriorKit`: piezas de arquitectura y atrezo.
- `CharacterModel`: personaje procedural animado, descrito con un diccionario.
- `Interactable`: base de lo que responde a E. Hereda `ClueObject`, `LocationExit`,
  `RestPoint` y `NpcInteraction`.
- `Npc`: estados de reposo, marcha, espera y conversación.
- `Conditions` y `Effects`: interpretan los bloques `if` y `effects` de los datos.

## Señales de `EventBus`

| Señal | Se emite cuando |
| --- | --- |
| `interaction_focus_changed` | Cambia el elemento al alcance |
| `notification_requested` | Hay que mostrar un aviso |
| `location_change_requested`, `location_changed` | Se pide y se completa un cambio de lugar |
| `player_locks_changed` | Cambian los bloqueos del control del jugador (`GameState.lock_player`) |
| `clue_discovered`, `testimony_recorded`, `deduction_made` | Avanza la investigación |
| `hypothesis_changed` | El jugador anota o cambia una hipótesis en el tablero (`Investigation.set_hypothesis`) |
| `flag_set`, `objectives_changed` | Cambia el progreso |
| `time_changed`, `day_changed` | Avanza el calendario |
| `story_action` | Los datos piden una acción: abrir la acusación, iniciar el epílogo, cerrar el caso |
| `subtitle_requested` | Una voz o un sonido narrado necesita subtítulo (lo muestra `SubtitleBar` si están activados) |
| `clue_inspection_requested`, `rest_requested` | El jugador examina una pista o se acuesta |

`SaveSystem` escucha varias de estas señales para pedir autoguardados y emite las suyas
(`save_started`, `save_finished`, `slot_deleted`, `slots_changed`, `active_slot_changed`), que
usan los menús, el indicador y `ExitManager`. Ver [GUARDADO.md](GUARDADO.md).

## Formato de los datos

Las **condiciones** (`if`) admiten `flags`, `not_flags`, `clues`, `not_clues`, `testimonies`,
`deductions`, `day_min`, `day_max` y `any`.

Los **efectos** (`effects`) admiten `flags`, `clues`, `testimonies`, `minutes`, `notify` y
`action`.

Pregunta de un diálogo:

```json
{
  "id": "carta",
  "label": "He encontrado esta carta de Marcos en su cuarto.",
  "if": {"clues": ["carta_amor"]},
  "lines": [{"s": "lucia", "t": "¡Eso es mío!"}],
  "effects": {"testimonies": ["t_lucia_escalera"]}
}
```

Una pregunta puede llevar `variants` para responder según el estado, y una escena puede llevar
`choices` y `after`.

## Añadir contenido

- **Retrato propio:** cambia `portrait` en `data/characters.json` por una ruta a un PNG o SVG.
  Así se integrarán los retratos generados con IA; ver [RECURSOS.md](RECURSOS.md).
- **Voces:** aún no hay soporte. El diseño previsto es un campo opcional por línea de diálogo
  con la ruta del audio, que se ignora si el archivo no existe.
- **Lugar:** su entrada en `data/locations.json` con `name`, `icon` (icono del HUD), `scene` y
  `outdoor`. Ver [HUD.md](HUD.md).
- **Pista:** añádela a `data/clues.json` y colócala con `add_interactable(ClueObject.new("id"), posición)`
  o concédela desde un diálogo.
- **NPC:** añade su entrada en `characters.json`, su rutina en `schedules.json` y su archivo en
  `data/dialogues/`.
- **Deducción:** añádela a `data/deductions.json`; el tablero la detecta sola y dibuja su hilo.
- **Sospechoso:** `"suspect": true` en su entrada de `characters.json`; el tablero y el expediente
  le dan ficha sin tocar código.
- **Estado que deba guardarse:** si es una decisión o un hecho de la historia, usa una marca
  desde los datos; si es un sistema nuevo, registra una sección. Ver [GUARDADO.md](GUARDADO.md).

## HUD de exploración

`Hud` (`scenes/ui/hud.tscn`) muestra el lugar con la fecha, el objetivo pendiente, una barra con
las teclas reales del InputMap, el aviso de interacción, las notificaciones y un marco fino. Sólo
presenta: `HudInfo` lee los datos de `GameData`, `GameClock`, `StoryDirector` e `InputLabels`, y
el HUD se actualiza con las señales de `EventBus`. Se retira mientras el jugador no tiene el
control (conversaciones, transiciones, pantallas, pausa) y vuelve al recuperarlo. Las piezas
(`ParchmentPanel`, `NoirPlate`, `HudKeyHint`, `CinematicFrame`...) y su estilo (`HudStyle`) son
reutilizables. Detalle, ampliaciones y pruebas en [HUD.md](HUD.md).

## Conversaciones

`DialogueUi` (`scenes/ui/dialogue_ui.tscn`) es una sola ventana de cuero y pergamino con dos modos:
la lectura (placa con el nombre, texto grande que se escribe poco a poco y se reparte en páginas si
no cabe, «[E] Continuar») y la elección (tarjetas de respuesta con la placa «Tus preguntas» o «Tus
respuestas»). Sólo coordina: la conversación la lleva `DialogueManager`, que avisa con señales, y la
interfaz contesta con `advance()` y `choose()`. Las siluetas y su iluminación son de `DialogueCast`,
las entradas de `DialogueControls` y el estilo de `DialogueStyle`; el resto de piezas están en
`scripts/ui/dialogue/`. No guarda estado propio. Detalle, controles, animaciones y pruebas en
[DIALOGOS.md](DIALOGOS.md).

## Expediente

`JournalUi` (`scenes/ui/journal_ui.tscn`) es una carpeta de cuero con cinco secciones: objetivos,
pistas, testimonios, sospechosos y deducciones. Sólo presenta: `JournalInfo` lee los datos de
`StoryDirector`, `GameState`, `GameData`, `GameClock` e `InputLabels` sin cambiar nada, así que
el expediente no tiene estado que guardar. Cada sección hereda de `JournalSection` (lista a la
izquierda, ficha a la derecha) y sólo dice de dónde salen sus datos y cómo se pinta su ficha; las
piezas (`JournalFolder`, `JournalTabs`, `JournalList`, `JournalDetail`, `JournalPhoto`,
`JournalEmptyState`...) y su estilo (`JournalStyle`) son reutilizables. Las secciones se crean una
vez y se ponen al día con `EventBus`. Detalle, recorrido con teclado y pruebas en
[EXPEDIENTE.md](EXPEDIENTE.md).

## Tablero de deducción

`BoardUi` (`scenes/ui/board_ui.tscn`) es un tablero de cuero con la fila de sospechosos, un corcho
con las fichas de lo descubierto e hilos rojos, y la columna «Comparar elementos». Sólo coordina:
`BoardInfo` lee los datos sin cambiar nada, la relación la decide `Investigation.try_link` y las
hipótesis se anotan con `Investigation.set_hypothesis`, que las valida y emite
`EventBus.hypothesis_changed`. Las piezas (`BoardFrame`, `BoardSuspectCard`, `BoardCanvas`,
`BoardEvidenceCard`, `BoardConnections`, `BoardComparisonPanel`, `BoardHypothesisEditor`...) y su
estilo (`BoardStyle`) están en `scripts/ui/board/` y reutilizan las del expediente y el HUD. Los
hilos sólo unen deducciones registradas y pasan por detrás del papel. Detalle, recorrido con
teclado y pruebas en [TABLERO.md](TABLERO.md).

## Menús

Todos los menús oscuros se dibujan en código, sin texturas de fondo, y se superponen al escenario
real: el menú principal sobre la plaza en marcha, y la pausa y sus pantallas sobre el juego
congelado por `get_tree().paused`. Los fundidos funcionan en pausa porque `PauseMenu` usa
`PROCESS_MODE_ALWAYS`.

| Pieza | Papel |
| --- | --- |
| `MenuStyle` | Paleta (panel `#101116`, dorado `#B58B4A`, crema `#F1DEB9`, burdeos `#8A2632`) y estilos de deslizadores, interruptores, teclas, filas y «Próximamente» |
| `MenuFrame` | Panel translúcido con filete dorado; con `emblem`, medallón sobre una cresta |
| `MenuHeading`, `GoldDivider` | Título entre filigranas y filetes con rombo |
| `MenuOptionButton` | Opción de pergamino con resaltado animado; `compact` y `centered` para la pausa y «Volver» |
| `MenuScreen` | Pantalla que se abre encima de otra: fundido, Escape, señal `closed` |
| `CategoryMenu` | `MenuScreen` con pestañas (`CategoryTab`) y páginas desplazables; base de las dos siguientes |
| `SettingsMenu` | Audio, Gráficos, Jugabilidad, Filtros (tarjetas `FilterCard`) y Accesibilidad con las preferencias reales de `Settings`; ver [CONFIGURACION.md](CONFIGURACION.md) y [FILTROS.md](FILTROS.md) |
| `OptionSelector` | Fila «‹ valor ›» de una lista cerrada: izquierda y derecha, aceptar y ratón |
| `ControlsMenu` | Teclas leídas del InputMap al abrir, en filas `BindingRow` con `KeyCap`; nombres en `InputLabels`. En «Otros», las tres herramientas (`MenuActionRow`): reasignar, mando y restaurar; ver [CONTROLES.md](CONTROLES.md) |
| `RebindMenu` | «Reasignar teclas», encima de Controles: tecla principal y alternativa de cada acción (`RebindRow`, `KeySlotButton`), conflictos con `ConfirmDialog` |
| `GamepadMenu` | «Jugar con mando», encima de Controles: el esquema de botones leído del InputMap |
| `MapScreen` | Mapa del pueblo sobre la pausa, con M o con la opción «Mapa»; ver [MAPA.md](MAPA.md) |

Escape (o B en el mando) cierra siempre la pantalla de arriba: expediente o configuración → pausa →
juego; reasignar teclas o el esquema del mando → Controles → pausa. El mapa
abierto con M vuelve directamente al juego; abierto desde la pausa, a la pausa. Al
volver, el foco regresa a la opción que abrió la pantalla. Las pestañas se recorren con
arriba y abajo y cambian la página; a la derecha se entra en la página y a la izquierda se
vuelve a su pestaña.

### Funcionalidades preparadas para futuras versiones

Lo previsto se mostraría desactivado, sin foco y con «Próximamente» (`CategoryMenu.add_planned_section`);
no guarda nada. Hoy ni Configuración ni Controles tienen nada previsto: todas sus opciones existen.

| Ampliación | Qué tocar |
| --- | --- |
| Opción de Configuración nueva | Describirla en `SettingsSchema`, aplicarla donde corresponda y crear su fila con `_add_switch_row` o `_add_selector` en la página de su categoría de `scripts/ui/settings_menu.gd`; ver [CONFIGURACION.md](CONFIGURACION.md) |
| Acción o categoría de controles | Crear la acción en el InputMap (con su botón del mando) y añadir su fila o categoría a `CATEGORIES` de `scripts/ui/controls_menu.gd`; si se puede reasignar, también a `InputBindings.ACTIONS`. Ver [CONTROLES.md](CONTROLES.md) |
| Reasignar el mando u otra disposición de botones | Ver «Ampliaciones» en [CONTROLES.md](CONTROLES.md) |
| Categoría nueva en cualquier menú por categorías | Otra llamada a `add_category()` en `_build_categories()` |
| Filtro visual nuevo | Su identificador en `VisualFilters.IDS` y su nombre, descripción y parámetros en `VisualFilters.FILTERS`; la tarjeta y la preferencia salen solas. Ver [FILTROS.md](FILTROS.md) |
| Pantalla o capa de interfaz nueva | Siempre en una `CanvasLayer` por encima de la 1 (`PostFx.LAYER`), o el filtro visual la teñiría; `test_visual_filters` lo comprueba |

Las teclas 1 a 9 de las respuestas (fila superior y teclado numérico) y el clic de las
conversaciones se leen en `DialogueControls`, fuera del InputMap; por eso figuran como teclas fijas
en `CATEGORIES`. Avanzar y confirmar sí usan `interact` y `ui_accept`.

## Decisiones técnicas

- **Niebla por postproceso.** La niebla volumétrica no se usa porque la cámara es ortográfica.
- **NPC con puntos de ruta.** Caminan en línea recta entre marcadores y saltan al destino si
  se atascan cuatro segundos. No se usa `NavigationRegion3D`.
- **Corte de casa de muñecas.** Las paredes entre la cámara y el jugador son bajas, pero su
  colisión es completa.
- **Sincronización vertical desactivada por defecto.** Ver `ESTADO_PROYECTO.md`.
- **Guardado por secciones y en segundo plano.** Cada sistema registra su parte del estado en
  `SaveSystem`; el guardado manual, el automático y el de salida comparten un único flujo de
  escritura atómica en un hilo, y el autoguardado sólo escribe en la ranura activa. Ver
  [GUARDADO.md](GUARDADO.md).
- **Cierre controlado.** `auto_accept_quit` está desactivado: toda salida pasa por
  `ExitManager`, que guarda y comprueba el resultado antes de cerrar.

## Verificación

```powershell
powershell -File tools\verificar.ps1
```

Además de las pruebas, el script guarda una partida en un proceso de Godot y la carga en otro
nuevo. Con `-ConVentana` comprueba también las imágenes de las ranuras y el cierre real de la
ventana con la X y con Alt + F4. Las pruebas usan `user://pruebas_guardado/`, de modo que nunca
tocan las partidas del jugador.
