# 13. Sesión 7: personajes

Rama `feature/blender-personajes`, creada desde el cierre de la sesión 6 (`06651cf`). Las mallas
del detective y de los nueve NPC salen de Blender; la programación de los personajes no cambia.

## 7.1. Auditoría

| Pieza | Qué hace | Relación con el modelo |
| --- | --- | --- |
| `CharacterModel` (`scripts/actors/character_model.gd`) | Seis pivotes (`PiernaIzq`, `PiernaDer`, `Torso`, `BrazoIzq`, `BrazoDer`, `Cabeza`), cada uno con un `MeshBatcher` propio (semilla = nombre del pivote, variación de tono 0,012) y una `MeshInstance3D`; animación procedural en `_process` (paso, balanceo de brazos, respiración, cabeza al hablar) | Sólo las mallas de los pivotes dependen del aspecto |
| `Npc` (`scripts/actors/npc.gd`) | Rutinas, navegación, conversación, salida por puertas | Usa `build`, `set_motion`, `set_talking`, `set_head_turn`, `set_head_tilt`, `set_fade` |
| `PlayerController` | Movimiento del detective | Usa `build` y `set_motion` |
| `Game` | Sonido de pasos | Escucha la señal `stepped` |
| Conversaciones (`scripts/ui/dialogue/`) | Siluetas SVG y placa con el nombre | **Independientes del modelo 3D** |
| Guardado | Guarda escenario, posición, pistas, marcas y estado de los NPC | No guarda nada del modelo |
| Colisión | Cápsula de 0,3 × 1,8 m en `npc.tscn` y `player.tscn` | Independiente del modelo |

Usos de la interfaz pública: `npc.gd` (21 llamadas), `player_controller.gd` (2) y `game.gd`
(`stepped`). Ninguno cambia.

## 7.2–7.3. Diseño: preservar pivotes y animación

- **No hay esqueleto ni animaciones de Blender.** Se conservan los seis pivotes y la animación
  procedural; sólo cambia de dónde sale la malla de cada pivote.
- `build(look, character_id = "")`: `Npc` pasa su `npc_id` y el detective `"detective"`. Si hay un
  modelo `personaje_<id>`, cada pivote dibuja su malla con
  `ModelCatalog.draw_in(batch, id, IDENTITY, procedural, <Pivote>)` (objeto `<Objeto>_<Pivote>`
  del GLB); si no, con el código de siempre. La firma antigua `build(look)` sigue valiendo.
- **Orientación:** las mallas se capturan en el espacio de cada pivote, con los ejes de Godot
  (personaje mirando a −Z). Al pasar a Blender, la conversión de ejes las deja mirando a **+Y**,
  como fija [05-estandares.md](05-estandares.md#ejes-y-orientación). No se gira ningún nodo padre
  (invertiría el sentido de `set_head_tilt`).
- **Pivotes:** el origen de cada objeto es su pivote (cadera, hombros, cuello). En el `.blend` cada
  objeto se coloca en su sitio (posición de «muestra») para ver el personaje montado; el juego no
  usa esa posición, coloca la malla en el pivote de siempre.
- **Colores:** un GLB por personaje, con sus colores. Es una desviación de la propuesta de la
  sesión 1 (materiales por papel teñidos con el `look`): con un GLB por personaje cada aspecto es
  exacto y se puede retocar un personaje sin afectar a los demás. El precio es que cambiar el
  `look` de `characters.json` exige volver a exportar (`migrar.py --ids personaje_<id>`); las
  pruebas lo detectan porque la malla ya no coincidiría con el código.

## 7.4. Prototipo: el detective

`personaje_detective.glb` (390 triángulos, abrigo largo, fedora y bufanda), commit `a417214`.
Comprobado antes de extenderlo: misma malla por pivote que el código, mismos pivotes y misma pose
animada.

## 7.5–7.6. Validación y resto de personajes

| Personaje | Triángulos | Personaje | Triángulos |
| --- | --- | --- | --- |
| Detective | 390 | Irene | 366 |
| Elena | 446 | Ortega | 338 |
| Marcos | 294 | Rosa | 396 |
| Lucía | 330 | Eusebio | 322 |
| Anselmo | 292 | Hilario | 276 |

Las mismas cifras que la auditoría de la sesión 1: cada personaje conserva estatura, ropa,
peinado, sombrero y complementos.

| Comprobación | Resultado |
| --- | --- |
| `test_personajes.test_every_character_uses_its_model` | Los diez usan su modelo, con una sola malla por pivote |
| `test_personajes.test_pivots_and_animation_are_unchanged` | Con y sin modelo: mismos pivotes, misma escala, misma pose tras 30 fotogramas de caminar, hablar, girar e inclinar la cabeza, y `set_fade` llega a la malla |
| `test_personajes.test_missing_character_model_falls_back` | Sin GLB, el detective vuelve a las mallas procedurales con sus seis pivotes |
| `test_models.test_each_model_matches_its_procedural_piece` | Cada pivote de cada personaje cubre lo mismo que su código, con el mismo color |
| Pruebas de NPC, jugador, conversaciones y sonido | Ver la batería en [07-linea-base.md](07-linea-base.md) |
| Captura de una conversación con Rosa en el café | Modelo frente a procedural: media 1,3 por píxel en la zona de los personajes (la cabeza se mueve al hablar); mismas llamadas de dibujado (235) |

## 7.7–7.8. Diálogos y comportamiento

Las conversaciones usan siluetas SVG y la placa del nombre: no dependen del modelo. La animación
al hablar (`set_talking`) y la mirada (`set_head_turn`) actúan sobre los mismos pivotes. Rutinas,
navegación, puntos de aparición y estados de los NPC no se han tocado (`npc.gd` sólo pasa su id a
`build`).

## Rendimiento

Mismo número de mallas por personaje (seis, una por pivote) y mismos triángulos: el coste de
dibujado no cambia. El GLB de cada personaje se lee una vez (caché de `ModelCatalog`).

## Pendiente

- Retoque artístico de los personajes en Blender (caras, manos): con `fiel: false`.
- Un cuerpo base compartido con materiales por papel (la propuesta original) sólo compensa si se
  añaden muchos personajes nuevos.
