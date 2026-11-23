# Estado de la migración a Blender

Registro vivo para retomar el trabajo tras una interrupción. Se actualiza al terminar cada etapa.
El detalle de cada decisión está en los documentos numerados de esta carpeta.

## Ahora

| Dato | Valor |
| --- | --- |
| Sesión | 4 terminada; siguiente: 5 — interiores |
| Rama | `feature/blender-objetos` (cerrada) → `feature/blender-interiores` |
| Último commit válido | `66fee96` + documentación de la sesión 4 |
| Fase | Sesión 4 validada: 543 pruebas, 20 modelos |
| Próxima acción | Sesión 5: piezas propias del café, la mansión y el archivo (borrador escenarios_s5.py), estanterías optimizadas (optimizar_ocultas.py), pruebas de interiores |

Encargo vigente (2026-11-23): sesiones 2 → 3 → 4 → 5 y después 6 (exteriores) → 7 (personajes) →
8 (integración), cada una en su rama creada desde la anterior. Ver [06-plan-migracion.md](06-plan-migracion.md).

## Dónde se trabaja

- **Copia de trabajo de la migración:** un `git worktree` aparte (en el scratchpad de la sesión de
  Claude Code), no la carpeta principal. Motivo: el editor de Godot está abierto sobre la carpeta
  principal y reescribe `project.godot` y `scenes/main/main_menu.tscn` (ruido sin confirmar desde
  la sesión 1, R17). Esos dos archivos no se tocan ni se confirman.
- **Base de la sesión 2:** `3090bad` (último commit de `feature/blender-auditoria`). Contiene
  `fec1bfa` (cierre de la sesión 1) y un commit posterior del propietario que sólo añade el
  servidor MCP de Blender a `.mcp.json`.

## Herramientas

| Qué | Cómo |
| --- | --- |
| Batería | `godot --headless --path new-game-project res://tests/test_runner.tscn -- [--filtro=test_x]` (más de 10 min la completa) |
| Importar clases nuevas | `godot --headless --path new-game-project --import` |
| Blender | `blender --background --factory-startup --python blender/scripts/<script>.py -- <args>` |
| MCP | Blender y Godot MCP disponibles pero opcionales: el flujo usa los ejecutables por terminal (reproducible) |

## Sesiones

| Sesión | Rama | Estado | Último commit |
| --- | --- | --- | --- |
| 1 | `feature/blender-auditoria` | Terminada | `fec1bfa` (+ `3090bad` MCP) |
| 2 | `feature/blender-prototipo-buzon` | Terminada y verificada | `1faa819` (+ registro) |
| 3 | `feature/blender-arquitectura` | Terminada y validada | `3c5cf14` (+ registro) |
| 4 | `feature/blender-objetos` | Terminada y validada | `66fee96` (+ documentación) |
| 5 | `feature/blender-interiores` | Pendiente | — |
| 6 | `feature/blender-exteriores` | Pendiente | — |
| 7 | `feature/blender-personajes` | Pendiente | — |
| 8 | `feature/blender-integracion` | Pendiente | — |

## Decisiones técnicas

1. **R5:** el tono de cada cara sale de un hash de su centro (rejilla de 1 cm desplazada 0,37 cm)
   y de la semilla. Mismo aspecto (±0,035), distinto reparto. Capturas antes/después: sin cambio
   de estilo apreciable.
2. **Los GLB guardan los colores puros de la paleta** (sin variación). La variación de tono la
   añade el juego al fusionar el modelo en el lote, por polígono y con el mismo hash: un modelo
   sin editar se ve exactamente como la pieza procedural.
3. **R4:** el `.blend` guarda el color en lineal; el GLB, en sRGB (Godot lo guarda con 8 bits:
   en lineal los oscuros perdían hasta 4/255). `ModelCatalog` no convierte.
4. **Referencias en JSON** (polígonos reales) en lugar de un GLB exportado por Godot.
5. **Importación de GLB** sin LOD, mallas de sombra ni tangentes.
6. **Sesión 3:** `ModelCatalog.draw(location, id, colocación, procedural, variante, tinte)`; registro en `ModelRegistry`; variantes = objetos de un mismo GLB (origen = pivote; posición en el .blend ignorada); tinte con `vs_tinte` (factor × color del kit); referencias capturadas desde los escenarios reales; `validar_modelos` y `migrar.py`. Detalle en 09-sistema-de-modelos.md
7. **Sesión 4:** refactorizaciones verificadas con `huella_escenarios.tscn` (huella idéntica antes y después). El GLB lleva el número de polígono en un mapa UV (tono exacto por polígono). Prueba por superficie cubierta (`test_each_model_matches_its_procedural_piece`). El importador no une vértices si se perderían caras coincidentes

## Pruebas

| Momento | Resultado |
| --- | --- |
| Línea base (sesión 1, `85b9f82`) | 524 correctas |
| Tras R5 (`8e4e7ec`) | 528 correctas, 0 con fallos |
| Cierre de la sesión 2 (`aa20034`, carpeta de trabajo) | 538 correctas, 0 con fallos |
| `verificar.ps1 -ConVentana` en copia limpia de `3831ad3` | Todo correcto salvo «Pruebas automatizadas»: 538 correctas, pero dos pruebas de `test_models` no liberaban un nodo y Godot avisaba de RID sin liberar al cerrar. Corregido en `1faa819` |
| Paso de pruebas repetido en copia limpia de `1faa819` | **538 correctas, 0 con fallos, sin líneas `ERROR:`** (código 0) |
| Cierre de la sesión 3 (`3c5cf14`, carpeta de trabajo) | 542 correctas, 0 con fallos, sin `ERROR:` |
| Cierre de la sesión 4 (carpeta de trabajo) | 543 correctas, 0 con fallos, sin `ERROR:` |

Ruido entre dos capturas idénticas de la plaza (lluvia y grano): media 4,4 por píxel, máximo 185.
Las comparaciones exactas se hacen con la geometría (pruebas), no con píxeles.

## Errores conocidos

- `test_integration` intermitente con el equipo cargado (R19).
- `verificar.ps1` marca como fallo cualquier línea `ERROR:` (también los avisos de recursos sin
  liberar al cerrar): al probar, buscar también `ERROR:` en la salida, no sólo `FALLO`.
