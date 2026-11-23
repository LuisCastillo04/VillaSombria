# Recursos del proyecto

Registro de los recursos que no se crean dentro del propio proyecto: de dónde vienen, con qué
herramienta se generaron y bajo qué condiciones se usan. Actualízalo cada vez que entre un
recurso nuevo.

## Estado actual

Todo el contenido actual se genera en el propio repositorio:

| Recurso | Origen |
| --- | --- |
| Geometría y escenarios | Primitivas generadas por código (`scripts/world/`); las piezas migradas se dibujan con modelos propios de Blender (`assets/modelos/`), con el código como alternativa |
| Personajes 3D | Modelo procedural (`scripts/actors/character_model.gd`) |
| Siluetas de los interrogatorios | SVG generados con `tools/generar_siluetas.py` |
| Grabados sepia del expediente | SVG generados con `tools/generar_grabados.py` |
| Ilustraciones de las evidencias (reloj de sobremesa, violetas prensadas) | SVG generados con `tools/generar_evidencias.py`; provisionales, ver [EVIDENCIAS.md](EVIDENCIAS.md) |
| Iconos de la interfaz | SVG escritos a mano en el repositorio (`assets/ui/iconos/`) |
| Materiales y efectos | Shaders propios (`assets/shaders/`) |
| Música, ambientes y efectos | Composiciones y sonidos originales sintetizados con `tools/generar_audio.py` (`tools/sintesis/`), en `assets/audio/`; ver [AUDIO.md](AUDIO.md) y [AUDIO_INVENTARIO.md](AUDIO_INVENTARIO.md) |
| Fuentes | Fuentes del sistema; no se incluyen archivos de fuentes. Las manuscritas de las cartas y la del periódico usan familias de Microsoft Office si el equipo las tiene y, si no, Segoe Script y Georgia, que vienen con Windows; ver [EVIDENCIAS.md](EVIDENCIAS.md) |
| Motor | Godot Engine 4.7, licencia MIT |

## Herramientas de desarrollo de terceros

No forman parte del contenido del juego.

| Carpeta | Origen | Licencia | Uso |
| --- | --- | --- | --- |
| `addons/godot_mcp/` | Godlink MCP 0.6.0 («Godot MCP»), de Tomer Yud, instalado desde la Asset Store de Godot ([tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp)) | MIT (`addons/godot_mcp/LICENSE`) | Conecta Claude Code con el editor. Hay que desactivarlo antes de exportar una versión para jugadores; ver [GODLINK_MCP.md](GODLINK_MCP.md) |

## Recursos previstos

### Retratos generados con ChatGPT (confirmado)

- **Uso:** retratos de los interrogatorios; posiblemente también fondo del menú y documentos de las pistas.
- **Integración:** los retratos sólo requieren cambiar el campo `portrait` de cada personaje en
  `data/characters.json`. No hace falta tocar código. Otros usos sí requerirán programación.
- **Formato recomendado:** PNG con fondo transparente, unos 800×1100 píxeles, encuadre de busto
  y un estilo uniforme para los diez personajes. Las siluetas SVG actuales sirven de referencia.
- **Ubicación sugerida:** `assets/retratos/`.

### Voces generadas con ElevenLabs (pendiente de créditos)

- **Decisión:** depende de los créditos disponibles. Puede no llegar a usarse.
- **Estado del juego:** todavía no reproduce voces. El soporte no está implementado.
- **Diseño previsto:** un campo opcional por línea de diálogo con la ruta del audio. Si el archivo
  no existe, la línea se lee en silencio, de modo que se puede doblar sólo una parte, por ejemplo
  la introducción, la confrontación y el epílogo.
- **Ubicación sugerida:** `assets/voces/`.

### Modelos 3D hechos en Blender (en curso)

- **Estado:** 68 modelos en el juego desde el 2026-11-23 (atrezo, mobiliario, fachadas, piezas
  de los escenarios y los diez personajes). Lista en
  [blender/INVENTARIO_MODELOS.md](blender/INVENTARIO_MODELOS.md) y en `ModelRegistry.MODELS`.
- **Origen:** modelos propios, hechos en Blender 5.3 a partir de las piezas procedurales de hoy.
- **Integración:** GLB en `assets/modelos/<categoría>/`, fusionados en el lote de cada escenario;
  el código procedural se conserva como alternativa.
- **Fuentes editables:** `.blend` en `VillaSombria/blender/fuentes/`, fuera del proyecto Godot.

## Condiciones que hay que comprobar

Antes de usar estos recursos en la entrega o en una publicación:

- [ ] El profesor permite contenido generado con IA en el proyecto final, y cómo debe declararse.
- [ ] Las condiciones de uso vigentes de OpenAI para las imágenes generadas.
- [ ] El plan de ElevenLabs utilizado: si exige atribución y si permite uso público o comercial.
- [ ] Ninguna voz clona a una persona real sin su permiso.

## Registro de recursos

Añade una fila por recurso o lote de recursos.

| Archivo o carpeta | Herramienta | Fecha | Autor de la indicación | Condiciones |
| --- | --- | --- | --- | --- |
| `assets/modelos/` y `blender/fuentes/` (modelos 3D) | Blender 5.3 (exportador glTF 5.3.43) con los scripts de `blender/scripts/`, a partir de las piezas procedurales del propio juego; escrito con Claude Code (Anthropic) | 23/11/2026 | Los autores | Originales del proyecto. Cada GLB tiene su `.blend` de origen y su registro de exportación en `blender/registro/`. Blender no hace falta para abrir ni jugar el proyecto |
| `assets/audio/` (115 archivos) | Sintetizador propio en Python (`tools/generar_audio.py` y `tools/sintesis/`, con NumPy, SciPy y FFmpeg), escrito y compuesto con Claude Code (Anthropic) | 22/11/2026 | Los autores | Originales del proyecto: síntesis sin muestras grabadas ni recursos de terceros. NumPy y SciPy (BSD) y FFmpeg (LGPL) sólo se usan para generarlos; no forman parte del juego |

## Créditos previstos

Cuando los recursos entren en el juego, los créditos del menú (`scripts/ui/main_menu.gd`) y el
README deberán indicarlo, por ejemplo:

- «Retratos generados con IA (ChatGPT, OpenAI) bajo la dirección de Juan Camilo Miño Castillo y Luis Eduardo Miño Castillo.»
- «Voces sintéticas generadas con ElevenLabs.»

Al mismo tiempo habrá que retirar la frase «El juego no incluye recursos de terceros» de los
créditos y del README.
