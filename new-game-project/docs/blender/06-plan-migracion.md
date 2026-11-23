# 6. Plan de migración por sesiones y ramas

Cada sesión trabaja en su propia rama, creada desde **el último commit de la rama de la sesión
anterior** (no desde `main`, salvo que el propietario haya fusionado la anterior y lo indique).
Los commits se hacen automáticamente y en pequeño; **ninguna sesión hace `push`** sin permiso
expreso.

## Resumen

| Sesión | Rama | Parte de | Alcance | Riesgo |
| --- | --- | --- | --- | --- |
| 1 | `feature/blender-auditoria` | `main` (`85b9f82`) | Auditoría, documentación y línea base. Sin cambios en el juego | — |
| 2 | `feature/blender-prototipo-buzon` | último commit de la sesión 1 | Infraestructura mínima y **un** modelo: el buzón de la plaza | Bajo |
| 3 | `feature/blender-atrezo-exterior` | sesión 2 | Resto del atrezo de tamaño fijo de `PropsKit` | Bajo–medio |
| 4 | `feature/blender-mobiliario` | sesión 3 | Mobiliario de `InteriorKit` (fijo primero, variantes después) | Medio |
| 5 | `feature/blender-personajes` | sesión 4 | Mallas de `CharacterModel` desde GLB, misma interfaz | Alto |
| 6 | `feature/blender-arquitectura` | sesión 5 | Detalles de `BuildingKit` y piezas propias de cada escenario | Medio–alto |
| 7 | `feature/blender-pulido` | sesión 6 | Mejora artística en Blender, escenas de atrezo opcionales, cierre | Medio |

El orden va de lo que menos puede romper a lo que más. Si una sesión no termina su alcance, la
siguiente lo completa antes de empezar el suyo.

## Sesión 2 — Prototipo: el buzón

Detalle paso a paso en [08-sesion-2.md](08-sesion-2.md). En resumen:

1. Preparar Git para binarios (`.gitattributes`, `.gitignore`).
2. Decidir y aplicar R5 (variación de tono determinista por cara), en un commit aislado con
   capturas antes y después.
3. Crear `ModelCatalog`, `MeshBatcher.add_surfaces` y `tests/unit/test_models.gd`.
4. Crear la exportación de referencias (vía A) y los dos scripts de Blender.
5. Exportar el buzón, crear `blender/fuentes/atrezo/buzon.blend` y su GLB.
6. Medir R4 (sRGB frente a lineal) y fijar la conversión.
7. Hacer que `PropsKit.mailbox` use el modelo, conservando su colisión.
8. Comparar (capturas, llamadas de dibujado, pruebas) y documentar.

**Criterio de éxito:** el buzón se ve igual (o con diferencias explicadas), sus colisiones son
idénticas, la plaza sigue siendo tres mallas, todas las pruebas pasan y el modo procedural sigue
funcionando.

## Sesión 3 — Atrezo exterior (`PropsKit`)

Orden: `barrel`, `crate` (un cubo; las dos medidas, 0,7 y 0,9, con escala uniforme), `bench`,
`street_lamp` (la luz sigue en el kit), `cafe_table`, `signpost` (sólo el poste y los tableros; los
rótulos siguen siendo `Label3D`), `newsstand` (el rótulo «PRENSA» y la pista del periódico siguen
en GDScript), `car`.

Se quedan procedurales: `hedge`, `low_wall` (tamaño por parámetro, bordes que evitan caídas) y
`tree` hasta la sesión 7 (su valor es artístico; conviene rehacerlo a mano, no exportarlo).

## Sesión 4 — Mobiliario (`InteriorKit`)

1. Tamaño fijo: `chair`, `armchair`, `plant`, `floor_lamp`, `ceiling_lamp`, `filing_cabinet`,
   `grandfather_clock`, `back_window`, `painting` (marco; el lienzo es un color por parámetro).
