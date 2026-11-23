# NPC, navegación y límites de los escenarios

Cómo se impide que el detective caiga al vacío, cómo caminan los NPC sin atravesar nada ni
estorbar a la investigación, cómo intervienen en persona en una escena y cómo salen de un
escenario, dónde se configuran y cómo se prueba. Rama `fix/npcs-colisiones-escenarios`.

## Qué se corrigió

| Síntoma | Causa | Solución |
| --- | --- | --- |
| En el café, la mansión y el archivo el detective podía caer al vacío | El suelo de colisión de cada escenario es un rectángulo mayor que el edificio (40 × 24 m en el café). Por el hueco de la puerta de la calle se salía a ese suelo invisible y, en su borde, se caía | La puerta de la calle se cierra por fuera (`InteriorKit.seal_street_door`): se llega al umbral y se sale con E, como siempre |
| En la estación también | El murete sur terminaba 1,1 m antes del límite invisible del oeste | El murete llega hasta el límite |
| En el café, NPC «encimados» detrás de la barra | Era Rosa sola: todos los NPC aparecían mirando a −Z, de espaldas a la clientela, y de espaldas sus rizos se leían como dos cabezas | Cada marcador puede tener orientación (`face_marker`): Rosa mira a la clientela |
| En la mansión, NPC pegados o superpuestos | La ronda de Lucía terminaba en el sitio de Irene, Anselmo y Marcos compartían «pasillo» el lunes, y los NPC no chocaban entre sí | Puntos nuevos y rutinas sin solapes; los NPC chocan entre sí y con el detective |
| NPC atravesando muebles | Caminaban en línea recta y, si se atascaban 4 s, saltaban al destino. Los taburetes de las mesas del café no tenían colisión | Navegación horneada con las colisiones reales; un camino bloqueado se recalcula. Los taburetes tienen colisión |
| NPC demasiado estáticos | No había comportamiento ambiental | Estados, perfiles por personaje y rutinas con paseos, visitas y rondas |
| Al entrar por primera vez en el café, el sargento Ortega hablaba sin estar allí | La escena «llamada» era una llamada de teléfono y su rutina lo tenía en la mansión desde las 8:00. Rosa sí estaba, pero detrás de la barra, a 9 m: durante la escena la tapaban las siluetas de la conversación, que cubren los lados y la franja de abajo | Hasta la llamada, Ortega espera junto a la puerta del café y Rosa le hace compañía (tramos con `if`). Intervienen en persona (`cast`), se vuelven hacia el detective y, al terminar, Ortega sale por la puerta hacia la mansión y Rosa vuelve a la barra |
| Una cómoda en mitad del cuarto de Lucía | Estaba a 0,63 m de la pared del fondo, justo delante de la puerta de la alcoba, y dejaba un paso de 0,63 m | Contra la pared del fondo, entre la esquina y esa puerta |
| El árbol de otoño de la plaza se montaba sobre el quiosco | Estaba en (−4,8; 10,0), a 0,45 m del mostrador: la copa tapaba el toldo y el tronco cortaba el paso delante de los periódicos | En (−2,0; 0,3), entre el banco oeste y la farola del norte, dentro de una jardinera octogonal de piedra con arbustos y flores (`PropsKit.planter`, modelo `jardinera`). Ocho cuñas de colisión cubren el octógono: se rodea sin atravesarla y la navegación no deja huecos dentro |
| Una caja suelta junto a la cama de la pensión del café | La mesilla estaba en (−9,6; −3,2), en mitad del cuarto y junto al paso del tabique; la cama, a 1,1 m de la pared | La cama, con el cabecero contra la pared del fondo (z −3,6 → −4,65); la mesilla, a su derecha y contra la misma pared, apoyada en el suelo (antes flotaba 1 cm). Silla nueva (modelo `silla`) delante de la cómoda, que hace de escritorio. El punto de descanso y el de aparición «cama» se mueven con la cama |
| La mesilla del cuarto de Lucía, en mitad del cuarto | Estaba en (−11,4; 4,6), a 1 m del costado de la cama y a 2,4 m de la pared | En (−13,45; 5,45): contra la pared del fondo, junto al cabecero y a 0,2 m de la cama, con su misal. La pista de la carta va delante de ella y Lucía la mira desde su puesto |

## Límites de los escenarios

