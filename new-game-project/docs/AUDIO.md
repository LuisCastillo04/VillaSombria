# Sonido adaptativo

El sonido de Villa Sombría acompaña la investigación: cambia con el lugar, con la hora, con lo que
se descubre y con lo que hace el jugador. Toda la música y todos los efectos son originales y se
generan con el sintetizador del proyecto (`tools/sintesis/`); no hay muestras grabadas ni recursos de
terceros. El inventario completo, con duraciones, tamaños y niveles, está en
[AUDIO_INVENTARIO.md](AUDIO_INVENTARIO.md).

## Ideas de diseño

- **El silencio también cuenta.** La introducción en el andén y la llamada del café suenan sin
  música; en las piezas tranquilas, tras unos minutos la música se retira un rato y deja sólo la
  lluvia y el lugar.
- **Un leitmotiv, «el reloj detenido».** Fa - Mi - Re - La, Si bemol - La. Suena entero en el menú,
  como caja de música en la mansión, a trozos en la calle y en fa mayor en el epílogo, cuando el
  misterio ya se entiende.
- **La tensión no corta la música.** Cada pieza de exploración tiene una capa de tensión de la misma
  duración exacta que suena sincronizada; la historia sólo sube o baja su volumen.
- **El diálogo manda.** Mientras alguien habla, la música y el ambiente se apartan y no suenan detalles.
- **Cada lugar suena a sí mismo**, con sonidos que salen de lo que hay en el escenario: la fuente de
  la plaza, la locomotora del andén, el reloj de pie y la chimenea de la mansión, la vajilla del café,
  el mecanismo de la torre del reloj sobre el archivo.

## Arquitectura

```text
AudioManager (autoload, coordina)              data/audio.json (qué suena y cuándo)
├── AudioMusic      pista del momento, capa de tensión, fundidos, atenuación, silencios
├── AudioAmbience   capas, emisores 3D, detalles ocasionales, campanadas
├── AudioEffects    efectos puntuales: variantes, tono, espera, instancias, prioridad
└── Mundo (Node3D)  emisores y efectos colocados en el escenario (se pausa con el juego)

AudioCatalog  lee y valida el catálogo        AudioMood  tensión que pide la historia
AudioLoop     un bucle con su fundido          (lógica pura, sin nodos)
```

| Pieza | Archivo | Papel |
| --- | --- | --- |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Escucha el juego y decide: lugar, pantallas, escenas, sucesos, hora, guardado, foco de la interfaz |
| `AudioCatalog` | `scripts/audio/audio_catalog.gd` | Lee `data/audio.json`, resuelve alias, carga los archivos y valida el catálogo |
| `AudioMood` | `scripts/audio/audio_mood.gd` | Tensión de la historia y pista que corresponde, sin estado propio |
| `AudioMusic` | `scripts/audio/audio_music.gd` | Fundidos cruzados, capa de tensión sincronizada, atenuación y silencios intencionados |
| `AudioAmbience` | `scripts/audio/audio_ambience.gd` | Capas sin reiniciar, emisores 3D, detalles al azar, capas nocturnas y campanadas |
| `AudioEffects` | `scripts/audio/audio_effects.gd` | Grupo fijo de 12 voces y voces 3D temporales |
| `AudioLoop` | `scripts/audio/audio_loop.gd` | Volumen de un bucle = nivel propio + atenuación + fundido, cada parte independiente |

### Canales

| Canal | Envía a | Qué lleva | Efectos |
| --- | --- | --- | --- |
| `Master` | — | Todo | Limitador (techo −0,5 dB) |
| `Musica` | `Master` | Piezas y fragmentos musicales | Paso bajo para la pausa (apagado normalmente) |
| `Ambiente` | `Master` | Capas, emisores, detalles y campanadas | Paso bajo para la pausa (apagado normalmente) |
| `Efectos` | `Master` | Interfaz, interacciones y pasos | — |

Los volúmenes de los cuatro canales son los de Configuración (`Settings`); `AudioManager` nunca los
toca. Las atenuaciones se hacen en los reproductores, así que no interfieren con lo que elige el
jugador.

### Qué escucha

