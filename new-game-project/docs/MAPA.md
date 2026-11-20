# Mapa del pueblo

Cómo funciona el mapa de Villa Sombría, cómo sabe dónde está el detective, cómo se calibra y cómo
ampliarlo.

## Qué hace

- Se abre con **M** durante la exploración o con **Mapa** en la pausa. Se cierra con **Esc**,
  **M** o **Volver**, y se vuelve a donde se abrió: al juego o a la pausa.
- Congela el juego detrás, como la pausa. El detective no puede moverse con el mapa abierto.
- Muestra el pueblo ilustrado sobre un pergamino, una chincheta dorada por cada lugar real, el
  rombo de objetivo en los lugares donde hay algo pendiente hoy y el marcador del detective.
- A la derecha: la leyenda, los objetivos pendientes de hoy (los de `story.json`) y la ficha del
  lugar señalado.
- Las chinchetas se señalan con el ratón, las flechas, el mando o el dedo. Al pulsar una queda
  seleccionada y su ficha dice si el detective está allí, si ya ha estado y qué tiene pendiente.

## Piezas

| Archivo | Responsabilidad |
| --- | --- |
| `data/map.json` | Lienzo, zonas calibradas y lugares |
| `scripts/map/map_calibration.gd` | `MapCalibration`: transformación del suelo del escenario al lienzo a partir de puntos de referencia |
| `scripts/map/map_region.gd` | `MapRegion`: zona exterior calibrada, con su área transitable |
| `scripts/map/map_place.gd` | `MapPlace`: lugar del pueblo con su chincheta |
| `scripts/autoload/town_map.gd` | Autoload `TownMap`: registro, `locate()`, visibilidad, objetivos y lugares visitados (sección de guardado `map`) |
| `scripts/ui/map/town_map_art.gd` | `TownMapArt`: ilustración del pueblo dibujada en código |
| `scripts/ui/map/town_map_view.gd` | `TownMapView`: pergamino, ilustración, chinchetas y marcador con una transformación común |
| `scripts/ui/map/map_place_pin.gd` | `MapPlacePin`: chincheta con rótulo; es un botón |
| `scripts/ui/map/map_player_marker.gd` | `MapPlayerMarker`: marcador del detective que late y se desliza |
| `scripts/ui/map/map_symbols.gd`, `map_symbol_icon.gd` | Símbolos compartidos por el mapa y la leyenda |
| `scenes/ui/map_screen.tscn`, `scripts/ui/map_screen.gd` | `MapScreen`: la pantalla, sobre `MenuScreen` |
| `assets/ui/iconos/mapa.svg` | Icono de la opción de la pausa |

`TownMap` no conoce la interfaz: la pantalla le pregunta y escucha `TownMap.visited_changed` y
`EventBus.objectives_changed`. La escena de juego le pasa el detective a la pausa
(`PauseMenu.set_map_target`), sin rutas de nodos fijas.

## Cómo se sabe dónde está el detective

Cada fotograma con el mapa abierto, `TownMapView` lee la posición real del detective
(`PlayerController.global_position`), hacia dónde mira y el escenario actual
(`GameState.location_id`), y llama a `TownMap.locate()`. Hay tres casos:

1. **Exterior calibrado** (plaza y estación). Su X y su Z se convierten al lienzo con la
   transformación de su zona: si el detective cruza la plaza de un lado a otro, el marcador recorre
   la distancia proporcional, y la flecha del marcador indica hacia dónde mira. La posición se
   limita al área transitable (los muros invisibles del escenario), de modo que el marcador nunca
   sale de la zona dibujada.
2. **Interior** (café, archivo, mansión). El mapa no tiene plano de los interiores y no se inventa
   una posición dentro de ellos: el marcador señala el edificio, quieto aunque el detective camine
   dentro, y la ficha dice «Estás dentro».
3. **Escenario que no figura en el mapa** (el campo de pruebas, o uno nuevo sin datos). No hay
   marcador ni posición por defecto: la ficha dice «Fuera del mapa».

