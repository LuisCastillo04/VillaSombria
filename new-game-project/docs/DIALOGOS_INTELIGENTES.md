# Diálogos inteligentes

Cómo recuerda el juego lo que el detective ha preguntado a cada personaje, cómo se presentan las
preguntas en las tres modalidades, cómo se desbloquean preguntas nuevas, qué indicadores llevan los
personajes, dónde se releen las declaraciones y cómo viaja todo con las partidas guardadas. La
ventana de las conversaciones se describe en [DIALOGOS.md](DIALOGOS.md).

## Qué resuelve

Antes, las preguntas ya hechas seguían en el menú igual que las nuevas, con la única diferencia de un
rombo. El jugador repetía conversaciones sin querer y le costaba ver qué había de nuevo. Ahora:

- cada pregunta tiene un identificador estable y un registro de cuándo se completó y qué entregó;
- el menú distingue lo pendiente de lo ya preguntado según la modalidad elegida en Configuración;
- repetir una conversación nunca vuelve a ejecutar sus consecuencias;
- lo que la investigación desbloquea llega marcado como «Nuevo»;
- los personajes indican, sin saturar el escenario, si tienen algo pendiente;
- el expediente guarda la transcripción de cada pregunta para releerla sin repetirla.

## Las tres modalidades

Configuración → Jugabilidad → **Sistema de diálogos** (`jugabilidad/sistema_dialogos`). Es una
preferencia del jugador, común a todas las partidas; el progreso de cada partida no depende de ella y
cambiarla nunca lo borra ni lo altera.

| Modalidad | Preguntas pendientes | Preguntas ya hechas | Repetir |
| --- | --- | --- | --- |
| Repetición libre (`libre`) | En el orden de los datos | En su sitio, atenuadas, con verificación y flecha de repetir | Siempre |
| Diálogo inteligente (`inteligente`, **por defecto**) | Primero, en el orden de los datos | En «Preguntas realizadas», plegada al empezar cada conversación | Desplegando la sección |
| Diálogo único (`unico`) | Primero | En «Preguntas realizadas», con candado, sin número y sin foco | Nunca; se releen en el expediente |

