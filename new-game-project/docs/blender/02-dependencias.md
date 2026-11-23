# 2. Mapa de dependencias

Qué sistemas tocan la geometría procedural y qué les pasaría si un modelo pasara a venir de un
archivo de Blender. Las rutas son relativas a `new-game-project/`.

## La idea clave: lo visual y lo lógico ya están separados

Cada pieza de los kits hace dos cosas distintas en la misma función:

| Parte | Qué hace | Con qué |
| --- | --- | --- |
| Visual | Añade triángulos con color de vértice al lote del escenario | `location.batch.box/cylinder/sphere/face/gable/pyramid/ground` |
| Lógica | Colisiones, luces, rótulos, puntos de interacción, tipo de suelo, huecos de paso | `location.collider`, `location.solid` (la mitad de colisión), `add_point_light`, `add_sign`, `add_interactable`, `register_surface`, `add_doorway` |

Ningún sistema lee los triángulos del lote. La navegación, las colisiones, el guardado, el mapa y
las pruebas de alcance leen sólo la parte lógica. **Si una migración sustituye únicamente las
llamadas a `batch.*` y deja las demás exactamente igual, el comportamiento del juego no cambia.**
Esta es la regla en la que se apoya toda la arquitectura propuesta ([04-arquitectura.md](04-arquitectura.md)).

`solid(center, size, color, yaw)` es las dos cosas a la vez (`batch.box` + `collider`): al migrar una
pieza que lo use hay que sustituirlo por `collider(center, size, yaw)` más el modelo, con el mismo
centro, tamaño y giro.

## Dependencias por sistema

### Colisiones

- Todas las formas son `BoxShape3D` hijas de un único `StaticBody3D` llamado `Colisiones`, creado
  en `LocationBase._ready` (`scripts/world/location_base.gd:47`). Capa 1.
- Capas del resto: detective capa 2, máscara 1+4; NPC capa 4, máscara 1+2+4; interactivos
  (`Area3D`) capa 8 (`scenes/actors/*.tscn`, `scripts/world/interactable.gd`).
- Las colisiones se construyen con `batch.xform` (el sistema local de `BuildingKit.begin` o de
  los muebles girados), igual que la geometría. Un modelo importado debe usar la misma
  transformación, o quedará desplazado de su colisión.
- Barreras invisibles: `collider` sin geometría, `block_passage`, `InteriorKit.seal_street_door`,
  y los muros perimetrales de `plaza.gd` y `estacion.gd`. No tienen parte visual: **no se migran**.

**Impacto si se migra sólo lo visual:** ninguno. **Riesgo:** que un modelo nuevo sea más grande o
más pequeño que su colisión (el jugador lo atraviesa o choca con aire). Se controla comparando la
caja del modelo con la de la colisión ([03-riesgos.md](03-riesgos.md), R3).

### Navegación de los NPC

- `LocationNavigation.bake` (`scripts/world/location_navigation.gd`) hornea la malla en tiempo
  de ejecución con `PARSED_GEOMETRY_STATIC_COLLIDERS`, máscara 1, **sólo a partir del nodo
  `Colisiones`**. Las mallas visuales no intervienen.
- Consecuencia: una escena de atrezo que trajera su propio `StaticBody3D` fuera de `Colisiones`
  detendría al detective pero **no** entraría en la navegación (los NPC la atravesarían) ni en la
  prueba del mapa. Toda colisión debe registrarse con `location.collider` dentro de `build()`.
- El horneado ocurre en `_ready` justo después de `build()`: nada que se añada más tarde entra.

### Interacciones y detección del jugador

- `Interactable` (`Area3D`, esfera de 1,1 m) se coloca con `add_interactable(nodo, punto)`; el
  detector del jugador es una esfera de 1,3 m en la capa 8. No dependen de ninguna malla.