2. Con variantes (vía B, un script de Blender que genera cada medida usada en el juego):
   `bed` (1,6×2,2; 2,0×2,3; 1,2×2,0), `dresser` (1,4; 1,6; 1,8; 2,0 con espejo), `bookshelf`
   (3,2×2,6; 4,0×3,0; 3,0×2,5; 3,0×2,0), `sofa`, `desk`, `table` (seis medidas), `fireplace`.
3. Los muebles con pistas encima o al lado van al final de la sesión, uno por commit, con
   comprobación explícita de la pista (lista en [01-inventario.md](01-inventario.md#referencias-narrativas)).

Se quedan procedurales: suelos, paredes, `rug`, `seal_street_door`.

## Sesión 5 — Personajes

1. Script de Blender (vía B) que genera el cuerpo base con los seis pivotes en su sitio y todas las
   piezas opcionales, partiendo de las medidas de `character_model.gd`.
2. `CharacterModel` con dos orígenes de mallas (procedural y GLB) y la misma interfaz.
3. Materiales por papel teñidos con el `look`.
4. Pruebas de NPC, jugador y audio en los dos modos; medida de llamadas de dibujado en el café
   (el escenario con más NPC a la vez).
5. Sólo después, retoques manuales del cuerpo y las caras.

## Sesión 6 — Arquitectura y piezas de escenario

- `BuildingKit`: `window`, `door`, `awning`, `chimney`, `column` (su colisión sigue en el kit).
- `BuildingKit.body` **conserva su colisión** y su huella: la usan el mapa del pueblo y
  `test_map`. Se puede sustituir la malla, no las medidas.
- Piezas propias de `plaza.gd`, `cafe.gd`, `estacion.gd` y `mansion.gd`: fuente, verja y
  mansión de fondo, torre del reloj, frontón del archivo, barra y botellero del café, tren, reloj de
  andén. Se extraen primero a funciones con nombre (sin cambiar el resultado) y luego se migran.
- No se tocan: suelos, paredes, barreras, puntos de aparición, marcadores ni salidas.

## Sesión 7 — Pulido

- Remodelado artístico (vía C) de las piezas que más se ven: árboles, coche, fuente, personajes.
- Escenas de atrezo independientes (`LocationBase.add_prop`) si se quiere colocar piezas desde el
  editor ([04-arquitectura.md](04-arquitectura.md#escenas-de-atrezo-independientes-opcional-fase-posterior)).
- `docs/RECURSOS.md`, `docs/ARQUITECTURA.md` y `docs/ESTADO_PROYECTO.md` al día.
- Verificación completa con ventana.

## Lista de comprobación de cada sesión

Al empezar:

1. `git status`, `git branch -vv`, `git log --oneline -5`; mirar los `.jsonl` recientes del
   proyecto por si hay otra sesión trabajando en la misma carpeta.
2. Crear la rama desde el último commit de la sesión anterior.
3. No confirmar `project.godot` ni `scenes/main/main_menu.tscn` si sólo traen ruido del editor.

Por cada pieza:

1. Captura «antes» desde un punto fijo, con `--stats`.
2. Referencia (vía A) → `.blend` → GLB.
3. Kit: modelo con alternativa procedural; **las llamadas lógicas, sin cambios**.
4. Prueba en `test_models.gd` (colisiones idénticas, caja, capas, colores).
5. Captura «después» desde el mismo punto y comparación.
6. Commit con rutas concretas.

Al terminar:

1. `godot --headless --path . --import` si hay clases o recursos nuevos.
2. `powershell -File tools\verificar.ps1` en una copia limpia de la rama (worktree temporal), y
   `-ConVentana` si la sesión cambia algo visible.
3. Actualizar este plan y [07-linea-base.md](07-linea-base.md) con los resultados.
4. Entregar el resumen: commits, pruebas, riesgos abiertos y punto de partida de la sesión
   siguiente.

## Qué no se hace en ninguna sesión sin una decisión expresa

- Borrar el código procedural de una pieza.
- Cambiar colisiones, barreras, puntos de aparición, marcadores o salidas.
- Cambiar la historia, los datos de los personajes o el formato de guardado.
- Instanciar modelos que añadan llamadas de dibujado sin presupuestarlas en la prueba.
- Importar `.blend` directamente en Godot.
