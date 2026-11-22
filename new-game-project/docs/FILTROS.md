# Filtros visuales

Filtros de color del mundo en **Configuración → Filtros**: Modo noir, Sepia, Frío nocturno y Colores
originales. Qué hace cada uno, cómo se aplica sin tocar la interfaz, dónde se guarda y cómo se prueba.

## Los cuatro filtros

| Identificador | Nombre | Qué hace |
| --- | --- | --- |
| `noir` | Modo noir | Blanco y negro con una curva de contraste en S marcada: sombras profundas sin llegar al negro puro y las farolas, las ventanas y la lluvia iluminada en blanco |
| `sepia` | Sepia | Marrón en las sombras y crema dorado en las luces, con un poco del color original para que los materiales no se confundan; el negro algo levantado y el blanco algo apagado, como en una fotografía antigua |
| `cold_night` | Frío nocturno | Sombras azules, algo más de la mitad del color original y luces apenas cálidas: la luz de las farolas sigue siendo cálida frente al ambiente frío |
| `original` | Colores originales | Ninguna corrección: el aspecto de siempre. Es el valor por defecto |

Los identificadores son estables y son lo único que se guarda; los nombres y las descripciones que se
ven en Configuración salen del mismo catálogo (`VisualFilters.FILTERS`).

## Cómo se aplica

```
Mundo 3D (escenario, personajes, luces, sombras, lluvia, carteles)
   │  tonemap y ajustes del entorno de cada escenario (sin cambios)
   ▼
PostFx, capa 1: noir_post.gdshader lee la pantalla una sola vez
   niebla ─► filtro de color ─► viñeta ─► grano
   ▼
Interfaz, capas 2 a 50: HUD, menú principal, conversaciones, expediente, tablero,
pausa, configuración, mapa, fundidos, indicador de guardado, confirmaciones, salida
```

- **Una sola pasada, sin piezas nuevas.** El juego ya tenía un postproceso de pantalla completa
  (`PostFx`, `scenes/world/post_fx.tscn`) que leía la pantalla para dibujar la niebla, la viñeta y el
  grano. El filtro es un paso más dentro de ese mismo shader. No hay cámaras, viewports, materiales ni
  texturas nuevas.
- **Sólo el mundo.** `PostFx` está en la capa 1 (`PostFx.LAYER`) y toda la interfaz en capas
  superiores, así que lo que lee de la pantalla es sólo el mundo y lo que se dibuja encima conserva sus
  colores: dorado, crema, burdeos y fondo oscuro. `test_every_interface_is_drawn_above_the_filter`
  recorre el árbol con la pausa y Configuración abiertas y falla si algún control quedara por debajo.
- **Antes de la viñeta y el grano.** El filtro va después de la niebla (que es parte del mundo y se
  tiñe con él) y antes de la viñeta y el grano, que así se ven igual con cualquier filtro.
- **Por qué no con el entorno 3D.** Los ajustes de color de `Environment` actúan antes de la niebla y
  el grano del postproceso: con ellos, el modo noir seguiría teniendo la niebla azulada encima.
- **Las imágenes de las ranuras no se filtran.** `SavePreview` (imágenes de las partidas y foto del
  expediente) crea su propio material con los valores por defecto del shader, que dejan la imagen tal
  cual. El filtro es una preferencia de la pantalla, no de la partida: una partida guardada en noir se
  ve en color en la lista y no cambia si después se elige otro filtro.

### Parámetros del shader

`noir_post.gdshader` recibe la corrección de color en estos parámetros. `VisualFilters.NEUTRAL` tiene
los valores que no cambian nada, y cada filtro sólo indica los que cambia:

