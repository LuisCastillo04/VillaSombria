# 8. Sesión 2: prototipo del buzón e instrucciones para continuar

## Punto de partida

| Dato | Valor |
| --- | --- |
| Rama de partida | `feature/blender-auditoria` |
| Commit de partida | El último de esa rama (el que añade este índice y el punto de partida; ver [README.md](README.md#punto-de-partida-de-la-sesión-2)) |
| Rama nueva | `feature/blender-prototipo-buzon` |
| Base del código del juego | `85b9f82` (`main` tras el PR #16). La sesión 1 sólo añadió documentación |

Comprobar antes de crear la rama:

```bash
git fetch --all --prune
git log --oneline -8 feature/blender-auditoria   # los commits docs(blender) encima de 85b9f82
git diff --stat 85b9f82 feature/blender-auditoria  # sólo docs/blender/ y docs/RECURSOS.md
git status                                         # project.godot y main_menu.tscn: ruido del editor, no confirmar
git switch -c feature/blender-prototipo-buzon feature/blender-auditoria
```

Si el propietario fusionó la rama de la auditoría en `main` y lo indica, partir de `main`.
Si `main` avanzó con otros cambios de código, partir de la rama de auditoría y avisar.

## Por qué el buzón

`PropsKit.mailbox` (`scripts/world/props_kit.gd:140`) es el objeto más seguro del juego para
estrenar el proceso:

- Un único uso: `plaza.gd:204`, en (−2,2; 0; −12,1), en la acera junto a la terraza del café.
- Ninguna referencia en datos, mapa, diálogos ni pruebas (comprobado con `grep`).
- Sin luz, sin rótulo, sin capa de brillo, sin giro y sin interactivo cerca (el puesto «terraza»
  queda a 2,5 m).
- Tamaño fijo: 68 triángulos, caja de 0,60 × 1,24 × 0,60 m; colisión independiente de
  0,5 × 1,2 × 0,5 m a 0,6 m de altura.
- Tiene frente: la ranura está en +Z local, así que el prototipo comprueba también la orientación.
- Cerca del punto de aparición «desde_cafe»: fácil de encuadrar en una captura.

Descartados para el prototipo: el barril y la caja (tres y cinco usos en tres escenarios: más
superficie de fallo), la planta (dentro de la mansión, junto a pistas) y la farola (luz y brillo).

## Procedimiento

Cada paso termina con las pruebas en verde y un commit pequeño. Las rutas son relativas a la raíz
del repositorio salvo que se indique `new-game-project/`.

### Paso 1. Capturas y medidas «antes»

Desde `new-game-project/`, con ventana (Godot en la ruta de [07-linea-base.md](07-linea-base.md)):

```text
godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=<scratchpad>/buzon_antes.png --location=plaza --spawn=desde_cafe --frames=40 --stats
```

Ajustar `--pos=x,y,z` si el detective tapa el buzón (debe verse su frente). Guardar también una
captura general de cada escenario para el paso 3. Las capturas van al scratchpad, no al
repositorio.

### Paso 2. Git preparado para binarios

`.gitattributes` (raíz): `*.glb binary` y `*.blend binary`. `.gitignore` (raíz): `*.blend1`,
`*.blend@`, `blender/**/__pycache__/`.
Commit: `chore(blender): tratar los modelos y los .blend como binarios`.

### Paso 3. Variación de tono independiente del orden (riesgo R5)

Recomendado: que `MeshBatcher.face` calcule el tono de cada cara a partir de su posición (un hash
del centro de la cara redondeado al centímetro, combinado con la semilla), no del orden de
llamada. El aspecto general no cambia (misma amplitud, ±0,035), pero cada cara conserva su tono
aunque se quiten o añadan otras. Capturas antes y después de los cinco escenarios.
Commit aislado: `refactor(world): variación de tono por cara independiente del orden`.
Si el propietario prefiere no cambiar nada visible todavía, saltar este paso y comparar en el
paso 9 con una máscara alrededor del buzón.

### Paso 4. Catálogo de modelos y fusión en el lote

- `scripts/world/model_catalog.gd` (`class_name ModelCatalog`): tabla `MODELS` con
  `"buzon": "res://assets/modelos/atrezo/buzon.glb"`; `place(location, id, transform) -> bool`
  (falso si el modelo está desactivado, no existe o no se puede leer, con `push_warning`);
  caché de superficies; `enabled`; lectura de `--modelos=procedural` en
  `OS.get_cmdline_user_args()` para las capturas de comparación; `clear()`.
- `MeshBatcher.add_surfaces(surfaces, transform)`: triángulos sin índices bajo
  `xform * transform`, normales giradas con la base, color por vértice, capa por nombre de
  material. **No** usa el generador de variación.
- `GameData._exit_tree`: `ModelCatalog.clear()` junto a `MaterialLibrary.clear()`.
- `tests/unit/test_models.gd` con una malla sintética creada en código (sin GLB): posición y giro,
  capa por nombre de material, alternativa cuando la ruta no existe.

Ejecutar `godot --headless --path . --import` (clase nueva) y la batería.
Commit: `feat(world): catálogo de modelos fusionados en el lote del escenario`.

### Paso 5. Exportación de referencias desde Godot (vía A)

`new-game-project/tools/modelos/exportar_referencias.tscn` + `.gd` (se lanza como las pruebas:
`godot --headless --path . res://tools/modelos/exportar_referencias.tscn -- --pieza=buzon`):

1. Crea un `LocationBase` sin añadirlo al árbol y le asigna un `StaticBody3D` en `_body`.
2. Llama a la parte visual procedural del kit con `ModelCatalog` desactivado.
3. Arma un `Node3D` con una `MeshInstance3D` por capa (`Buzon`, y `BuzonBrillo` si la hay) y
   materiales copiados con nombre (`vs_opaco`, `vs_brillo`).
4. Exporta con `GLTFDocument.append_from_scene` y `write_to_filesystem` a
   `blender/referencias/buzon.glb`.
5. Escribe `blender/referencias/buzon_colisiones.json` con cada caja (centro, tamaño, giro).

Commit: `feat(modelos): exportar las piezas procedurales como referencia para Blender`.

### Paso 6. Scripts de Blender

- `blender/scripts/importar_referencia.py -- --id buzon --categoria atrezo`: escena vacía, unidades
  métricas, importa la referencia, crea las colecciones `Exportar` (copia editable, objeto
  `Buzon`) y `Referencia` (original y cajas de colisión en alambre, excluida de la exportación) y
  guarda `blender/fuentes/atrezo/buzon.blend`.
- `blender/scripts/exportar_glb.py -- --blend blender/fuentes/atrezo/buzon.blend --destino new-game-project/assets/modelos/atrezo/buzon.glb`:
  activa `Exportar`, comprueba que existen todas las opciones de
  [05-estandares.md](05-estandares.md#exportación-desde-blender), exporta y escribe
  `blender/registro/buzon.json`.

Lanzar con:

```text
"D:\Program Files (x86)\steam\steamapps\common\Blender\blender.exe" --background --factory-startup --python blender/scripts/importar_referencia.py -- --id buzon --categoria atrezo
```

Commit: `chore(blender): scripts para importar referencias y exportar GLB`.

### Paso 7. El buzón en Blender y su GLB

En el prototipo **no se edita** la malla: primero hay que demostrar que el viaje completo
Godot → Blender → Godot devuelve lo mismo. Exportar, importar en Godot (`--import`) y confirmar
`buzon.blend`, `buzon.glb`, `buzon.glb.import` y el registro.

**Medir R4** en `test_models.gd`: comparar los colores de las caras del GLB con los de la pieza
procedural (tolerancia 1/255). Si la diferencia es la de sRGB ↔ lineal, aplicar la conversión en
`ModelCatalog` (un único sitio) y anotar el resultado en [03-riesgos.md](03-riesgos.md).
Comprobar también la orientación: la ranura debe quedar en +Z.

Commit: `feat(modelos): modelo de Blender del buzón de la plaza`.

### Paso 8. Usar el modelo en el juego

```gdscript
static func mailbox(location: LocationBase, where: Vector3) -> void:
	if not ModelCatalog.place(location, "buzon", Transform3D(Basis.IDENTITY, where)):
		_mailbox_mesh(location.batch, where)
	location.collider(where + Vector3.UP * 0.6, Vector3(0.5, 1.2, 0.5))
```

`_mailbox_mesh` contiene las tres líneas `batch.*` de hoy, sin cambios. Pruebas nuevas:

- Mismas colisiones con modelo y sin él (lista exacta de centros y tamaños).
- Caja del modelo igual a la procedural con ±5 cm.
- La plaza sigue con ≤ 3 `MeshInstance3D` y ningún `StaticBody3D` aparte de `Colisiones`.
- Con `ModelCatalog.enabled = false`, la pieza se dibuja como antes.

Commit: `feat(modelos): el buzón de la plaza usa su modelo de Blender`.

### Paso 9. Comparación con el original

1. Captura «después» con los mismos argumentos del paso 1.
2. Captura en modo procedural: los mismos argumentos más `--modelos=procedural`.
3. Diferencia de píxeles entre «después» y «procedural» con `System.Drawing` desde PowerShell
   (no hay PIL en el equipo): máximo y media en la zona del buzón y fuera de ella. Con el paso 3
   hecho, fuera del buzón la diferencia debe ser cero.
4. `--stats`: mismas llamadas de dibujado que antes (≈ 91 en la plaza).
5. Tiempo de carga de la plaza: `bake_milliseconds` y, si se puede, el tiempo de `_ready`.

### Paso 10. Verificación completa

En una copia limpia de la rama (worktree temporal), desde `new-game-project/`:

```text
powershell -File tools\verificar.ps1
powershell -File tools\verificar.ps1 -ConVentana
```

No lanzar la batería a la vez que `verificar.ps1` (comparten `user://pruebas_guardado`).

### Paso 11. Documentación y cierre

- Actualizar [01-inventario.md](01-inventario.md) (buzón migrado), [03-riesgos.md](03-riesgos.md)
  (R4 y R5 resueltos), [06-plan-migracion.md](06-plan-migracion.md) y
  [07-linea-base.md](07-linea-base.md) (nueva línea base).
- `docs/RECURSOS.md`: fila del buzón. `docs/ARQUITECTURA.md`: sección breve «Modelos de Blender».
- Commit: `docs(blender): documentar el prototipo del buzón y su comparación`.
- Informe final: commits, pruebas, diferencias medidas, decisiones y punto de partida de la
  sesión 3. **Sin `push`.**

## Criterios de aceptación del prototipo

- [ ] El buzón se dibuja desde `assets/modelos/atrezo/buzon.glb`.
- [ ] Sus colisiones son exactamente las de antes; la navegación y las pruebas de alcance pasan.
- [ ] La plaza sigue siendo 3 mallas y las mismas llamadas de dibujado.
- [ ] Colores y orientación iguales al original (o diferencia medida y explicada).
- [ ] `--modelos=procedural` y `ModelCatalog.enabled = false` devuelven el aspecto original.
- [ ] Sin el GLB, el juego funciona y avisa.
- [ ] `verificar.ps1` y `-ConVentana` correctos en copia limpia.
- [ ] El `.blend` está fuera de `new-game-project/` y abre en Blender 5.3 con las colecciones
      `Exportar` y `Referencia`.

## Cómo volver atrás

- Sin tocar Git: `ModelCatalog.enabled = false`, o quitar `"buzon"` de la tabla. El código
  procedural sigue ahí.
- Con Git: los commits son pequeños y separados; `git revert` del commit del paso 8 deja el GLB
  sin usar.

## Después del prototipo

Con el proceso validado, la sesión 3 (`feature/blender-atrezo-exterior`) repite los pasos 1, 5–9
por cada pieza de `PropsKit` de tamaño fijo, en el orden de [06-plan-migracion.md](06-plan-migracion.md),
y sólo entonces empieza a **editar** modelos en Blender (primero retoques pequeños, uno por commit).

## Resultado (2026-11-23)

La sesión 2 se hizo en la rama `feature/blender-prototipo-buzon`, creada desde `3090bad` (cierre
de la sesión 1 más un commit del propietario que sólo añade el MCP de Blender a `.mcp.json`), en
un `git worktree` aparte: el editor de Godot seguía abierto sobre la carpeta principal y
reescribe `project.godot` y `main_menu.tscn` (R17).

### Qué se hizo y en qué se apartó del procedimiento

| Paso | Hecho | Diferencia con lo previsto |
| --- | --- | --- |
| 1. Capturas «antes» | Cinco escenarios y el buzón (`--pos=-4.6,0.1,-9.0`), con `--stats` | Las capturas llevan lluvia y grano: dos capturas idénticas difieren en media 4,4 por píxel (máximo 185). Las comparaciones exactas se hacen con la geometría |
| 2. Git para binarios | `.gitattributes` y `.gitignore` en la raíz; `*.glb binary` también en `new-game-project/.gitattributes` (su `* text=auto` tiene prioridad dentro del proyecto) | — |
| 3. R5 | `MeshBatcher.shaded`: hash del centro de la cara | Rejilla desplazada 0,37 cm para que las medidas del juego no caigan en el borde de una celda |
| 4. Catálogo | `ModelCatalog`, `MeshBatcher.add_surfaces`, `MeshBatcher.recording` | Los triángulos importados se reagrupan en polígonos (arista, normal y color) para aplicar la misma variación de tono que `face` |
| 5. Referencias | `tools/modelos/exportar_referencias.tscn` → `blender/referencias/<id>.json` | **JSON con polígonos en lugar de un GLB exportado por Godot**: conserva los polígonos reales (cuadriláteros, octógonos), es legible en un diff y no depende de cómo Godot codifica el color. `tools/` tiene `.gdignore`: la escena se carga por ruta y no se exporta con el juego |
| 6. Scripts de Blender | `vs_comun.py`, `importar_referencia.py`, `exportar_glb.py` | El color se guarda en el `.blend` en lineal y se exporta en sRGB (R4) |
| 7. Buzón en Blender | `blender/fuentes/atrezo/buzon.blend`, `assets/modelos/atrezo/buzon.glb` (5,4 kB) y `blender/registro/buzon.json` | Importación sin LOD, mallas de sombra ni tangentes: el juego sólo lee los triángulos |
| 8. Uso en el juego | `PropsKit.mailbox` → `ModelCatalog.place`, si falla `_mailbox_mesh` | — |
| 9. Comparación | Pruebas geométricas (abajo) y capturas | — |

### Medidas

| Medida | Procedural | Modelo de Blender |
| --- | --- | --- |
| Triángulos del buzón | 68 | 68 |
| Polígonos | 26 | 26 (Blender parte los cuatro octógonos con otras diagonales: misma superficie) |
| Caja | 0,60 × 1,24 × 0,60 m | 0,60 × 1,24 × 0,60 m |
| Colores | `622222`, `551d1d`, `1d2027` | Iguales (con el color en lineal salían `551c1c` y `1c1c26`) |
| Colisión | 0,5 × 1,2 × 0,5 m a 0,6 m | La misma (la registra el kit, no el modelo) |
| Mallas de la plaza | 3 | 3 |

`test_models.test_locations_match_with_and_without_models` construye los cinco escenarios con
modelos y en modo procedural y exige los mismos polígonos (vértices a 1 mm, área, color a 1/255 y
cara frontal) y la misma lista de colisiones. Se comprobó que detecta un cambio de color de la
pieza procedural (prueba de mutación: falla con 0,047 de diferencia en el buzón y en la plaza).

### Cómo usar el prototipo como plantilla

```text
# desde new-game-project/
godot --headless --path . res://tools/modelos/exportar_referencias.tscn -- --pieza=buzon
# desde la raíz del repositorio
blender --background --factory-startup --python blender/scripts/importar_referencia.py -- --id buzon
blender --background --factory-startup --python blender/scripts/exportar_glb.py -- --id buzon --categoria atrezo
# desde new-game-project/
godot --headless --path . --import
```

La sesión 3 generaliza estos pasos (registro de modelos, variantes, captura automática de las
referencias desde los escenarios y validación).