Al abrir el mapa y al cambiar de escenario, el marcador se coloca al instante; dentro de un mismo
exterior se desliza hacia la posición real. Como la pausa congela al detective, la posición es la
última real antes de abrirlo. Al cargar una partida, la sección `player` del guardado coloca al
detective donde estaba y el mapa lee esa posición: no hay una posición propia del mapa.

La cámara del juego mira con un giro de 45°, y el mapa usa el mismo: pulsar «arriba» mueve el
marcador hacia arriba en el mapa, y «derecha», hacia la derecha.

## Calibración

Cada zona exterior de `map.json` declara:

```json
"plaza": {
  "location": "plaza",
  "bounds": [-14.0, -14.0, 29.1, 13.5],
  "anchors": [
    {"id": "fuente", "world": [3.5, 3.0], "map": [430.0, 540.0]},
    {"id": "puerta_archivo", "world": [9.5, -12.8], "map": [615.0, 456.8]},
    {"id": "verja_mansion", "world": [-13.1, -3.0], "map": [340.1, 348.2]},
    {"id": "puerta_cafe", "world": [-6.1, -13.1], "map": [485.2, 321.9]}
  ]
}
```

- `bounds`: área transitable en X y Z (mínimos y máximos), tomada de los muros invisibles del
  escenario.
- `anchors`: puntos de referencia, cada uno con su posición en el escenario (X y Z, en metros) y en
  el lienzo (1600 × 1000 unidades). Con dos puntos se calcula una semejanza; con tres o más, una
  transformación afín por mínimos cuadrados. Cada zona tiene cuatro: con tres el ajuste siempre es
  exacto, y el cuarto permite notar un punto mal medido.

Al cargar, `MapCalibration` comprueba el error de cada punto. Si uno se aleja más de 2 unidades, si
los puntos están alineados o si el mapa saldría en espejo, la zona se descarta, se avisa con un
error y sus lugares desaparecen del mapa en lugar de colocarse mal.

**Puntos actuales.** Escala común de 12 unidades por metro y giro de 45°:

| Zona | Punto | Escenario (X, Z) | Lienzo |
| --- | --- | --- | --- |
| Plaza | Fuente | 3,5; 3,0 | 430,0; 540,0 |
| Plaza | Puerta del archivo | 9,5; −12,8 | 615,0; 456,8 |
| Plaza | Verja de la mansión | −13,1; −3,0 | 340,1; 348,2 |
| Plaza | Puerta del café | −6,1; −13,1 | 485,2; 321,9 |
| Estación | Taquilla | −7,6; 2,0 | 1088,5; 401,6 |
| Estación | Salida a la plaza | 17,0; 12,6 | 1207,3; 700,3 |
| Estación | Andén | 5,0; −1,8 | 1227,7; 476,2 |
| Estación | Reloj del andén | 10,6; 0,2 | 1258,2; 540,7 |

Las pruebas exigen además que las dos zonas dibujadas en código no se deformen (la misma escala en
los dos ejes y ángulos rectos): un punto desplazado una unidad y media ya las hace fallar.

**Por qué es verificable.** La ilustración de cada exterior se dibuja en metros del propio
escenario y con la misma transformación que el marcador, así que el dibujo y el marcador no pueden
separarse. Las medidas de los edificios copian las de `plaza.gd` y `estacion.gd`, y
`test_map.test_drawn_buildings_match_the_scene_colliders` comprueba que cada edificio dibujado
coincida con su colisión real. Otras pruebas comprueban que las puertas queden junto a su edificio,
que la calle Mayor una las salidas reales y que todos los puntos de aparición caigan dentro del área
calibrada.

**Si cambia un escenario.** Si se mueve un edificio en `plaza.gd`, hay que moverlo también en
`PLAZA_BUILDINGS` de `town_map_art.gd`; la prueba avisa si no coinciden. Si cambian los muros
invisibles, hay que actualizar `bounds`.

