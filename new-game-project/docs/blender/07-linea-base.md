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

## Sesión 2 (2026-11-23): tras el prototipo del buzón

| Comprobación | Resultado |
| --- | --- |
| Batería (`test_runner.tscn`) en la rama, `aa20034` | **538 correctas, 0 con fallos** (524 + 4 de `test_mesh_batcher` + 10 de `test_models`) |
| Llamadas de dibujado y primitivas, plaza junto al buzón (`--stats`, 1280 × 720) | Antes 218 / 61.038 · con modelo 218 / 61.038 · procedural 218 / 61.038 |
| Llamadas y primitivas, plaza desde «inicio» | 236 / 99.972 en los tres casos |
| Diferencia de píxeles modelo frente a procedural (zona del buzón) | Media 5,0, igual al ruido de lluvia y grano entre dos capturas idénticas (5,8): sin diferencia visible |
| Geometría de los cinco escenarios con y sin modelos | Idéntica (`test_locations_match_with_and_without_models`) |

El cambio de R5 altera el reparto de tonos de todos los escenarios (no su amplitud). Diferencia
media de las capturas antes/después de R5 en interiores, sin lluvia: café 0,9; mansión 3,9;
archivo 3,8 (la mansión y el archivo incluyen NPC que se mueven). Revisadas a ojo: mismo aspecto.

## Sesiones 3 y 4 (2026-11-23)

| Momento | Batería | Otras medidas |
| --- | --- | --- |
| Cierre de la sesión 3 (`3c5cf14`) | 542 correctas, 0 con fallos | Pipeline determinista: rehacer el `.blend` del buzón desde cero da el mismo GLB (mismo `sha256`) |
| Cierre de la sesión 4 (`66fee96` + documentación) | **543 correctas, 0 con fallos**, sin `ERROR:` | 20 modelos, 86 usos; llamadas de dibujado iguales con y sin modelos (café 235, mansión 328, archivo 226) |
| Cierre de la sesión 5 (`f07f3f7`) | **544 correctas, 0 con fallos**, sin `ERROR:` | 34 modelos; archivo 73.692 primitivas por fotograma (antes 99.872), mansión 118.270 (antes 140.968); mismas llamadas de dibujado |
| Cierre de la sesión 6 (`7437acb`) | **544 correctas, 0 con fallos**, sin `ERROR:` | 58 modelos; plaza 236 / 99.972 y estación 230 / 29.676 (llamadas / primitivas), iguales con y sin modelos |
