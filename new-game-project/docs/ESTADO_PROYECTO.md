# Estado del proyecto

Las fases 0 a 10 están implementadas y el caso se puede jugar de principio a fin.

**Falta una partida completa jugada por una persona.** Ver [Qué no se ha comprobado](#qué-no-se-ha-comprobado).

## Entorno comprobado

- Godot 4.7.2 stable (Steam): `D:\Program Files (x86)\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.
  No está en el PATH; `tools/verificar.ps1` usa esa ruta o la variable `GODOT_BIN`.
- GPU NVIDIA GeForce GTX 1650 Ti, con una Intel UHD integrada y dos pantallas.
- Proyecto Godot en `new-game-project/`, la ruta original del repositorio.
- Identidad Git: `Luis Castillo <161898989+LuisCastillo04@users.noreply.github.com>`, dirección
  noreply de GitHub que coincide con el remoto `LuisCastillo04/VillaSombria`.
- Los commits son locales: no se hace push sin autorización del propietario.

## Fases

| Fase | Estado | Cómo se verificó |
| --- | --- | --- |
| 0. Preparación | Hecha | Importación y arranque por terminal |
| 1. Detective y exploración | Hecha | Pruebas con entradas simuladas y captura |
| 2. Plaza | Hecha | Capturas de varios puntos y pruebas de escenario |
| 3. NPC | Hecha | Pruebas de rutinas y comportamiento |
| 4. Diálogos con siluetas | Hecha | Pruebas de lógica y de interfaz; capturas |
| 5. Investigación | Hecha | Pruebas y capturas |
| 6. Tablero de deducción | Hecha | Pruebas a través de la interfaz y capturas |
| 7. Tiempo y rutinas | Hecha | Pruebas de eventos, horarios y puertas |
| 8. Escenarios adicionales | Hecha | Capturas y pruebas de alcance con colisiones reales |
| 9. Historia jugable | Hecha | Recorrido automático completo del caso |
| 10. Pulido e interfaces | Hecha | Pruebas y capturas; audio sin escuchar |

Diferencias con el encargo:

- **Fase 3:** se pasó directamente a los personajes reales, sin NPC de prueba.
- **Fase 3:** los NPC usan puntos de ruta, no navegación. Al cambiar de escenario según su rutina,
  aparecen y desaparecen en lugar de caminar hasta la puerta.
- **Fase 8:** el piso superior de la mansión y la bodega no existen como espacios recorribles.

## Pruebas

`tools/verificar.ps1` importa el proyecto, arranca la escena principal y ejecuta las pruebas.

Último resultado: 82 pruebas correctas, 0 fallos.

| Archivo | Cubre |
| --- | --- |
| `test_player` | Movimiento relativo a la cámara, colisiones, interacción, bloqueos |
| `test_world` | Mallas agrupadas, salidas, marcadores, pistas obtenibles, alcance real |
| `test_data_integrity` | Referencias de los datos, rutinas sin huecos, siluetas |
| `test_npc` | Rutinas, marcha, espera, conversación |
| `test_dialogue` | Flujo, condiciones, efectos, tiempo, bloqueo |
| `test_investigation` | Pistas, deducciones, acusación, eventos, vertical slice |
| `test_board` | Tablero y acusación manejados por su interfaz |
| `test_story` | El caso completo, de la llegada al epílogo |
| `test_integration` | Rutas reales, puertas, cama y conversación con entradas de teclado |
| `test_save` | Guardado, archivos corruptos, pausa, menú, volumen |

Las pruebas de alcance se validaron con una mutación: tapiar el cuarto de Lucía y quitar una
pista hizo fallar las pruebas correspondientes.

También se exportó un paquete `.pck`: incluye los JSON, excluye `tests/` y `tools/`, y el juego
arranca desde él sin errores en modo sin ventana.

## Qué no se ha comprobado

- **Nadie ha jugado una partida completa a mano.** El recorrido automático demuestra que se
  puede terminar, pero no si es divertido, claro o equilibrado.
- **El audio no se ha escuchado.** Se comprueba que se genera y que el volumen llega a los
  canales, no cómo suena.
- **No se ha generado un `.exe`:** faltan las plantillas de exportación de Godot.
- **La animación y las transiciones** se revisaron con capturas fijas, no en movimiento.
- **La tasa de fotogramas en primer plano.** Ver el apartado siguiente.

## Rendimiento

Medido a 1920×1080, con la ventana lanzada desde la terminal:

| Prueba | Tiempo por fotograma |
| --- | --- |
| Lógica sin renderizar (plaza) | 6,9 ms |
| Juego con sincronización vertical | ~180 ms |
| Proyecto Godot vacío con sincronización vertical | ~182 ms |
| Juego sin sincronización vertical | 33,3 ms |
| Proyecto Godot vacío sin sincronización vertical | 33,3 ms |

El coste no depende del juego: un proyecto vacío se comporta igual en este equipo, y apagar
cualquier efecto no cambiaba el resultado. La GPU estaba al 7 % en la plaza.

La causa exacta no se ha confirmado. Coincide con la sincronización vertical en un portátil de
doble GPU, y el límite de 30 FPS podría deberse a que la ventana no tenía el foco. Por eso el
juego usa por defecto `vsync` desactivado y 60 FPS como máximo, con opción en Configuración.

La plaza tiene unas 91 llamadas de dibujado y 134.000 primitivas por fotograma.

## Problemas conocidos

- Con todas las deducciones hechas, los hilos del tablero se cruzan mucho.
- El editor de Godot no muestra la geometría de los escenarios: se genera al ejecutar.
- Mientras el editor siga abierto desde antes de crear los autoloads, su analizador marca
  errores falsos. Se resuelve con **Proyecto > Recargar proyecto actual**.

## Bloqueos

Ninguno.

## Siguiente tarea

1. Jugar una partida completa y anotar qué resulta confuso o lento.
2. Ajustar la dificultad y el ritmo con esas notas.
3. Instalar las plantillas de exportación y generar el `.exe`.