**Si se sustituye la ilustración por una imagen pintada** (por ejemplo, una ilustración isométrica
como la de referencia): hay que medir en la imagen la posición de tres o más puntos reconocibles de
cada exterior (la fuente, las puertas) y escribirlos en `map`. La calibración afín admite la
perspectiva isométrica. `TownMapArt` sólo dibuja, así que se puede cambiar por un `TextureRect`
sin tocar `TownMap` ni el marcador.

## Lugares

| Lugar | Escenarios | Zona de su chincheta | En el mapa | Objetivos asociados |
| --- | --- | --- | --- | --- |
| Plaza Mayor | `plaza` | Plaza (la fuente) | Posición exacta | — |
| Café La Luna | `cafe` | Plaza (el edificio) | Edificio | `o_cafe`, `o_dormir1`, `o_dormir2` |
| Archivo Municipal | `archivo` | Plaza (el edificio) | Edificio | `o_archivo` |
| Mansión Valdés | `mansion` | Plaza (el edificio) | Edificio | `o_mansion`, `o_despacho` |
| Estación de tren | `estacion` | Estación (la taquilla) | Posición exacta | `o_estacion` |

La imagen de referencia incluía un **Callejón**, pero el juego no lo tiene y no se ha añadido. El
Banco Valdés aparece rotulado porque está en la plaza, pero no tiene chincheta porque no se puede
visitar. La calle Mayor entre la plaza y la estación, las casas de los alrededores, la rosa de los
vientos y la cartela son decoración: no tienen chincheta ni posición jugable.

Los objetivos sin un lugar fijo (interrogar a los sospechosos, hablar con Ortega, usar el tablero)
aparecen en el panel con un punto en lugar del rombo.

### Campos de un lugar

```json
{"id": "archivo", "locations": ["archivo"], "region": "plaza", "anchor": [9.5, -18.0],
 "label": "Archivo Municipal", "objectives": ["o_archivo"]}
```

| Campo | Obligatorio | Significado |
| --- | --- | --- |
| `id` | Sí | Identificador único |
| `locations` | Sí | Escenarios de `locations.json` que pertenecen al lugar |
| `region` | Sí | Zona calibrada donde está la chincheta |
| `anchor` | Sí | Posición de la chincheta en metros de esa zona |
| `label` | No | Nombre en el mapa; si falta, el del escenario |
| `objectives` | No | Objetivos de `story.json` que se cumplen allí |
| `discovered_if` | No | Condición (formato de `Conditions`) para conocerlo; sin ella, se conoce desde el principio |
| `available_if` | No | Condición para que esté abierto; si no se cumple, la chincheta se ve atenuada |
| `interest` | No | `false` lo deja sin chincheta |
| `label_side` | No | `below` (por defecto) o `above`: lado del rótulo |

**Reglas.** Una chincheta se muestra si todos sus escenarios existen con su escena, si el lugar se
conoce (su condición o haberlo visitado) y si es un punto de interés. Hoy ningún lugar tiene
condiciones: todos son conocidos y están abiertos, porque el juego no tiene un sistema de
descubrimiento y no se han añadido restricciones nuevas.

## Guardado

`TownMap` registra la sección `map` con los lugares que el detective ha pisado:

```json
"map": {"visited": ["estacion", "plaza"]}
```

- Se anota al entrar en cada escenario (`EventBus.location_changed`).
- Una partida nueva empieza vacía (`Game._start_new_game` llama a `TownMap.reset()`).
- Las partidas anteriores al mapa no traen la sección: cargan sin lugares visitados y el lugar donde
  se reanuda se anota al construir el escenario. No hace falta cambiar la versión del formato.
- Se ignoran los identificadores que no son lugares conocidos.

La posición del detective no se guarda aparte: es la de la sección `player`. Los objetivos y la
visibilidad de las chinchetas se deducen del estado, como en el resto del juego.

## Controles

| Entrada | Efecto |
| --- | --- |
| M (acción `open_map`) | Abre el mapa desde la exploración o desde la pausa; con el mapa abierto, lo cierra |
| Esc, botón de cancelar | Cierra el mapa |
| Flechas, cruceta | Recorren las chinchetas; desde las de abajo se baja a «Volver» |
| Ratón, dedo | Señalan y seleccionan chinchetas |
| Intro, botón de aceptar | Selecciona la chincheta señalada |