Cada escenario declara en `build()` su **área transitable** (`play_area`, un rectángulo XZ que
encierra todo lo que se puede pisar). Las colisiones deben impedir salir de ella; el área sirve
para hornear la navegación y para la red de seguridad.

| Escenario | `play_area` |
| --- | --- |
| Plaza | x −14,5 … 29,6; z −14,5 … 14 |
| Café | x −15 … 13; z −6 … 6 |
| Mansión | x −14 … 14; z −9 … 9 |
| Archivo | x −10 … 10; z −7 … 7 |
| Estación | x −16 … 23; z −4,3 … 14,5 |
| Campo de pruebas | x −20 … 20; z −20 … 20 (con bordes cerrados) |

Utilidades de `LocationBase`:

- `block_passage(desde, hasta)`: muro invisible de 3 m entre dos puntos del suelo. Para cerrar un
  hueco concreto sin rodear el escenario con una caja que bloquearía caminos válidos.
- `InteriorKit.seal_street_door(...)`: cierra por fuera el hueco de la puerta de la calle. La
  barrera queda tras el grosor de la pared y la solapa 0,3 m por cada lado.
- `InteriorKit.wall` registra cada hueco de pared como paso (`get_doorways()`): los NPC no se paran
  en ellos.
- `is_inside_play_area(punto, margen)` y `is_standing_point(punto, radio)`: dentro del área, con
  suelo debajo y sin obstáculos.

`test_world_bounds` recorre cada escenario desde cada punto de aparición con la cápsula del
detective (celdas de 0,4 m) y falla si llega a un punto sin suelo o fuera del área, y camina con
teclas reales contra cada puerta de la calle. Con la geometría anterior detecta las cuatro fugas
(el detective acababa en z ≈ 20, sin suelo).

**Al añadir un escenario:** declarar `play_area`, cerrar con `seal_street_door` o
`block_passage` lo que dé al vacío y añadirlo a `LOCATIONS` en `test_world_bounds`.

## Red de seguridad: `FallGuard`

Componente reutilizable (`scripts/actors/fall_guard.gd`) para cualquier `CharacterBody3D`. Lo
llevan el detective (`player.tscn`) y cada NPC (`npc.tscn`). No sustituye a las colisiones: es la
última defensa si alguna falla.

1. **Punto seguro.** Se actualiza sólo si el cuerpo está en el suelo, a la altura del suelo, dentro
   del área y lleva 0,2 s asentado (no mientras resbala ni en el aire).
2. **Situación anormal.** 2 m por debajo del suelo, o más de 0,75 m fuera del área.
3. **Recuperación.** Vuelve al punto seguro parado (velocidad cero), sin tocar el estado de la
   partida, y emite `recovered`. La cámara salta allí (`Game._on_player_recovered`); un NPC hace
   una pausa y vuelve a decidir.
4. **Sin bucles.** Tras un rescate espera 0,25 s; si hay más de tres rescates en cinco segundos, el
   punto seguro se descarta y se usa el de reserva: la entrada del escenario para el detective, su
   puesto para un NPC.
5. **Guardar y cargar.** `Game` guarda `get_savable_position()`: en plena caída, el último suelo
   válido. Al cargar, una posición fuera de la zona transitable no se aplica (se queda en la
   entrada).
6. `teleport()` (aparición, cambio de lugar, carga) fija el punto seguro y borra el historial.

## Navegación: `LocationNavigation`

`LocationBase` la crea tras construir la geometría (`scripts/world/location_navigation.gd`, un
`NavigationRegion3D`):

- Hornea en tiempo de ejecución con las **colisiones estáticas** del escenario (las mismas que
  detienen al detective), limitadas a `play_area` y hasta 2,2 m de altura (sin tejados ni techos).
- Celdas de 0,15 m; radio 0,3 m y altura 1,8 m, como la cápsula de los personajes. Con esa celda el
  radio no pierde precisión.
- **Mapa propio** por escenario: dos escenarios cargados a la vez (en las pruebas) no se mezclan. Se
  libera con el escenario.
- El servidor tarda unos fotogramas en integrar la malla: `is_map_ready()` lo indica y los NPC no
  deciden movimientos hasta entonces.
- Sobre mesas, camas y barras quedan islas sueltas: `is_on_floor_mesh()` sólo acepta el suelo.
- Hornear cuesta entre 4 y 30 ms por escenario, durante el fundido de entrada.

## Comportamiento de los NPC

### Estados (`Npc.State`)

