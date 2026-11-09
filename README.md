# Villa Sombría

Aventura detectivesca 2.5D low-poly noir hecha con **Godot 4.7** y **GDScript**.

Octubre de 1948. Julián Valdés, el hombre más influyente de Villa Sombría, aparece muerto
durante una celebración privada. Tienes tres días para explorar el pueblo, examinar pruebas,
interrogar a cinco sospechosos y encontrar las contradicciones que señalan al culpable.

## Autores

Creado y desarrollado por **Luis Castillo** y **Juan Camilo Miño Castillo**, con la misma
participación en diseño, programación, narrativa y dirección.

## Características

- Cinco escenarios: plaza, mansión Valdés, Café La Luna, archivo municipal y estación de tren.
- Interrogatorios con siluetas 2D a contraluz, preguntas que se desbloquean con las pruebas y
  respuestas que dependen de lo que ya sabes.
- Expediente con pistas, testimonios, sospechosos y deducciones.
- Tablero de deducción que comprueba relaciones reales entre pruebas y declaraciones.
- Calendario de tres días con rutinas de personajes. Nada se pierde por llegar tarde.
- Acusación final con motivo, oportunidad y medios. Equivocarse no termina la partida.
- Guardado automático y manual.

## Requisitos

- Godot Engine 4.7 (probado con 4.7.2 stable, renderizador Forward+).
- Windows 10/11 con una GPU compatible con Direct3D 12 o Vulkan.

El juego no necesita recursos externos: la geometría, los materiales, las siluetas y el sonido
se generan con primitivas, shaders, SVG y síntesis incluidos en el repositorio.

## Instalación y ejecución

1. Clona el repositorio.
2. Abre Godot e importa `new-game-project/project.godot`.
3. Pulsa **F5**.

Desde la terminal:

```powershell
& "<ruta a Godot>" --path new-game-project
```

## Controles

| Tecla | Acción |
| --- | --- |
| WASD o flechas | Moverse |
| Mayús | Correr |
| E | Interactuar y avanzar el diálogo |
| 1 a 9, ratón o Intro | Elegir una pregunta |
| J o Tab | Abrir el expediente |
| B | Abrir el tablero de deducción |
| T | Dejar pasar una hora |
| Esc | Pausa |

## Cómo se juega

Los rombos ámbar señalan pistas sin examinar y personajes con preguntas nuevas. Cada acción
consume tiempo y cada personaje sigue su rutina: la pestaña Sospechosos del expediente dice
dónde está cada uno. Para terminar el día, acuéstate en la pensión del Café La Luna.

En el tablero, selecciona dos elementos y pulsa **Relacionar**. Una deducción sirve después
como prueba para la siguiente.

Si el juego va a tirones, prueba a cambiar **Sincronización vertical** en Configuración.

## Verificación

```powershell
powershell -File new-game-project\tools\verificar.ps1
```

El script importa el proyecto, arranca la escena principal y ejecuta las pruebas automatizadas.
Si Godot no está en la ruta de Steam por defecto, define antes la variable `GODOT_BIN`.

## Documentación

- [Estado del proyecto](new-game-project/docs/ESTADO_PROYECTO.md)
- [Plan de desarrollo](new-game-project/docs/PLAN_DESARROLLO.md)
- [Arquitectura](new-game-project/docs/ARQUITECTURA.md)
- [Historia](new-game-project/docs/HISTORIA.md) (contiene la solución del caso)

## Licencia de terceros

Godot Engine se distribuye bajo licencia MIT. El proyecto no incluye recursos de terceros.
