# Villa Sombría

Aventura detectivesca 2.5D low-poly noir hecha con **Godot 4.7** y **GDScript**.

Julián Valdés, el hombre más influyente de Villa Sombría, aparece muerto durante una
celebración privada. Tienes tres días para explorar el pueblo, examinar pruebas,
interrogar a cinco sospechosos y encontrar las contradicciones que señalan al culpable.

## Requisitos

- Godot Engine 4.7 (probado con 4.7.2 stable, renderizador Forward+).
- Windows 10/11 con una GPU compatible con Direct3D 12 o Vulkan.

El juego no necesita recursos externos: la geometría, los materiales y las siluetas se
generan con primitivas, shaders y SVG incluidos en el repositorio.

## Ejecución

1. Abre Godot e importa `new-game-project/project.godot`.
2. Pulsa **F5**.

Desde la terminal:

```powershell
& "<ruta a Godot>" --path new-game-project
```

## Verificación

```powershell
powershell -File new-game-project\tools\verificar.ps1
```

El script importa el proyecto, arranca la escena principal y ejecuta las pruebas. Si Godot
no está en la ruta de Steam por defecto, define antes la variable `GODOT_BIN`.

## Documentación

- [Plan de desarrollo](new-game-project/docs/PLAN_DESARROLLO.md)
- [Estado del proyecto](new-game-project/docs/ESTADO_PROYECTO.md)