| Estado | Qué hace |
| --- | --- |
| `IDLE` | En reposo: pausas, miradas a los lados, cambios de orientación alrededor de la de su sitio y, si el detective está cerca, alguna mirada hacia él |
| `WANDER` | Paseo corto alrededor de su puesto, o visita a un punto concreto (la barra, los ficheros) |
| `PATROL` | Hacia el siguiente punto de su ronda; espera en cada uno |
| `RETURN` | De vuelta a su puesto: tras una visita, al cambiar de tramo de su rutina o si se alejó |
| `INTERACT` | El detective lo enfoca para hablarle: se detiene y se vuelve hacia él |
| `DIALOGUE` | Conversación activa, o escena narrativa en la que interviene en persona: quieto, mirando al detective |
| `LEAVE` | Su rutina lo lleva a otro lugar: camina hasta la salida y la cruza desvaneciéndose |

Al terminar cada pausa decide según su modo: en una ronda va al punto siguiente; si pasea, a veces
visita un punto (salvo que la investigación lo necesite) o da un paseo; si está lejos de su
puesto, vuelve; si no, otra pausa.

### Perfiles (`NpcProfile`)

El papel y el carácter de cada personaje están en `characters.json`, bloque `ambient`; cada tramo
de `schedules.json` puede ajustarlo según lo que esté haciendo. Prioridad: tramo › personaje ›
papel.

| Clave | Por defecto | Qué es |
| --- | --- | --- |
| `role` | `secundario` | `importante` (no se aleja), `secundario` (pasea) o `vigilancia` (ronda) |
| `behavior` (sólo tramo) / `mode` | según el papel | `stay`, `wander` o `patrol`. Un tramo con `patrol` es una ronda |
| `radius` | 1,0 / 1,6 / 1,2 según el papel | Radio máximo de los paseos, en metros, desde su puesto |
| `speed` | 1,2 | Velocidad al caminar, en m/s (el detective anda a 4) |
| `pause` | [4, 9] | Segundos de pausa entre movimientos |
| `glance` | [2, 5] | Segundos entre miradas y giros en reposo |
| `wander_chance` | 0,5 | Probabilidad de dar un paseo al terminar cada pausa |
| `visit_chance` | 0 | Probabilidad de ir a uno de sus puntos de visita |
| `visits` (sólo tramo) | — | Marcadores que visita de vez en cuando |
| `patrol` (sólo tramo) | — | Marcadores de su ronda, en orden; debe incluir su puesto |
| `if` (sólo tramo) | — | Condición de la historia, con el formato de `Conditions`: el tramo sólo vale mientras se cumple. Gana el primer tramo que encaje, así que el condicionado va antes del que lo sustituye |
| `attend_seconds` | 5 | Segundos que se queda mirando al detective que lo enfoca sin hablarle |
| `talk_pause` | [2,5, 4,5] | Pausa tras una conversación antes de retomar lo que hacía |
| `head_tilt` | 0 | Inclinación de la cabeza en reposo; negativa mira al suelo |
| `notice_distance` | 3,5 | Distancia a la que se fija en el detective |

Ejemplo:

```json
"ambient": {"role": "importante", "speed": 1.0, "glance": [4.0, 8.0], "head_tilt": -0.14}
```

```json
{"day": 2, "from": "12:00", "to": "24:00", "location": "cafe", "marker": "mesa_fondo",
 "activity": "En el Café La Luna", "visits": ["barra_extremo"], "visit_chance": 0.3}
```

Tramo con condición: el primer día, hasta que se atiende la llamada, el sargento espera en el
café; después rige el tramo siguiente, el de la mansión.

```json
{"day": 1, "from": "08:00", "to": "24:00", "location": "cafe", "marker": "puerta_sargento",
 "activity": "Espera al inspector en el Café La Luna", "behavior": "stay",
 "if": {"not_flags": ["llamada_atendida"]}}
```

### Reparto

