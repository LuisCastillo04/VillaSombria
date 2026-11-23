# Migración de modelos a Blender

Plan para pasar, poco a poco, los modelos 3D que hoy genera el código de Villa Sombría a modelos
editables en Blender, **sin perder ninguna funcionalidad**. La sesión 1 (2026-11-22) fue sólo de
auditoría y planificación. Desde la sesión 2 (2026-11-23) hay modelos de Blender en el juego.

**Estado al día y punto de partida para retomar:** [ESTADO_MIGRACION.md](ESTADO_MIGRACION.md).

## Documentos

| # | Documento | Contenido |
| --- | --- | --- |
| 1 | [01-inventario.md](01-inventario.md) | Todas las piezas generadas por código, con medidas, triángulos, colisiones, usos, referencias narrativas, viabilidad, riesgo y prioridad |
| 2 | [02-dependencias.md](02-dependencias.md) | Qué sistemas dependen de la geometría y de qué manera |
| 3 | [03-riesgos.md](03-riesgos.md) | Riesgos y medidas preventivas |
| 4 | [04-arquitectura.md](04-arquitectura.md) | Evaluación Blender–Godot y arquitectura propuesta (atrezo y personajes) |
| 5 | [05-estandares.md](05-estandares.md) | Carpetas, nombres, ejes, escala, color, opciones de exportación, Git |
| 6 | [06-plan-migracion.md](06-plan-migracion.md) | Sesiones, ramas, orden y listas de comprobación |
| 7 | [07-linea-base.md](07-linea-base.md) | Resultado de las pruebas antes de empezar |
| 8 | [08-sesion-2.md](08-sesion-2.md) | Procedimiento completo del prototipo (el buzón), su resultado y medidas |
| 9 | [09-sistema-de-modelos.md](09-sistema-de-modelos.md) | Arquitectura implementada (sesión 3): API, variantes, tinte, captura, validación, cómo añadir o retocar un modelo |
| 10 | [10-sesion-4-objetos.md](10-sesion-4-objetos.md) | Sesión 4: selección, migración y validación del mobiliario y los objetos compartidos |
| 11 | [11-sesion-5-interiores.md](11-sesion-5-interiores.md) | Sesión 5: auditoría de los interiores, piezas propias, optimización de las estanterías y pruebas |
| — | [INVENTARIO_MODELOS.md](INVENTARIO_MODELOS.md) | Inventario generado de los modelos migrados (`python blender/scripts/inventario.py`) |
| — | [ESTADO_MIGRACION.md](ESTADO_MIGRACION.md) | Registro vivo: sesión, rama, último commit, pruebas, decisiones y próxima acción |

## Hallazgos principales

1. **Lo visual y lo lógico ya están separados en el código.** Cada pieza de los kits dibuja con
   `batch.*` y, aparte, registra su colisión, luz, rótulo o punto de interacción. Ningún sistema lee
   las mallas: la navegación se hornea con las colisiones, el guardado sólo guarda escenario y
   posición, y el mapa y las pruebas leen el nodo `Colisiones`. Sustituir sólo la parte visual no
   cambia el comportamiento.
2. **Todo el escenario se dibuja con tres mallas** (`MeshBatcher`) y una prueba lo exige. Por eso
   los modelos de Blender deben **fusionarse en ese lote**, no instanciarse como nodos.
3. **Los personajes miran a −Z y el atrezo a +Z local.** En Blender eso significa frente a +Y para
   personajes y a −Y para el resto.
4. **El tono de cada cara depende del orden en que se añaden las caras.** Quitar una pieza cambia
   el tono de todo lo que viene después en ese escenario: hay que resolverlo antes de comparar
   capturas (riesgo R5).
5. **El color de vértice se guarda en sRGB y glTF lo define lineal:** hay que medir el viaje de ida
   y vuelta en el prototipo (riesgo R4).
6. **`CharacterModel` se puede conservar entera como fachada**: seis pivotes con nombre, animación
   procedural, misma interfaz. Un GLB con un objeto por pivote encaja sin esqueleto.
7. Las colisiones de las escenas de atrezo **tienen que acabar en `Colisiones`**: si no, los NPC
   las atraviesan y la prueba del mapa no las ve.
8. Entorno listo: Godot 4.7.2 y Blender 5.3.0 (exportador glTF 5.3.43), ambos utilizables sin
   ventana desde la terminal.

## Decisiones recomendadas

| Decisión | Recomendación |
| --- | --- |
| Formato de intercambio | GLB, confirmado en el repositorio junto a su `.import` |
| Fuentes editables | `.blend` en `VillaSombria/blender/`, **fuera** del proyecto Godot |
| Vía de trabajo | Exportar primero desde Godot (geometría exacta) → `.blend` → retocar a mano o con script → exportar con script |
| Integración | `ModelCatalog` + `MeshBatcher.add_surfaces`: el GLB se fusiona en el lote; el código procedural se queda como alternativa |
| Colisiones, luces, rótulos, interacciones | Siguen en GDScript, sin cambios |
| Personajes | `CharacterModel` como fachada; GLB con seis pivotes y piezas opcionales; colores por material de papel |
| Qué no se migra | Suelos, paredes, barreras, muretes, setos, alfombras, marcador, rótulos |
| Prototipo | `PropsKit.mailbox` (el buzón de la plaza) |

## Punto de partida de la sesión 2

- **Rama:** `feature/blender-auditoria`, creada desde `main` en `85b9f82` (PR #16, sonido
  adaptativo), que contenía todo el código del juego. La única rama con commits fuera de `main`
  era `docs/sustentacion-academica` (sólo documentos de la sustentación): no se incluyó.
- **Commit:** el último de `feature/blender-auditoria`, el que añade este índice
  (`docs(blender): registrar la línea base y el punto de partida de la sesión 2`).
- **Rama nueva:** `feature/blender-prototipo-buzon`, desde ese commit.
- **Pendiente sin confirmar en la carpeta de trabajo:** `new-game-project/project.godot` y
  `new-game-project/scenes/main/main_menu.tscn`, modificados por el editor de Godot abierto (quita
  `MCPRuntime` y el complemento, reordena autoloads y añade UIDs). No forman parte de la migración.
- **Primer paso:** [08-sesion-2.md](08-sesion-2.md), paso 1.
