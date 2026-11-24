# Correcciones gráficas de los escenarios

Rama `fix/correcciones-graficas-escenarios` (noviembre de 2026). Siete defectos señalados con
capturas: parpadeo de las puertas del archivo y del café, Banco Valdés, árboles sobre el
empedrado, sillón de la mansión, parpadeo de los libros y vegetación de la plaza y la estación.

## Causa de los parpadeos: caras coplanares (z-fighting)

La cámara es ortográfica (`ExplorationCamera`, `near` 0,5 y `far` 100): su profundidad es lineal
y precisa al micrómetro. Dos caras sólo se pelean si están **en el mismo plano** y miran hacia el
mismo lado. En ese caso las dos dan la misma profundidad en cada píxel, gana una u otra según el
redondeo de la rasterización y, como la cámara sigue al detective con suavizado, el reparto
cambia a cada paso: la zona «titila».

No era la iluminación (las luces de las puertas no tienen sombras), ni geometría duplicada
(`ModelCatalog` dibuja cada pieza una vez), ni una animación: las tres zonas se encontraron
midiendo la geometría y se confirmaron con capturas del juego con la cámara desplazada 1,3 cm.

| Zona | Causa | Solución |
| --- | --- | --- |
| Puertas del archivo y del café | El marco de `BuildingKit.door` y el zócalo de `BuildingKit.body` sobresalían 11 cm de la fachada: caras frontales en el mismo plano en las franjas del marco junto a la hoja (unos 1,5 m² por puerta) | El marco sobresale 13 cm |
| Taquilla de la estación | El mismo defecto con su marco (0,6 m²) | El marco sobresale 13 cm |
| Ventanas (todas) | Parteluz y travesaño con la cara frontal en el mismo plano en el cruce | Travesaño 5 mm por delante |
| Libros de las estanterías | El libro más alto medía 55 cm y entre baldas hay 45: atravesaba la balda de arriba y su frente coincidía con el de los libros de encima | Libros de 26 a 41 cm, nunca por encima del mueble; baldas y fondo entre los laterales |
| Sofá y sillón de la mansión | Brazos y asiento del sofá con el frente enrasado; respaldo y asiento del sillón con el costado enrasado (visible con el sillón girado) | 1–2 cm de diferencia |

Las piezas que son modelos de Blender (`puerta`, `ventana`, `ventana_interior`, `taquilla`,
`estanteria`, `sillon`, `sofa`) se regeneraron con `python blender/scripts/migrar.py --ids <id>
--forzar` (la estantería, además, con `optimizar_ocultas.py`, como en la sesión 5).

### Detector

`tests/unit/coplanar_faces.gd` busca, en los triángulos ya fusionados de un escenario (con los
modelos de Blender), las parejas de caras visibles para la cámara que comparten plano (0,4 mm) y
superficie (más de 0,05 cm²). Después lanza rayos hacia la cámara contra la propia malla para
descartar las que quedan tapadas o dentro de otro sólido.

```
godot --headless --path . res://tools/modelos/detectar_coplanares.tscn -- [--escenario=plaza] [--ocultos]
```

Zonas visibles antes → después: plaza 62 → 19, café 70 → 69, mansión 327 → 128, archivo 569 → 41,
estación 5 → 1. Lo que queda está fuera de este encargo (ver «Pendiente»).

## Banco Valdés

- Fachada (sistema local de `BuildingKit`, X a lo largo, +Z hacia la plaza): dos columnas de
  dos ventanas iluminadas en X = ±3 (las mismas posiciones que antes), puerta doble en el centro
  (`BuildingKit.double_door`, modelo `puerta_doble`), aviso «CERRADO POR MANTENIMIENTO» con
  martillo y llave (`BuildingKit.notice`, modelo `aviso`; el texto es un `Label3D`) y valla de
  obras delante (`PropsKit.work_barrier`, modelo `valla_obras`). Sólo hay una valla.
- La puerta no es una salida ni un interactivo; el marco, el escalón y la valla tienen colisión.
- **Muro delante de las ventanas:** el tramo sur de la tapia de la mansión medía 8 m (Z −0,3…7,7)
  y se metía 3,7 m por delante de la fachada del banco (Z 4…14), tapando media planta baja y la
  ventana derecha. Ahora va del pilar de la verja a la esquina del banco (`GATE_WALLS` en
  `plaza.gd`) con la albardilla enrasada en ese extremo. La verja sigue empezando en su pilar.
- El murete sur de la plaza arranca en el frente del zócalo del banco: su albardilla y el zócalo
  compartían la cara superior (0,7 m).
- Mapa del pueblo actualizado (tapia y murete). El marcador `puerta_banco` se aparta 20 cm.

## Alcorques

`PropsKit.tree_pit` (modelo `alcorque`): cuadrado de 1,4 m a ras del suelo, bordillo de piedra de
6 cm en cuatro piezas que no se solapan, tierra a 3,5 cm (2,5 cm sobre el empedrado de la plaza) y
unas hojas caídas. Devuelve el pie del tronco. La colisión cubre el alcorque: se rodea como la
jardinera y la navegación no pasa por encima. Los tres árboles del empedrado están en `PIT_TREES`
(`plaza.gd`); el de la jardinera no cambia. El mapa dibuja los alcorques.

## Sillón de la mansión

El sofá mira hacia +X; el sillón estaba en (2,8; −3,0) mirando hacia la cámara. Ahora está en
(3,0; −5,2) con giro −90°: de frente al sofá, al otro lado de la mesa baja y con casi un metro
libre a cada lado (`SALON_*` en `mansion.gd`). El marcador `salon_este` mira a la mesa.

## Vegetación

`PropsKit.shrub_bed` (modelo `parterre`, una variante por largo): murete de piedra de 30 cm,
tierra y una fila de arbustos low-poly con los verdes de la jardinera. Posiciones en `SHRUB_BEDS`
de `plaza.gd` y `estacion.gd`; el mapa las lee de ahí.

- Plaza: acera del archivo a la derecha de las cajas, detrás del seto de la calle de la estación
  y por fuera del murete este.
- Estación: por dentro de los muretes este y sur (junto al edificio y junto al seto de la calle)
  y a lo largo del borde del andén, detrás de los bancos.

Ninguno está en la calle, en la plaza, en el paso a la calle, delante de una puerta ni sobre las
vías, y todos tienen colisión.

## Pruebas

`tests/unit/test_scene_graphics.gd`: sin solapes visibles en puertas, taquilla, estanterías
(también cada variante suelta, con las caras ocultas), sala de la mansión, fachada del banco,
alcorques y parterres; puerta del banco sin interacción y con colisión; tapia terminada en la
esquina del banco y en el pilar; sillón de cara al sofá y con paso alrededor; alcorques que se
rodean; parterres que no se meten en nada, llegadas y puestos de NPC libres y caminos entre las
llegadas de cada exterior. Con el marco de puerta antiguo, la prueba falla (comprobado).

## Pendiente

Solapes que el detector sigue encontrando y que no formaban parte del encargo:

- Juntas de tabiques de los interiores (zócalos y remates de dos paredes que se cruzan), sobre
  todo en la mansión y el café.
- Plaza: zócalos del café y de la casa estrecha (se solapan 10 cm), cruce de los muretes sur y
  este, bordillos de la esquina noroeste, el banco de la fuente que mira al oeste y un detalle de
  la torre del reloj. Estación: el canto de la marquesina.