| Personaje | Papel | Qué hace |
| --- | --- | --- |
| Rosa | importante | Recorre la barra de punta a punta, de cara a la clientela. El primer día, hasta la llamada, hace compañía al sargento cerca de la entrada |
| Irene | secundario | En el café ronda su mesa y a veces va a la barra; en el salón de la mansión, junto a la ventana; en el archivo lee sin moverse |
| Marcos | secundario | Inquieto: ronda la chimenea o su mesa del café y va a la barra; el lunes por la mañana recorre el vestíbulo |
| Ortega | vigilancia | El primer día espera al inspector junto a la puerta del café; tras la llamada, ronda corta en el vestíbulo de la mansión, a la vista de la entrada; el lunes por la mañana, alrededor de la fuente |
| Elena | importante | En el salón no se mueve (cabeza baja); encerrada en su alcoba, da vueltas por ella |
| Lucía | secundario | Ronda entre el vestíbulo y el lado este del salón; el lunes hace recados junto al quiosco y se acerca a la terraza |
| Anselmo | secundario | Pausado, se mueve por el office; el lunes va y viene al vestíbulo |
| Eusebio | importante | En la taquilla, mirando al andén |
| Hilario | secundario | El domingo pasea por la plaza; en el archivo atiende el mostrador y va a los ficheros |

### Reglas de convivencia

- **Sitios de parada** (puestos, rondas y visitas): a 1,2 m de los de los demás NPC presentes, a
  1,1 m de cualquier hueco de paso y a 0,9 m de pistas, salidas y camas (`NPC_SPACING`,
  `NPC_DOORWAY_CLEARANCE`, `NPC_INTERACTABLE_CLEARANCE` en `LocationBase`).
- **Paseos:** punto al azar dentro del radio, sobre el suelo (no sobre un mueble), libre de lo
  anterior y con un camino corto que no cruce puertas: un paseo nunca cambia de estancia.
- **Visitas:** sólo si el sitio está libre y el NPC no tiene preguntas pendientes
  (`DialogueManager.has_new_topics`): si la investigación lo necesita, no se va.
- **Camino cortado:** si en 1,5 s no avanza, se detiene y vuelve a decidir. Sólo si tres veces
  seguidas no consigue volver a su puesto se le recoloca allí (con un aviso en el registro; no ha
  ocurrido en ninguna prueba).
- **Personas en el camino:** la evitación (RVO) esquiva a los demás NPC y al detective, que es un
  obstáculo de evitación (`NavigationObstacle3D`). Si alguien está justo delante, el NPC se aparta
  hacia un lado con suelo para rodearlo: la evitación sola no elige lado y se paraba.
- **Colisiones:** capa 4; chocan con el escenario, el detective y entre sí (máscara 7).

## Interacción con el detective

1. Cuando el detective enfoca a un NPC (aparece «Hablar con...»), el NPC pasa a `INTERACT`: se
   detiene y se vuelve hacia él. Si el detective se va, sigue con lo suyo hacia el mismo destino.
2. Si lo enfoca sin hablarle durante `attend_seconds`, el NPC sigue y tarda otro tanto en volver a
   pararse: nunca le cierra el paso para siempre.
3. Al pulsar E la conversación empieza con el NPC ya quieto; durante `DIALOGUE` no se mueve.
4. Al cerrar la conversación hace una pausa (`talk_pause`), todavía mirando al detective, y
   retoma lo que hacía. Tampoco vuelve a pararse en cuanto lo enfocan de nuevo. Si entretanto su
   rutina lo cambió de puesto, o de lugar, antes termina esa pausa.
5. Las conversaciones con los NPC no han cambiado. La escena de la llamada del café se adaptó para
   que el sargento esté en persona (ver la sección siguiente).

## Escenas con personajes presentes

Una escena de `escenas.json` puede declarar en `cast` qué personajes intervienen en persona. Al
empezar (`DialogueManager.scene_started`), el escenario detiene a los que estén presentes, los
vuelve hacia el detective (estado `DIALOGUE`) y sólo gesticula quien tiene la palabra; el detective
se vuelve hacia quien le habla (`Game`). Al terminar hacen la pausa de después de hablar y retoman
su rutina, que puede haber cambiado con los efectos de la escena. Los que hablan sin estar (el
narrador, una voz) no necesitan estar en la sala.

**La llamada del café.** Era una llamada de teléfono: el sargento hablaba sin estar en el café y
Rosa, detrás de la barra, quedaba tapada por las siluetas de la conversación. Ahora:

1. Hasta que se atiende la llamada (`llamada_atendida`), Ortega espera junto a la puerta del café
   (`puerta_sargento`) y Rosa ha salido de la barra a hacerle compañía (`sala_rosa`). Son tramos
   con `if`; la verja de la mansión sigue cerrada hasta entonces, así que nunca se le busca allí
   antes de tiempo.
