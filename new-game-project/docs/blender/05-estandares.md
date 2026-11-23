# 5. Estándares para archivos de Blender y Godot

Reglas que deben cumplir todos los modelos. Si una regla no se puede cumplir para una pieza, se
anota la excepción en su registro y en el commit.

## Carpetas

```text
VillaSombria/                          raíz del repositorio
├── blender/                           fuera del proyecto Godot (Godot no lo ve)
│   ├── fuentes/<categoría>/<id>.blend      fuente editable de cada modelo
│   ├── referencias/<id>.json               la pieza procedural tal como la dibuja el juego (vía A):
│   │                                       variantes, polígonos, colisiones cercanas y usos
│   ├── registro/<id>.json                  registro de la última exportación
│   └── scripts/                            migrar.py, importar_referencia.py, exportar_glb.py, vs_comun.py
└── new-game-project/
    ├── assets/modelos/<categoría>/<id>.glb (+ .glb.import)   lo que carga el juego
    └── tools/modelos/                      exportar_referencias.tscn y validar_modelos.tscn
```

Categorías: `atrezo` (`PropsKit`), `mobiliario` (`InteriorKit`), `arquitectura` (`BuildingKit`),
`escenario` (piezas propias de un escenario concreto) y `personajes`.

Los `.blend` **nunca** dentro de `new-game-project/`: Godot intentaría importarlos y exigiría
Blender configurado en cada equipo ([03-riesgos.md](03-riesgos.md), R8).

## Nombres

| Qué | Regla | Ejemplos |
| --- | --- | --- |
| Id de modelo y archivos | Español, minúsculas, `snake_case`, **sin tildes ni eñes** | `buzon`, `farola`, `banco_plaza`, `mesa_cafe`, `reloj_pie` |
| Objetos de Blender | `PascalCase` en español, como los nodos de Godot | `Buzon`, `Farola`, `PiernaIzq` |
| Pivotes de personaje | Exactamente los de `CharacterModel` | `PiernaIzq`, `PiernaDer`, `Torso`, `BrazoIzq`, `BrazoDer`, `Cabeza` |
| Piezas opcionales de personaje | `Pelo_<hair_style>`, `Sombrero_<hat>`, `Extra_<extra>` con los valores de `characters.json` | `Pelo_curly`, `Sombrero_kepi`, `Extra_tray` |
| Materiales (atrezo) | Por capa del lote | `vs_opaco`, `vs_brillo`, `vs_suelo` |
| Materiales (personajes) | Por papel del `look` | `vs_piel`, `vs_abrigo`, `vs_pantalon`, `vs_zapatos`, `vs_acento`, `vs_pelo`, `vs_sombrero` |
| Colecciones | Lo que se exporta y lo que no | `Exportar`, `Referencia` |
| Atributo de color | El nombre por defecto del exportador | `Color` |

## Ejes y orientación

Blender usa Z arriba; el exportador glTF (con `export_yup = True`) convierte a Y arriba. Un punto
de Blender `(x, y, z)` llega a Godot como `(x, z, −y)`.

| Tipo | Frente en Godot | Frente en Blender | Vista de Blender que lo enseña de frente |
| --- | --- | --- | --- |
| Atrezo, mobiliario, fachadas | **+Z** local (la ranura del buzón, los libros de la estantería, la puerta) | **−Y** | Front (tecla 1 del teclado numérico) |
| Personajes | **−Z** (`atan2(-dir.x, -dir.z)` en `npc.gd`) | **+Y** | Back (Ctrl + 1) |

Los personajes se modelan mirando a +Y para que lleguen a Godot mirando a −Z **sin** un nodo
girado de por medio: girar 180° un nodo padre invierte el sentido de `set_head_tilt` (la viuda
abatida miraría hacia arriba).

Pivotes de personaje en coordenadas de **Blender** (metros, personaje de altura 1,0):

