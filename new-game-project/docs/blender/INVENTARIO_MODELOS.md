# Inventario de modelos migrados

Generado con `python blender/scripts/inventario.py` a partir del registro de modelos, las
referencias y los registros de exportación. No editar a mano: volver a generarlo.

Cada modelo tiene su fuente en `blender/fuentes/<categoría>/<id>.blend`, su GLB en
`new-game-project/assets/modelos/<categoría>/<id>.glb` y su respaldo procedural en el kit o
el escenario que lo dibuja (`ModelCatalog.draw`). Triángulos: de todas las variantes, una vez.
Validación de todos: `tools/modelos/validar_modelos.tscn` y `tests/unit/test_models.gd`
(los personajes, además, `tests/unit/test_personajes.gd`). Estado «migrado» = existen el .blend,
el GLB y su .import.

| Categoría | Id | Variantes | Usos | Dónde | Usado por (con su respaldo procedural) | Triángulos | Colisiones (kit) | Tinte | Brillo | Fidelidad | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| arquitectura | aviso | 1 | 1 | plaza | `building_kit.gd` | 32 | 0 | — | — | exacto | migrado |
| arquitectura | chimenea_tejado | 1 | 1 | plaza | `building_kit.gd` | 24 | 0 | — | — | exacto | migrado |
| arquitectura | columna | 1 | 4 | plaza | `building_kit.gd` | 52 | 1 | — | — | exacto | migrado |
| arquitectura | puerta | 2 | 2 | plaza | `building_kit.gd` | 120 | 0 | sí | sí | exacto | migrado |
| arquitectura | puerta_doble | 1 | 1 | plaza | `building_kit.gd` | 180 | 2 | — | sí | exacto | migrado |
| arquitectura | toldo | 1 | 1 | plaza | `building_kit.gd` | 320 | 0 | — | — | exacto | migrado |
| arquitectura | ventana | 12 | 34 | estacion, plaza | `building_kit.gd` | 768 | 0 | — | sí | exacto | migrado |
| atrezo | alcorque | 1 | 3 | plaza | `props_kit.gd` | 122 | 0 | — | — | exacto | migrado |
| atrezo | arbol | 4 | 4 | plaza | `props_kit.gd` | 656 | 4 | — | — | exacto | migrado |
| atrezo | banco | 1 | 5 | estacion, plaza | `props_kit.gd` | 108 | 1 | — | — | exacto | migrado |
| atrezo | barril | 1 | 3 | cafe, estacion, plaza | `props_kit.gd` | 84 | 1 | — | — | exacto | migrado |
| atrezo | buzon | 1 | 1 | plaza | `props_kit.gd` | 68 | 1 | — | — | exacto | migrado |
| atrezo | caja | 2 | 5 | cafe, estacion, plaza | `props_kit.gd` | 48 | 2 | — | — | exacto | migrado |
| atrezo | coche | 1 | 1 | plaza | `props_kit.gd` | 252 | 1 | — | sí | exacto | migrado |
| atrezo | farola | 1 | 13 | estacion, plaza | `props_kit.gd` | 92 | 1 | — | sí | exacto | migrado |
| atrezo | jardinera | 1 | 1 | plaza | `props_kit.gd` | 538 | 8 | — | — | exacto | migrado |
| atrezo | mesa_cafe | 1 | 7 | cafe, plaza | `props_kit.gd` | 136 | 3 | — | — | exacto | migrado |
| atrezo | parterre | 8 | 8 | estacion, plaza | `props_kit.gd` | 4072 | 8 | — | — | exacto | migrado |
| atrezo | poste_indicador | 2 | 2 | estacion, plaza | `props_kit.gd` | 88 | 2 | — | — | exacto | migrado |
| atrezo | quiosco | 1 | 1 | plaza | `props_kit.gd` | 192 | 1 | — | — | exacto | migrado |
| atrezo | valla_obras | 1 | 1 | plaza | `props_kit.gd` | 110 | 1 | — | — | exacto | migrado |
| escenario | barra_cafe | 1 | 1 | cafe | `cafe.gd` | 36 | 1 | — | — | exacto | migrado |
| escenario | botellero_cafe | 1 | 1 | cafe | `cafe.gd` | 1452 | 0 | — | — | exacto | migrado |
| escenario | copa | 1 | 1 | mansion | `mansion.gd` | 24 | 0 | — | — | exacto | migrado |
| escenario | escaparate_cafe | 1 | 1 | plaza | `plaza.gd` | 84 | 0 | — | sí | exacto | migrado |
| escenario | foto | 1 | 1 | mansion | `mansion.gd` | 12 | 0 | — | — | exacto | migrado |
| escenario | fuente | 1 | 1 | plaza | `plaza.gd` | 234 | 2 | — | — | exacto | migrado |
| escenario | huellas_betun | 1 | 1 | mansion | `mansion.gd` | 60 | 0 | — | — | exacto | migrado |
| escenario | libro | 4 | 4 | archivo, mansion | `archivo.gd`, `cafe.gd`, `mansion.gd` | 48 | 0 | sí | — | exacto | migrado |
| escenario | locomotora | 1 | 1 | estacion | `estacion.gd` | 396 | 0 | — | sí | exacto | migrado |
| escenario | mansion_fondo | 1 | 1 | plaza | `plaza.gd` | 18 | 0 | — | — | exacto | migrado |
| escenario | marquesina | 1 | 1 | estacion | `estacion.gd` | 84 | 3 | — | — | exacto | migrado |
| escenario | mesilla | 1 | 1 | cafe | `cafe.gd` | 12 | 1 | — | — | exacto | migrado |
| escenario | mostrador_archivo | 1 | 1 | archivo | `archivo.gd` | 24 | 1 | — | — | exacto | migrado |
| escenario | papeles | 4 | 4 | archivo, cafe, mansion | `archivo.gd`, `cafe.gd`, `mansion.gd` | 48 | 0 | sí | — | exacto | migrado |
| escenario | portico_archivo | 1 | 1 | plaza | `plaza.gd` | 29 | 0 | — | — | exacto | migrado |
| escenario | reloj_anden | 1 | 1 | estacion | `estacion.gd` | 56 | 1 | — | sí | exacto | migrado |
| escenario | reloj_caido | 1 | 1 | mansion | `mansion.gd` | 48 | 0 | — | — | exacto | migrado |
| escenario | rotulo_banco | 1 | 1 | plaza | `plaza.gd` | 12 | 0 | — | — | exacto | migrado |
| escenario | rotulo_cafe | 1 | 1 | plaza | `plaza.gd` | 12 | 0 | — | — | exacto | migrado |
| escenario | tablero_llaves | 1 | 1 | mansion | `mansion.gd` | 60 | 0 | — | — | exacto | migrado |
| escenario | taburete | 1 | 5 | cafe | `cafe.gd` | 40 | 1 | — | — | exacto | migrado |
| escenario | taquilla | 1 | 1 | estacion | `estacion.gd` | 60 | 0 | — | sí | exacto | migrado |
| escenario | telefono | 1 | 1 | cafe | `cafe.gd` | 24 | 0 | — | — | exacto | migrado |
| escenario | tintero | 1 | 1 | mansion | `mansion.gd` | 12 | 0 | — | — | exacto | migrado |
| escenario | torre_reloj | 1 | 1 | plaza | `plaza.gd` | 96 | 0 | — | sí | exacto | migrado |
| escenario | vagon | 1 | 1 | estacion | `estacion.gd` | 364 | 0 | — | sí | exacto | migrado |
| escenario | verja_mansion | 1 | 1 | plaza | `plaza.gd` | 408 | 5 | — | sí | exacto | migrado |
| mobiliario | archivador | 1 | 4 | archivo | `interior_kit.gd` | 108 | 1 | — | — | exacto | migrado |
| mobiliario | cama | 3 | 3 | cafe, mansion | `interior_kit.gd` | 180 | 3 | sí | — | exacto | migrado |
| mobiliario | chimenea | 1 | 1 | mansion | `interior_kit.gd` | 48 | 1 | — | sí | exacto | migrado |
| mobiliario | comoda | 4 | 4 | cafe, mansion | `interior_kit.gd` | 216 | 4 | — | — | exacto | migrado |
| mobiliario | cuadro | 2 | 2 | archivo, mansion | `interior_kit.gd` | 48 | 0 | sí | — | exacto | migrado |
| mobiliario | escritorio | 1 | 1 | mansion | `interior_kit.gd` | 60 | 1 | — | — | exacto | migrado |
| mobiliario | estanteria | 4 | 11 | archivo, mansion | `interior_kit.gd` | 3856 | 4 | — | — | optimizado | migrado |
| mobiliario | lampara_pie | 1 | 4 | archivo, cafe, mansion | `interior_kit.gd` | 60 | 1 | — | sí | exacto | migrado |
| mobiliario | lampara_techo | 1 | 14 | archivo, cafe, mansion | `interior_kit.gd` | 40 | 0 | — | sí | exacto | migrado |
| mobiliario | mesa | 6 | 6 | archivo, cafe, mansion | `interior_kit.gd` | 360 | 6 | sí | — | exacto | migrado |
| mobiliario | planta | 1 | 4 | cafe, mansion | `interior_kit.gd` | 60 | 1 | — | — | exacto | migrado |
| mobiliario | reloj_pie | 1 | 1 | mansion | `interior_kit.gd` | 84 | 1 | — | — | exacto | migrado |
| mobiliario | silla | 1 | 8 | archivo, cafe, mansion | `interior_kit.gd` | 72 | 1 | sí | — | exacto | migrado |
| mobiliario | sillon | 1 | 2 | mansion | `interior_kit.gd` | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | sofa | 1 | 1 | mansion | `interior_kit.gd` | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | ventana_interior | 4 | 4 | archivo, cafe, mansion | `interior_kit.gd` | 192 | 0 | — | sí | exacto | migrado |
| personajes | personaje_anselmo | 6 | 6 | personaje | `character_model.gd` | 292 | 0 | — | — | exacto | migrado |
| personajes | personaje_detective | 6 | 6 | personaje | `character_model.gd` | 390 | 0 | — | — | exacto | migrado |
| personajes | personaje_elena | 6 | 6 | personaje | `character_model.gd` | 446 | 0 | — | — | exacto | migrado |
| personajes | personaje_eusebio | 6 | 6 | personaje | `character_model.gd` | 322 | 0 | — | — | exacto | migrado |
| personajes | personaje_hilario | 6 | 6 | personaje | `character_model.gd` | 276 | 0 | — | — | exacto | migrado |
| personajes | personaje_irene | 6 | 6 | personaje | `character_model.gd` | 366 | 0 | — | — | exacto | migrado |
| personajes | personaje_lucia | 6 | 6 | personaje | `character_model.gd` | 330 | 0 | — | — | exacto | migrado |
| personajes | personaje_marcos | 6 | 6 | personaje | `character_model.gd` | 294 | 0 | — | — | exacto | migrado |
| personajes | personaje_ortega | 6 | 6 | personaje | `character_model.gd` | 338 | 0 | — | — | exacto | migrado |
| personajes | personaje_rosa | 6 | 6 | personaje | `character_model.gd` | 396 | 0 | — | — | exacto | migrado |

**Total:** 74 modelos, 266 usos en el juego, 20745 triángulos en los GLB.
