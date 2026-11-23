# 1. Inventario de modelos generados por código

Estado de `main` en `85b9f82` (2026-11-22). Las cifras de triángulos, cajas y colisiones se han
**medido** construyendo cada pieza aislada en Godot 4.7.2 (escena temporal fuera del
repositorio); los usos se han contado en `scripts/world/locations/*.gd`.

## Cómo se genera la geometría

| Archivo | Qué hace |
| --- | --- |
| `scripts/world/mesh_batcher.gd` (`MeshBatcher`) | Acumula primitivas facetadas (`face`, `box`, `cylinder`, `sphere`, `gable`, `pyramid`, `ground`) con color de vértice y una variación de tono por cara; las fusiona en una malla por capa (`OPAQUE`, `GLOW`, `GROUND`) |
| `scripts/world/material_library.gd` (`MaterialLibrary`) | Tres materiales compartidos: `vertex_lit` (color de vértice sRGB, rugosidad 0,82), `glow` (`assets/shaders/glow_vertex.gdshader`, sin sombreado) y `cobblestone` (empedrado procedural en espacio de mundo); más el del marcador |
| `scripts/world/palette.gd` (`Palette`) | 25 colores con nombre (tabla en [05-estandares.md](05-estandares.md#materiales-y-color)) |
| `scripts/world/location_base.gd` (`LocationBase`) | Base de los escenarios: lote `batch`, `StaticBody3D` `Colisiones`, puntos de aparición, marcadores, huecos de paso, tipos de suelo, luces, rótulos, interactivos, navegación |
| `scripts/world/building_kit.gd` (`BuildingKit`) | Arquitectura en un sistema local de fachada (`begin`/`end` fijan `batch.xform`) |
| `scripts/world/props_kit.gd` (`PropsKit`) | Atrezo de exteriores |
| `scripts/world/interior_kit.gd` (`InteriorKit`) | Suelos, paredes y mobiliario de interiores (corte de casa de muñecas) |
| `scripts/world/locations/*.gd` | Cada escenario: llama a los kits y añade piezas propias con `batch.*` |
| `scripts/actors/character_model.gd` (`CharacterModel`) | Detective y NPC: seis pivotes con malla propia y animación procedural |
| `scripts/world/interaction_marker.gd` (`InteractionMarker`) | Rombo flotante sobre lo interactivo |

No hay ni un solo modelo 3D externo en el proyecto (`assets/` sólo contiene audio, shaders y SVG).

## Escenarios

| Escenario | Escena | Triángulos (opaco / brillo / suelo) | Colisiones | Luces (con sombra) | Rótulos | Interactivos | Apariciones / marcadores / huecos | Horneado de navegación |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plaza Mayor | `scenes/world/locations/plaza.tscn` | 6.361 / 536 / 12 | 52 | 13 (4) | 8 | 4 salidas, 1 pista | 5 / 9 / 0 | 19,8 ms |
| Café La Luna | `cafe.tscn` | 3.920 / 204 / — | 43 | 7 (1) | 2 | 1 salida, cama | 2 / 10 / 3 | 6,9 ms |
| Mansión Valdés | `mansion.tscn` | 6.752 / 224 / — | 44 | 8 (3) | 0 | 1 salida, 9 pistas | 1 / 10 / 8 | 7,9 ms |
| Archivo municipal | `archivo.tscn` | 13.082 / 120 / — | 25 | 4 (1) | 0 | 1 salida | 1 / 4 / 1 | 5,6 ms |
| Estación | `estacion.tscn` | 2.394 / 224 / 6 | 23 | 6 (1) | 3 | 1 salida | 2 / 3 / 0 | 8,4 ms |
| Campo de pruebas | `test_ground.tscn` | 60 / — / — | 9 | 1 (1) | 0 | 1 poste | 1 / 0 / 0 | 17,6 ms |

Cada escenario son 2 o 3 `MeshInstance3D` (`GeometriaOpaque`, `GeometriaGlow`, `GeometriaGround`).
El archivo pesa el doble que los demás por sus ocho estanterías (1.356 triángulos cada una, un
prisma por libro).

## Leyenda de la evaluación

- **Exp. directa:** viabilidad de exportarla tal cual desde Godot (vía A). *Alta* = medidas fijas;
  *Media* = pocas variantes; *Baja* = medidas por parámetro en cada uso.
- **Blender:** conveniencia de llevarla a Blender. *Sí* = gana con un modelo editable;
  *Variantes* = mejor con un script de Blender que genere cada medida (vía B); *No* = se queda
  procedural.
- **Riesgo:** de romper algo al migrarla. **Prio.:** sesión del plan en que se migra
  ([06-plan-migracion.md](06-plan-migracion.md)); «—» = no se migra.
- Toda pieza con colisión participa en la **navegación** a través de esa colisión (no de su malla).
  Ninguna pieza de escenario interviene en animaciones ni en el guardado.

## `PropsKit` (atrezo de exteriores)

| Función | Uso | Tri. (capas) | Caja (m) | Colisión | Luz / rótulo | Narrativa / notas | Exp. directa | Blender | Riesgo | Prio. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mailbox` | Plaza ×1 | 68 (opaco) | 0,60 × 1,24 × 0,60 | 0,5 × 1,2 × 0,5 | — | Ninguna; no aparece en datos, mapa ni diálogos | Alta | Sí | **Mínimo** | **Migrado (sesión 2)**: `assets/modelos/atrezo/buzon.glb` |
| `barrel` | Plaza, estación, café ×1 | 84 | 0,76 × 0,90 × 0,76 | 0,65 × 0,9 × 0,65 | — | — | Alta | Sí | Bajo | **Migrado (sesión 4)**: `barril` |
| `crate(size, yaw)` | Plaza ×2, estación ×2, café ×1 (0,7 y 0,9) | 24 + 12 | 0,93 × 0,90 × 0,93 (0,9) | `solid` del tamaño | — | Escala uniforme | Alta | Sí | Bajo | **Migrado (sesión 4)**: `caja` |
| `bench(yaw)` | Plaza ×3, estación ×2 | 108 | 1,80 × 0,91 × 0,46 | 1,9 × 0,9 × 0,5 | — | Puesto «banco_anden» cerca | Alta | Sí | Bajo | 3 |
| `street_lamp(shadows)` | Plaza ×6 (4 con sombra), estación ×4 (1) | 72 + 20 brillo | 0,52 × 3,98 × 0,45 | 0,3 × 3,0 × 0,3 | `OmniLight3D` 5,0 / 9,5 m | La luz se queda en el kit | Alta | Sí | Bajo | 3 |
| `cafe_table` | Plaza ×2, café ×5 | 136 | 1,64 × 0,76 × 0,98 | 3 cajas (mesa y dos asientos) | — | Puestos «mesa_*» del café cerca | Alta | Sí | Bajo | **Migrado (sesión 4)**: `mesa_cafe` |
| `signpost(labels)` | Plaza ×1 (3 rótulos), estación ×1 (1) | 56 | 1,90 × 2,70 × 0,15 | 0,2 × 2,4 × 0,2 | `Label3D` por flecha | Tableros por número de rótulos | Media | Sí | Bajo | 3 |
| `newsstand(yaw)` | Plaza ×1 | 192 | 3,00 × 2,27 × 2,00 | `solid` 2,6 × 2,1 × 1,5 | «PRENSA» | **Pista `periodico_aniversario` al lado** | Alta | Sí | Medio | 3 |
| `car(yaw)` | Plaza ×1 | 180 + 72 brillo | 1,97 × 1,37 × 4,26 | 1,9 × 1,4 × 4,2 | — | Faros en capa de brillo | Alta | Sí (remodelar) | Bajo | 3 |
| `tree(height, autumn)` | Plaza ×4 (2 de otoño) | 164 | 2,62 × 4,07 × 2,22 (4 m) | 0,4 × 2,0 × 0,4 | — | Altura por parámetro; artístico | Media | Sí (a mano) | Bajo | 7 |
| `hedge(center, size)` | Plaza ×1, estación ×1 | 272 (15 m) | según `size` | `solid` de `size` | — | Borde que evita salir del escenario | Baja | No | Medio | — |
| `low_wall(center, size)` | Plaza ×2, estación ×2 | 24 | según `size` | `solid` de `size` | — | Borde cercano a la cámara | Baja | No | Alto | — |

## `InteriorKit` (interiores)

| Función | Uso | Tri. (capas) | Caja (m) | Colisión | Luz | Narrativa / notas | Exp. directa | Blender | Riesgo | Prio. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `chair(yaw, color)` | Café ×3, mansión ×2, archivo ×3 | 72 | 0,50 × 1,11 × 0,50 | 0,5 × 1,0 × 0,5 | — | Color por parámetro (3 colores) | Alta | Sí | Bajo | **Migrado (sesión 4)**: `silla` |
| `armchair(yaw, color)` | Mansión ×2 | 48 | 1,02 × 1,02 × 0,92 | 1,0 × 1,1 × 0,95 | — | Puesto «salon_este» cerca | Alta | Sí | Bajo | **Migrado (sesión 4)**: `sillon` |
| `plant` | Café ×1, mansión ×3 | 60 | 0,84 × 1,26 × 0,73 | 0,5 × 0,8 × 0,5 | — | — | Alta | Sí | Bajo | **Migrado (sesión 4)**: `planta` |
| `floor_lamp(energy)` | Café ×1, mansión ×2, archivo ×1 | 36 + 24 brillo | 0,61 × 1,92 × 0,62 | 0,28 × 1,2 × 0,28 | `OmniLight3D` | La luz se queda en el kit | Alta | Sí | Bajo | **Migrado (sesión 4)**: `lampara_pie` |
| `ceiling_lamp(energy, range, shadows)` | Café ×6, mansión ×5, archivo ×3 | 12 + 28 brillo | 0,68 × 0,90 × 0,68 | — | `OmniLight3D` (sombra en 5) | Sin colisión | Alta | Sí | Bajo | **Migrado (sesión 4)**: `lampara_techo` |
| `filing_cabinet(yaw)` | Archivo ×4 | 108 | 0,90 × 1,84 × 0,64 | `solid` 0,9 × 1,8 × 0,6 | — | Puesto «ficheros» de Hilario | Alta | Sí | Bajo | **Migrado (sesión 4)**: `archivador` |
| `grandfather_clock(yaw)` | Mansión ×1 (vestíbulo) | 84 | 0,70 × 2,40 × 0,48 | `solid` 0,6 × 2,2 × 0,4 | — | **Temático** (el caso gira en torno a relojes) | Alta | Sí | Bajo | **Migrado (sesión 4)**: `reloj_pie` |
| `back_window(size, yaw)` | Café ×1, mansión ×2, archivo ×1 | 36 + 12 brillo | 1,70 × 2,30 × 0,12 (1,5 × 2,1) | — | — | Cuatro medidas | Media | Variantes | Bajo | **Migrado (sesión 4)**: `ventana_interior` |
| `painting(size, color, yaw)` | Mansión ×1, archivo ×1 | 24 | 1,84 × 1,14 × 0,07 | — | — | Lienzo de color por parámetro | Media | Variantes | Bajo | **Migrado (sesión 4)**: `cuadro` |
| `bed(yaw, blanket, size)` | Café ×1 (1,6 × 2,2), mansión ×2 (2,0 × 2,3; 1,2 × 2,0) | 60 | 1,50 × 1,20 × 2,15 (1,5 × 2,1) | 0,8 m de alto | — | **Cama del café: `RestPoint` y aparición «cama»** | Media | Variantes | Medio | **Migrado (sesión 4)**: `cama` |
| `dresser(width, mirror, yaw)` | Café ×1, mansión ×3 (1,4; 1,6; 1,8; 2,0 con espejo) | 48 / 72 | 1,46 × 0,88 × 0,54 (1,4) | `solid` ancho × 0,84 × 0,5 | — | **Office: pista `foto_clara`; cuarto de Lucía: recolocada el 2026-11-22** | Media | Variantes | Medio | **Migrado (sesión 4)**: `comoda` |
| `bookshelf(width, height, yaw)` | Mansión ×3, archivo ×8 (4 medidas) | 1.356 (3,2 m) | 3,28 × 2,68 × 0,45 | ancho × alto × 0,45 | — | Una caja por libro: buena candidata a reducir triángulos | Media | Variantes | Bajo | **Migrado (sesión 4)**: `estanteria` |
| `sofa(yaw, color, length)` | Mansión ×1 | 48 | 2,60 × 1,01 × 0,97 | 2,6 × 1,1 × 0,98 | — | Puesto «salon_sofa» cerca | Alta | Sí | Bajo | **Migrado (sesión 4)**: `sofa` |
| `desk(size)` | Mansión ×1 (despacho) | 60 | 2,60 × 0,84 × 1,20 | `solid` del tamaño | — | **Pista `copa_lavada` encima (y = 0,6)** | Alta | Sí | Medio | **Migrado (sesión 4)**: `escritorio` |
| `table(size, color)` | Café ×1, mansión ×4, archivo ×1 (6 medidas) | 60 | según `size` | `size` | — | **Mesas de `carta_amor`, `lista_invitados`, `libro_bodega`** | Baja | Variantes | Medio | **Migrado (sesión 4)**: `mesa` |
| `fireplace(width)` | Mansión ×1 | 36 + 12 brillo | 2,80 × 2,10 × 0,80 | `solid` 2,4 × 2,0 × 0,6 | `OmniLight3D` | Puesto «salon_chimenea» | Alta | Sí | Bajo | **Migrado (sesión 4)**: `chimenea` |
| `rug(center, size, color)` | Café ×1, mansión ×4, archivo ×1 | 36 | según `size` | — | — | `register_surface("alfombra")` para los pasos | Baja | No | Medio | — |
| `plank_floor`, `tile_floor` | Todos los interiores | — | por escenario | — | — | `register_surface` (madera, baldosa) | Baja | No | Alto | — |
| `wall(from, to, height, gaps)` | Todos los interiores (19 llamadas: café 6, mansión 9, archivo 4) | — | por escenario | 3 m de alto por tramo | — | `add_doorway` por hueco; corte de casa de muñecas | Baja | No | **Alto** | — |
| `seal_street_door` | Café, mansión, archivo | — | — | barrera invisible | — | Evita salir por la puerta de la calle | — | No | **Alto** | — |

## `BuildingKit` (arquitectura)

| Función | Uso | Tri. (capas) | Caja (m) | Colisión | Narrativa / notas | Exp. directa | Blender | Riesgo | Prio. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `body(width, height, depth, wall, roof)` | Plaza ×4 (café, casa estrecha, archivo, banco), estación ×1 | 42 | 11,5 × 8,7 × 7,7 (café) | `solid` ancho × alto × fondo | **Huella copiada en el mapa del pueblo y comprobada por `test_map`** | Baja | Sí, sin cambiar la huella | Alto | 6 |
| `window(x, y, w, h, lit, shutters)` | Plaza ×32 (directas y en rejillas), estación ×2 | 72 + 12 brillo | 1,95 × 1,66 × 0,21 (1,0 × 1,4) | — | Encendida o no; contraventanas | Media | Variantes | Bajo | 6 |
| `window_grid` | Plaza ×3 | — | — | — | Reparte `window` | — | — | — | 6 |
| `door(x, w, h, color)` | Plaza ×2 (café, archivo) | 48 + 12 brillo | 2,10 × 2,70 × 0,76 | — | **Junto a `LocationExit`** (las salidas siguen en el escenario) | Media | Sí | Medio | 6 |
| `awning(x, y, w, depth)` | Plaza ×1 (café) | 320 | 10,0 × 0,81 × 1,62 | — | Toldo a rayas | Media | Sí | Bajo | 6 |
| `chimney(where)` | Plaza ×1 | 24 | 0,85 × 1,31 × 0,85 | — | — | Alta | Sí | Bajo | 6 |
| `column(base, height)` | Plaza ×4 (pórtico del archivo) | 52 | 0,70 × 4,10 × 0,70 | 0,5 × alto × 0,5 | — | Alta | Sí | Bajo | 6 |

## Piezas propias de cada escenario (código `batch.*` dentro del escenario)

| Escenario | Pieza | Colisión | Narrativa / notas | Blender | Riesgo | Prio. |
| --- | --- | --- | --- | --- | --- | --- |
| Plaza | Suelos, aceras y bordillos | suelo de 90 × 90 m | Empedrado por shader | No | Alto | — |
| Plaza | Escaparate, rótulo y toldo del café | — | «CAFÉ LA LUNA», salida al café | Sí | Medio | 6 |
| Plaza | Pórtico, frontón y torre del reloj del archivo | columnas | Esfera del reloj en capa de brillo; salida con cierre el domingo | Sí | Medio | 6 |
| Plaza | Mansión de fondo, tapia, pilares, verja | tapia, pilares, verja (3,9 × 3,0 m) | «MANSIÓN VALDÉS»; salida cerrada hasta `llamada_atendida` | Sí | Medio | 6 |
| Plaza | Fuente | dos cajas giradas 45° | Ronda del sargento alrededor (4 marcadores) | Sí | Bajo | 6 |
| Plaza | Muros invisibles del perímetro | 4 cajas | — | No | Alto | — |
| Café | Barra, taburetes, botellero, espejo | barra `solid` + 5 taburetes | Puestos «barra*» detrás; 78 cilindros de botellas | Sí | Medio | 6 |
| Café | Teléfono sobre la barra | — | Referencia narrativa (desde él llamó el sargento); hoy decorativo | Sí | Bajo | 6 |
| Café | Mesita de la pensión, papeles de la trastienda | caja | — | Sí | Bajo | 6 |
| Estación | Vías, traviesas, raíles, bordillo | bordillo (90 m) | El bordillo impide bajar a las vías | Sí (sin la colisión) | Medio | 6 |
| Estación | Tren (locomotora y vagón) | — | Llegada del detective; ventanas en brillo | Sí (a mano) | Bajo | 6 |
| Estación | Marquesina, reloj de andén | 3 postes + reloj | — | Sí | Bajo | 6 |
| Mansión | Reloj caído y cristales del despacho | — | **Pista `reloj_despacho`** | Sí, sin moverlo | Medio | 6 |
| Mansión | Huellas de betún | — | **Pista `huellas_betun`** | Sí, sin moverlas | Medio | 6 |
| Mansión | Objetos sobre muebles (copa, tintero, papel, libro, foto) | — | **Pistas `copa_lavada`, `carta_amor`, `lista_invitados`, `libro_bodega`, `foto_clara`** | Sí, sin moverlos | Medio | 6 |
| Mansión | Tablero de llaves del office | — | **Pista `llave_reloj`** | Sí, sin moverlo | Medio | 6 |
| Archivo | Mostrador y papeles | mostrador `solid` | Puesto «mostrador» de Hilario | Sí | Bajo | 6 |
| Campo de pruebas | Losa y bloques | `solid` | Sólo para pruebas | No | — | — |

## Personajes (`CharacterModel`)

Estructura común: seis pivotes (`PiernaIzq`, `PiernaDer`, `Torso`, `BrazoIzq`, `BrazoDer`,
`Cabeza`), cada uno con su `MeshBatcher` y una `MeshInstance3D` (6 llamadas de dibujado por
personaje), sólo capa opaca. Altura base 1,0 escalada por `height`. Miran a −Z. Cápsula de
colisión de 0,3 × 1,8 m en la escena (`npc.tscn`, `player.tscn`), independiente del modelo.

| Personaje | Aspecto (`characters.json` o `PlayerController.LOOK`) | Triángulos | Caja (m) | Dónde (`schedules.json`) |
| --- | --- | --- | --- | --- |
| Detective (Mateo Ibarra) | Abrigo largo, fedora, bufanda | 390 | 0,68 × 1,98 × 0,59 | Todos |
| Elena Valdés | Vestido, moño, perlas, 0,96 | 446 | 0,84 × 1,98 × 0,86 | Mansión, estación |
| Marcos Valdés | Engominado, corbata, cigarrillo | 294 | 0,67 × 1,90 × 0,55 | Mansión, café |
| Lucía Ferrer | Vestido, trenza, cofia, delantal, 0,93 | 330 | 0,84 × 1,90 × 0,86 | Mansión, plaza |
| Anselmo Roca | Frac, calvo, pajarita, bandeja | 292 | 0,89 × 1,88 × 0,63 | Mansión |
| Irene Vidal | Vestido, pelo largo, pamela, 0,98 | 366 | 0,86 × 1,94 × 0,86 | Mansión, café, archivo |
| Sargento Bruno Ortega | Quepis, bigote, placa, 1,04 | 338 | 0,67 × 1,95 × 0,54 | Café, plaza, mansión |
| Rosa Mena | Vestido, rizos, delantal, 0,94 | 396 | 0,84 × 1,93 × 0,86 | Café |
| Eusebio Pardo | Gorra, bigote, gafas | 322 | 0,67 × 1,91 × 0,54 | Estación |
| Don Hilario Luna | Calvo, pajarita, gafas, 0,95 | 276 | 0,67 × 1,88 × 0,55 | Archivo, plaza |

Variantes que debe cubrir un modelo de Blender: peinados `short`, `slick`, `bun`, `long`, `braid`,
`curly`, `bald`; sombreros `none`, `fedora`, `wide_brim`, `kepi`, `cap`, `maid_cap`; largo de
abrigo `short`, `long`, `tails`; `dress`; extras `tray`, `cigarette`, `apron`, `scarf`, `pearls`,
`bowtie`, `tie`, `badge`, `mustache`, `glasses`.

Evaluación: exportación directa **media** (diez combinaciones distintas de un mismo código);
Blender **sí**, con un cuerpo base y piezas opcionales (vía B, luego retoque a mano); riesgo
**alto** (interfaz usada por NPC, jugador, pasos y pruebas); prioridad **5**.

## Otros generados por código que no se migran

| Elemento | Archivo | Motivo |
| --- | --- | --- |
| Marcador de interacción (rombo) | `scripts/world/interaction_marker.gd` | Es interfaz, con material propio sin profundidad |
| Rótulos | `LocationBase.add_sign` (`Label3D`) | Texto editable con la letra del tema |
| Lluvia | `scripts/world/rain_effect.gd` | Partículas |
| Entorno, luna, niebla | `scripts/world/atmosphere.gd` | Iluminación |
| Posprocesado y filtros | `scripts/world/post_fx.gd`, `noir_post.gdshader` | Efecto de pantalla |

## Referencias narrativas

Elementos con los que el modelo de alrededor no debe moverse ni cambiar de tamaño sin revisar la
interacción:

| Interactivo | Escenario | Punto | Pieza junto a la que está |
| --- | --- | --- | --- |
| Pista `periodico_aniversario` | Plaza | (−5,2; 0; 10,6) | Quiosco de prensa (−6,0; 0; 10,6), girado 90° |
| Pista `reloj_despacho` | Mansión | (9,3; 0; −3,9) | Reloj caído y cristales (geometría propia) |
| Pista `copa_lavada` | Mansión | (12,0; 0,6; −6,0) | Escritorio (11,0; 0; −6,4) y copa dibujada en (12,0; 0,84; −6,3) |
| Pista `huellas_betun` | Mansión | (11,2; 0; −2,2) | Huellas dibujadas hacia la puerta de servicio |
| Pista `billete_tren` | Mansión | (−10,6; 0; −7,8) | Alcoba: cómoda con espejo (−12,0; 0; −8,6) y silla (−12,0; 0; −7,4) |
| Pista `carta_amor` | Mansión | (−10,6; 0; 4,6) | Mesita del cuarto de Lucía (−11,4; 0; 4,6) y tintero |
| Pista `lista_invitados` | Mansión | (3,2; 0; 6,6) | Mesa del vestíbulo (3,8; 0; 7,6) y papel |
| Pista `foto_clara` | Mansión | (8,6; 0; 0,5) | Cómoda del office (8,6; 0; −0,6) y foto |
| Pista `libro_bodega` | Mansión | (7,7; 0; 6,2) | Mesa del office (8,2; 0; 7,4) y libro |
| Pista `llave_reloj` | Mansión | (12,9; 0; 0,3) | Tablero de llaves (12,9; 1,0; −0,86) |
| `RestPoint` y aparición «cama» | Café | (−12,8; 0; −2,2) | Cama de la pensión (−12,8; 0; −3,6) |
| Salidas (`LocationExit`) | Todos | — | Puertas de `BuildingKit.door`, verja de la mansión, huecos de pared |
| Reloj de pie | Mansión | (−4,4; 0; 7,6) | Temático, sin interacción |
| Teléfono del café | Café | (3,9; 1,22; −3,9) | Citado en la historia; sin interacción |
