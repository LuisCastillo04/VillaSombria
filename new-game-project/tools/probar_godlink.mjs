// Comprueba la conexión entre el servidor de Godlink MCP y el editor de Godot sin pasar por Claude Code.
//
// Uso (con el editor de Godot abierto en este proyecto):
//   node new-game-project/tools/probar_godlink.mjs             sólo lectura: estado, ajustes, escena principal y errores
//   node new-game-project/tools/probar_godlink.mjs --ejecutar  además ejecuta la escena principal, captura la pantalla,
//                                                              lee los errores del depurador y detiene el juego
//
// Lanza el servidor con el mismo comando que `.mcp.json` y le habla MCP por stdio. No modifica escenas,
// scripts ni ajustes. La captura se guarda en `res://addons/godot_mcp/cache/screenshots/` (ignorada por git).
// Termina con código 0 si todo funciona, 1 si algo falla y 2 si falta la configuración.
// Detalle en docs/GODLINK_MCP.md.
import { spawn, execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const RAIZ = fileURLToPath(new URL('../../', import.meta.url));
const EJECUTAR = process.argv.includes('--ejecutar');
const ESPERA_CONEXION_MS = 60000;

let config;
try {
  config = JSON.parse(readFileSync(new URL('../../.mcp.json', import.meta.url), 'utf8')).mcpServers.godot;
} catch (e) {
  console.error(`No se puede leer el servidor "godot" de .mcp.json en ${RAIZ}: ${e.message}`);
  process.exit(2);
}

console.log(`Servidor: ${config.command} ${config.args.join(' ')}`);
const servidor = spawn(config.command, config.args, { cwd: RAIZ, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
let registro = '';
servidor.stderr.on('data', (d) => { registro += d.toString(); });

let pendiente = '';
let siguienteId = 1;
const respuestas = new Map();
servidor.stdout.on('data', (d) => {
  pendiente += d.toString();
  let fin;
  while ((fin = pendiente.indexOf('\n')) >= 0) {
    const linea = pendiente.slice(0, fin).trim();
    pendiente = pendiente.slice(fin + 1);
    if (!linea) continue;
    let mensaje;
    try { mensaje = JSON.parse(linea); } catch { continue; }
    if (mensaje.id != null && respuestas.has(mensaje.id)) {
      respuestas.get(mensaje.id)(mensaje);
      respuestas.delete(mensaje.id);
    }
  }
});

function enviar(method, params, plazoMs = 60000) {
  const id = siguienteId++;
  servidor.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => { respuestas.delete(id); reject(new Error(`sin respuesta a ${method} en ${plazoMs / 1000} s`)); }, plazoMs);
    respuestas.set(id, (m) => { clearTimeout(t); resolve(m); });
  });
}

