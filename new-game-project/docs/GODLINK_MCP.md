# Godlink MCP: Claude Code conectado a Godot

Godlink MCP permite que Claude Code lea el proyecto desde el editor de Godot abierto, ejecute el
juego, haga capturas y lea los errores del depurador. Este documento explica qué piezas tiene, cómo
ponerlo en marcha en otro equipo, qué precauciones hay que tener y cómo comprobar que funciona.

Es una herramienta de desarrollo: el juego no la necesita para funcionar.

## Piezas

| Pieza | Dónde | Qué hace |
| --- | --- | --- |
| Complemento «Godot MCP» 0.6.0 (Godlink en la Asset Store) | `new-game-project/addons/godot_mcp/` | Dentro del editor: se conecta al servidor y ejecuta las herramientas. Copia sin cambios de la versión instalada desde la Asset Store; licencia MIT, © Tomer Yud ([tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp)) |
| Autoload `MCPRuntime` | `addons/godot_mcp/runtime/mcp_runtime.gd`, último de la lista en `project.godot` | Dentro del juego en marcha: capturas, entrada simulada y consulta de nodos en vivo |
| Servidor `godot-mcp-server` 0.6.0 | Paquete npm; no se guarda en el repositorio | Habla MCP con Claude Code por stdio y con Godot por WebSocket |
| `.mcp.json` | Raíz del repositorio | Le dice a Claude Code cómo lanzar el servidor |

```
Claude Code ──stdio──► godot-mcp-server (Node) ──WebSocket 127.0.0.1:6505──► complemento del editor
 (VS Code)               │                                                  └► MCPRuntime (juego en marcha)
                         ├─ HTTP 127.0.0.1:6506: otras sesiones de Claude Code reutilizan este servidor
                         └─ HTTP :6510: visualizador del proyecto, sólo si se usa map_project
```

## Requisitos

- Godot 4.7 (probado con 4.7.2 stable, Steam). El complemento pide Godot 4.4 o posterior.
- Node.js LTS con npm (probado con Node.js 24.21.0 y npm 11.19.0). `npx` descarga el servidor la
  primera vez y lo guarda en la caché de npm del usuario.
- Claude Code: la extensión de VS Code basta. **No hace falta el comando `claude` en el PATH**: la
  extensión lee `.mcp.json` por su cuenta, así que el «no se reconoce» de PowerShell no importa.

## Puesta en marcha

1. Abre `new-game-project/project.godot` en Godot. El complemento ya está activado
   (Proyecto → Configuración del proyecto → Plugins → Godot MCP). Arriba a la derecha aparece
   **MCP: Connecting...** en amarillo mientras no haya servidor. Es normal: el complemento es el
   cliente y espera a que Claude Code lance el servidor.
2. Abre en VS Code la carpeta raíz del repositorio (donde está `.mcp.json`, no `new-game-project/`) y
   empieza una conversación nueva de Claude Code. Los servidores sólo se cargan al iniciar la sesión.
3. La primera vez Claude Code pide aprobar el servidor `godot` de `.mcp.json`. Apruébalo. Si no ves
   el aviso, escribe `/mcp` en el chat: ahí aparece el servidor, su estado y la opción de activarlo.
4. En Godot, el indicador pasa a **MCP: Agent Active** (verde). Si sólo llega a **MCP: No Agent**
   (naranja), el servidor está en marcha pero ninguna sesión de Claude Code lo está usando.
5. Pide a Claude que compruebe el estado con `get_godot_status`.