| Señal | Reacción |
| --- | --- |
| `Game._load_location` → `AudioManager.enter_location` | Paisaje sonoro del lugar con fundido cruzado; la música se decide un segundo después |
| `EventBus.location_change_requested` | Puerta del lugar al que se entra, puerta de salida a la calle o pasos por el empedrado |
| `EventBus.player_locks_changed` | Cada motivo (`dialogo`, `pausa`, `expediente`, `tablero`, `inspeccion`, `acusacion`, `cierre`...) puede sonar al abrirse y cerrarse, atenuar, amortiguar, suspender detalles o cambiar la música |
| `DialogueManager.scene_started`, `closed` | Música y señal propias de cada escena (`scenes`) |
| `EventBus.clue_discovered`, `deduction_made`, `testimony_recorded` | Fragmento de pista, de deducción y la pluma del testimonio |
| `EventBus.notification_requested` | «historia»: fragmento inquietante y más tensión durante 90 s; «info»: aviso suave |
| `EventBus.time_changed` | Capas nocturnas y campanadas al pasar la hora en punto |
| `EventBus.flag_set`, `day_changed` | Recalcula la tensión de la historia |
| `EventBus.rest_requested` | Sonido de la cama |
| `SaveSystem.save_started`, `save_finished` | Confirmación sonora de los guardados manuales correctos |
| `Viewport.gui_focus_changed` | Cambio de opción en los menús, sólo si lo provoca el jugador |
| `CharacterModel.stepped` (del detective) | Paso según el suelo que pisa |

Las llamadas explícitas son pocas: `enter_location` y `attach_listener` en `Game`, `enter_location("menu")`
en el menú principal, la muestra de volumen en Configuración, los sonidos de `MenuScreen` al abrirse y
cerrarse, el picaporte de una salida cerrada, dejar pasar una hora y la acusación que no se sostiene.

## Estados del sonido

| Situación | Qué pasa | Dónde se configura |
| --- | --- | --- |
| Exploración | Pieza del lugar y su ambiente; la capa de tensión según la historia | `locations`, `intensity` |
| Conversación | Música −9 dB, ambiente −5 dB, sin detalles, en 0,6 s; vuelve en 1,4 s | `screens.dialogo` |
| Pista descubierta | Fragmento de vibráfono y piano; la música baja 6 dB mientras suena | `events.clue`, `sounds.pista_descubierta` |
| Deducción | Crescendo de cuerdas que resuelve; la música baja 8 dB | `events.deduction` |
| Situación sospechosa | Aviso de la historia: fragmento y +0,3 de tensión durante 90 s | `intensity.story_boost` |
| Tensión narrativa | Crece con los días, en la mansión, al saber que el reloj miente y de noche en la calle | `intensity` |
| Acusación | Pieza «La acusación» con tensión 0,35; si falla, fragmento disonante | `screens.acusacion` |
| Confrontación | La misma pieza, sin reiniciar, a tensión plena | `scenes.confrontacion` |
| Resolución | Epílogo en fa mayor, que sigue en la pantalla de caso cerrado | `scenes.epilogo`, `intensity.resolved` |
| Pausa | Música y ambiente amortiguados (paso bajo a 850 Hz) y más bajos; el mundo no hace ruidos nuevos | `screens.pausa` |
| Silencios | En piezas tranquilas, tras 150–240 s la música se retira 40–75 s | `rests`, `music.*.rests` |

### Tensión de la historia

`AudioMood.story_intensity` suma, sin pasar de `max` (0,85):

| Regla | Valor |
| --- | --- |
| Día 1 / 2 / 3 | 0 / 0,2 / 0,45 |
| Mansión (escena del crimen) / archivo | +0,25 / +0,05 |
| Marca `ortega_briefing` (vista la escena del crimen) | +0,1 |
| Marca `hora_real_conocida` (el reloj miente) | +0,15 |
| Noche (desde las 20:00) en la calle | +0,1 |

La capa de tensión sigue la curva intensidad^1,5 (a 0,2 apenas se oye; a 0,85 está casi plena). No se
guarda: se deduce del estado de la partida, así que al cargar suena exactamente lo que corresponde.

### Prioridad de la música

Una orden explícita (`set_music_override`) → una pantalla que cambia la música (la acusación) → la
escena narrativa en curso → el caso resuelto → la pieza del lugar. Pedir la pieza que ya suena no la
reinicia: de la plaza a la estación, o de la acusación a la confrontación, la música continúa.

## Escenarios

| Lugar | Música | Capas | Emisores 3D | Detalles | Campanadas |
| --- | --- | --- | --- | --- | --- |
| Menú | «Villa Sombría» (tema) | Lluvia y viento suaves | — | — | — |
| Plaza | «Calle lluviosa» | Lluvia; viento de noche | Fuente | Contraventanas, truenos lejanos, cárabo de noche | Torre del reloj |
| Estación | «Calle lluviosa» | Lluvia; viento de noche | Locomotora | Golpes metálicos, silbatos lejanos, campana del andén, truenos, cárabo | — |
| Café La Luna | «Medianoche en La Luna» (gramófono) | Murmullo de las mesas, lluvia en los cristales | — | Tazas, cucharillas, sillas, cafetera, caja registradora | Torre, amortiguada |
| Mansión Valdés | «Ecos de la casa Valdés» | Casa grande y viento, lluvia en los ventanales | Reloj de pie, chimenea | Crujidos, puertas lejanas, ráfagas | Reloj de pie |
| Archivo | «Legajos» | Sala y mecanismo de la torre, lluvia | — | Páginas, crujidos, Don Hilario sellando | Torre, amortiguada |