| Parámetro | Neutro | Noir | Sepia | Frío nocturno | Qué hace |
| --- | --- | --- | --- | --- | --- |
| `grade_amount` | 0 | 1 | 1 | 1 | Cuánto se aplica. Con 0 el shader ni siquiera calcula la corrección |
| `grade_saturation` | 1 | 0 | 0,2 | 0,55 | Parte del color original que se conserva |
| `grade_contrast` | 1 | 1,5 | 1,12 | 1,08 | Pendiente de la curva en S de la luminancia en el pivote |
| `grade_pivot` | 0,5 | 0,3 | 0,32 | 0,3 | Luminancia que no cambia con el contraste. Es baja porque el juego es de noche |
| `grade_lift` | 0 | 0,012 | 0,035 | 0,012 | Luminancia a la que llega el negro |
| `grade_gain` | 1 | 1 | 0,96 | 0,98 | Luminancia a la que llega el blanco |
| `grade_shadow_tint` | (1, 1, 1) | (1, 1, 1) | (1,28, 0,95, 0,62) | (0,8, 1, 1,5) | Tono de las sombras |
| `grade_highlight_tint` | (1, 1, 1) | (1, 1, 1) | (1,12, 1, 0,78) | (1,03, 1, 0,93) | Tono de las luces |
| `grade_balance` | 0,5 | 0,5 | 0,5 | 0,3 | Luminancia en la que los dos tintes pesan igual |

La curva en S está partida en el pivote: dos potencias que se unen allí con la misma pendiente, así que
el contraste crece sin recortar el negro ni el blanco y las diferencias de luz entre materiales se
mantienen. Los tintes multiplican la luminancia y la suya es casi 1, así que tiñen sin aclarar ni
oscurecer. El color que se conserva crece o mengua con la nueva luminancia para no cambiar de tono.

### Medidas en las capturas

Medias de color en la estación a las 21:00, con la herramienta de capturas a 1280 × 720:

| | Luz de la farola (R, G, B) | Suelo (R, G, B) |
| --- | --- | --- |
| Colores originales | 164, 146, 115 | 50, 47, 59 |
| Modo noir | 159, 159, 159 | 44, 44, 44 |
| Sepia | 165, 145, 106 | 64, 49, 34 |
| Frío nocturno | 160, 146, 120 | 43, 48, 70 |

`grade_balance` existe por esto: con el equilibrio en 0,5 el azul de las sombras llegaba a los tonos
medios y la farola del frío nocturno se veía blanca (147, 146, 150).

## Uno solo a la vez

- El filtro activo es **una sola preferencia**, `filtros/activo`, con uno de los cuatro
  identificadores. No hay forma de tener dos: elegir uno sustituye al anterior.
- Cada filtro escribe **todos** los parámetros, partiendo de los neutros: al pasar de uno a otro no
  queda ningún resto del anterior.
- **Repetir el filtro activo no hace nada**: `Settings.set_value` no guarda ni avisa si el valor no
  cambia, y `VisualFilters.apply_to_material` no vuelve a escribir un material que ya lo tiene.

## Preferencia y persistencia

Se guarda con las demás preferencias en `user://ajustes.cfg`, en su propia sección:

```ini
[filtros]
activo="original"
```

- **Por defecto, Colores originales.** Sin archivo, o con un archivo de antes de los filtros, el juego
  empieza con los colores de siempre.
- **Validación.** `SettingsSchema` sólo admite los cuatro identificadores. Uno desconocido, un número o
  el texto visible («Modo noir») se rechazan al leer: se usan los colores originales y el archivo se
  reescribe corregido.
- **Al elegir.** Se guarda en el acto y se aplica a todos los postprocesos del árbol
  (`VisualFilters.apply`).
- **Al arrancar y al releer el archivo.** `Settings` lo lee antes de la primera escena y lo vuelve a
  aplicar en `apply_all`.
- **Al cambiar de escena.** Cada `PostFx` se registra al aparecer (`VisualFilters.register_post`) y
  toma el filtro vigente: el de la partida, el del menú principal, el de una partida cargada y, como
  `PostFx` sigue en su sitio, también al cambiar de lugar o entrar en un interior. Nada lo devuelve a
  los colores originales en un fundido o una carga.
- **Independiente de las partidas.** No va en las ranuras: cargar una partida mantiene el filtro que
  hay ahora, no el de cuando se guardó.

## Configuración → Filtros

La pestaña está entre Jugabilidad y Accesibilidad, como en la referencia. Arriba, en cursiva, «Activa
filtros de pantalla que solo cambian los colores del juego.»; debajo, una tarjeta por filtro
(`FilterCard`, `scripts/ui/filter_card.gd`) con su nombre, su descripción y, a la derecha:

- **«✓ ACTIVO»** en el filtro aplicado: botón granate con filete dorado claro, y la tarjeta con el
  filete dorado encendido y un halo.