| Objeto | Origen (x, y, z) |
| --- | --- |
| `PiernaIzq` | (−0,11; 0; 0,84) |
| `PiernaDer` | (0,11; 0; 0,84) |
| `Torso` | (0; 0; 0,84) |
| `BrazoIzq` | (−0,27; 0; 1,42) |
| `BrazoDer` | (0,27; 0; 1,42) |
| `Cabeza` | (0; 0; 1,50) |

## Origen, escala y transformaciones

- 1 unidad = 1 metro; `Unit Scale` 1,0; sistema métrico.
- El origen de cada pieza es el **mismo punto de referencia que usa su función de kit**. Casi
  siempre `where`: el centro de la base, sobre el suelo (`z = 0` en Blender). Si la función usa
  otro (por ejemplo, el centro de una alfombra o de un seto), se anota en el registro.
- Aplicar ubicación, rotación y escala (Ctrl + A) antes de exportar. Sin escalas negativas.
- El giro y la posición en el escenario los pone el kit (`yaw_degrees`, `batch.xform`): el modelo
  se guarda sin girar.

## Geometría

- Estilo low-poly facetado: **Shade Flat**. Sin subdivisión al exportar (los modificadores se
  aplican con `export_apply = True`).
- Normales hacia fuera (Mesh → Normals → Recalculate Outside).
- La caja del modelo debe coincidir con la de la pieza procedural con **±5 cm**, salvo que el
  cambio sea intencionado; en ese caso la colisión se cambia en otro commit, con su prueba.
- Presupuesto de triángulos (orientativo; la cifra real de cada pieza procedural está en
  [01-inventario.md](01-inventario.md)): atrezo pequeño ≤ 300, mueble ≤ 800, pieza grande
  (coche, quiosco, chimenea) ≤ 1.500, personaje completo ≤ 1.500, fachada ≤ 3.000.
- Sin luces, cámaras, colisiones, esqueletos ni animaciones en el GLB (salvo decisión explícita en
  una fase posterior).

## Materiales y color

- **Sin texturas** mientras la pieza se fusione en el lote. El color va por vértice, en el dominio
  de **esquina de cara** (cada cara de un color, como hoy).
- El juego ignora las propiedades del material: sólo lee su **nombre** para saber la capa
  (`vs_brillo` → capa de brillo). Las propiedades sólo sirven para verlo bien en Blender.
- Colores de la paleta compartida (`scripts/world/palette.gd`). Antes del primer modelo editado
  a mano hay que cerrar el riesgo R4 (sRGB o lineal) con la medida del prototipo.

| Nombre | Hex | Nombre | Hex |
| --- | --- | --- | --- |
| `INK` | `#0b0e14` | `WOOD` | `#4a3426` |
| `NIGHT` | `#141a26` | `WOOD_DARK` | `#2e2019` |
| `SLATE` | `#2a3242` | `WOOD_LIGHT` | `#7a5a3e` |
| `STEEL` | `#46536a` | `ROOF` | `#262b36` |
| `FOG` | `#7f8ca3` | `ROOF_RED` | `#4c2b2a` |
| `STONE` | `#565a63` | `IRON` | `#1d2027` |
| `STONE_DARK` | `#3a3d45` | `FOLIAGE` | `#243226` |
| `STONE_LIGHT` | `#7a7c82` | `FOLIAGE_LIGHT` | `#32443a` |
| `PLASTER` | `#6d6a66` | `AMBER` | `#e8a33d` |
| `PLASTER_WARM` | `#7d6f5e` | `AMBER_SOFT` | `#f4c67a` |
| `BRICK` | `#5c3a34` | `WINDOW_WARM` | `#ffc36b` |
| `WINE` | `#7a2a2a` | `CARPET` | `#5a2326` |
| `PAPER` | `#d9cbaa` | | |

Los kits usan además `darkened()`/`lightened()` sobre estos colores; la exportación de referencia
(vía A) los trae ya calculados.

## Exportación desde Blender

Siempre con `blender/scripts/exportar_glb.py`, nunca a mano desde el menú, para que las opciones
sean las mismas. Opciones fijas (nombres comprobados en Blender 5.3.0, exportador 5.3.43):