Las escenas narrativas: la introducción y la llamada del café suenan sin música (la llamada, con el
teléfono); el segundo y el tercer día empiezan con su fragmento.

Los pasos del detective dependen del suelo: los escenarios declaran sus tarimas, baldosas y alfombras
al construirse (`InteriorKit` llama a `LocationBase.register_surface`); en la calle, empedrado mojado.

## Interfaz

| Acción | Sonido |
| --- | --- |
| Moverse por un menú | `ui_mover` (sólo si lo hace el jugador, con teclado, mando o ratón) |
| Confirmar / volver | `ui_aceptar` («click») / `ui_cancelar` |
| Abrir o cerrar una pantalla de menú | `ui_abrir` / `ui_cerrar` (`MenuScreen.open_sound`, `close_sound`); el mapa, `mapa_abrir` |
| Pausa | `pausa_abrir` / `pausa_cerrar` |
| Expediente, tablero, evidencia | Carpeta de cuero, corcho y chincheta, papel |
| Texto de los diálogos | Tecleo apagado (`tecla`), cuatro variantes |
| Guardado manual | Timbre del carro de la máquina de escribir |
| Avisos informativos | Dos notas de vibráfono |
| Caso cerrado | Sello |

## Configuración

Configuración → Audio tiene cuatro barras: **Volumen general**, **Música**, **Ambiente** y
**Efectos**. Son las preferencias `audio/Master`, `audio/Musica`, `audio/Ambiente` y `audio/Efectos`
de `Settings`, que las valida, las aplica al canal en el acto y las guarda en `user://ajustes.cfg`
(ver [CONFIGURACION.md](CONFIGURACION.md)). Al mover la barra general o la de efectos suena una
muestra para oír el nivel; la música y el ambiente ya se oyen detrás del menú.

## Optimización

- **Streaming.** La música y los ambientes son Ogg Vorbis (calidad 3, unos 110 kbit/s): se
  descodifican mientras suenan. Los efectos cortos son WAV mono que Godot comprime con QOA al importar.
- **Memoria.** El catálogo sólo conserva los efectos ya usados; las pistas y los ambientes los retiene
  su reproductor y se liberan al apagarse. Un lugar usa como mucho dos pistas a la vez (durante un
  fundido), cuatro o cinco capas y dos emisores.
- **Sin procesos permanentes.** Ningún nodo de audio usa `_process`: los fundidos son `Tween`, los
  detalles y los silencios, `Timer`; los pasos salen de la animación que ya existe.
- **Límites.** 12 voces planas con robo por prioridad, 8 voces 3D, tiempo mínimo entre disparos y
  número máximo de copias por efecto; los detalles nunca repiten el último.
- **Pausa.** El temporizador de detalles y los sonidos del mundo se congelan con el juego; la
  interfaz sigue sonando porque `AudioManager` usa `PROCESS_MODE_ALWAYS`.
- **Salida.** Al cerrar, `AudioManager` detiene y libera todos los reproductores y vacía su caché.
- **Android.** Ogg Vorbis y WAV con QOA son formatos nativos de Godot en todas las plataformas; no
  hay dependencias nuevas.

## Cómo se generó el audio

```powershell
python tools/generar_audio.py                      # todo (unos 8 minutos)
python tools/generar_audio.py --solo efectos       # musica, fragmentos, ambientes o efectos
python tools/generar_audio.py --espectrogramas <carpeta>
```

Requiere Python 3.10+, NumPy, SciPy y FFmpeg con libvorbis (matplotlib sólo para los
espectrogramas). Las semillas son fijas: cada ejecución produce el mismo resultado.

