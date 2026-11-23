# 5. Estándares para archivos de Blender y Godot

Reglas que deben cumplir todos los modelos. Si una regla no se puede cumplir para una pieza, se
anota la excepción en su registro y en el commit.

## Carpetas

```text
VillaSombria/                          raíz del repositorio
├── blender/                           fuera del proyecto Godot (Godot no lo ve)
│   ├── fuentes/<categoría>/<id>.blend      fuente editable de cada modelo
│   ├── referencias/<id>.glb                exportación de la pieza procedural (vía A)
│   ├── referencias/<id>_colisiones.json    colisiones de la pieza procedural
│   ├── registro/<id>.json                  registro de la última exportación
│   └── scripts/                            importar_referencia.py, exportar_glb.py, construir_<id>.py
└── new-game-project/
    ├── assets/modelos/<categoría>/<id>.glb (+ .glb.import)   lo que carga el juego
    └── tools/modelos/                      escena de exportación de referencias (vía A)
```

Categorías: `atrezo` (exteriores de `PropsKit`), `mobiliario` (`InteriorKit`), `arquitectura`
(`BuildingKit` y piezas propias de un escenario), `personajes`.

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
)
```

El script imprime y guarda en `blender/registro/<id>.json`: versión de Blender y del exportador,
fecha, `.blend` de origen, número de triángulos, caja y opciones usadas. Si una opción no existe
en la versión instalada, el script se detiene en lugar de exportar con otra configuración.

## Importación en Godot

- El `.glb` y su `.glb.import` se confirman juntos.
- Opciones de importación por defecto; el juego no usa los LOD ni las mallas de sombra porque lee
  los triángulos y los fusiona en el lote.
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