```python
bpy.ops.export_scene.gltf(
    filepath=destino,                 # new-game-project/assets/modelos/<cat>/<id>.glb
    export_format="GLB",
    use_active_collection=True,       # la colección «Exportar», activa
    use_active_collection_with_nested=True,
    export_yup=True,
    export_apply=True,                # por defecto es False
    export_normals=True,
    export_vertex_color="ACTIVE",     # por defecto es "MATERIAL"
    export_all_vertex_colors=False,
    export_materials="EXPORT",
    export_image_format="NONE",
    export_lights=False,
    export_cameras=False,
    export_extras=False,
    export_animations=False,
    export_skins=False,
    export_morph=False,
)
```

Antes de exportar, el script recodifica en memoria el atributo `Color` de lineal a sRGB (R4: el
GLB lleva el color tal como lo usa el lote). El `.blend` no se guarda.

El script imprime y guarda en `blender/registro/<id>.json`: versión de Blender y del exportador,
fecha, `.blend` de origen, número de triángulos, caja y opciones usadas. Si una opción no existe
en la versión instalada, el script se detiene en lugar de exportar con otra configuración.

## Importación en Godot

- El `.glb` y su `.glb.import` se confirman juntos.
- Importación sin LOD, sin mallas de sombra y sin tangentes (`meshes/generate_lods`,
  `meshes/create_shadow_meshes` y `meshes/ensure_tangents` a `false`): el juego lee los
  triángulos y los fusiona en el lote. `blender/scripts/migrar.py` ajusta los `.import` nuevos y
  `validar_modelos` avisa si falta.
- No se edita la escena importada ni se le añaden scripts. Si alguna vez hace falta, escena
  heredada aparte.
- Los modelos sólo se cargan a través de `ModelCatalog` (una tabla con todas las rutas): así hay
  un único sitio que revisar al renombrar o mover un archivo.

## Git

- Antes del primer binario, en `.gitattributes` de la raíz: `*.glb binary` y `*.blend binary`.
- En `.gitignore` de la raíz: `*.blend1`, `*.blend@` y `blender/**/__pycache__/`.
- Conventional Commits en español, sin líneas de coautoría: `feat(modelos): …`,
  `chore(blender): …`, `test(modelos): …`, `docs(blender): …`.
- Una pieza por commit (fuente, GLB, código y prueba de esa pieza). `git add` con rutas
  concretas; nunca `project.godot` ni `main_menu.tscn` si sólo traen ruido del editor.

## Registro de recursos

Cada modelo nuevo se añade a `docs/RECURSOS.md` con su origen («propio, hecho en Blender 5.3 a
partir de `PropsKit.mailbox`»), su `.blend` y su GLB.

## Contrato de compatibilidad de los modelos (sesión 3)

Lo que debe cumplir un modelo para que `ModelCatalog` lo use, y lo que garantiza el juego a cambio.
Las comprobaciones automáticas están entre paréntesis.

### Identificador y registro

- Cada modelo tiene un **id estable** en `ModelCatalog.MODELS` (`snake_case`, sin tildes ni eñes):
  es el nombre de su GLB (`assets/modelos/<categoría>/<id>.glb`), de su `.blend`
  (`blender/fuentes/<categoría>/<id>.blend`), de su referencia y de su registro.
- La entrada lleva `categoria`, `objeto` (nombre del objeto de Blender) y `fiel` (ver abajo)
  (`validar_modelos`, `test_registered_models_are_complete`).
- Los ids de modelo **no se guardan en las partidas** ni aparecen en los datos (`data/*.json`):
  el guardado sigue usando sólo ids de escenario, de pista, de NPC y la posición. Renombrar un
  modelo no rompe ninguna partida.

### Objetos, variantes y pivote

- Un GLB contiene **un objeto de primer nivel por variante**: `<objeto>` para la pieza sin
  variantes y `<objeto>_<variante>` para cada medida o forma (`Mesa_160x76x90`, `Caja_90`).
  La clave de variante la elige el kit con `ModelCatalog.size_key` o un texto fijo, y debe
  incluir **todos** los parámetros que cambian la forma (la captura falla si dos usos de la
  misma variante no coinciden).
