# Estado de la migración a Blender

Registro vivo para retomar el trabajo tras una interrupción. Se actualiza al terminar cada etapa.
El detalle de cada decisión está en los documentos numerados de esta carpeta.

## Ahora

| Dato | Valor |
| --- | --- |
| Sesión | 2 — prototipo del buzón |
| Rama | `feature/blender-prototipo-buzon` |
| Último commit válido | `8e4e7ec` refactor(world): variación de tono por cara independiente del orden |
| Fase | R5 resuelto; siguiente: catálogo de modelos y fusión en el lote |
| Próxima acción | `ModelCatalog`, `MeshBatcher.add_surfaces`, grabación de caras, `test_models.gd` |

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
| 2 | `feature/blender-prototipo-buzon` | En curso | `8e4e7ec` |
| 3 | `feature/blender-arquitectura` | Pendiente | — |
| 4 | `feature/blender-objetos` | Pendiente | — |
| 5 | `feature/blender-interiores` | Pendiente | — |

## Decisiones técnicas

1. **R5:** el tono de cada cara sale de un hash de su centro (rejilla de 1 cm desplazada 0,37 cm)
   y de la semilla. Mismo aspecto (±0,035), distinto reparto. Capturas antes/después: sin cambio
   de estilo apreciable.
2. **Los GLB guardan los colores puros de la paleta** (sin variación). La variación de tono la
   añade el juego al fusionar el modelo en el lote, por polígono y con el mismo hash: un modelo
   sin editar se ve exactamente como la pieza procedural.

## Pruebas

| Momento | Resultado |
| --- | --- |
| Línea base (sesión 1, `85b9f82`) | 524 correctas |
| Tras R5 (`8e4e7ec`) | 528 correctas, 0 con fallos |

Ruido entre dos capturas idénticas de la plaza (lluvia y grano): media 4,4 por píxel, máximo 185.
Las comparaciones exactas se hacen con la geometría (pruebas), no con píxeles.

## Errores conocidos

- `test_integration` intermitente con el equipo cargado (R19).