| Módulo | Contenido |
| --- | --- |
| `tools/sintesis/dsp.py` | Filtros, ruido periódico, reverberación por convolución con respuestas sintéticas, buses de mezcla que pliegan las colas en el bucle |
| `tools/sintesis/instrumentos.py` | Piano (inarmonicidad, dos cuerdas, macillo), contrabajo, cuerdas por tabla de ondas, vibráfono, caja de música, campanas, varilla de reloj, escobillas, ride, timbal, latido |
| `tools/sintesis/teoria.py` | Notas, acordes, conducción de voces y partitura medida en pulsos |
| `tools/sintesis/musica.py` | Las siete piezas y los cinco fragmentos |
| `tools/sintesis/ambientes.py` | Lluvia, viento, murmullo con voces sintéticas ininteligibles, casa, archivo, fuente, locomotora, reloj y chimenea |
| `tools/sintesis/efectos.py` | Detalles de cada lugar, interfaz, puertas, papeles, teléfono, sello y pasos |

**Bucles sin costura.** Las piezas usan tempos con un número entero de muestras por pulso; lo que
suena más allá del final (colas de notas y de reverberación) se suma al principio, como se oiría al
repetirse. Los ambientes se construyen periódicos: ruido filtrado en frecuencia, modulaciones con
ciclos enteros y sucesos que se pliegan. El generador decodifica cada Ogg y compara el salto del final
al principio con el salto habitual entre muestras vecinas; el resultado está en el inventario.

## Ampliar

| Quiero... | Qué hacer |
| --- | --- |
| Sonido para un lugar nuevo | Su entrada en `locations` de `data/audio.json` (`music`, `layers`, `night_layers`, `emitters`, `details`, `chime`). `test_audio` comprueba que todo lugar de `locations.json` tenga la suya |
| Una pieza nueva | Componerla en `tools/sintesis/musica.py` (o traer un Ogg propio), añadirla a `TRACKS` y a `music` con `base`, `tension` opcional, `volume_db` y `rests` |
| Cambiar un sonido | Sustituir el archivo con el mismo nombre, o cambiar la ruta en el catálogo |
| Un efecto nuevo | Entrada en `sounds` con `files` y, si hace falta, `bus`, `volume_db`, `pitch`, `cooldown`, `max`, `priority`, `spatial` |
| Reaccionar a una pantalla nueva | Su motivo de `GameState.lock_player` en `screens` (`open`, `close`, `music_db`, `ambience_db`, `muffle`, `details`, `music`, `intensity`) |
| Música para una escena | Su identificador en `scenes` (`music`, `"music": ""` para silencio, `intensity`, `music_db`, `cue`) |
| Más tensión por la historia | Marcas en `intensity.flags`; para un suceso puntual, `AudioManager.raise_tension(cantidad, segundos)` |
| Una cinemática | `AudioManager.set_music_override("pista")` y, al acabar, `set_music_override("")` |
| Un ciclo de día y noche real | Ya hay capas `night_layers` y detalles con `hours`; bastaría con emitir `time_changed` con la hora |

## Pruebas

`tests/unit/test_audio.gd` comprueba el catálogo (archivos, identificadores y un paisaje para cada
lugar), que todos los archivos se cargan, que los bucles se repiten y que cada capa de tensión dura
exactamente lo mismo que su pieza; la tensión de la historia y la prioridad de la música; que entrar
dos veces no duplica ni reinicia, que al cambiar de lugar lo anterior se apaga y se libera, que la
lluvia continúa entre exteriores y que la misma pieza no se reinicia; detalles, capas nocturnas y
campanadas; diálogo, pausa, sucesos, acusación, epílogo, puertas, foco y límites de los efectos; la
integración con la escena de juego (oyente, emisores) y que cargar una partida restaura el sonido sin
duplicados.

Dos pruebas miden la señal real que mezcla Godot con `AudioEffectCapture` (en headless el controlador
«Dummy» también mezcla): que el tema del menú se oye y baja de verdad en un diálogo, y que la capa de
tensión cambia de volumen en plena reproducción.

Lo que una prueba automática no puede juzgar es cómo suena: la calidad de las piezas y de los
efectos hay que escucharla en el juego. Para eso hay una grabación guionizada del juego real:

```powershell
godot --headless --path . res://tests/visual/escucha.tscn -- --out=C:/ruta/escucha.wav
```

Recorre en unos cuatro minutos el menú, la introducción, la plaza con sus campanadas, la llamada del
café, una conversación, la mansión con una pista y un suceso, la pausa, el archivo, la acusación, la
confrontación y el epílogo, y graba lo que sale por `Master`. Junto al WAV deja un `.txt` con el
segundo en que empieza cada momento, para ir directamente a lo que se quiera escuchar. Sin ventana,
el controlador «Dummy» mezcla algo más despacio que el reloj (en torno a un 9 %, más durante las
cargas de escena), así que las marcas se adelantan respecto al audio; con ventana, la mezcla sigue al
dispositivo de audio y coinciden.
