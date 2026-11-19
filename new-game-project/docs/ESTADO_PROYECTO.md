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
| Sistema de guardado | Hecho | Pruebas, reinicio en dos procesos, cierre real de la ventana y capturas; ver [GUARDADO.md](GUARDADO.md) |
| Rediseño del menú principal | Hecho | Pruebas de navegación y capturas a 1280×720, 1920×1080, 2560×1080 y 1024×768 |

Diferencias con el encargo:

- **Fase 3:** se pasó directamente a los personajes reales, sin NPC de prueba.
- **Fase 3:** los NPC usan puntos de ruta, no navegación. Al cambiar de escenario según su rutina,
  aparecen y desaparecen en lugar de caminar hasta la puerta.
- **Fase 8:** el piso superior de la mansión y la bodega no existen como espacios recorribles.

## Pruebas

`tools/verificar.ps1` importa el proyecto, arranca la escena principal, ejecuta las pruebas y
guarda una partida en un proceso de Godot para cargarla en otro nuevo. Con `-ConVentana` además
comprueba las imágenes de las ranuras y cierra la ventana real con la X y con Alt + F4.

Último resultado: 176 pruebas correctas, 0 fallos; el reinicio, las imágenes y los dos cierres
de la ventana, correctos.

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
| `test_save` | Guardado y carga básicos, archivos dañados, pausa, menú, volumen |
| `test_save_format` | Escritura atómica, recuperación, validación, versiones y migración |
| `test_save_slots` | Ranuras, restauración completa, autoguardado sólo en la activa, bloqueos, importaciones, partida nueva limpia |
| `test_active_slot` | Ranura activa al guardar, cargar, reiniciar, eliminar y empezar de nuevo |
| `test_exit` | X, Alt + F4 y botones de salida: guardar antes de salir, sin ranura, fallos, repeticiones |
| `test_save_navigation` | Teclado, mando, doble clic y foco del expediente |
| `test_autosave` | Política de autoguardado: agrupación, momentos seguros, separación, puntos de control |
| `test_save_indicator` | Indicador de guardado: aparición, éxito, fallo real e instancia única |
| `test_save_menus` | Guardar, sobrescribir, eliminar y cargar desde la pausa y el menú principal |
| `test_main_menu` | Plaza en marcha detrás del menú, orden e iconos de las opciones, «Continuar» según las partidas, navegación con teclado, mando y ratón, foco de los paneles |
| `persistencia/reinicio` | Guardar, cerrar el proceso y cargar en otro desde el menú principal |
| `persistencia/cierre` | Con ventana: cerrar con la X o Alt + F4 guarda en la ranura activa |
| `visual/vista_previa` | Con ventana: la imagen de cada ranura es la escena guardada, sin la pausa |

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
- **El menú principal con un mando real y el ratón a mano.** Las pruebas envían las mismas
  acciones (`ui_up`, `ui_down`, `ui_cancel`) y movimientos de ratón por código, y el resaltado
  animado de las opciones se revisó con capturas fijas.
- **El guardado y la carga no se han probado jugando a mano.** Las pruebas manejan los menús como
  lo haría el jugador, el reinicio se probó en dos procesos y el cierre con ventana real, pero
  falta jugar guardando, saliendo y cargando con ratón, teclado y mando, y ver en movimiento las
  animaciones del expediente y del indicador.
- **Alt + F4 en un `.exe`:** se probó con el juego ejecutándose en el motor del editor, enviando
  la pulsación a su ventana; falta repetirlo con el ejecutable exportado.
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

- `test_integration` falló una vez en ocho ejecuciones: las teclas B y T no llegaron a
  procesarse. Sus pruebas envían la pulsación y la liberación en el mismo fotograma con
  `Input.parse_input_event`, y con el equipo cargado la pulsación puede perderse.
- Con todas las deducciones hechas, los hilos del tablero se cruzan mucho.
- El editor de Godot no muestra la geometría de los escenarios: se genera al ejecutar.
- Mientras el editor siga abierto desde antes de crear los autoloads, su analizador marca
  errores falsos. Se resuelve con **Proyecto > Recargar proyecto actual**.
- En el equipo de desarrollo, el paso «Importación» de `verificar.ps1` aparece como fallido
  porque la configuración del editor de Godot apunta a un `Code.exe` de otro usuario que no
  existe. No depende del proyecto: los demás pasos se ejecutan y pasan.

## Recursos previstos

Se usarán retratos generados con ChatGPT y, si alcanzan los créditos, voces de ElevenLabs. Nada
de esto está integrado todavía y el juego aún no reproduce voces. Antes de la entrega hay que
confirmar con el profesor que se permite contenido generado con IA. Ver [RECURSOS.md](RECURSOS.md).

## Bloqueos

Ninguno.

## Siguiente tarea

1. Jugar una partida completa y anotar qué resulta confuso o lento, guardando, saliendo y
   cargando desde la pausa y el menú principal.
2. Ajustar la dificultad y el ritmo con esas notas.
3. Instalar las plantillas de exportación y generar el `.exe`.
