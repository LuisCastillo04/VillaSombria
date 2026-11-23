# 11. Sesión 5: interiores

Rama `feature/blender-interiores`, creada desde el cierre de la sesión 4 (`3dc3a57`). Lleva a
Blender lo que quedaba de visual en los interiores (las piezas propias de cada escenario) y
optimiza el escenario más pesado, sin tocar su arquitectura espacial.

## 5.1. Auditoría de los interiores

Interiores reales del juego: **Café La Luna** (con la pensión y la trastienda), **Mansión Valdés**
y **Archivo municipal**. No hay otros (la plaza y la estación son exteriores; `test_ground` es un
campo de pruebas).

| | Café La Luna | Mansión Valdés | Archivo municipal |
| --- | --- | --- | --- |
| Suelos | Baldosa (salón), tablones (pensión, trastienda) | Tablones y baldosa por estancia | Tablones |
| Paredes | 6 tramos, puerta a la calle sellada | 9 tramos, puerta sellada | 4 tramos, puerta sellada |
| Mobiliario (sesión 4) | Mesas de terraza ×5, cama, cómoda, mesa, lámparas, planta, ventana, sillas ×3, caja, barril | Sofá, sillones, mesas ×4, escritorio, estanterías ×3, camas ×2, cómodas ×3, chimenea, cuadro, ventanas ×2, plantas ×3, reloj de pie, lámparas | Estanterías ×8, archivadores ×4, mesa, sillas ×3, lámparas, ventana, cuadro |
| Piezas propias (sesión 5) | Barra, taburetes ×5, botellero con espejo, teléfono, mesilla, papeles | Tintero, copa, reloj caído y cristales, huellas de betún, libros ×2, papeles, foto, tablero de llaves | Mostrador, papeles ×2, libros ×2 |
| Luces | 7 (1 con sombra) | 8 (3) | 4 (1) |
| Colisiones | 43 | 44 | 25 |
| Pistas y objetos interactivos | Cama (`RestPoint`), salida | 9 pistas, salida | Salida (cerrada el domingo) |
| NPC (marcadores) | Rosa, Ortega, clientes (10 marcadores) | Familia y servicio (10) | Hilario (4) |
| Navegación | Horneada con las colisiones al entrar (`LocationNavigation`) | Ídem | Ídem |

## 5.2. Límites

Se respetan las decisiones de la auditoría: **suelos, paredes, barreras, alfombras y sellos de las
puertas siguen procedurales**. No se reconstruye la distribución de ninguna estancia.

## 5.3–5.5. Migración

- **Refactorización** (`16f7d94`): cada pieza propia se dibuja con
  `ModelCatalog.draw` y conserva fuera sus colisiones, rótulos, luces, pistas y salidas, en el
  mismo orden. Huella de los seis escenarios idéntica antes y después.
- **14 modelos nuevos** (categoría `escenario`), todos copia exacta de su pieza:

| Escenario | Modelos | Notas |
| --- | --- | --- |
| Café | `barra_cafe`, `taburete` (5 usos), `botellero_cafe` (1.452 triángulos), `telefono`, `mesilla`, `papeles` | La barra conserva su colisión de 9 × 1,1 × 0,7 m; los puestos de detrás de la barra (`barra*`) y los de los clientes no cambian |
| Mansión | `tintero`, `copa`, `reloj_caido`, `huellas_betun`, `foto`, `tablero_llaves`, `libro`, `papeles` | Cada objeto sigue exactamente donde estaba, junto a su pista (`copa_lavada`, `reloj_despacho`, `huellas_betun`, `foto_clara`, `llave_reloj`, `carta_amor`, `libro_bodega`, `lista_invitados`) |
| Archivo | `mostrador_archivo`, `papeles`, `libro` | El mostrador conserva su colisión y el puesto «mostrador» de Hilario |

- **Compartidos:** `papeles` y `libro` se usan en los tres interiores: un objeto por medida y el
  color como tinte. No se duplicó ningún `.blend` ni GLB.

