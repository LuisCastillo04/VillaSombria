# Inventario de modelos migrados

Generado con `python blender/scripts/inventario.py` a partir del registro de modelos, las
referencias y los registros de exportación. No editar a mano: volver a generarlo.

Cada modelo tiene su fuente en `blender/fuentes/<categoría>/<id>.blend`, su GLB en
`new-game-project/assets/modelos/<categoría>/<id>.glb` y su respaldo procedural en el kit o
el escenario que lo dibuja (`ModelCatalog.draw`). Triángulos: de todas las variantes, una vez.

| Categoría | Id | Variantes | Usos | Dónde | Triángulos | Colisiones (kit) | Tinte | Brillo | Fidelidad | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atrezo | barril | 1 | 3 | cafe, estacion, plaza | 84 | 1 | — | — | exacto | migrado |
| atrezo | buzon | 1 | 1 | plaza | 68 | 1 | — | — | exacto | migrado |
| atrezo | caja | 2 | 5 | cafe, estacion, plaza | 48 | 2 | — | — | exacto | migrado |
| atrezo | mesa_cafe | 1 | 7 | cafe, plaza | 136 | 3 | — | — | exacto | migrado |
| mobiliario | archivador | 1 | 4 | archivo | 108 | 1 | — | — | exacto | migrado |
| mobiliario | cama | 3 | 3 | cafe, mansion | 180 | 3 | sí | — | exacto | migrado |
| mobiliario | chimenea | 1 | 1 | mansion | 48 | 1 | — | sí | exacto | migrado |
| mobiliario | comoda | 4 | 4 | cafe, mansion | 216 | 4 | — | — | exacto | migrado |
| mobiliario | cuadro | 2 | 2 | archivo, mansion | 48 | 0 | sí | — | exacto | migrado |
| mobiliario | escritorio | 1 | 1 | mansion | 60 | 1 | — | — | exacto | migrado |
| mobiliario | estanteria | 4 | 11 | archivo, mansion | 5748 | 4 | — | — | exacto | migrado |
| mobiliario | lampara_pie | 1 | 4 | archivo, cafe, mansion | 60 | 1 | — | sí | exacto | migrado |
| mobiliario | lampara_techo | 1 | 14 | archivo, cafe, mansion | 40 | 0 | — | sí | exacto | migrado |
| mobiliario | mesa | 6 | 6 | archivo, cafe, mansion | 360 | 6 | sí | — | exacto | migrado |
| mobiliario | planta | 1 | 4 | cafe, mansion | 60 | 1 | — | — | exacto | migrado |
| mobiliario | reloj_pie | 1 | 1 | mansion | 84 | 1 | — | — | exacto | migrado |
| mobiliario | silla | 1 | 8 | archivo, cafe, mansion | 72 | 1 | sí | — | exacto | migrado |
| mobiliario | sillon | 1 | 2 | mansion | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | sofa | 1 | 1 | mansion | 48 | 1 | sí | — | exacto | migrado |
| mobiliario | ventana_interior | 4 | 4 | archivo, cafe, mansion | 192 | 0 | — | sí | exacto | migrado |

**Total:** 20 modelos, 86 usos en el juego, 7708 triángulos en los GLB.
