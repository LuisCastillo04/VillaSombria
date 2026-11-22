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
| Rediseño de pausa, configuración y controles | Hecho | Pruebas de navegación, ajustes e InputMap; capturas a 1920×1080, 1600×900 y 1280×720 |
| Mapa del pueblo | Hecho | Dibujo comparado con las colisiones reales, recorridos con entradas reales, carga de partidas y capturas a 1920×1080, 2560×1080, 1280×720 y 1024×768; ver [MAPA.md](MAPA.md) |
| Rediseño del HUD de exploración | Hecho | Pruebas con la escena de juego real (datos, barra, visibilidad, proporciones) y capturas en los cinco escenarios a 1280×720, 1366×768, 1600×900, 1920×1080, 1024×768 y 2560×1080; ver [HUD.md](HUD.md) |
| Rediseño del expediente | Hecho | Pruebas con la escena de juego real (datos de las cinco secciones, estados vacíos, teclado y ratón, restauración, proporciones, guardar y cargar) y capturas a 1280×720, 1366×768, 1600×900, 1920×1080 y 1024×768; ver [EXPEDIENTE.md](EXPEDIENTE.md) |
| Rediseño del tablero de deducción | Hecho | Pruebas con la escena de juego real (sospechosos y valoraciones, hipótesis y borradores, corcho, hilos, comparación con sus cuatro resultados, teclado y ratón, proporciones, guardar y cargar) y capturas a 1280×720, 1366×768, 1600×900, 1920×1080 y 1440×1080; ver [TABLERO.md](TABLERO.md) |
| Configuración avanzada | Hecha | Pruebas de preferencias, pantalla, calidad, conversaciones, confirmaciones, accesibilidad y menú con la escena de juego real; ventana real con los cuatro modos, la resolución, VSync y la confirmación que restaura; reinicio en dos procesos; arranque del juego real con cada modo guardado; mediciones de GPU por nivel y capturas a 1280×720 y 1920×1080 en tamaño normal, «Muy grande» y contraste aumentado; ver [CONFIGURACION.md](CONFIGURACION.md) |
| Rediseño de las conversaciones | Hecho | Pruebas con la escena de juego real y entradas de teclado y ratón (placa y luz de quien habla, escritura, páginas, voces de una escena, respuestas y sus consecuencias, rótulos, foco, HUD y avisos, escenas encadenadas, guardar y cargar, proporciones) y capturas a 1280×720, 1366×768, 1600×900 y 1920×1080 comparadas con las referencias; ver [DIALOGOS.md](DIALOGOS.md) |

Diferencias con el encargo:

- **Fase 3:** se pasó directamente a los personajes reales, sin NPC de prueba.
- **Fase 3:** los NPC usan puntos de ruta, no navegación. Al cambiar de escenario según su rutina,
  aparecen y desaparecen en lugar de caminar hasta la puerta.
- **Fase 8:** el piso superior de la mansión y la bodega no existen como espacios recorribles.

## Pruebas

`tools/verificar.ps1` importa el proyecto, arranca la escena principal, ejecuta las pruebas,
guarda una partida en un proceso de Godot para cargarla en otro nuevo y hace lo mismo con las
preferencias. Con `-ConVentana` además comprueba las imágenes de las ranuras, los modos de pantalla
y la resolución con la ventana real, y cierra la ventana con la X y con Alt + F4.

Último resultado, tras la configuración avanzada, con `-ConVentana`: 360 pruebas correctas, 0 fallos;
reinicio de la partida y de las preferencias en dos procesos, imágenes de las ranuras, modos de
pantalla y cierre con la X y con Alt + F4, correctos. El paso «Importación» sale fallido por el
`Code.exe` del editor (ver Problemas conocidos).

