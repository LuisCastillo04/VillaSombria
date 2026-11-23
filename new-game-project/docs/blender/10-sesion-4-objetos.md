# 10. Sesión 4: objetos y mobiliario

Rama `feature/blender-objetos`, creada desde el cierre de la sesión 3 (`5e1b91f`). Aplica la
arquitectura de la sesión 3 ([09-sistema-de-modelos.md](09-sistema-de-modelos.md)) a todo el
mobiliario de `InteriorKit` y a los objetos de `PropsKit` que se usan dentro y fuera.

## 4.1. Inventario y selección

Fuente: [01-inventario.md](01-inventario.md) (sesión 1) y la captura de los escenarios reales
(`exportar_referencias.tscn`), que cuenta cada uso y cada medida. Todos los muebles listados en la
auditoría existen como funciones del kit; ninguno es un recurso independiente previo.

| Pieza | Función | Complejidad (tri.) | Usos | Variantes | Colisión | Interacciones cercanas | Riesgo | Decisión |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Silla | `chair` | 72 | 8 | color → tinte | 1 caja (kit) | Ninguna | Bajo | Migrada |
| Sillón | `armchair` | 48 | 2 | color → tinte | 1 caja | Puesto «salon_este» | Bajo | Migrada |
| Sofá | `sofa` | 48 | 1 | largo + tinte | 1 caja | Puesto «salon_sofa» | Bajo | Migrada |
| Mesa | `table` | 60 | 6 | 6 medidas + tinte | 1 caja | **Pistas `carta_amor`, `lista_invitados`, `libro_bodega`** encima o al lado | Medio | Migrada; colisión y altura sin cambios |
| Escritorio | `desk` | 60 | 1 | medida | 1 caja | **Pista `copa_lavada`** encima | Medio | Migrada; `solid` partido en caja + colisión |
| Estantería | `bookshelf` | 1.044–2.052 | 11 | 4 medidas | 1 caja | Puesto «ficheros» cerca | Bajo | Migrada (copia exacta); optimización en la sesión 5 |
| Archivador | `filing_cabinet` | 108 | 4 | — | 1 caja | Puesto «ficheros» | Bajo | Migrada |
| Chimenea | `fireplace` | 48 (12 brillo) | 1 | ancho | 1 caja + luz | Puesto «salon_chimenea» | Bajo | Migrada; la luz sigue en el kit |
| Lámpara de pie | `floor_lamp` | 60 (24 brillo) | 4 | — | 1 caja + luz | — | Bajo | Migrada |
| Lámpara de techo | `ceiling_lamp` | 40 (28 brillo) | 14 | — | sin colisión; luz | — | Bajo | Migrada |
| Cama | `bed` | 60 | 3 | 3 medidas + colcha | 1 caja | **Cama del café: `RestPoint` y aparición «cama»** | Medio | Migrada; colisión y punto de descanso sin cambios |
| Cómoda | `dresser` | 48/72 | 4 | 4 anchos, espejo | 1 caja | **Pista `foto_clara`** (office) | Medio | Migrada |
| Cuadro | `painting` | 24 | 2 | 2 medidas + lienzo | — | — | Bajo | Migrada |
| Ventana del fondo | `back_window` | 48 (12 brillo) | 4 | 4 medidas | — | — | Bajo | Migrada |
| Planta | `plant` | 60 | 4 | — | 1 caja | — | Bajo | Migrada |
| Reloj de pie | `grandfather_clock` | 84 | 1 | — | 1 caja | Temático | Bajo | Migrada |
| Barril | `PropsKit.barrel` | 84 | 3 | — | 1 caja | — | Bajo | Migrada (compartida con exteriores) |
| Caja | `PropsKit.crate` | 24 | 5 | 2 lados | 1 caja | — | Bajo | Migrada (compartida) |
| Mesa de terraza | `PropsKit.cafe_table` | 136 | 7 | — | 3 cajas | Puestos «mesa_*» del café | Bajo | Migrada (compartida) |
| Alfombra | `rug` | 36 | 6 | medida y color libres | — | `register_surface` (pasos) | Medio | **No se migra** (decisión de la auditoría) |
| Suelos, paredes, barreras | `plank_floor`, `tile_floor`, `wall`, `seal_street_door` | — | — | — | Sí | Bordes, pasos, puertas | Alto | **No se migran** |

## 4.2–4.4. Migración, reutilización e interactuables

- **Refactorización previa** (`9e4516c`): cada pieza dibuja su malla con `ModelCatalog.draw` y
  una función `_<pieza>_mesh`; colisiones y luces se quedan en el kit. La **huella** de los seis
  escenarios (`tools/modelos/huella_escenarios.tscn`: 16.578 polígonos y colisiones) es idéntica
  antes y después: la refactorización no cambia nada de lo que se dibuja ni de lo que choca.
- **Reutilización:** un `.blend` y un GLB por pieza, con todas sus medidas como objetos
  (`Mesa_120x76x80`…). 20 modelos cubren **86 usos** en el juego; las 14 lámparas de techo, por
  ejemplo, salen de un solo objeto. El color por parámetro (tapicerías, mesas, colchas, lienzos)
  es un tinte: no hace falta un modelo por color.
- **Interactuables:** ningún `Interactable`, pista, salida, punto de descanso, marcador ni
  colisión ha cambiado de sitio ni de tamaño (la huella incluye las colisiones). Las pistas
  apoyadas en muebles siguen a la misma altura: el mueble es geométricamente idéntico.

## 4.5. Validación

| Comprobación | Resultado |
| --- | --- |
| `validar_modelos` (20 modelos) | 0 errores, 0 avisos |
| `test_each_model_matches_its_procedural_piece` | Cada uso de cada pieza (86) coincide con su código: superficie, plano, color a 1/255 y cara frontal |
| `test_locations_match_with_and_without_models` | Los cinco escenarios, iguales con y sin modelos, mismas colisiones |
| Prueba de mutación | Cambiar el color de las patas de la silla (0,3 → 0,4) hace fallar la prueba en sus ocho usos |
| Llamadas de dibujado (`--stats`, 1280 × 720) | Café 235, mansión 328, archivo 226: iguales con modelos y en modo procedural |
| Capturas modelo frente a procedural | Café media 0,65 por píxel, mansión 2,7, archivo 2,7: sólo NPC en otra postura |
| Batería completa | Ver [07-linea-base.md](07-linea-base.md) |

Incidencias resueltas durante la sesión:

1. **Tapas coincidentes del barril:** al unir vértices Blender borraba una de dos caras
   superpuestas con normales opuestas (78 de 84 triángulos). El importador deja el objeto sin
   unir cuando eso pasa (`b7e6764`).
2. **Tono de caras vecinas coplanarias:** al reagrupar los triángulos por arista y color, el
   respaldo y el asiento de una silla compartían tono. El GLB lleva ahora el número de polígono de
   Blender en un mapa UV y el juego agrupa por él (`9a0fb14`).
3. **Comparación robusta:** la prueba compara por superficie cubierta (coordenadas baricéntricas,
   rejilla con margen) en lugar de reconstruir polígonos; la anterior daba falsos fallos con caras
   superpuestas y en los bordes de la rejilla.

## Pendiente

- Optimizar las estanterías (las caras que la cámara no ve): sesión 5.
- `rug`, suelos, paredes y barreras siguen procedurales por decisión de la auditoría.