Si el indicador se queda en «Connecting...», consulta [Problemas frecuentes](#problemas-frecuentes).

## Configuración de `.mcp.json`

```json
{
  "mcpServers": {
    "godot": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "godot-mcp-server@0.6.0"]
    }
  }
}
```

- **`cmd /c`**: en Windows `npx` es un script `npx.cmd`. Claude Code lanza el comando sin shell, y
  sin `cmd /c` no lo encuentra.
- **`@0.6.0`**: el servidor va fijado a la versión del complemento. Sin versión, `npx` traería la
  última, y el servidor y el complemento pueden dejar de coincidir. Según el propio servidor 0.6.1,
  con un complemento 0.6.0 las herramientas siguen funcionando, pero avisa del desajuste y algunas
  novedades no están disponibles (no se ha probado aquí).
  Para actualizar, cambia las dos cosas en el mismo commit: el complemento desde la Asset Store y el
  número de `.mcp.json`.
- El archivo es de proyecto: no guarda credenciales y no toca la configuración global de Claude Code.

## Qué cambia en el proyecto

- `project.godot`: la sección `[editor_plugins]` y el autoload `MCPRuntime`, el último de la lista
  para no alterar el orden de los del juego. Se registra con su ruta `res://`, no con `uid://`,
  porque al desactivar el complemento éste sólo retira el autoload si la ruta coincide con la suya.
- `.gitignore`: `addons/godot_mcp/cache/`, donde el complemento guarda capturas, el historial de
  deshacer y su estado.
- `export_presets.cfg`: la misma carpeta queda fuera de la exportación.

## Precauciones

- **Muchas herramientas escriben en disco** (`edit_script`, `add_node`, `update_project_settings`,
  `setup_autoload`, `delete_file`…). Los cambios van directos a los archivos y **Ctrl+Z en Godot no
  los deshace**: hay que usar `mcp_undo` o git. Revisa `git status` después de pedir cambios.
- **Ejecutar el juego guarda las escenas abiertas** si «Guardar antes de ejecutar» está activado en
  el editor (lo está por defecto). Si cambias de rama con Godot abierto, vuelve a abrir el proyecto
  antes de ejecutar nada desde Claude Code.
- **Cambiar de rama con el editor abierto** también puede hacer que Godot reescriba `project.godot`
  con su lista de autoloads antigua, reordenada, al guardar ajustes (al activar este complemento
  pasó con `ConfirmDialog`, `Controls` y las acciones `ui_*`). Revisa el diff de `project.godot`
  antes de confirmarlo.
- **Exportar para jugadores**: `MCPRuntime` es un autoload y entraría en el juego exportado. Ahí
  seguiría intentando conectarse a `127.0.0.1:6505` cada 2 segundos y aceptaría entrada simulada y
  llamadas a métodos de cualquier programa local que escuche en ese puerto. Antes de exportar una
  versión para jugadores, desactiva el complemento (Proyecto → Configuración del proyecto → Plugins):
  eso retira el autoload. Después, exporta y vuelve a activarlo.
- **Pruebas automatizadas**: `MCPRuntime` también arranca en `tools/verificar.ps1` y en las
  escenas de `tests/`. Sin servidor no hace nada. Con Claude Code abierto se conectaría como «juego en
  marcha», así que no pidas capturas a Claude mientras corre la batería.
- El servidor sólo escucha en `127.0.0.1`. Al arrancar cierra el proceso que esté escuchando en el
  puerto 6505 (lo normal es un servidor anterior que se quedó colgado).
- El servidor no se cierra al cerrar Claude Code mientras Godot siga conectado: la sesión siguiente
  lo reutiliza. Se cierra solo cuando Godot se desconecta y nadie lo usa.

## Comprobar la conexión

Con el editor de Godot abierto en el proyecto y sin otra sesión ejecutando el juego:

```powershell
node new-game-project\tools\probar_godlink.mjs             # sólo lectura
node new-game-project\tools\probar_godlink.mjs --ejecutar  # además ejecuta el juego, lo captura y lo detiene
```

El script lanza el servidor con el comando de `.mcp.json` y le habla MCP como lo haría Claude Code.
Comprueba que el servidor arranca, que el editor se conecta, que la escena principal se lee y cuántos
errores y avisos hay. Con `--ejecutar`, además, ejecuta la escena principal, espera a `MCPRuntime`,
hace una captura y lee los nodos de `/root` y el depurador antes de detener el juego. No modifica
escenas, scripts ni ajustes. Si Claude Code ya tiene un servidor en marcha, el script lo reutiliza.

Desde Claude Code, el flujo equivalente es `run_scene` con `wait_for_runtime: true` →
`take_screenshot` → `get_errors` con `wait_ms: 300` → `stop_scene`. Las capturas quedan en
`res://addons/godot_mcp/cache/screenshots/`. Para esperar, mejor que Claude espere por su cuenta: en
las pruebas, la herramienta `wait` volvió antes de tiempo con el juego en marcha.

### Resultado del 21 de noviembre de 2026

Con Godot 4.7.2 abierto en la rama `chore/configuracion-godlink-mcp`:

- El servidor 0.6.0 arrancó como principal (WebSocket 6505, HTTP 6506) y ofreció 77 herramientas.
- El editor se conectó en unos 3,5 s. `get_project_settings`, `read_scene`, `scene_tree_dump` y
  `get_errors` respondieron. La escena principal es `res://scenes/main/main_menu.tscn`.
- `run_scene` abrió el menú principal y `MCPRuntime` se conectó en 5 s. La captura (1280×720) muestra
  el menú completo, y `/root` tiene los 15 autoloads del juego en su orden, más `MCPRuntime` y
  `MainMenu`.
- Depurador: 0 errores y 19 avisos de análisis de GDScript que ya existían en scripts del juego
  (división entera, variables que ocultan propiedades). Ninguno viene del complemento.
- `stop_scene` detuvo el juego y `git status` quedó igual que antes de la prueba.

## Problemas frecuentes

| Síntoma | Causa y solución |
| --- | --- |
| «MCP: Connecting...» que no cambia | No hay servidor. Abre una conversación **nueva** de Claude Code en la raíz del repositorio y comprueba en `/mcp` que el servidor `godot` está aprobado y conectado. Para descartar el servidor, ejecuta `cmd /c npx -y godot-mcp-server@0.6.0` en la raíz: debe decir `WebSocket server listening on port 6505` y el indicador de Godot debe cambiar. Ciérralo con Ctrl+C |
| `/mcp` muestra el servidor como fallido | Comprueba `node --version` y `npx --version` en una terminal nueva. Si Node.js se instaló con VS Code abierto, reinicia VS Code para que vea el PATH nuevo |
| El puerto 6505 está ocupado | `netstat -ano \| findstr :6505` muestra el PID. Si es un `node.exe` antiguo, ciérralo desde el Administrador de tareas |
| `take_screenshot` dice que el runtime no está conectado | El juego no está en marcha o se lanzó sin `wait_for_runtime: true`. Comprueba también que `MCPRuntime` sigue en la lista de autoloads |
| Avisos de versión en `get_godot_status` | El servidor y el complemento no coinciden: deja los dos en la misma versión (ver arriba) |
| «claude no se reconoce» en PowerShell | No afecta: la extensión de VS Code no usa ese comando. Si algún día quieres usar la CLI, instálala aparte; `.mcp.json` le sirve igual |
