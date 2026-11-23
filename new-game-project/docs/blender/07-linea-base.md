# 7. Resultados de las pruebas iniciales (línea base)

Medida antes de cualquier cambio relacionado con Blender. Sirve para saber, en cada sesión, si un
fallo es nuevo o ya estaba.

## Condiciones

| Dato | Valor |
| --- | --- |
| Fecha | 2026-11-22 |
| Commit medido | `85b9f82` (`main` = `origin/main`, «Merge pull request #16 … feature/audio-adaptativo») |
| Dónde | Copia limpia del commit (`git worktree add --detach … HEAD` en una carpeta temporal), **no** la carpeta de trabajo |
| Por qué en copia limpia | La carpeta de trabajo tenía `project.godot` y `scenes/main/main_menu.tscn` modificados por el editor de Godot abierto: sin el autoload `MCPRuntime`, sin el complemento activado, autoloads reordenados y UIDs añadidos. Probar ahí habría medido otro proyecto. Esos dos archivos siguen sin confirmar |
| Godot | 4.7.2, `D:\Program Files (x86)\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` |
| Orden | `powershell -File tools\verificar.ps1` desde `new-game-project/` (sin `-ConVentana`) |

## Resultado: todo correcto

| Paso | Resultado |
| --- | --- |
| Importación | correcto |
| Arranque de la escena principal | correcto |
| Pruebas automatizadas (`tests/test_runner.tscn`) | correcto — **524 correctas, 0 con fallos** |
| Reinicio: guardar partida | correcto |
| Reinicio: cargar en un proceso nuevo | correcto |
| Reinicio: guardar preferencias | correcto |
| Reinicio: preferencias en un proceso nuevo | correcto |
| Reinicio: personalizar teclas | correcto |
| Reinicio: teclas en un proceso nuevo y restaurar | correcto |
| Reinicio: teclas de fábrica en otro proceso | correcto |
| Resumen | **todo correcto**, código de salida 0 |

Observaciones:

- En otras ocasiones el paso «Importación» había salido «FALLÓ» en este equipo por una ruta del
  editor a un `Code.exe` inexistente. Esta vez, en la copia limpia, salió correcto. Si vuelve a
  fallar sólo ese paso, es del entorno.
- `test_integration` es intermitente con el equipo cargado (teclas perdidas). Hoy pasó. Si falla
  en una sesión posterior, repetir la batería antes de atribuirlo a un cambio.

## Qué no se ejecutó y por qué

| Comprobación | Motivo |
| --- | --- |
| `verificar.ps1 -ConVentana` (imágenes de ranuras, modos de pantalla, cierre con X y Alt + F4) | Abre y cierra varias ventanas y pasa por pantalla completa; esta sesión no cambia nada visible ni de la ventana. **La sesión 2 sí debe ejecutarlo** al terminar, porque cambia la imagen de la plaza |
| Capturas de comparación (`tests/visual/captura.tscn`) | Necesitan ventana y no hay nada que comparar todavía. La sesión 2 hace la captura «antes» en su primer paso |
| Partida completa a mano | Fuera del alcance de una auditoría |

## Medidas de referencia

Medidas con una escena temporal (no incluida en el repositorio) que construye los escenarios y
cada pieza aislada. Se usan en [01-inventario.md](01-inventario.md).

| Escenario | Triángulos opacos | Brillo | Suelo | Colisiones | Horneado de navegación |
| --- | --- | --- | --- | --- | --- |
| Plaza | 6.361 | 536 | 12 | 52 | 19,8 ms |
| Café | 3.920 | 204 | — | 43 | 6,9 ms |
| Mansión | 6.752 | 224 | — | 44 | 7,9 ms |
| Archivo | 13.082 | 120 | — | 25 | 5,6 ms |
| Estación | 2.394 | 224 | 6 | 23 | 8,4 ms |

Buzón (`PropsKit.mailbox`), candidato del prototipo: 68 triángulos (204 vértices sin índices),
sólo capa opaca, caja de 0,60 × 1,24 × 0,60 m, una colisión de 0,5 × 1,2 × 0,5 m centrada a
0,6 m de altura.

Medida previa de `docs/ESTADO_PROYECTO.md`: la plaza dibuja unas 91 llamadas por fotograma y
134.000 primitivas. La sesión 2 la repetirá con `--stats` antes y después del buzón.

## Entorno de Blender

Blender 5.3.0 (`D:\Program Files (x86)\steam\steamapps\common\Blender\blender.exe`) arranca sin
ventana y tiene el exportador glTF 5.3.43. Comprobado con
`blender --background --factory-startup --python-expr …`. No se ha creado ningún archivo de
Blender en esta sesión.