- Varias pistas están colocadas **al lado o encima** de un mueble concreto: si el mueble cambia de
  tamaño o de forma, la pista puede quedar dentro de él o flotando. Lista en
  [01-inventario.md](01-inventario.md#referencias-narrativas).
- `InteractionMarker` (el rombo) se genera con `MeshBatcher` y usa `MaterialLibrary.marker()`:
  es interfaz, no escenario. **Se mantiene procedural.**
- `LocationBase.is_spot_clear_for_npc` mide distancias a los `Interactable` hijos del escenario:
  no depende de modelos.

### Rutas y posiciones de los NPC

- Puestos (`add_marker`, `face_marker`), huecos de paso (`add_doorway`, lo llama
  `InteriorKit.wall` por cada hueco) y salidas (`LocationExit`) son coordenadas en GDScript.
- `data/schedules.json` nombra marcadores por su id; `tests/unit/test_world.gd` comprueba que
  existen y son alcanzables; `test_npc_layout.gd` y `test_npc_leave.gd`, que no estorban.
- Ninguno depende de la geometría. Sí dependen de las colisiones (alcance real).

### Puntos de aparición y transiciones

- `add_spawn(id, punto, yaw)`; `Game._load_location` coloca al detective, fija `FallGuard.fallback`
  y los límites de la cámara (`scripts/core/game.gd:172`). `LocationExit` emite
  `location_change_requested` con escenario y punto de aparición.
- `test_world.test_spawns_are_not_inside_obstacles` comprueba con una cápsula que ningún punto
  de aparición está dentro de una colisión. No mira mallas.

### Cámara y límites del escenario

- `ExplorationCamera` ortográfica a 45° (`scripts/player/exploration_camera.gd`), con su foco
  limitado por `camera_limits`. Los interiores usan el corte de casa de muñecas
  (`InteriorKit.BACK_WALL` 3,7 m al fondo, `PARTITION` 1,05 m delante).
- **Dependencia visual, no lógica:** un modelo más alto que el original en las paredes o muebles
  cercanos a la cámara puede tapar al detective. Las paredes bajas, setos y muretes del lado de la
  cámara deben conservar su altura.

### Animaciones procedurales

- `CharacterModel` (`scripts/actors/character_model.gd`) construye seis pivotes con nombre
  (`PiernaIzq`, `PiernaDer`, `Torso`, `BrazoIzq`, `BrazoDer`, `Cabeza`), cada uno con su malla
  `Malla<Capa>`, y los anima en `_process`: balanceo de piernas y brazos (`rotation.x`), vaivén
  vertical, giro e inclinación de la cabeza y cabeceo al hablar.
- Interfaz pública que usan otros scripts (contada con `grep`):

  | Miembro | Quién lo usa |
  | --- | --- |
  | `build(look)` | `npc.gd`, `player_controller.gd`, `test_audio.gd` |
  | `rotation.y` del nodo `Model` | `npc.gd` (25 usos), `player_controller.gd`, pruebas de NPC |
  | `set_motion(ratio)` | `npc.gd`, `player_controller.gd` |
  | `set_talking(bool)`, `is_talking()` | `npc.gd`, pruebas |
  | `set_head_turn(yaw)`, `set_head_tilt(pitch)` | `npc.gd` |
  | `set_fade(amount)` | `npc.gd` (salida por la puerta) |
  | señal `stepped` | `game.gd` (sonido de pasos), `test_audio.gd` |
  | `_process(delta)` llamado a mano | `test_audio.gd:421` (ritmo de pasos) |

- El nodo `Model` de `npc.tscn` y `player.tscn` lleva el script `CharacterModel`; las dos escenas
  esperan `$Model` de ese tipo (`@onready var model: CharacterModel = $Model`).
- **Orientación:** los personajes miran a **−Z** (`atan2(-direction.x, -direction.z)` en
  `npc.gd:212`). El atrezo, en cambio, tiene su frente en **+Z** local. Ver
  [05-estandares.md](05-estandares.md#ejes-y-orientación).
- `set_fade` recorre todos los `GeometryInstance3D` descendientes: funciona igual con mallas
  importadas, siempre que cuelguen del nodo `Model`.

### Persistencia y recuperación de partidas

- El guardado (`scripts/autoload/save_system.gd`, `scripts/save/save_format.gd`) almacena el id
  del escenario, el punto de aparición y la pose del detective (posición y giro), además del
  estado de la historia. **No guarda rutas de nodos, nombres de mallas ni ids de modelos.**
- Al cargar, `Game._apply_saved_pose` valida la posición con `LocationBase.is_standing_point`
  (rayo al suelo y cápsula contra la capa 1). Depende de las colisiones, no de las mallas.
- `SavePreview` dibuja la miniatura de la ranura con una cámara copiada de la del juego: se verá
  el modelo nuevo sin cambios de código.

**Impacto:** ninguno mientras no cambien las colisiones. Las partidas antiguas siguen siendo válidas.

### Identificadores persistentes

- Ids que sí persisten o aparecen en datos: escenarios (`locations.json`), puntos de aparición,
  marcadores (`schedules.json`), pistas (`clues.json`), personajes (`characters.json`, con su
  bloque `model` de aspecto). Ninguno identifica un modelo 3D.
- Los ids de modelo que se creen (`buzon`, `farola`…) son nuevos y sólo los usará el código de los
  kits: no hay que migrar datos guardados.

### Sonido

- `AudioManager.play_footstep` pregunta `LocationBase.get_surface_at` (zonas declaradas por
  `plank_floor`, `tile_floor` y `rug` con `register_surface`). Los suelos y alfombras deben seguir
  llamando a `register_surface` aunque cambie su aspecto.
- El ritmo de los pasos sale de la señal `stepped` de `CharacterModel`.

### Iluminación y calidad gráfica

- Las luces (`OmniLight3D`) las crean `add_point_light` y los kits (`street_lamp`, `floor_lamp`,
  `ceiling_lamp`, `fireplace`) y se registran en `GraphicsQuality.register_light`, que guarda la
  sombra «de diseño» y la reduce según la calidad. **Las luces no deben venir en los GLB**
  (exportar con `export_lights = False`) o escaparían a la configuración gráfica.
- Superficies que brillan (ventanas, faroles, pantallas): capa `GLOW` con
  `assets/shaders/glow_vertex.gdshader` (sin sombreado, `pow(COLOR, 2.2) * 1.5`).

### Rótulos

- `add_sign` crea `Label3D` con la letra serif del tema (`UiTheme.serif()`): CAFÉ LA LUNA,
  PRENSA, MANSIÓN VALDÉS, flechas de los postes… El texto se queda en Godot (editable y con la
  misma letra). El modelo sólo aporta el tablero.

### Mapa del pueblo

- `scripts/ui/map/town_map_art.gd` copia a mano las medidas de los edificios de `plaza.gd` y
  `estacion.gd` (`PLAZA_BUILDINGS`, `STATION_BUILDINGS`).
- `tests/unit/test_map.gd:103` comprueba que cada edificio dibujado coincide con una colisión de
  `Colisiones`. Un edificio remodelado debe conservar la huella de su colisión
  (`BuildingKit.body` → `solid` de anchura × fondo), o habrá que actualizar el mapa y la prueba a
  la vez.

### Rendimiento y llamadas de dibujado

- `MeshBatcher` fusiona todo un escenario en como mucho tres `MeshInstance3D` (capas `GROUND`,
  `OPAQUE`, `GLOW`), con tres materiales compartidos (`MaterialLibrary`).
- `tests/unit/test_world.gd:18` (`test_geometry_is_batched`) exige **≤ 3 `MeshInstance3D` hijos
  directos** de cada escenario.
- Cada personaje son 6 `MeshInstance3D` (una por pivote): 6 llamadas de dibujado más sombras.
- Medida previa: la plaza tiene unas 91 llamadas de dibujado y 134.000 primitivas por fotograma
  (`docs/ESTADO_PROYECTO.md`, «Rendimiento»).
- **Trampa:** instanciar un GLB como `Node3D` hijo del escenario no aumenta el recuento de esa
  prueba (sólo cuenta hijos directos `MeshInstance3D`), pero sí añade llamadas de dibujado. La
  prueba pasaría sin medir lo que pretende. La arquitectura propuesta fusiona los modelos en el
  lote para que el número real no cambie.

### Variación de color por cara

- `MeshBatcher.face` oscurece o aclara cada cara al azar (±0,035) con un generador **por
  escenario** y semilla fija (7). El tono de cada cara depende de **cuántas caras se añadieron
  antes**. Quitar las caras del buzón cambia el tono de todas las que vienen después en la plaza.
  Ver [03-riesgos.md](03-riesgos.md), R5.

### Cierre del motor

- `GameData._exit_tree` llama a `MaterialLibrary.clear()` para soltar materiales estáticos al
  cerrar (las cachés estáticas sin soltar provocan avisos al salir). Una caché estática de
  modelos importados debe liberarse en el mismo sitio.

### Herramientas y pruebas que leen la estructura

| Archivo | Qué lee | Se rompe si… |
| --- | --- | --- |
| `tests/unit/test_world.gd` | `MeshInstance3D` hijos, `_spawns`, colisiones con cápsula, alcance | hay más de 3 mallas hijas; cambian colisiones |
| `tests/unit/test_world_bounds.gd` | suelo bajo cada punto alcanzable, puertas a la calle, huecos interiores | cambian suelos de colisión o barreras |
| `tests/unit/test_map.gd` | nodo `Colisiones` y sus `BoxShape3D` | cambia la huella de un edificio |
| `tests/unit/test_location_navigation.gd` | malla horneada | cambian colisiones |
| `tests/unit/test_audio.gd` | `CharacterModel.new()`, `build`, `stepped`, `_process`; `get_surface_at` | cambia la interfaz del personaje o desaparece `register_surface` |
| `tests/unit/test_npc*.gd` | `model.rotation`, `is_talking` | cambia el nodo `Model` o su interfaz |
| `tests/visual/captura.gd` | escena renderizada; `--stats` mide llamadas de dibujado | — (es la herramienta para comparar) |