// Llama a una herramienta y devuelve su resultado ya interpretado. Lanza si falla.
async function herramienta(nombre, args = {}, plazoMs = 60000) {
  const r = await enviar('tools/call', { name: nombre, arguments: args }, plazoMs);
  if (r.error) throw new Error(`${nombre}: ${r.error.message}`);
  const texto = (r.result?.content || []).map((c) => c.text ?? '').join('\n');
  let datos;
  try { datos = JSON.parse(texto); } catch { datos = texto; }
  if (r.result?.isError || datos?.ok === false) throw new Error(`${nombre}: ${datos?.error ?? texto}`);
  return datos;
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
const correcto = (texto) => console.log(`  ok  ${texto}`);

function contarNodos(nodo) {
  return 1 + (nodo?.children || []).reduce((n, hijo) => n + contarNodos(hijo), 0);
}

function resumirErrores(datos) {
  const lista = datos.errors || [];
  const errores = lista.filter((e) => e.severity === 'error');
  const avisos = lista.length - errores.length;
  return { errores, avisos };
}

async function principal() {
  const inicio = await enviar('initialize', {
    protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'probar_godlink', version: '1.0.0' },
  }, 180000); // la primera vez npx descarga el paquete
  servidor.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  correcto(`servidor ${inicio.result.serverInfo.name} ${inicio.result.serverInfo.version} iniciado`);

  const lista = await enviar('tools/list', {});
  correcto(`${lista.result.tools.length} herramientas disponibles`);

  let estado;
  const limite = Date.now() + ESPERA_CONEXION_MS;
  do {
    estado = await herramienta('get_godot_status');
    if (estado.connected) break;
    await esperar(2000);
  } while (Date.now() < limite);
  if (!estado.connected) {
    throw new Error(`el editor no se conectó en ${ESPERA_CONEXION_MS / 1000} s: ¿está Godot abierto con el complemento activado?`);
  }
  correcto(`editor conectado por el puerto ${estado.websocket_port} (${estado.project_path})`);

  const runtime = await herramienta('get_runtime_status');
  correcto(`Godot ${runtime.godot_version}`);

  const ajustes = await herramienta('get_project_settings');
  const escena = ajustes.settings?.main_scene;
  correcto(`escena principal: ${escena}`);

  const lectura = await herramienta('read_scene', { scene_path: escena });
  correcto(`${escena} tiene ${contarNodos(lectura.root)} nodos; raíz ${lectura.root?.name} (${lectura.root?.type})`);

  const abierta = await herramienta('scene_tree_dump', { max_depth: 0 });
  correcto(`escena abierta en el editor: ${abierta.scene_path || '(ninguna)'}`);

  const previos = resumirErrores(await herramienta('get_errors', { max_errors: 100 }));
  correcto(`editor: ${previos.errores.length} errores y ${previos.avisos} avisos`);

  if (!EJECUTAR) return 0;

  if ((await herramienta('is_playing')).playing) {
    throw new Error('ya hay un juego en marcha desde el editor: detenlo antes de usar --ejecutar');
  }
  const ejecucion = await herramienta('run_scene', { wait_for_runtime: true, startup_timeout_ms: 25000 }, 90000);
  if (!ejecucion.runtime_connected) throw new Error('el juego arrancó, pero MCPRuntime no se conectó');
  correcto(`juego en marcha (${ejecucion.scene_path}); MCPRuntime conectado en ${ejecucion.wait_for_runtime_ms} ms`);

  try {
    await esperar(3000); // deja que el menú termine de aparecer
    const captura = await herramienta('take_screenshot');
    correcto(`captura ${captura.width}×${captura.height}: ${captura.absolute_path}`);

    const raiz = await herramienta('query_runtime_node', { node_path: '/root', include_children: true, properties: [] });
    correcto(`nodos bajo /root: ${raiz.children.map((n) => n.name).join(', ')}`);

    const durante = resumirErrores(await herramienta('get_errors', { max_errors: 100, wait_ms: 500 }));
    correcto(`depurador: ${durante.errores.length} errores y ${durante.avisos} avisos`);
    for (const e of durante.errores) console.log(`      ${e.file}:${e.line} ${e.message}`);
    if (durante.errores.length) return 1;
  } finally {
    await herramienta('stop_scene');
    correcto('juego detenido');
  }
  return 0;
}

let codigo = 1;
try {
  codigo = await principal();
  console.log(codigo === 0 ? 'Godlink MCP funciona.' : 'Godlink MCP responde, pero hay errores.');
} catch (e) {
  console.error(`  FALLO  ${e.message}`);
  console.error(`Registro del servidor:\n${registro.trim()}`);
} finally {
  // En modo primario el servidor no se cierra solo mientras Godot siga conectado.
  servidor.stdin.end();
  try {
    if (process.platform === 'win32') execSync(`taskkill /PID ${servidor.pid} /T /F`, { stdio: 'ignore' });
    else servidor.kill();
  } catch { /* ya había terminado */ }
  process.exit(codigo);
}
