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
| `assets/siluetas/` | Siluetas SVG de los interrogatorios |
| `assets/shaders/` | Empedrado, brillo, contraluz y postproceso |
| `scenes/main/` | Menú principal y escena de juego |
| `scenes/actors/` | Detective y NPC |
| `scenes/world/locations/` | Los cinco escenarios y el campo de pruebas |
| `scenes/ui/` | Interfaz |
| `scripts/autoload/` | Sistemas globales |
| `scripts/core/` | Escena de juego, condiciones y efectos |
| `scripts/save/` | Formato de las partidas y escritura segura |
| `scripts/actors/` | Modelo procedural, NPC y rutinas |
| `scripts/player/` | Controlador, cámara y detector de interacción |
| `scripts/world/` | Kits de construcción, interactivos y escenarios |
| `scripts/ui/` | Interfaz |
| `tests/unit/` | Pruebas automatizadas |
| `tests/persistencia/` | Prueba de guardar, cerrar y volver a cargar en otro proceso |
| `tests/visual/` | Herramientas de captura y de rendimiento |
| `tools/` | Verificación y generación de siluetas |

## Autoloads

| Nombre | Responsabilidad |
| --- | --- |
| `EventBus` | Señales globales |
| `GameData` | Carga los JSON de `data/` |
| `GameState` | Estado guardable: marcas, pistas, testimonios, deducciones e hipótesis |
| `GameClock` | Día y hora; el tiempo sólo avanza con acciones del jugador |
| `Investigation` | Registro sin duplicados, deducciones y evaluación de la acusación |
| `DialogueManager` | Flujo de conversaciones y escenas, sin interfaz |
| `StoryDirector` | Objetivos, eventos por hora, escenas al entrar en un lugar, descanso |
| `SaveSystem` | Ranuras de guardado, autoguardado y carga en `user://saves/`; ver [GUARDADO.md](GUARDADO.md) |
| `SaveIndicator` | Indicador animado de guardado, por encima de cualquier escena |
| `Settings` | Volumen, pantalla completa y sincronización vertical |
| `AudioManager` | Sonido sintetizado al arrancar |

## Escenas

`scenes/main/main_menu.tscn` es la escena principal. `scenes/main/game.tscn` contiene:

```text
Game
├── WorldRoot          escenario activo, sustituido al cambiar de lugar
├── Player
├── CameraRig          cámara ortográfica
├── PostFx             niebla, viñeta y grano
├── Hud
├── DialogueUi
├── ClueInspector
├── JournalUi
├── BoardUi
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
| `clue_discovered`, `testimony_recorded`, `deduction_made` | Avanza la investigación |
| `flag_set`, `objectives_changed` | Cambia el progreso |
| `time_changed`, `day_changed` | Avanza el calendario |
| `story_action` | Los datos piden una acción: abrir la acusación, iniciar el epílogo, cerrar el caso |
| `clue_inspection_requested`, `rest_requested` | El jugador examina una pista o se acuesta |

`SaveSystem` escucha varias de estas señales para pedir autoguardados y emite las suyas
(`save_started`, `save_finished`, `slot_deleted`, `slots_changed`), que usan los menús y el
indicador. Ver [GUARDADO.md](GUARDADO.md).

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
- **Pista:** añádela a `data/clues.json` y colócala con `add_interactable(ClueObject.new("id"), posición)`
  o concédela desde un diálogo.
- **NPC:** añade su entrada en `characters.json`, su rutina en `schedules.json` y su archivo en
  `data/dialogues/`.
- **Deducción:** añádela a `data/deductions.json`; el tablero la detecta sola.
- **Estado que deba guardarse:** si es una decisión o un hecho de la historia, usa una marca
  desde los datos; si es un sistema nuevo, registra una sección. Ver [GUARDADO.md](GUARDADO.md).

## Decisiones técnicas

- **Niebla por postproceso.** La niebla volumétrica no se usa porque la cámara es ortográfica.
- **NPC con puntos de ruta.** Caminan en línea recta entre marcadores y saltan al destino si
  se atascan cuatro segundos. No se usa `NavigationRegion3D`.
- **Corte de casa de muñecas.** Las paredes entre la cámara y el jugador son bajas, pero su
  colisión es completa.
- **Sincronización vertical desactivada por defecto.** Ver `ESTADO_PROYECTO.md`.
- **Guardado por secciones y en segundo plano.** Cada sistema registra su parte del estado en
  `SaveSystem`; la escritura va a un hilo y es atómica. Ver [GUARDADO.md](GUARDADO.md).

## Verificación

```powershell
powershell -File tools\verificar.ps1
```

Además de las pruebas, el script guarda una partida en un proceso de Godot y la carga en otro
nuevo. Las pruebas usan `user://pruebas_guardado/`, de modo que nunca tocan las partidas del jugador.
