# 3. Riesgos y medidas preventivas

Ordenados por gravedad. «Probabilidad» e «impacto» se valoran como alto, medio o bajo para el
primer prototipo y las primeras fases (atrezo). Los riesgos de personajes y edificios se repiten
en el plan, en la fase donde aparecen.

| Id | Riesgo | Prob. | Impacto | Medida preventiva |
| --- | --- | --- | --- | --- |
| R1 | Al sustituir un `solid(...)` por un modelo se pierde su colisión | Media | Alto | Regla: toda pieza migrada conserva sus llamadas lógicas (`collider`, luces, rótulos, `register_surface`). Prueba nueva que construye cada pieza migrada en los dos modos (procedural y modelo) y exige **la misma lista de colisiones** (centro y tamaño) |
| R2 | Una escena de atrezo trae su propio `StaticBody3D` | Media | Alto | Las colisiones sólo se registran con `location.collider` dentro de `build()`. La navegación (`LocationNavigation.bake`) y `test_map` sólo leen `Colisiones`. Prueba nueva: ningún escenario tiene otro `StaticBody3D` que `Colisiones` |
| R3 | El modelo no coincide con su colisión (se atraviesa o se choca con aire) | Media | Medio | En Blender, colección `Referencia` con las cajas de colisión exportadas desde Godot (no se exporta al juego). Prueba que compara la caja del modelo con la del procedural con 5 cm de tolerancia para las exportaciones directas |
| R4 | **Resuelto en la sesión 2.** Los colores cambian en el viaje Godot → glTF → Blender → glTF → Godot (sRGB frente a lineal) | Alta | Medio | El juego guarda los colores de vértice en sRGB (`vertex_color_is_srgb = true`; el brillo aplica `pow(COLOR, 2.2)`), y glTF define `COLOR_0` como lineal. **Medirlo en la sesión 2** con colores conocidos de `Palette` antes de dar por bueno el prototipo, y, si hace falta, convertir al cargar (`Color.linear_to_srgb`) en un único sitio. **Medido:** Blender exporta `COLOR_0` en lineal y Godot lo guarda con 8 bits por canal; al volver a sRGB, los oscuros pierden hasta 4/255 (`IRON` `1d2027` → `1c1c26`). Solución: el `.blend` guarda el color en lineal (se ve bien en Blender) y `exportar_glb.py` escribe el GLB con el color ya en sRGB; `ModelCatalog.LINEAR_VERTEX_COLORS = false`. Resultado: colores exactos |
| R5 | **Resuelto en la sesión 2.** La variación de tono por cara depende del orden: quitar caras de una pieza cambia el tono de todas las siguientes del escenario | Segura | Bajo (visual) | `MeshBatcher` usa un generador por escenario con semilla 7. Recomendado: un commit previo, aislado, que haga la variación **determinista por cara** (a partir de la posición de la cara, no del orden), con capturas antes y después. Así cada migración sólo cambia sus propias caras y las comparaciones son exactas. Alternativa si el propietario no quiere ningún cambio visual previo: comparar con tolerancia y máscara alrededor de la pieza. **Hecho:** `MeshBatcher.shaded` calcula el tono con un hash del centro de la cara (rejilla de 1 cm desplazada 0,37 cm) y la semilla; los modelos importados reciben la misma variación por polígono (`ModelCatalog.polygon_centers`) |
| R6 | Modelos girados 180° o con el eje equivocado | Alta | Medio | Los personajes miran a −Z y el atrezo a +Z local. Convención fija en [05-estandares.md](05-estandares.md#ejes-y-orientación) (atrezo: frente a −Y de Blender; personajes: frente a +Y). Prueba de orientación en el prototipo (la ranura del buzón debe quedar en +Z) |
| R7 | Más llamadas de dibujado al instanciar GLB como nodos, sin que la prueba lo detecte | Alta si se instancia | Medio | Los modelos estáticos se **fusionan en el lote** del escenario (mismos tres materiales). La prueba de lotes se amplía para contar todas las `GeometryInstance3D` del escenario (salvo marcadores y NPC), no sólo las hijas directas |
| R8 | Godot intenta importar los `.blend` que estén dentro del proyecto y falla en equipos sin Blender configurado (el coautor, el jurado) | Alta si se ponen dentro | Alto | Los `.blend` viven **fuera** de `new-game-project/`, en `VillaSombria/blender/`. Al proyecto sólo entran los `.glb` con su `.import` |
| R9 | Binarios mal tratados por Git (`* text=auto eol=lf`) o copias `.blend1` en el historial | Media | Bajo | Añadir `*.glb binary` y `*.blend binary` a `.gitattributes`, y `*.blend1`/`*.blend@` a `.gitignore`, en la sesión 2 antes del primer binario. Los modelos low-poly pesan kilobytes: no hace falta Git LFS |
| R10 | Interfaz de `CharacterModel` rota al cambiar los personajes | Media | Alto | `CharacterModel` se mantiene como fachada con la misma API, los mismos seis pivotes con el mismo nombre y la señal `stepped`. Las pruebas de NPC y de audio se ejecutan con los dos modos |
| R11 | Se pierde el aspecto por personaje (`look` en `characters.json`) si los colores van «cocidos» en el GLB | Alta si se cuecen | Medio | Materiales por papel (`vs_piel`, `vs_abrigo`…) que `CharacterModel` tiñe con el `look`; las piezas opcionales (peinados, sombreros, extras) se muestran u ocultan por nombre |
| R12 | Una pista queda dentro de un mueble o flotando al cambiar el mueble | Media | Alto | Lista de pistas apoyadas en muebles en [01-inventario.md](01-inventario.md#referencias-narrativas); esos muebles conservan su caja exterior. `test_world.test_everything_is_reachable` debe seguir pasando |
| R13 | Un modelo más alto tapa al detective (cámara a 45°, corte de casa de muñecas) | Media | Medio | No migrar paredes, setos ni muretes del lado de la cámara en las primeras fases. Capturas desde los mismos puntos antes y después |
| R14 | El exportador de Blender cambia de opciones o de comportamiento (Blender de Steam se actualiza solo) | Media | Medio | El script de exportación fija **todas** las opciones relevantes y escribe la versión de Blender y del exportador en un registro junto al GLB. Versión comprobada hoy: Blender 5.3.0, exportador glTF 5.3.43 |
| R15 | (Ya no aplica: la referencia se exporta como polígonos en JSON, no con el exportador glTF de Godot.) El exportador glTF de Godot genera mallas sin índices (como el lote) y en Blender cada cara queda suelta | Segura | Bajo | Es lo esperado: el aspecto facetado viene de ahí. En Blender, «Merge by Distance» sólo si se va a remodelar; los colores van por esquina de cara, así que no se pierden |
| R16 | Coste de carga al convertir GLB en triángulos del lote cada vez que se entra en un escenario | Baja | Bajo | Caché estática por id de modelo (ya transformada y sin índices); se libera en `GameData._exit_tree` junto a `MaterialLibrary.clear()`. Vigilar `bake_milliseconds` y el tiempo de carga |
| R17 | Confirmar ruido del editor (`project.godot` sin `MCPRuntime`, UIDs en `main_menu.tscn`) | Alta | Medio | Nunca `git add -A`: rutas concretas y revisar `git diff --cached` antes de cada commit. Hoy esos dos archivos estaban modificados por el editor y no se han confirmado |
| R18 | Otra sesión trabaja a la vez en la misma carpeta y cambia de rama | Media | Alto | Antes de editar, mirar los `.jsonl` recientes del proyecto y `git status`/`git branch` |
| R19 | `test_integration` falla de forma intermitente con el equipo cargado | Conocida | Bajo | Repetir la batería antes de culpar a un cambio (ver [07-linea-base.md](07-linea-base.md)) |
| R20 | Autoría y licencias de los modelos | Baja | Medio | Todos los modelos son propios. Registrar cada uno en `docs/RECURSOS.md` (origen, herramienta, `.blend` de origen) |

## Medidas generales

1. **Nada se elimina.** El código procedural de cada pieza sigue en su kit como alternativa. Si
   el GLB falta o no se puede leer, la pieza se dibuja como hoy y se avisa con `push_warning`.
2. **Una pieza por commit**, con su prueba y su captura de comparación.
3. **Interruptor global** para dibujar todo con el código procedural (para comparar y para volver
   atrás sin tocar Git).
4. **Pruebas en los dos modos** para cada pieza migrada (colisiones idénticas, caja parecida,
   capa de brillo donde la había).
5. **Verificación completa** (`tools/verificar.ps1`) en una copia limpia de la rama antes de dar
   por terminada cada sesión.
6. **Sin luces, cámaras ni colisiones dentro de los GLB.** Sólo mallas.

## Estado de los riesgos al terminar la sesión 8

| Id | Estado | Cómo se cubre |
| --- | --- | --- |
| R1 | Controlado | Las colisiones se quedan en el kit; huella de escenarios y prueba por escenario con y sin modelos (mismas colisiones) |
| R2 | Controlado | Ningún GLB trae colisiones (`validar_modelos`); `test_plaza_keeps_its_batches` exige una sola colisión estática |
| R3 | Controlado | `validar_modelos` compara la caja de cada objeto con la procedural (±5 cm); la colección `Referencia` enseña las colisiones en Blender |
| R4 | Resuelto (sesión 2) | GLB con color en sRGB; importación sin compresión |
| R5 | Resuelto (sesión 2) | Tono por centro del polígono; número de polígono en el GLB (sesión 4) |
| R6 | Controlado | Pruebas de orientación (buzón) y de equivalencia (cara frontal) de cada pieza y de cada pivote |
| R7 | Controlado | Los modelos se fusionan en el lote: mismas llamadas de dibujado en los cinco escenarios |
| R8 | Controlado | `.blend` fuera del proyecto; el proyecto importa sin Blender |
| R9 | Controlado | `*.glb`/`*.blend` binarios; `*.blend1` ignorados; finales LF en `blender/` |
| R10 | Controlado | `CharacterModel` mantiene su interfaz; `test_personajes` compara pivotes y animación |
| R11 | Resuelto de otra forma | Un GLB por personaje con sus colores (no por papel): el aspecto es exacto |
| R12 | Controlado | Ningún mueble con pistas ha cambiado de forma ni de sitio (pruebas de equivalencia) |
| R13 | Sin cambios | No se han migrado paredes, setos ni muretes |
| R14 | Controlado | `exportar_glb.py` fija las opciones y guarda versiones y `sha256` en el registro |
| R15 | No aplica | La referencia es JSON con polígonos |
| R16 | Medido | Caché de 3,1 MB con los 68 modelos; primera construcción +26 a +75 ms, después igual o menos que el código |
| R17 | Controlado | `project.godot` y `main_menu.tscn` sin cambios en las ocho sesiones |
| R18 | Controlado | Trabajo en un `worktree` aparte; comprobación de otras sesiones al empezar |
| R19 | Abierto | `test_integration` sigue siendo intermitente con el equipo cargado (no ha fallado en estas sesiones) |
| R20 | Controlado | `docs/RECURSOS.md` registra los modelos (propios, hechos con Blender a partir del código del juego) |

