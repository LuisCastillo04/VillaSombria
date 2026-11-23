# Inventario de modelos migrados

Generado con `python blender/scripts/inventario.py` a partir del registro de modelos, las
referencias y los registros de exportación. No editar a mano: volver a generarlo.

Cada modelo tiene su fuente en `blender/fuentes/<categoría>/<id>.blend`, su GLB en
`new-game-project/assets/modelos/<categoría>/<id>.glb` y su respaldo procedural en el kit o
el escenario que lo dibuja (`ModelCatalog.draw`). Triángulos: de todas las variantes, una vez.

| Categoría | Id | Variantes | Usos | Dónde | Triángulos | Colisiones (kit) | Tinte | Brillo | Fidelidad | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| arquitectura | chimenea_tejado | 1 | 1 | plaza | 24 | 0 | — | — | exacto | migrado |
| arquitectura | columna | 1 | 4 | plaza | 52 | 1 | — | — | exacto | migrado |
| arquitectura | puerta | 2 | 2 | plaza | 120 | 0 | sí | sí | exacto | migrado |
| arquitectura | toldo | 1 | 1 | plaza | 320 | 0 | — | — | exacto | migrado |
| arquitectura | ventana | 12 | 34 | estacion, plaza | 768 | 0 | — | sí | exacto | migrado |
| atrezo | arbol | 4 | 4 | plaza | 656 | 4 | — | — | exacto | migrado |
| atrezo | banco | 1 | 5 | estacion, plaza | 108 | 1 | — | — | exacto | migrado |
| atrezo | barril | 1 | 3 | cafe, estacion, plaza | 84 | 1 | — | — | exacto | migrado |
| atrezo | buzon | 1 | 1 | plaza | 68 | 1 | — | — | exacto | migrado |
| atrezo | caja | 2 | 5 | cafe, estacion, plaza | 48 | 2 | — | — | exacto | migrado |
| atrezo | coche | 1 | 1 | plaza | 252 | 1 | — | sí | exacto | migrado |
| atrezo | farola | 1 | 13 | estacion, plaza | 92 | 1 | — | sí | exacto | migrado |
| atrezo | mesa_cafe | 1 | 7 | cafe, plaza | 136 | 3 | — | — | exacto | migrado |
| atrezo | poste_indicador | 2 | 2 | estacion, plaza | 88 | 2 | — | — | exacto | migrado |
| atrezo | quiosco | 1 | 1 | plaza | 192 | 1 | — | — | exacto | migrado |
| escenario | barra_cafe | 1 | 1 | cafe | 36 | 1 | — | — | exacto | migrado |
| escenario | botellero_cafe | 1 | 1 | cafe | 1452 | 0 | — | — | exacto | migrado |
| escenario | copa | 1 | 1 | mansion | 24 | 0 | — | — | exacto | migrado |
| escenario | escaparate_cafe | 1 | 1 | plaza | 84 | 0 | — | sí | exacto | migrado |
| escenario | foto | 1 | 1 | mansion | 12 | 0 | — | — | exacto | migrado |
| escenario | fuente | 1 | 1 | plaza | 234 | 2 | — | — | exacto | migrado |
| escenario | huellas_betun | 1 | 1 | mansion | 60 | 0 | — | — | exacto | migrado |
| escenario | libro | 4 | 4 | archivo, mansion | 48 | 0 | sí | — | exacto | migrado |
| escenario | locomotora | 1 | 1 | estacion | 396 | 0 | — | sí | exacto | migrado |
| escenario | mansion_fondo | 1 | 1 | plaza | 18 | 0 | — | — | exacto | migrado |
| escenario | marquesina | 1 | 1 | estacion | 84 | 3 | — | — | exacto | migrado |
| escenario | mesilla | 1 | 1 | cafe | 12 | 1 | — | — | exacto | migrado |
| escenario | mostrador_archivo | 1 | 1 | archivo | 24 | 1 | — | — | exacto | migrado |
| escenario | papeles | 4 | 4 | archivo, cafe, mansion | 48 | 0 | sí | — | exacto | migrado |
| escenario | portico_archivo | 1 | 1 | plaza | 29 | 0 | — | — | exacto | migrado |
| escenario | reloj_anden | 1 | 1 | estacion | 56 | 1 | — | sí | exacto | migrado |
| escenario | reloj_caido | 1 | 1 | mansion | 48 | 0 | — | — | exacto | migrado |
| escenario | rotulo_banco | 1 | 1 | plaza | 12 | 0 | — | — | exacto | migrado |
| escenario | rotulo_cafe | 1 | 1 | plaza | 12 | 0 | — | — | exacto | migrado |
| escenario | tablero_llaves | 1 | 1 | mansion | 60 | 0 | — | — | exacto | migrado |
| escenario | taburete | 1 | 5 | cafe | 40 | 1 | — | — | exacto | migrado |
| escenario | taquilla | 1 | 1 | estacion | 60 | 0 | — | sí | exacto | migrado |
| escenario | telefono | 1 | 1 | cafe | 24 | 0 | — | — | exacto | migrado |
| escenario | tintero | 1 | 1 | mansion | 12 | 0 | — | — | exacto | migrado |
| escenario | torre_reloj | 1 | 1 | plaza | 96 | 0 | — | sí | exacto | migrado |
| escenario | vagon | 1 | 1 | estacion | 364 | 0 | — | sí | exacto | migrado |
| escenario | verja_mansion | 1 | 1 | plaza | 408 | 5 | — | sí | exacto | migrado |
| mobiliario | archivador | 1 | 4 | archivo | 108 | 1 | — | — | exacto | migrado |
| mobiliario | cama | 3 | 3 | cafe, mansion | 180 | 3 | sí | — | exacto | migrado |
| mobiliario | chimenea | 1 | 1 | mansion | 48 | 1 | — | sí | exacto | migrado |
| mobiliario | comoda | 4 | 4 | cafe, mansion | 216 | 4 | — | — | exacto | migrado |
| mobiliario | cuadro | 2 | 2 | archivo, mansion | 48 | 0 | sí | — | exacto | migrado |
| mobiliario | escritorio | 1 | 1 | mansion | 60 | 1 | — | — | exacto | migrado |
| mobiliario | estanteria | 4 | 11 | archivo, mansion | 3932 | 4 | — | — | optimizado | migrado |
| mobiliario | lampara_pie | 1 | 4 | archivo, cafe, mansion | 60 | 1 | — | sí | exacto | migrado |
| mobiliario | lampara_techo | 1 | 14 | archivo, cafe, mansion | 40 | 0 | — | sí | exacto | migrado |
| mobiliario | mesa | 6 | 6 | archivo, cafe, mansion | 360 | 6 | sí | — | exacto | migrado |
| mobiliario | planta | 1 | 4 | cafe, mansion | 60 | 1 | — | — | exacto | migrado |
| mobiliario | reloj_pie | 1 | 1 | mansion | 84 | 1 | — | — | exacto | migrado |
| mobiliario | silla | 1 | 8 | archivo, cafe, mansion | 72 | 1 | sí | — | exacto | migrado |
| mobiliario | sillon | 1 | 2 | mansion | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | sofa | 1 | 1 | mansion | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | ventana_interior | 4 | 4 | archivo, cafe, mansion | 192 | 0 | — | sí | exacto | migrado |
| personajes | personaje_anselmo | 6 | 6 | personaje | 292 | 0 | — | — | exacto | migrado |
| personajes | personaje_detective | 6 | 6 | personaje | 390 | 0 | — | — | exacto | migrado |
| personajes | personaje_elena | 6 | 6 | personaje | 446 | 0 | — | — | exacto | migrado |
| personajes | personaje_eusebio | 6 | 6 | personaje | 322 | 0 | — | — | exacto | migrado |
| personajes | personaje_hilario | 6 | 6 | personaje | 276 | 0 | — | — | exacto | migrado |
| personajes | personaje_irene | 6 | 6 | personaje | 366 | 0 | — | — | exacto | migrado |
| personajes | personaje_lucia | 6 | 6 | personaje | 330 | 0 | — | — | exacto | migrado |
| personajes | personaje_marcos | 6 | 6 | personaje | 294 | 0 | — | — | exacto | migrado |
| personajes | personaje_ortega | 6 | 6 | personaje | 338 | 0 | — | — | exacto | migrado |
| personajes | personaje_rosa | 6 | 6 | personaje | 396 | 0 | — | — | exacto | migrado |

**Total:** 68 modelos, 251 usos en el juego, 15767 triángulos en los GLB.
