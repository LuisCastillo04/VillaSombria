# Configuración

Preferencias del jugador: qué se guarda, dónde, cómo se valida y cómo se aplica.

## Persistencia

Las preferencias se guardan en `user://ajustes.cfg`, aparte de las partidas: no dependen de ninguna
ranura y no viajan en los archivos de `user://saves/`. Las lee y las escribe el autoload `Settings`
(`scripts/autoload/settings.gd`); qué preferencias existen lo describe `SettingsSchema`
(`scripts/settings/settings_schema.gd`).

```ini
[meta]
version=2

[audio]
Master=0.8
Musica=0.8
Efectos=0.8
Ambiente=0.8

[graficos]
modo_ventana="ventana"
resolucion=Vector2i(1280, 720)
vsync=false
calidad_iluminacion="alto"
calidad_efectos="alto"

[jugabilidad]
velocidad_texto="normal"
avance_automatico=false
confirmaciones=true

[accesibilidad]
tamano_letra="normal"
contraste_alto=false
subtitulos=true
movimiento_reducido=false
```

| Sección | Preferencias | Valores |
| --- | --- | --- |
| `audio` | Volumen de `Master`, `Musica`, `Efectos` y `Ambiente` | 0 a 1 |
| `graficos` | `modo_ventana` | `ventana`, `sin_bordes`, `pantalla_completa`, `exclusiva` |
| | `resolucion` | De 1024 × 576 a 7680 × 4320 |
| | `vsync` | Sí o no |
| | `calidad_iluminacion`, `calidad_efectos` | `bajo`, `medio`, `alto` |
| `jugabilidad` | `velocidad_texto` | `lento`, `normal`, `rapido`, `instantaneo` |
| | `avance_automatico`, `confirmaciones` | Sí o no |
| `accesibilidad` | `tamano_letra` | `normal`, `grande`, `muy_grande` |
| | `contraste_alto`, `subtitulos`, `movimiento_reducido` | Sí o no |
| `controles` | Reservada para las teclas de un sistema de reasignación | `Settings` nunca la borra |

### Reglas

- **Valores por defecto.** Sin archivo, cada preferencia toma el valor de `SettingsSchema`: el aspecto
  original del juego (calidad alta), ventana de 1280 × 720, sincronización vertical desactivada,
  texto a velocidad normal y confirmaciones activadas. Leer no crea el archivo.
- **Validación.** `SettingsSchema.validate` sólo admite el tipo y los valores de cada preferencia.
  Los volúmenes fuera de rango se ajustan a 0 o 1; una opción desconocida, un tipo equivocado o una
  resolución imposible se rechazan y queda el valor anterior (al leer, el valor por defecto).
- **Cambios independientes.** `Settings.set_value(clave, valor)` valida, aplica, escribe sólo esa
  clave sobre el archivo existente y emite `Settings.changed(clave, valor)`. Repetir el valor vigente
  no escribe ni avisa.
- **Lo ajeno se conserva.** Las secciones y claves que `Settings` no conoce (por ejemplo, lo que
  guarde un sistema de reasignación en `controles`) siguen en el archivo después de cada escritura.
- **Formato anterior.** La versión 1 guardaba `volumen/*`, `pantalla/completa` y `pantalla/vsync`.
  Al leerla se migra (pantalla completa pasa a ser el modo `pantalla_completa`), se retiran las
  secciones antiguas y el archivo se reescribe con `version=2`.
- **Archivos dañados.** Si un valor no es válido, se usa el de por defecto y el archivo se reescribe
  corregido. Si el archivo entero es ilegible, se aparta una copia con el sufijo `.danado` y se
  empieza con los valores por defecto.
- **Arranque.** `Settings` lee el archivo en su `_ready`, antes de la primera escena, y aplica lo que
  depende del motor.

### Atajos que se mantienen

`Settings.volumes`, `Settings.fullscreen`, `Settings.vsync`, `set_volume`, `set_fullscreen`,
`set_vsync` y `save` siguen funcionando como antes; ahora leen y escriben las claves del esquema.

## Añadir una preferencia

1. Descríbela en `SettingsSchema.DEFINITIONS` con su tipo, su valor por defecto y lo que admite; si
   es una lista cerrada, añade el nombre visible de cada valor a `LABELS`.
2. Quien la use la lee con `Settings.get_value("seccion/nombre")` y escucha `Settings.changed`.
3. Si depende del motor (ventana, calidad, escala), aplícala en `Settings._apply_key`.

## Pruebas

`tests/unit/test_settings.gd` comprueba los valores por defecto, las categorías, la validación, la
escritura de una sola clave sin perder el resto del archivo, la corrección de valores dañados, la
migración del formato anterior, la recarga como en un nuevo arranque y que las preferencias no se
guardan en las partidas. Las pruebas usan `user://pruebas_guardado/ajustes.cfg`
(`TestCase.reset_test_settings`) y nunca tocan los ajustes del jugador.

El caso del archivo ilegible se comprobó a mano con la misma prueba: el motor imprime un `ERROR:` al
analizarlo y `verificar.ps1` tomaría esa línea por un fallo, así que no forma parte de la batería.