## 5.6. Coherencia visual

Todos los modelos son copia exacta de su pieza procedural (misma paleta, proporciones y tono por
cara), salvo las estanterías, a las que sólo les faltan caras que no se ven. Las luces, rótulos,
niebla y filtros siguen siendo los mismos porque los modelos se dibujan con los materiales del
lote. Capturas con y sin modelos: diferencias al nivel del ruido (NPC en otra postura).

## 5.7. Optimización

| Medida | Antes (procedural) | Después |
| --- | --- | --- |
| Triángulos de las estanterías (4 variantes) | 5.748 | 3.932 |
| Triángulos opacos del archivo | 13.082 | 9.342 (-29 %) |
| Triángulos opacos de la mansión | 6.752 | 5.558 (-18 %) |
| Primitivas por fotograma del archivo (`--stats`, incluye sombras) | 99.872 | 73.692 (-26 %) |
| Primitivas por fotograma de la mansión | 140.968 | 118.270 (-16 %) |
| Llamadas de dibujado (café, mansión, archivo) | 235, 327–328, 226 | Iguales |
| Mallas por escenario | 2–3 | 2–3 (los modelos se fusionan en el lote) |
| Tamaño de los GLB de todo el juego | — | 764 kB (`assets/modelos/` con los `.import`: 928 kB) |
| Fuentes `.blend` (fuera del juego) | — | 3,2 MB |

Se quitaron sólo caras que la cámara de exploración (inclinación fija de -36°) no puede ver:
las que miran hacia abajo y las traseras interiores tapadas enteras por el fondo del mueble. Un
primer criterio más amplio quitaba también la trasera de los libros que asoman por encima del
fondo; la comparación de capturas lo detectó (528 píxeles distintos en la zona) y se corrigió
(23 píxeles, igual que el ruido). La prueba `test_optimized_models_only_drop_hidden_faces` lo
impide en adelante.

La memoria de vídeo no cambia apreciablemente: cada escenario sigue siendo una malla por capa y los
modelos sólo se leen al construir el escenario (caché por id en `ModelCatalog`).

## 5.8. Pruebas de funcionamiento

La batería cubre cada sistema con los modelos activos (son los que usa el juego por defecto):

| Sistema | Pruebas |
| --- | --- |
| Entrada y salida de interiores, transiciones | `test_world` (salidas hacia apariciones reales), `test_integration`, `test_save_navigation` |
| Movimiento, colisiones, caídas al vacío | `test_player`, `test_world_bounds`, `test_fall_guard` |
| Navegación y rutinas de NPC | `test_location_navigation`, `test_npc`, `test_npc_layout`, `test_npc_leave`, `test_npc_interaction`, `test_cafe_first_visit` |
| Diálogos, pistas, interactuables | `test_dialogue`, `test_evidence`, `test_investigation`, `test_story` |
| Guardado y carga | `test_save`, `test_save_format`, `test_autosave`, `test_save_slots` y los reinicios de `verificar.ps1` |
| Mapa | `test_map`, `test_map_screen` |
| Modelos | `test_models` (equivalencia pieza a pieza y por escenario, optimizados, respaldos) |

Compatibilidad con partidas guardadas: el formato de guardado no ha cambiado (ningún archivo de
`scripts/save/` ni de `SaveSystem` se ha tocado) y ningún id visual se guarda. Las pruebas de
formato (ida y vuelta, versiones futuras, archivos dañados) y los reinicios de `verificar.ps1`
(guardar en un proceso y cargar en otro) siguen pasando. No había partidas antiguas de prueba en el
repositorio para cargarlas tal cual; las partidas del jugador no se han tocado.

## Pendiente

- Alfombras, suelos, paredes y barreras: procedurales por decisión de la auditoría.
- Retoques artísticos en Blender: los modelos son copias exactas; mejorar su aspecto es trabajo
  posterior (con `fiel: false` y capturas).
