# Recursos del proyecto

Registro de los recursos que no se crean dentro del propio proyecto: de dónde vienen, con qué
herramienta se generaron y bajo qué condiciones se usan. Actualízalo cada vez que entre un
recurso nuevo.

## Estado actual

Todo el contenido actual se genera en el propio repositorio:

| Recurso | Origen |
| --- | --- |
| Geometría y escenarios | Primitivas generadas por código (`scripts/world/`) |
| Personajes 3D | Modelo procedural (`scripts/actors/character_model.gd`) |
| Siluetas de los interrogatorios | SVG generados con `tools/generar_siluetas.py` |
| Materiales y efectos | Shaders propios (`assets/shaders/`) |
| Sonido y música | Síntesis al arrancar (`scripts/autoload/audio_manager.gd`) |
| Fuentes | Fuentes del sistema; no se incluyen archivos de fuentes |
| Motor | Godot Engine 4.7, licencia MIT |

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
| *(vacío)* | | | | |

## Créditos previstos

Cuando los recursos entren en el juego, los créditos del menú (`scripts/ui/main_menu.gd`) y el
README deberán indicarlo, por ejemplo:

- «Retratos generados con IA (ChatGPT, OpenAI) bajo la dirección de Luis Castillo y Juan Camilo Miño Castillo.»
- «Voces sintéticas generadas con ElevenLabs.»

Al mismo tiempo habrá que retirar la frase «El juego no incluye recursos de terceros» de los
créditos y del README.