En las tres, repetir una pregunta sólo reproduce lo que se dijo: no cuesta tiempo ni vuelve a marcar
hechos, entregar pistas o testimonios, avisar o lanzar acciones (ver
[Repetir sin duplicar](#repetir-sin-duplicar)).

**Diálogo único sin bloqueos de la historia.** Si la investigación desbloquea otra variante de una
pregunta bloqueada, esa variante vuelve como pregunta pendiente e independiente: preguntar por el
informe del forense antes de mediodía («Todavía no») no impide recibirlo después. Las conversaciones
pensadas para repetirse (`"repeatable": true`, hoy sólo «Reúna a los sospechosos») nunca se bloquean
ni se apartan: si el jugador se echa atrás en la acusación, puede volver a reunirlos. Una prueba
recorre el caso entero en esta modalidad (`test_story.test_single_mode_never_blocks_the_story`).

## Cómo se ve

| Estado | Representación |
| --- | --- |
| Pendiente | Papel y tinta plenos, rombo burdeos a la izquierda, número de su tecla |
| Recién desbloqueada | Además, la cinta discreta «NUEVO» a la derecha, en burdeos (dorada si está señalada) |
| Realizada | Papel más transparente, tinta sepia (`#5e4a37`, contraste de unos 6,5:1) y marca de verificación ocre |
| Repetible | Flecha circular a la derecha, que deja paso a la flecha de la señalada |
| Bloqueada | Aún más atenuada, candado a la izquierda, sin número; no se puede señalar ni pulsar |
| Señalada | Burdeos con borde dorado, letra crema y flecha, como siempre |

- **«Preguntas realizadas · N»**: cabecera discreta entre dos filetes, en versalitas espaciadas
  como las cintas del expediente, con un cheurón que gira al desplegarla. Señalada, toma el burdeos y
  el dorado de las tarjetas.
- **«No hay nuevas preguntas disponibles por el momento.»**: línea en cursiva sepia sobre la lista
  cuando el personaje no tiene preguntas pendientes.
- En el diálogo único, el pie de la ventana añade «Lo ya respondido se relee en el expediente [J]»,
  con la tecla real. Va en el pie, que ya existía, para no restar alto a la lista.
- Al desplegar o plegar, la ventana cambia de alto con la misma transición que al pasar de la
  lectura a las respuestas, y las tarjetas entran escalonadas. Con «Reducir movimiento», sin
  deslizamientos.

### Navegación

| Entrada | Efecto |
| --- | --- |
| ↑ ↓ | Recorren lo que se puede elegir, cabecera incluida; las bloqueadas y las plegadas se saltan |
| → ← | Con la cabecera señalada, despliegan y pliegan; ← desde una pregunta de la sección la pliega y deja el foco en la cabecera |
| E, Intro, Espacio | Eligen la señalada; en la cabecera, la despliegan o la pliegan |
| 1 a 9 | Eligen la pregunta con ese número: sólo se numeran las visibles y elegibles, seguidas y sin huecos |
| Ratón | Señala al moverse; un clic elige o despliega; las bloqueadas muestran un aviso al pasar por encima |

El foco empieza en la primera pregunta pendiente. Al volver al menú, regresa a la pregunta elegida si
sigue a la vista (una repetida desde la sección desplegada); si cambió de sección o desapareció, va a
la primera opción, nunca se queda en el aire. La sección conserva su estado mientras dura la
conversación y vuelve a plegarse en la siguiente. Con el mando valen la cruceta, el stick y A.

## Arquitectura

| Pieza | Responsabilidad |
| --- | --- |
| `scripts/core/conversation_log.gd` | `ConversationLog`: registro, modalidades, menú, situación de cada personaje, historial, limpieza y recuperación de partidas |
| `scripts/core/conditions.gd` | Claves nuevas `asked`, `not_asked` y `visited`; `is_closed` dice qué condiciones ya no podrán cumplirse |
| `scripts/autoload/dialogue_manager.gd` | Anota cada pregunta al terminar su respuesta, aplica sus efectos sólo la primera vez y emite el menú de `ConversationLog` |
| `scripts/autoload/game_state.gd` | Datos de la partida: `conversations`, `seen_topics` y el resumen `asked_topics` |
| `scripts/save/save_format.gd`, `save_system.gd` | Validación al cargar y huella de progreso sin contadores ni lo visto |
| `scripts/ui/dialogue/dialogue_choices.gd` | Lista con la sección plegable, el aviso, la numeración y la navegación |
| `scripts/ui/dialogue/dialogue_choice_item.gd` | Una tarjeta con su estado, sus iconos y la cinta «Nuevo» |
| `scripts/ui/dialogue/dialogue_choice_section.gd` | `DialogueChoiceSection`: la cabecera «Preguntas realizadas» |
| `scripts/ui/dialogue/dialogue_ornaments.gd`, `dialogue_style.gd` | Iconos dibujados (verificación, candado, repetir, cheurón), tintas y tamaños |
| `scripts/actors/npc_interaction.gd`, `scripts/world/interaction_marker.gd`, `interactable.gd` | Indicadores del personaje en el escenario y su estado para el HUD |
| `scripts/ui/hud/hud_prompt.gd` | El estado junto al aviso de interacción |
| `scripts/ui/journal/journal_interrogations_section.gd`, `journal_info.gd` | Pestaña «Preguntas» del expediente y estado en la ficha de sospechosos |
| `scripts/settings/settings_schema.gd`, `scripts/ui/settings_menu.gd` | La preferencia y su selector, con la explicación de la modalidad elegida |

La regla de siempre se mantiene: la lógica no depende de la interfaz. `ConversationLog` es una clase
estática sobre `GameState`, como `Conditions` y `Effects`; `DialogueManager` decide qué se ofrece y
qué pasa al elegir, y la interfaz sólo presenta lo que recibe en `options_shown`. No hay autoload
nuevo.

### El registro

Cada pregunta se identifica con **«personaje/pregunta»** (`ConversationLog.key`), los `id` de
`data/dialogues/`, nunca con su texto ni con su posición. Cada variante de una pregunta
(`variants`) lleva su propio `id` (`"pendiente"` y `"llegado"` en el informe del forense) y cuenta como
una conversación independiente; una pregunta sin variantes usa `base`.

```json
"conversations": {
  "ortega/informe": {"variants": {
    "pendiente": {"count": 1, "order": 4, "day": 2, "minutes": 640},
    "llegado": {"count": 2, "order": 9, "day": 2, "minutes": 760,
                "gained": {"clues": ["informe_forense"]}}
  }}
}
```

| Dato | Dónde |
| --- | --- |
| Personaje, pregunta y variante | La clave y la variante del registro |
| Estado (pendiente, realizada, bloqueada, no disponible) | `ConversationLog.menu`, a partir del registro, las condiciones y la modalidad |
| Si se completó | Que la variante esté en el registro |
| Repeticiones | `count` |
| Orden, día y hora de la primera vez | `order`, `day`, `minutes` |
| Pistas y testimonios que entregó | `gained`, medidos al aplicar sus efectos |
| Eventos y condiciones de desbloqueo | Los `effects` y el `if` de los datos, que no se copian |

**Una pregunta sólo cuenta como hecha cuando se ha oído entera su respuesta.** `DialogueManager` la
anota al terminar sus líneas, justo antes de aplicar sus efectos; mientras tanto,
`DialogueManager.get_current_topic()` dice qué respuesta se está oyendo. Si la conversación se
interrumpe antes, la pregunta sigue pendiente; y si se cierra el juego a mitad, se guarda el estado de
antes de la conversación, como siempre.

### Repetir sin duplicar

| | Primera vez | Repetición |
| --- | --- | --- |
| Pregunta normal | Efectos completos y `TOPIC_MINUTES` (10 min) si no fija otro coste | Sólo las líneas |
| Pregunta `repeatable` | Efectos completos | Efectos completos, sin coste de tiempo |
| Variante nueva de una pregunta hecha | Es una primera vez | — |

Además, `Investigation` ya ignoraba las pistas y los testimonios repetidos y `GameState` las marcas
repetidas; ahora tampoco se repiten los avisos (`notify`) ni las acciones (`action`). Las escenas de
`escenas.json` no cambian: `StoryDirector` sigue decidiendo con marcas cuándo se reproducen.

### El menú

`ConversationLog.menu(npc, modalidad)` devuelve, en orden, cada pregunta disponible con `id`,
`label`, `variant`, `state` (`pendiente`, `realizada`, `bloqueada`), `asked`, `fresh`, `section`
(`principal` o `realizadas`), `repeatable` y `count`. `DialogueManager` añade la de salir y lo emite
tal cual; `choose` sólo acepta lo que el menú ofrece en ese momento y nunca una bloqueada.

Sólo aparecen las preguntas cuya condición se cumple, como antes: una pregunta que sus propios datos
retiran al hacerla (el telegrama, con `not_clues`) desaparece también de «Preguntas realizadas». Su
transcripción sigue en el expediente.

## Desbloqueo de preguntas

Las preguntas se desbloquean con su condición `if`, como hasta ahora. Las claves:

| Clave | Se cumple si | Ejemplo en el caso |
| --- | --- | --- |
| `clues`, `not_clues` | Se tiene (o no) una pista | Elena y el billete de tren |
| `testimonies` | Se tiene un testimonio | Anselmo, después del brindis |
| `deductions` | Se ha hecho una deducción o una contradicción | «La jaqueca de Elena» abre su confesión |
| `flags`, `not_flags` | Ha pasado (o no) algo en la historia | Rosa y Marcos, tras hablar con él |
| `day_min`, `day_max` | Es al menos o como mucho ese día | El telegrama devuelto, el lunes |
| **`asked`, `not_asked`** | Se ha completado (o no) una conversación, «npc/pregunta» | — (nuevas) |
| **`visited`** | El detective ya ha pisado ese lugar de `locations.json` | — (nueva) |
| `any` | Se cumple alguna de sus condiciones | Elena y la invitada |

El caso no necesitaba preguntas nuevas: sus conversaciones ya se desbloquean con pistas,
testimonios, contradicciones, marcas y días. Las claves nuevas quedan listas para interrogatorios
futuros y no se ha inventado ningún hecho ni ninguna pregunta.

**«Nuevo».** `GameState.seen_topics` anota cada pregunta (cada variante) que ya apareció en el menú de
su personaje. Lo que aparece por primera vez en el menú de alguien con quien ya se había hablado llega
con «Nuevo», también lo que una respuesta desbloquea en mitad de la conversación; la marca dura esa
conversación. En la primera conversación con alguien nada es nuevo: todo lo sería.

## Indicadores de los personajes

`ConversationLog.npc_status` resume cada personaje, sin depender de la modalidad:

| Situación | Cuándo | En el escenario | Al acercarse (HUD) |
| --- | --- | --- | --- |
| `nuevo` | Tiene preguntas desbloqueadas que aún no han aparecido en su menú | Rombo más claro que late despacio | Rombo dorado · «Nuevas preguntas» |
| `pendiente` | Tiene preguntas sin hacer | El rombo de siempre | Rombo · «Preguntas pendientes» |
| `en_espera` | Todo lo disponible está hecho, pero la investigación aún puede abrir algo | Nada | Rombo hueco · «Sin novedades por ahora» |
| `completo` | Todo hecho y nada más puede abrirse | Nada | Verificación · «Interrogatorio completo» |

«Puede abrirse» descarta lo imposible con `Conditions.is_closed`: días pasados (la pregunta del
domingo a don Hilario) o condiciones `not_*` que ya no se cumplirán. El estado se pone al día solo con
pistas, testimonios, deducciones, marcas, días y conversaciones, y la ficha de cada sospechoso en el
expediente lo repite («Interrogatorio: …»). En el escenario sólo se ve algo cuando hay algo que hacer.

## Historial de declaraciones

Expediente (J) → **Preguntas** (tecla 6): cada pregunta completada, agrupada por personaje y en el
orden en que se hizo. La ficha enseña a quién se le preguntó, la pregunta, la fecha y la hora (si se
anotaron), cuántas veces se hizo, la **respuesta tal como se oyó** («Elena: «…»», la narración entre
paréntesis) y la **información obtenida** (los testimonios y las pistas que aportó). Consultarla no
reproduce la conversación ni aplica nada: sale de `ConversationLog.history()`, de sólo lectura.

Se evaluó integrarlo en la pestaña Testimonios, pero esa pestaña resume las pruebas que usan el
tablero y la acusación (un testimonio por hecho), mientras que aquí se guarda la conversación completa
de cada pregunta, también de las que no dan testimonio. Mezclarlas habría cambiado lo que leen el
tablero y la acusación. Por eso es una pestaña más del mismo expediente, no un menú aparte. Se llama
«Preguntas» porque «Interrogatorios» no cabía en las pestañas de una pantalla 5:4.

## Guardado

- `conversations` y `seen_topics` viajan en la sección `state` de cada ranura, junto a `asked_topics`,
  que se conserva como resumen para la compatibilidad. Los incluyen el guardado manual, el automático
  y el de salida; una partida nueva empieza sin ellos. Cada ranura tiene el suyo.
- La modalidad es una preferencia de `ajustes.cfg`, nunca de la partida.
- `SaveFormat` valida el registro como el resto del estado: descarta preguntas o variantes que ya no
  existen y contadores, días u horas imposibles, sin impedir nunca la carga ni cambiar la versión del
  formato (sigue siendo la 2).
- Repetir una pregunta y ver un menú no cuentan como progreso: no provocan autoguardados.

### Partidas anteriores

Las partidas guardadas antes del registro sólo traen `asked_topics`, que se anotaba al **empezar**
cada pregunta. Al cargarlas, `ConversationLog.recover` rehace lo que se puede probar, sin inventar
conversaciones completadas:

- una pregunta de `asked_topics` cuenta como completada si la partida tiene las pistas y los
  testimonios que entrega (o, si no entrega ninguno, sus marcas); una que no entrega nada, si es la
  única variante así de su pregunta (el informe que aún no había llegado);
- un testimonio o una pista que sólo entrega una pregunta prueba que esa pregunta se hizo;
- una pregunta empezada cuyas consecuencias no constan (una partida guardada a mitad de la respuesta,
  antes de que el juego guardara el estado previo al salir) **queda pendiente**: así repetirla las
  aplica y la historia no puede bloquearse;
- lo rehecho se marca `recovered`, sin día ni hora, y en el orden de `asked_topics`, que ya era el
  orden en que se hicieron. Cuenta como visto, para no llenar los menús de «Nuevo».

## Cómo añadir preguntas y condiciones

1. **Pregunta nueva**: añádela a `topics` del personaje en `data/dialogues/<id>.json`, con un `id`
   único y estable (sin `/` ni `#`), su `label`, sus `lines`, su condición `if` y sus `effects`. Una
   pregunta de seguimiento es una pregunta más con su propia condición; por ejemplo, la del billete
   de Elena:

   ```json
   {
     "id": "billete",
     "label": "He encontrado este billete en su tocador.",
     "if": {"clues": ["billete_tren"]},
     "lines": [{"s": "elena", "t": "Registra usted a las viudas con mucha soltura, inspector."}]
   }
   ```

   Para que dependa de otra conversación, `"if": {"asked": ["irene/quien"]}`; de un lugar,
   `"if": {"visited": ["archivo"]}`.
2. **Respuesta que cambia con la investigación**: `variants`, cada una con su `id`, su `if`, sus
   `lines` y sus `effects`. Gana la primera cuya condición se cumple; cada variante se registra, se
   repite y se bloquea por separado.
3. **Conversación que debe poder repetirse con sus efectos** (una acción, no una declaración):
   `"repeatable": true`. No aparece en el historial.
4. **No cambies el `id` de una pregunta o variante ya publicada**: las partidas guardadas lo usan. Si
   hace falta, la pregunta antigua se descarta al cargar con un aviso y su resumen la recupera.
5. `test_data_integrity` comprueba que los identificadores son únicos y que `asked` y `visited`
   apuntan a preguntas y lugares que existen. La interfaz, los indicadores, el historial y el guardado
   no necesitan cambios.

## Pruebas

| Archivo | Cubre |
| --- | --- |
| `test_conversation_log` | Completar sólo al terminar la respuesta (día, hora y lo obtenido), interrupción, variantes independientes con su coste, orden y estado en las tres modalidades, repetición voluntaria, bloqueo y variante nueva en el diálogo único, conversaciones repetibles, que repetir no vuelve a avisar ni a entregar nada (también con una pregunta de prueba no idempotente), «Nuevo», condiciones `asked`, `not_asked`, `visited` e `is_closed`, y la situación de cada personaje |
| `test_conversation_save` | Guardar y cargar el registro exacto, ranuras aisladas, partida nueva, autoguardado, repetir sin pedir guardado, cambiar de modalidad sin tocar el progreso, salir a mitad de una respuesta, partidas antiguas (preguntas, variantes, testimonios exclusivos, preguntas a medias) y registros dañados |
| `test_dialogue_modes_ui` | Con la escena de juego real: sección plegada por defecto, aviso sin pendientes, desplegar con → y repetir, foco al cambiar de sección, números sin huecos, flechas por la cabecera, «Nuevo», bloqueo con teclado, ratón y números, modalidad libre, cambio desde Configuración, salir del lugar y volver, indicadores del escenario y del HUD, y el historial sin efectos |
| `test_story` | El caso entero en diálogo único, preguntando por el informe antes de que llegue y reuniendo dos veces a los sospechosos |
| `test_data_integrity` | Identificadores de preguntas y variantes, `repeatable` y referencias de `asked` y `visited` |
| `persistencia/reinicio` | Registro (veces, orden, día, hora, variantes), lo visto y una pregunta recuperada de `asked_topics`, en otro proceso |
| `persistencia/ajustes` | La modalidad elegida, en otro proceso |

Correspondencia con los escenarios pedidos: 1 y 11 (`test_a_question_counts_only_when_its_answer_ends`,
`test_an_interrupted_question_stays_pending`, `test_exiting_halfway_through_an_answer_keeps_the_question_pending`);
2, 3 y 12 (`test_free_mode_*`, `test_smart_mode_*`, `test_repeating_never_reapplies_consequences`,
`test_one_time_events_never_run_twice`); 4 (`test_single_mode_*`); 5 (`test_switching_modes_from_the_settings_menu`,
`test_changing_the_mode_keeps_the_progress`); 6 (`test_leaving_and_coming_back_keeps_the_progress`);
7, 8 y 16 (`test_progress_round_trips_through_a_save`, `test_each_slot_keeps_its_own_history`,
`persistencia/reinicio`); 9 (`test_legacy_*`, `test_a_question_saved_halfway_stays_pending`);
10 (`test_evidence_unlocks_a_follow_up_question`); 13 (`test_smart_mode_groups_asked_questions_behind_a_folded_section`);
14 (`test_the_journal_history_never_replays_anything`); 15 (`test_single_mode_never_blocks_the_story`);
17 (`test_focus_moves_on_when_a_question_changes_section`, `test_smart_mode_lets_the_player_repeat_from_the_section`).

Resultado: con `verificar.ps1` sin ventana, importación, arranque y los siete reinicios correctos;
la batería, 642 correctas y 2 fallos de `test_integration` (la intermitencia conocida de las teclas
perdidas, ver [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md#problemas-conocidos)); repetida, cuatro veces de
cuatro correcta, y una segunda ejecución completa dio 644 correctas y 0 fallos (605 antes de empezar).

Dos mutaciones comprobaron que las pruebas detectan los fallos: con la sección desplegada por defecto
fallan cuatro pruebas de interfaz, y aplicando los efectos al repetir falla la prueba de los avisos.

`tests/visual/captura.gd` admite `--visto`, `--hecho` y `--junto`, y los pasos «d», «b» y «s».

## Limitaciones y mejoras pendientes

- Se probó con eventos simulados de teclado y ratón y con capturas fijas; no se ha jugado a mano ni
  con un mando físico, y las animaciones (cheurón, entrada escalonada, latido del rombo) no se han
  visto en movimiento.
- En el diálogo único, una pregunta bloqueada no se puede releer desde la conversación: se relee en el
  expediente. Podría añadirse una vista de sólo lectura dentro de la propia ventana.
- Las preguntas que sus datos retiran al hacerlas (el telegrama) no aparecen en «Preguntas
  realizadas», aunque sí en el historial. Para repetirlas habría que cambiar su condición en los datos.
- Las partidas antiguas no conservan cuándo se hizo cada pregunta ni cuántas veces se repitió: el
  historial las muestra sin fecha y con una sola vez.
- Las escenas narrativas (`escenas.json`) no entran en el historial: no son preguntas del jugador.