2. Al entrar el inspector, los dos quedan a los lados de quien entra, en la zona que la interfaz
   deja a la vista, y se vuelven hacia él mientras hablan.
3. Las líneas que hablaban del teléfono se adaptaron: Rosa explica que el sargento ha venido a
   esperarle y él añade que se adelanta a la mansión. En la mansión, Ortega ya no se presenta por
   segunda vez. El resto de la escena, sus efectos y el objetivo siguiente no cambian.
4. Al terminar, Ortega espera un momento, sale por la puerta de la calle y le espera en la mansión;
   Rosa vuelve detrás de la barra. Al volver al café, ni la escena se repite ni el sargento vuelve
   a aparecer.

## Salir del escenario

Cuando la rutina lleva a un NPC a otro lugar mientras el detective está delante (otra hora, una
marca nueva de la historia), ya no desaparece de golpe:

- `LocationBase` elige la salida que lleva a su destino (o la más cercana) y le pasa el punto
  desde el que cruzarla y hacia dónde, el hueco de la puerta si hay uno junto a ella.
- El NPC camina hasta allí con la navegación (estado `LEAVE`) y cruza el hueco sin colisiones,
  desvaneciéndose (`CharacterModel.set_fade`). Al terminar emite `left` y se libera.
- Mientras se va no se le puede hablar ni muestra aviso de preguntas.
- Sigue en la lista del escenario hasta salir: nunca hay dos copias del mismo personaje. Si su
  rutina lo vuelve a traer antes de salir, se queda.
- Si el paso hasta la salida se corta cerca de la puerta (el detective en el umbral), la cruza
  igualmente; lejos, lo vuelve a intentar y, tras tres intentos, sale desde donde esté con un aviso
  en el registro (no ha ocurrido en ninguna prueba).
- Un escenario sin salidas (el campo de pruebas) lo retira al instante, como antes.

Quien llega mientras el detective está en el escenario sigue apareciendo en su puesto.

## Rendimiento

- Las rutas se piden al decidir un movimiento (en las pausas), nunca en cada fotograma:
  `path_requests` lo cuenta y `test_navigation_is_not_queried_every_frame` exige menos de una
  cada 20 fotogramas por NPC.
- Un NPC quieto en el suelo no mueve su cuerpo.
- Medido con ventana a 1280 × 720 frente a `main`:

| Escenario | NPC | Física media por fotograma | Carga del escenario |
| --- | --- | --- | --- |
| Café | 3 | 0,36–0,44 → 0,63–0,73 ms | ~28–34 → ~32–40 ms |
| Mansión | 6 | 0,43 → 0,80 ms | ~51 → ~61 ms |
| Plaza | 2 | 0,40 → 0,58–0,67 ms | ~38 → ~58 ms |

Menos de 1 ms de física con seis NPC (el 5 % de un fotograma a 60 Hz). Los FPS no sirven para
comparar en este portátil: lanzado desde la terminal se queda en 30 con las dos ramas.

## Pruebas

| Archivo | Cubre |
| --- | --- |
| `test_world_bounds` | Suelo y área en todo lo alcanzable, puertas de la calle con teclas reales, huecos interiores abiertos |
| `test_fall_guard` | Punto seguro sólo en suelo válido, caída, salida del área, movimiento tras el rescate, bucles, guardar en plena caída y cargar una posición inválida |
| `test_location_navigation` | Malla lista en cada escenario, marcadores sobre ella, muebles fuera, nada fuera del área, estancias unidas por sus puertas sin atravesar paredes, cómoda del cuarto de Lucía contra la pared con el centro y la puerta de la alcoba despejados, mapas independientes |
| `test_npc_layout` | Cada media hora de los tres días, antes y después de la llamada del café, ningún NPC se para junto al puesto de otro; puntos libres, sobre la malla, lejos de puertas y pistas; orientación; comportamientos válidos y variados |
| `test_furniture_layout` | Árbol lejos del quiosco y paso libre delante del mostrador; jardinera infranqueable, rodeable y fuera de la malla, y dibujada en el mapa; cama, mesilla y silla de la pensión con colisión, sin meterse en otro mueble ni en la pared, contra la pared y junto a la cama, y la cama al alcance desde la puerta; mesilla de Lucía contra la pared y junto al cabecero, con la pista del misal accesible |
| `test_cafe_first_visit` | Con la escena de juego real: rutinas antes y después de la llamada y tramos condicionados con respaldo; al entrar, Rosa y Ortega en la sala, sin copias, en suelo libre, a la vista y no tapados por la interfaz; se detienen y miran al inspector; turnos de palabra; texto sin teléfono; Ortega sale por la puerta sin saltos ni atravesar nada y Rosa vuelve a la barra; visitas posteriores sin repetir la escena y con un solo Ortega en la mansión; cierre anticipado; guardar mientras sale |
| `test_npc_leave` | Salida por la puerta de la calle cuando cambia la rutina (sin saltos, sin atravesar nada, sin hablarle mientras), vuelta atrás si la rutina lo trae de nuevo, salida tapada y escenario sin salidas |
| `test_npc` | Rutinas (quien se va sale andando), rondas que rodean la fuente, paseos acotados, sin solaparse, camino cortado sin teletransporte, caídas, visitas con preguntas pendientes, coste de navegación, conversación, café sin atravesar muebles, paseos sin cambiar de estancia |
| `test_npc_interaction` | Con la escena de juego real: se detiene y mira al detective, retoma al irse él, límite de atención, conversación con E, el NPC quieto también se vuelve, rodea al detective plantado en su ronda, el sargento al alcance de la entrada, guardar y cargar |

