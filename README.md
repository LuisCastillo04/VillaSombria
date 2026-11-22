# Villa Sombría

Aventura detectivesca 2.5D low-poly noir hecha con **Godot 4.7** y **GDScript**.

Octubre de 1948. Julián Valdés, el hombre más influyente de Villa Sombría, aparece muerto
durante una celebración privada. Tienes tres días para explorar el pueblo, examinar pruebas,
interrogar a cinco sospechosos y encontrar las contradicciones que señalan al culpable.

## Autores

Creado y desarrollado por **Juan Camilo Miño Castillo** y **Luis Eduardo Miño Castillo**, con la misma
participación en diseño, programación, narrativa y dirección.

## Características

- Cinco escenarios: plaza, mansión Valdés, Café La Luna, archivo municipal y estación de tren.
- Interrogatorios con siluetas 2D a contraluz, preguntas que se desbloquean con las pruebas y
  respuestas que dependen de lo que ya sabes.
- Pruebas que se examinan con su propio aspecto: cartas manuscritas, el periódico del pueblo y
  fichas de investigación con su ilustración.
- Expediente con pistas, testimonios, sospechosos y deducciones.
- Tablero de deducción que comprueba relaciones reales entre pruebas y declaraciones.
- Calendario de tres días con rutinas de personajes. Nada se pierde por llegar tarde.
- Mapa del pueblo que sigue la posición real del detective, con los lugares y los objetivos del día.
- Acusación final con motivo, oportunidad y medios. Equivocarse no termina la partida.
- Sonido adaptativo original: un leitmotiv noir, la música y el ambiente de cada lugar, una capa de
  tensión que crece con la investigación, silencios intencionados, fragmentos al descubrir pistas y
  pasos que suenan según el suelo. Ver [Sonido](new-game-project/docs/AUDIO.md).
- Cinco ranuras de partida con imagen real de cada guardado. El autoguardado sigue la ranura en
  la que guardaste o que cargaste, y cerrar la ventana o pulsar Alt + F4 guarda antes de salir.

## Requisitos

- Godot Engine 4.7 (probado con 4.7.2 stable, renderizador Forward+).
- Windows 10/11 con una GPU compatible con Direct3D 12 o Vulkan.

Por ahora el juego no necesita recursos externos: la geometría, los materiales, las siluetas y
el sonido se generan con primitivas, shaders, SVG y el sintetizador del repositorio (`tools/generar_audio.py`). Está
previsto incorporar retratos generados con IA y, si hay créditos, voces sintéticas; ver
[Recursos](new-game-project/docs/RECURSOS.md).

## Instalación y ejecución

1. Clona el repositorio.
2. Abre Godot e importa `new-game-project/project.godot`.
3. Pulsa **F5**.

Desde la terminal:

```powershell
& "<ruta a Godot>" --path new-game-project
```

## Controles

| Tecla | Mando (Xbox) | Acción |
| --- | --- | --- |
| WASD o flechas | Stick izquierdo o cruceta | Moverse |
| Mayús | RT o LS (mantener) | Correr |
| E | A | Interactuar y avanzar el diálogo |
| 1 a 9, ratón o Intro | Cruceta y A | Elegir una pregunta |
| J o Tab | Y | Abrir el expediente |
| B | X | Abrir el tablero de deducción |
| M | Vista | Abrir el mapa del pueblo |
| T | RB | Dejar pasar una hora (pide confirmación; se puede desactivar en Configuración) |
| Esc | Menú (B para volver) | Pausa |

Las teclas se pueden cambiar en Pausa → Controles → Otros → **Reasignar teclas**, y volver a las
originales con **Restaurar las teclas predeterminadas**. El juego detecta el mando solo y muestra sus
botones (también de PlayStation y Nintendo). Ver [CONTROLES.md](new-game-project/docs/CONTROLES.md).

## Cómo se juega

Los rombos ámbar señalan pistas sin examinar y personajes con preguntas nuevas. Cada acción
consume tiempo y cada personaje sigue su rutina: la pestaña Sospechosos del expediente dice
dónde está cada uno. Para terminar el día, acuéstate en la pensión del Café La Luna.

En el tablero, selecciona dos elementos y pulsa **Relacionar**. Una deducción sirve después
como prueba para la siguiente. Pulsa un sospechoso para anotar tu valoración y tu hipótesis:
el expediente las recoge y se guardan con la partida.

Si el juego va a tirones, prueba a cambiar **Sincronización vertical** o a bajar **Sombras e
iluminación** y **Efectos y partículas** en Configuración → Gráficos. En Jugabilidad se elige la
velocidad del texto y el avance automático de las conversaciones, y en Accesibilidad, el tamaño de
letra, el contraste aumentado, los subtítulos y la reducción de movimiento. Ver
[CONFIGURACION.md](new-game-project/docs/CONFIGURACION.md).

## Verificación

```powershell
powershell -File new-game-project\tools\verificar.ps1
```

El script importa el proyecto, arranca la escena principal, ejecuta las pruebas automatizadas y
comprueba que una partida guardada se recupera al volver a abrir el juego. Con `-ConVentana`
también abre el juego para comprobar las imágenes de las ranuras y el cierre de la ventana.
Si Godot no está en la ruta de Steam por defecto, define antes la variable `GODOT_BIN`.

## Documentación

- [Estado del proyecto](new-game-project/docs/ESTADO_PROYECTO.md)
- [Plan de desarrollo](new-game-project/docs/PLAN_DESARROLLO.md)
- [Arquitectura](new-game-project/docs/ARQUITECTURA.md)
- [Guardado](new-game-project/docs/GUARDADO.md): ranura activa, autoguardado, salida, imágenes y cómo ampliarlo
- [Mapa](new-game-project/docs/MAPA.md): posición del detective, calibración, lugares y cómo ampliarlo
- [Evidencias](new-game-project/docs/EVIDENCIAS.md): carta, periódico y ficha al examinar pruebas, «Evidencia obtenida» y cómo añadir plantillas
- [Historia](new-game-project/docs/HISTORIA.md) (contiene la solución del caso)
- [Recursos](new-game-project/docs/RECURSOS.md): origen y condiciones de los recursos
- [Godlink MCP](new-game-project/docs/GODLINK_MCP.md): conexión de Claude Code con el editor de Godot

## Licencias y recursos

Godot Engine se distribuye bajo licencia MIT. Hoy el juego no incluye recursos de terceros. El
repositorio sí incluye un complemento de desarrollo de terceros, Godlink MCP
(`new-game-project/addons/godot_mcp/`, licencia MIT, © Tomer Yud), que sólo sirve para conectar
Claude Code con el editor; ver [GODLINK_MCP.md](new-game-project/docs/GODLINK_MCP.md).
Los recursos generados con IA que se añadan (retratos de ChatGPT y, posiblemente, voces de
ElevenLabs) se registrarán con su origen y condiciones en
[RECURSOS.md](new-game-project/docs/RECURSOS.md).