- El **origen** de cada objeto es el punto de referencia que usa la función del kit (`where`,
  normalmente el centro de la base sobre el suelo). La posición del objeto en el `.blend` **no se
  exporta al juego**: sólo sirve para repartir las variantes y verlas a la vez.
- Giro y escala aplicados (Ctrl + A); sin escalas negativas (`exportar_glb.py` se niega).
- Jerarquías: se admiten objetos hijos (se respeta su transformación relativa), pero no luces,
  cámaras, esqueletos ni animaciones (`validar_modelos`).
- Una variante que el GLB no tenga se dibuja con el código procedural, con un aviso: añadir una
  medida nueva en el juego nunca rompe el escenario.

### Ejes, escala y orientación

- 1 unidad = 1 m. Blender Z arriba; el exportador convierte a Y arriba (`export_yup`).
- Atrezo, mobiliario y escenario: frente hacia **−Y** en Blender (+Z en Godot).
- Personajes: frente hacia **+Y** en Blender (−Z en Godot), sin nodos girados de por medio
  (invertirían `set_head_tilt`). Ver la sección de personajes en
  [04-arquitectura.md](04-arquitectura.md#personajes-conservar-la-interfaz-de-charactermodel).
- El giro y la posición en el escenario los pone el kit: el modelo se guarda sin girar.

### Materiales y color

| Material | Capa del lote | Color de vértice |
| --- | --- | --- |
| `vs_opaco` | opaca (`vertex_lit`) | color de la pieza |
| `vs_brillo` | brillo (sin sombreado) | color emitido |
| `vs_suelo` | suelo (empedrado) | tinte del empedrado |
| `vs_tinte` | opaca | **factor** que se multiplica por el color que pasa el kit (`tint`): blanco = el color tal cual |

- El juego sólo lee el **nombre** del material. Cualquier otro nombre es un error
  (`validar_modelos`, `exportar_glb.py`).
- Sin texturas: color por vértice en el dominio de esquina de cara (cada cara de un color).
- El `.blend` guarda el color en lineal (se ve bien en Blender); el GLB lo lleva en sRGB (R4).
- La variación de tono por cara la añade el juego al fusionar el modelo: no se pinta en Blender.

### Colisiones, luces, rótulos e interacciones

- **Nunca** van en el GLB. Se quedan en el kit, fuera del `Callable` procedural de
  `ModelCatalog.draw` (la captura rechaza un `Callable` que registre colisiones o nodos).
- La colección `Referencia` del `.blend` enseña las cajas de colisión del juego para modelar
  alrededor; no se exporta.
- La caja del modelo debe quedar a ±5 cm de la de la pieza procedural (`validar_modelos`); si
  un modelo crece, la colisión se cambia en el kit, en otro commit y con su prueba.

### Fidelidad

- `fiel: true`: el GLB reproduce exactamente la pieza procedural. `test_models` compara los
  escenarios con modelos y sin ellos polígono a polígono.
- `fiel: false`: el modelo se ha retocado en Blender. Las pruebas comparan su caja y las
  colisiones del escenario, no los polígonos. Cambiar a `false` va en el mismo commit que el
  retoque, con capturas antes y después.

### Versiones

- `blender/registro/<id>.json` guarda la versión de Blender y del exportador, la fecha, los
  triángulos y la caja de cada objeto, las opciones y el `sha256` del GLB. `validar_modelos`
  avisa si el GLB no es el que escribió `exportar_glb.py`.
- El `.blend` es la fuente: `importar_referencia.py` no lo sobrescribe sin `--forzar`.

### Animación

- Atrezo y escenario: sin animación (geometría estática fusionada en el lote).
- Personajes: la animación sigue siendo procedural en `CharacterModel`; el GLB sólo aporta las
  mallas de los seis pivotes (sesión 7).