## Cómo comprobarlo a mano

1. **Bordes.** En el café, la mansión y el archivo, caminar (y correr) contra la puerta de la calle
   y contra las esquinas: el detective se queda en el umbral y «Salir a la plaza» sigue con E. En la
   estación, ir a la esquina sur del edificio de la taquilla.
2. **Café, lunes a mediodía** (esperar con T hasta las 12): Rosa recorre la barra mirando a la sala;
   Marcos e Irene rondan sus mesas y a veces van a la barra; nadie atraviesa mesas, taburetes ni la
   barra.
3. **Mansión, domingo por la mañana:** Ortega va y viene por el lado oeste del vestíbulo; Lucía
   cruza al salón; nadie se pisa.
4. **Interacción:** acercarse a Lucía mientras camina: se para y mira al detective; hablarle con E;
   al terminar, espera un momento y sigue. Quedarse plantado en la ronda de Ortega: lo rodea.
5. **Guardar y cargar** en la mansión con los NPC caminando: todos reaparecen en su puesto.
6. **Primera entrada al café** (partida nueva, de la estación a la plaza y al café): al entrar,
   Ortega está a la izquierda, junto a la puerta, y Rosa a la derecha, entre la puerta y la barra;
   los dos miran al inspector y se ven por encima de la ventana de la conversación. Al terminar,
   Ortega sale por la puerta y Rosa vuelve a la barra. Salir y volver a entrar: ni escena ni
   sargento. En la mansión, Ortega está en el vestíbulo y no se presenta otra vez.
7. **Cuarto de Lucía** (mansión, a la izquierda del vestíbulo): la cómoda está contra la pared del
   fondo, a la izquierda de la puerta de la alcoba; se cruza de una puerta a otra en línea recta.
   La mesilla está junto al cabecero, contra la pared, y «Examinar el misal de la mesilla»
   aparece al ponerse delante de ella.
8. **Plaza:** el árbol de otoño está en su jardinera, entre el banco oeste y la farola del norte;
   se rodea sin atravesar el bordillo y delante del quiosco no hay nada que estorbe.
9. **Pensión del café:** la cama tiene el cabecero contra la pared, la mesilla a su derecha y una
   silla delante de la cómoda; al despertar, «Acostarse hasta mañana» está al alcance.

## Limitaciones

- Los NPC no caminan de un escenario a otro: el que se va sale andando por la puerta, pero el que
  llega aparece en su puesto.
- No hay animaciones nuevas (sentarse, beber): el reposo usa el balanceo de siempre más giros de
  cabeza y de cuerpo. Los modelos son procedurales y no traen más.
- Sólo intervienen en persona los personajes que una escena declara en `cast` (por ahora, la
  llamada del café). Las demás escenas no detienen a los NPC.
- Tras dejar pasar una hora con T, quien debía haberse ido durante esa hora sale entonces,
  andando.
- En puertas de 1,4 m un NPC y el detective no caben a la vez: el NPC no se para en ellas, pero si
  se cruzan en una puede haber un titubeo breve hasta que uno pase.
- El movimiento sólo se ha revisado con capturas fijas y pruebas automáticas, no jugando a mano.