- **«SELECCIONAR»** en los demás.

La marca ✓ se dibuja en código para no depender de que la fuente tenga ese carácter. El botón tiene
siempre el mismo ancho, así que nada se mueve al cambiar de filtro.

| Con | Cómo se elige |
| --- | --- |
| Ratón | Un clic en cualquier parte de la tarjeta |
| Teclado | Desde la pestaña, derecha entra en la primera tarjeta; arriba y abajo las recorren; Intro o Espacio elige; izquierda vuelve a la pestaña |
| Mando | La cruceta o el stick recorren las tarjetas, A elige y B vuelve (ver [CONTROLES.md](CONTROLES.md)) |

Al elegir, el mundo cambia en el acto detrás del menú, que sigue abierto para comparar. La tarjeta
señalada toma el fondo burdeos de las filas de los menús. Con el contraste aumentado, el foco es el
contorno blanco y grueso de esa opción.

## Compatibilidad

| Con | Resultado |
| --- | --- |
| Luces de farolas, ventanas y lámparas | El filtro cambia sus colores en pantalla, no las luces: intensidad, color y sombras quedan como estaban (`test_filters_leave_lights_rain_and_quality_alone`) |
| Lluvia y niebla | La lluvia se sigue viendo con los cuatro filtros; la niebla se tiñe con el mundo |
| Calidad de iluminación y de efectos | Independientes: bajar la calidad sigue quitando sombras, resplandor, gotas, capas de niebla y grano, y el filtro sigue igual |
| Resolución, modos de ventana y pantalla completa | El filtro trabaja sobre la imagen ya dibujada en coordenadas de pantalla, así que no depende del tamaño. Comprobado en capturas a 1024 × 576, 1280 × 720 y 1920 × 1080 |
| Interiores | El mismo `PostFx` sigue activo, sin niebla; el filtro se aplica igual (captura del café en sepia) |
| Conversaciones, expediente, tablero, mapa, pausa y menú principal | Conservan sus colores; detrás, el mundo con el filtro |
| Contraste aumentado y tamaño de letra | Independientes: actúan sobre la interfaz, el filtro sobre el mundo |
| Fundidos | `ScreenFade` (capa 30) funde a negro por encima del filtro, sin tono marrón ni azul |
| Imágenes de las ranuras y foto del expediente | En sus colores, con cualquier filtro (`visual/vista_previa`) |

## Rendimiento

Plaza a 1920 × 1080 en el portátil de desarrollo (GTX 1650 Ti), calidad alta, con
`tests/visual/rendimiento.tscn`. Cada filtro, medido dos veces alternando con los colores originales:

| Filtro | GPU por fotograma | Llamadas de dibujado | Primitivas | Memoria de vídeo |
| --- | --- | --- | --- | --- |
| Colores originales | 6,97 ms | 267 | 139.148 | 344 MB |
| Modo noir | 7,05 ms | 267 | 139.148 | 344 MB |
| Sepia | 7,05 ms | 267 | 139.148 | 344 MB |
| Frío nocturno | 7,05 ms | 267 | 139.148 | 344 MB |

El filtro cuesta unos 0,08 ms de GPU por fotograma a 1080p y no añade llamadas, primitivas ni memoria.
El tiempo total por fotograma fue el mismo en las seis mediciones (33,3 ms al lanzarlo desde la
terminal en este portátil, también sin filtro), así que el filtro no cambió la tasa de fotogramas.

```powershell
godot --path . --resolution 1920x1080 res://tests/visual/rendimiento.tscn -- --location=plaza --filtro=noir
```

## Cómo comprobarlo en Godot

1. Abre el proyecto y ejecuta la escena principal (F5).
2. En el menú principal, entra en **Configuración → Filtros**. La plaza de detrás muestra el filtro.
3. Elige **Modo noir**: la plaza pasa al blanco y negro al momento, su tarjeta dice «✓ ACTIVO» y el
   menú conserva el dorado, el crema y el burdeos.
4. Elige **Sepia** y **Frío nocturno**: cada uno sustituye al anterior y sólo una tarjeta está activa.
   En el frío nocturno, las farolas siguen cálidas.
