# 12. Sesión 6: exteriores

Rama `feature/blender-exteriores`, creada desde el cierre de la sesión 5 (`6ef704f`). Lleva a
Blender el atrezo y los detalles de los dos exteriores del juego sin tocar su arquitectura física.

## 6.1. Exteriores del juego

Sólo hay dos: la **Plaza Mayor** y la **Estación**. No se ha inventado ningún escenario.

| | Plaza Mayor | Estación |
| --- | --- | --- |
| Suelos | Calles, aceras y plaza (empedrado por shader) | Andén y calle; vías y balasto |
| Edificios (`BuildingKit.body`) | Café, casa estrecha, archivo, banco | Edificio de la estación |
| Detalles de fachada | Ventanas (rejillas), puertas del café y el archivo, toldo, chimenea, columnas del pórtico | Dos ventanas |
| Piezas propias | Escaparate y rótulo del café, pórtico y torre del reloj del archivo, mansión del fondo, tapia y verja, rótulo del banco, fuente | Tren (locomotora y vagón), taquilla, marquesina, reloj de andén |
| Atrezo | Farolas ×6, bancos ×3, árboles ×4, coche, quiosco, buzón, cajas ×2, barril, poste, mesas de terraza ×2 | Farolas ×4, bancos ×2, cajas ×2, barril, poste |
| Bordes | Muretes ×2, seto, muros invisibles | Muretes ×2, seto, bordillo de las vías |
| Colisiones | 52 | 23 |
| Salidas | Café, archivo (cerrado el domingo), mansión (verja cerrada hasta `llamada_atendida`), estación | Plaza |
| Pistas | `periodico_aniversario` junto al quiosco | — |
| NPC | Ronda del sargento alrededor de la fuente, Lucía, Hilario | Eusebio, Elena |

Ya migrado antes: buzón (sesión 2), barril, caja y mesa de terraza (sesión 4).

## 6.2. Qué se migra y qué no

| Se migra (parte visual) | Se queda procedural |
| --- | --- |
| Farola, banco, árbol, coche, quiosco, poste indicador | Suelos, aceras, bordillos, vías y balasto |
| Ventana, puerta, toldo, chimenea, columna | `BuildingKit.body` (su huella la copian el mapa del pueblo y `test_map`) |
| Escaparate, rótulos, pórtico, torre del reloj, mansión del fondo, tapia y verja, fuente | Muretes y setos (bordes que evitan caídas) |
| Locomotora, vagón, taquilla, marquesina, reloj de andén | Muros invisibles, barreras |

En todos los casos la colisión sigue registrándose en el kit o en el escenario, en el mismo orden.

## 6.3–6.4. Migración y reutilización

- Refactorización (`a34d183`) verificada con la huella de los seis escenarios: idéntica antes y
  después (16.578 polígonos y colisiones).
- **24 modelos nuevos**, todos copia exacta. Reutilización: la farola (10 usos), el banco (5), el
  árbol (4 usos, 4 variantes de altura y otoño), la ventana (una sola fuente con 12 variantes por
  medida, luz y postigos, usada en las fachadas de la plaza, la mansión del fondo y la estación),
  la puerta (color de la hoja como tinte) y la columna (4 usos).
- Las piezas de fachada se colocan en el sistema local de cada edificio (`BuildingKit.begin`):
  la misma ventana sirve para una fachada girada 90° sin cambiar el modelo.

## 6.5. Colisiones y navegación

No se ha cambiado ninguna geometría física: la huella incluye cada colisión (centro, tamaño y
giro) y es idéntica. Las pruebas de límites (`test_world_bounds`, `test_fall_guard`), de
navegación (`test_location_navigation`), de salidas (`test_world`), del mapa (`test_map`, que
compara la ilustración con las colisiones) y de NPC pasan con los modelos activos.

## 6.6. Optimización

Los modelos exteriores son copia exacta: mismas mallas, mismos triángulos y mismas llamadas de
dibujado (cada exterior sigue siendo tres mallas: opaca, brillo y suelo). No se han quitado caras:
las piezas exteriores están exentas (no tienen una pared detrás que tape sus traseras) y pesan poco
(la más pesada, la verja con la tapia, 408 triángulos).

## 6.7. Pruebas

Ver [07-linea-base.md](07-linea-base.md) y el registro de estado.

## Pendiente

- `BuildingKit.body` (cuerpo, zócalo, cornisa y tejado): dos colores por parámetro y huella
  compartida con el mapa; migrarlo exige un tinte de dos colores y no aporta edición útil hoy.
- Suelos, vías, muretes y setos: procedurales por decisión de la auditoría.
- Remodelado artístico (árboles, coche, fuente, tren): los modelos están listos para retocarse en
  Blender con `fiel: false`.