M no hace nada durante una conversación, una transición, el expediente, el tablero o la
acusación, igual que J y B. La tecla aparece en Configuración › Controles y en la barra de teclas
del HUD, que leen el InputMap.

## Tamaño de pantalla y pantallas táctiles

`MapScreen` calcula el tamaño del pergamino para ocupar todo el alto disponible sin perder su
proporción (16:10) ni sacar el panel lateral de la pantalla. La ilustración, las chinchetas y el
marcador se colocan con la misma transformación del lienzo a la pantalla y se recolocan al cambiar
la ventana. Los rótulos usan un tamaño de letra fijo, legible a cualquier escala.

Pensando en Android: las chinchetas son botones de al menos 48 píxeles de ancho que responden a un
toque (Godot convierte los toques en clics), la navegación no depende del ratón y nada usa
coordenadas absolutas de pantalla.

## Cómo ampliarlo

| Ampliación | Qué tocar |
| --- | --- |
| Lugar nuevo en un exterior calibrado | Su escenario en `locations.json` y una entrada en `places` de `map.json`. La interfaz no cambia |
| Exterior nuevo con posición exacta | Una zona en `regions` con `bounds` y tres o más puntos de referencia, y su dibujo en `TownMapArt` (o una imagen pintada) |
| Lugares por descubrir o que se desbloquean | `discovered_if` o `available_if` con marcas, pistas o días, como en el resto de los datos |
| Seguimiento de un objetivo concreto | `TownMap.get_pending_objectives()` ya dice dónde se cumple cada uno; la pantalla podría resaltar sólo el elegido |
| Marcadores de pistas o de personajes | Otra capa de símbolos en `TownMapView`, con posiciones de `TownMap.locate()` o de las chinchetas |
| Viaje rápido | `TownMapView.place_pressed` ya da el lugar elegido; bastaría con pedir `EventBus.location_change_requested` con un punto de aparición y sus condiciones |
| Controles táctiles | Las chinchetas ya son botones; faltaría un gesto de zoom sobre `TownMapView` |

## Pruebas

| Prueba | Cubre |
| --- | --- |
| `test_map` | Datos sin errores, calibración exacta y sin deformación, arriba en pantalla es arriba en el mapa, áreas transitables, edificios dibujados frente a colisiones reales, puertas junto a su edificio, calle Mayor entre las salidas, posición proporcional, límites, interiores sin posiciones inventadas, objetivos, lugares visitados, datos dañados |
| `test_map_screen` | Abrir con M al empezar, caminar por la plaza con entradas reales, deslizamiento, entrar y salir del archivo, cambiar de escenario, cargar una partida, abrir y cerrar seguido, cuatro tamaños de pantalla, convivencia con la pausa, el expediente y las conversaciones, escenario sin mapa, objetivos del panel, teclado, ratón y selección, tecla en Controles |
| `test_save_slots` | La sección `map` se guarda, se recupera y no pasa a una partida nueva |
| `test_pause_menus` | La opción «Mapa» en la pausa |

Capturas: `tests/visual/captura.tscn` con `--open=map` (y `--open=map:archivo` para señalar una
chincheta).

## Limitaciones

- **Lo dibujado repite las medidas de los escenarios.** Si se cambia un escenario sin cambiar el
  mapa, la prueba de colisiones avisa de los edificios, pero no de los objetos pequeños (bancos,
  farolas, árboles).
- **Los interiores no tienen plano.** El marcador señala el edificio, no la habitación.
- **El recorrido de la calle Mayor entre la plaza y la estación no es jugable:** el juego pasa de
  una salida a la otra con un fundido, y el mapa no muestra al detective por el camino.
- **Revisión visual con capturas fijas.** Las animaciones (la pulsación, el deslizamiento, el
  rombo y la entrada) se comprobaron con pruebas y capturas, no a mano ni con un mando real.
- **Sonido:** la selección y «Volver» usan el clic existente; el mapa no tiene un sonido propio.