| Archivo | Cubre |
| --- | --- |
| `test_player` | Movimiento relativo a la cámara, colisiones, interacción, bloqueos |
| `test_world` | Mallas agrupadas, salidas, marcadores, pistas obtenibles, alcance real |
| `test_data_integrity` | Referencias de los datos, rutinas sin huecos, siluetas |
| `test_npc` | Rutinas, marcha, espera, conversación |
| `test_dialogue` | Flujo, condiciones, efectos, tiempo, bloqueo |
| `test_dialogue_ui` | Conversaciones rediseñadas: nombre y luz de quien habla, sólo texto en la ventana, escritura y avance de uno en uno, páginas sin perder palabras, voces de una escena, respuestas y consecuencias de `DialogueManager`, rótulos, flechas, números, ratón, protección y foco, listas largas, cierre y HUD, teclas aisladas, avisos por encima, escenas encadenadas, guardar y cargar, InputMap y proporciones de pantalla |
| `test_investigation` | Pistas, deducciones, acusación, eventos, vertical slice |
| `test_board` | Tablero y acusación manejados por su interfaz |
| `test_board_ui` | Tablero rediseñado: teclas reales, sospechosos y valoraciones, hipótesis, borradores y límite de la nota, corcho y huecos libres, hilos sólo de deducciones registradas, comparación y sus resultados, teclado y ratón, decoración sin ratón, proporciones de pantalla y partida cargada |
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
| `test_pause_menus` | Pausa sobre el escenario, ranura activa real, Escape por niveles, volumen y gráficos reales, teclas del InputMap, opciones previstas inertes, pestañas con teclado |
| `test_map` | Calibración del mapa, dibujo frente a colisiones reales, puertas y calle Mayor, posiciones exactas en exteriores y por edificio en interiores, objetivos, lugares visitados, datos dañados |
| `test_map_screen` | El mapa en el juego: posición al empezar, al caminar, al entrar y salir, al cargar; tamaños de pantalla, pausa, teclado, ratón y selección |
| `test_hud` | HUD de exploración: lugar, fecha y objetivo reales, barra según el InputMap y el estado, retirada en transiciones, conversaciones y pausa, proporciones de pantalla, ratón y foco, capas, avisos e indicador de guardado |
| `test_settings` | Preferencias: valores por defecto, categorías, validación, una clave por escritura sin perder el resto del archivo, valores dañados, migración del formato anterior, recarga y que no van en las partidas |
| `test_display` | Resoluciones según el monitor, ajuste de lo que no cabe, pantalla completa y modo de ventana como una sola preferencia, confirmación con cuenta atrás (mantener, restaurar, Escape, en pausa, una a la vez) y foco |
| `test_graphics_quality` | Niveles de iluminación y efectos en la plaza real: Alto es el original, ninguna luz se apaga, escenarios nuevos, una sola lluvia, el reloj no cambia |
| `test_dialogue_settings` | Velocidad del texto, protección del texto instantáneo y avance automático (espera, nunca elige, cambios a mitad, tecla, cierre) |
| `test_confirmations` | Dejar pasar una hora con y sin confirmaciones, tecla reasignada, límite del día y confirmaciones críticas siempre activas |
| `test_accessibility` | Tamaño de letra sin nada fuera de la pantalla, contraste aumentado reversible, subtítulos y movimiento reducido |
| `test_settings_menu` | Configuración sin «Próximamente», cada control con su preferencia, confirmación de la pantalla, teclado, mando, ratón y menú principal |
| `test_journal` | Expediente: apertura y cierre con las teclas reales, datos reales de las cinco secciones, estados vacíos, nada sin descubrir, teclado y ratón, restauración sin reconstruir, proporciones de pantalla y partida cargada |
| `persistencia/reinicio` | Guardar, cerrar el proceso y cargar en otro desde el menú principal |
| `persistencia/ajustes` | Cambiar preferencias de todas las categorías y leerlas y aplicarlas en otro proceso |
| `visual/pantalla` | Con ventana: los cuatro modos, la resolución ajustada al monitor, la posición, VSync y la confirmación que restaura |
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
- **Los menús con un mando real y el ratón a mano.** Las pruebas envían las mismas acciones
  (`ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_cancel`) y movimientos de ratón por código, y
  los fundidos y el resaltado animado se revisaron con capturas fijas.
- **La configuración con un mando real.** Los selectores, interruptores y la confirmación se prueban
  con las acciones `ui_*` que envía un mando, no con uno físico. Jugar con mando (fuera de los menús)
  sigue sin estar asignado: el sistema de controles personalizables no existe en el repositorio.
- **Los modos de pantalla en otros equipos.** Los cuatro modos se comprobaron con la ventana real en el
  monitor principal de este portátil (1920 × 1080 al 150 %), no moviendo la ventana a otro monitor ni
  con otras tarjetas gráficas.
- **El guardado y la carga no se han probado jugando a mano.** Las pruebas manejan los menús como
  lo haría el jugador, el reinicio se probó en dos procesos y el cierre con ventana real, pero
  falta jugar guardando, saliendo y cargando con ratón, teclado y mando, y ver en movimiento las
  animaciones del expediente y del indicador.
- **Alt + F4 en un `.exe`:** se probó con el juego ejecutándose en el motor del editor, enviando
  la pulsación a su ventana; falta repetirlo con el ejecutable exportado.
- **El mapa en movimiento.** La pulsación y el deslizamiento del marcador, el rombo y la entrada
  de la pantalla se comprobaron con pruebas y capturas fijas, no viéndolos ni con un mando real.
- **El HUD en movimiento.** Los fundidos, el deslizamiento al aparecer y el destello de los
  objetivos nuevos se comprobaron con pruebas y capturas fijas, no viéndolos jugando.
- **Las conversaciones en movimiento.** La escritura, el cambio de lectura a respuestas, la entrada
  escalonada de las tarjetas y el latido de «Continuar» se comprobaron con pruebas y capturas fijas,
  no viéndolos jugando; tampoco con un mando real ni escuchando el sonido de la escritura.
- **El tablero en movimiento.** Los fundidos, el brillo de la selección, el hilo que se tiende y
  el temblor de una comparación sin relación se comprobaron con pruebas y capturas fijas, no
  viéndolos jugando; tampoco con un mando real.
- **El expediente en movimiento.** Los fundidos de apertura, cierre, sección y ficha se
  comprobaron con pruebas y capturas fijas, no viéndolos jugando; tampoco con un mando real.
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
- Con todas las deducciones hechas, el corcho tiene muchos hilos. Ya no tapan ningún texto (pasan
  por detrás del papel) y los de la ficha elegida se avivan, pero un filtro por grupos ayudaría
  (ver «Cómo ampliarlo» en [TABLERO.md](TABLERO.md)).
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