5. Vuelve a **Colores originales**: la plaza recupera exactamente su aspecto.
6. Elige uno, empieza o carga una partida y abre la pausa (Esc), el expediente (J), el tablero (B) y
   el mapa (M), y habla con alguien: el mundo mantiene el filtro y ninguna pantalla cambia de color.
7. Entra en el café y vuelve a salir; cambia la calidad en **Gráficos**: el filtro sigue igual.
8. Cierra el juego y vuelve a abrirlo: el filtro sigue elegido. Está en
   `%APPDATA%\Godot\app_userdata\Villa Sombría\ajustes.cfg`, sección `[filtros]`.

Para comparar en imágenes:

```powershell
godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/noir.png --location=plaza --time=21:00 --ajustes=filtros/activo=noir
godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/filtros.png --open=settings:3 --ajustes=filtros/activo=sepia
```

## Limitaciones

- **Los filtros se han revisado con capturas fijas**, no jugando en movimiento con cada uno.
- **El mando se ha probado con eventos simulados**, como el resto de Configuración; no con uno físico.
- **El 2D del mundo.** Hoy todo el mundo es 3D (los carteles son `Label3D`). Si algún día se dibuja algo
  del mundo con nodos 2D, tendrá que ir en una capa por debajo de `PostFx` para recibir el filtro.
  Cualquier interfaz nueva tiene que ir en una capa por encima de la 1, o se filtraría; la prueba de
  capas lo detecta.
- **Icono de la pestaña.** Filtros usa el mismo icono de deslizadores que Jugabilidad, como en la
  referencia.
- **Coste fijo.** Con Colores originales no se calcula nada, pero la lectura de pantalla de la niebla, la
  viñeta y el grano es la de siempre: el filtro no la añade ni la quita.

## Añadir un filtro

1. Añade su identificador a `VisualFilters.IDS`, en la posición en que debe aparecer.
2. Añade su entrada a `VisualFilters.FILTERS`: `label`, `description` y en `grade` sólo los parámetros
   que cambian respecto a `NEUTRAL`, con `grade_amount` a 1.
3. Nada más: la preferencia admite el nuevo identificador, Configuración crea su tarjeta y el
   postproceso lo aplica. Revisa el resultado con `captura.tscn --ajustes=filtros/activo=<id>`.

Si un filtro necesita algo que la corrección de color no hace, añade el parámetro al shader con un valor
neutro por defecto y a `NEUTRAL`, para que los demás filtros no cambien.

## Piezas

| Pieza | Papel |
| --- | --- |
| `VisualFilters` (`scripts/settings/visual_filters.gd`) | Catálogo de filtros, parámetros neutros, validación de identificadores, aplicación a un material y a todos los postprocesos |
| `noir_post.gdshader` (`assets/shaders/`) | Niebla, filtro de color, viñeta y grano en una sola pasada |
| `PostFx` (`scripts/world/post_fx.gd`) | Capa 1 del mundo: se registra y muestra el filtro vigente |
| `SettingsSchema` / `Settings` | La preferencia `filtros/activo`: valor por defecto, validación, guardado y aplicación |
| `SettingsMenu` / `FilterCard` | La pestaña Filtros y sus tarjetas |

## Pruebas

`tests/unit/test_visual_filters.gd` comprueba el catálogo y su orden; que los colores originales son
el valor por defecto y neutro; los identificadores desconocidos, los archivos antiguos o dañados; un
material con un solo filtro y sin restos; con la escena de juego real, que cada cambio llega al mundo
en el acto y sólo hay un postproceso; que repetir el filtro activo no escribe nada ni crea materiales;
que toda la interfaz se dibuja encima del filtro; que no toca luces, entorno, lluvia, reloj ni posición
y convive con la calidad gráfica; que sobrevive a los cambios de lugar, a una escena de la historia, al
guardado (sin ir en la partida), a la carga y al menú principal; que releer las preferencias lo
aplica; y la página de Configuración con ratón, teclado y mando.

`tests/persistencia/ajustes.gd` guarda el sepia en un proceso y comprueba en otro que se aplica al
mundo que ya estaba y al que aparece después. `tests/visual/vista_previa.gd` (con ventana) comprueba
que las imágenes de las ranuras conservan su color con el modo noir activo.
