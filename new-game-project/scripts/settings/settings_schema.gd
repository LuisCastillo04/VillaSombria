class_name SettingsSchema
extends RefCounted
## Qué preferencias existen, en qué sección del archivo se guardan, su valor por defecto y qué
## valores admiten. `Settings` sólo acepta lo que valida este esquema: un archivo editado a mano,
## dañado o de una versión anterior nunca deja el juego en un estado imposible.
##
## Las claves tienen la forma «sección/nombre» y la sección es la del archivo `ajustes.cfg`.
## Para añadir una preferencia basta con describirla aquí; `Settings` la carga, la valida y la
## guarda sin más cambios. Quien la use la lee con `Settings.get_value` y escucha `Settings.changed`.

## Versión del formato. La 1 guardaba `volumen/*`, `pantalla/completa` y `pantalla/vsync`.
const VERSION := 2

## Secciones del archivo, una por categoría. `controles` queda reservada para las teclas que guarde
## un sistema de reasignación: `Settings` nunca borra lo que haya en ella.
const SECTIONS: Array[String] = ["audio", "graficos", "jugabilidad", "accesibilidad", "controles"]
## Secciones del formato anterior, que se migran al leerlas y después se retiran del archivo.
const LEGACY_SECTIONS: Array[String] = ["volumen", "pantalla"]

const DEFAULT_VOLUME := 0.8
const QUALITY_LEVELS: Array[String] = ["bajo", "medio", "alto"]

## Cada preferencia: tipo, valor por defecto y lo que admite (`min` y `max` para los números y las
## resoluciones, `options` para las listas cerradas).
const DEFINITIONS := {
	"audio/Master": {"type": TYPE_FLOAT, "default": DEFAULT_VOLUME, "min": 0.0, "max": 1.0},
	"audio/Musica": {"type": TYPE_FLOAT, "default": DEFAULT_VOLUME, "min": 0.0, "max": 1.0},
	"audio/Efectos": {"type": TYPE_FLOAT, "default": DEFAULT_VOLUME, "min": 0.0, "max": 1.0},
	"audio/Ambiente": {"type": TYPE_FLOAT, "default": DEFAULT_VOLUME, "min": 0.0, "max": 1.0},
	"graficos/modo_ventana": {"type": TYPE_STRING, "default": "ventana",
		"options": ["ventana", "sin_bordes", "pantalla_completa", "exclusiva"]},
	# Tamaño de la ventana en los modos con ventana. En pantalla completa manda el monitor.
	"graficos/resolucion": {"type": TYPE_VECTOR2I, "default": Vector2i(1280, 720),
		"min": Vector2i(1024, 576), "max": Vector2i(7680, 4320)},
	# Desactivada por defecto: en portátiles con doble GPU la sincronización vertical puede hundir
	# la tasa de fotogramas. El motor limita igualmente el juego a 60 FPS.
	"graficos/vsync": {"type": TYPE_BOOL, "default": false},
	"graficos/calidad_iluminacion": {"type": TYPE_STRING, "default": "alto", "options": QUALITY_LEVELS},
	"graficos/calidad_efectos": {"type": TYPE_STRING, "default": "alto", "options": QUALITY_LEVELS},
	"jugabilidad/velocidad_texto": {"type": TYPE_STRING, "default": "normal",
		"options": ["lento", "normal", "rapido", "instantaneo"]},
	"jugabilidad/avance_automatico": {"type": TYPE_BOOL, "default": false},
	# Preguntar antes de las acciones que se pueden confirmar (dejar pasar una hora). Las
	# confirmaciones de acciones destructivas no dependen de esta preferencia.
	"jugabilidad/confirmaciones": {"type": TYPE_BOOL, "default": true},
	"accesibilidad/tamano_letra": {"type": TYPE_STRING, "default": "normal",
		"options": ["normal", "grande", "muy_grande"]},
	"accesibilidad/contraste_alto": {"type": TYPE_BOOL, "default": false},
	# Subtítulos de las voces y de los sonidos narrados. El texto de las conversaciones se muestra
	# siempre: es obligatorio para jugar y no depende de esta preferencia.
	"accesibilidad/subtitulos": {"type": TYPE_BOOL, "default": true},
	"accesibilidad/movimiento_reducido": {"type": TYPE_BOOL, "default": false},
}

## Nombre de cada valor de las listas cerradas, tal como se muestra en Configuración.
const LABELS := {
	"ventana": "Ventana",
	"sin_bordes": "Ventana sin bordes",
	"pantalla_completa": "Pantalla completa",
	"exclusiva": "Pantalla completa exclusiva",
	"bajo": "Bajo",
	"medio": "Medio",
	"alto": "Alto",
	"lento": "Lento",
	"normal": "Normal",
	"rapido": "Rápido",
	"instantaneo": "Instantáneo",
	"grande": "Grande",
	"muy_grande": "Muy grande",
}


static func has_key(key: String) -> bool:
	return DEFINITIONS.has(key)


## Todas las claves, en el orden en que se describen (y se escriben en el archivo).
static func keys() -> Array[String]:
	var found: Array[String] = []
	for key: String in DEFINITIONS:
		found.append(key)
	return found


## Claves de una sección, por ejemplo `graficos`.
static func keys_in(section: String) -> Array[String]:
	var found: Array[String] = []
	for key in keys():
		if section_of(key) == section:
			found.append(key)
	return found


static func section_of(key: String) -> String:
	return key.get_slice("/", 0)


static func name_of(key: String) -> String:
	return key.get_slice("/", 1)


static func default_value(key: String) -> Variant:
	return (DEFINITIONS[key] as Dictionary)["default"] if DEFINITIONS.has(key) else null


## Valores por defecto de todas las preferencias.
static func defaults() -> Dictionary:
	var values := {}
	for key in keys():
		values[key] = default_value(key)
	return values


## Valores admitidos por una lista cerrada, en el orden en que se ofrecen.
static func options(key: String) -> Array[String]:
	var found: Array[String] = []
	if DEFINITIONS.has(key):
		found.assign((DEFINITIONS[key] as Dictionary).get("options", []))
	return found


## Nombre visible de un valor («pantalla_completa» → «Pantalla completa»).
static func label_of(value: String) -> String:
	return LABELS.get(value, value)


## Devuelve el valor saneado o `null` si no es admisible. Los números fuera de rango se ajustan a
## sus límites; un tipo equivocado, una opción desconocida o una resolución imposible se rechazan.
static func validate(key: String, value: Variant) -> Variant:
	if not DEFINITIONS.has(key):
		return null
	var definition: Dictionary = DEFINITIONS[key]
	match int(definition["type"]):
		TYPE_BOOL:
			if typeof(value) == TYPE_BOOL:
				return value
			if typeof(value) == TYPE_INT and (int(value) == 0 or int(value) == 1):
				return int(value) == 1
		TYPE_FLOAT:
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				var number := float(value)
				if not is_nan(number) and not is_inf(number):
					return clampf(number, float(definition["min"]), float(definition["max"]))
		TYPE_STRING:
			if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
				var text := String(value)
				if (definition["options"] as Array).has(text):
					return text
		TYPE_VECTOR2I:
			var size := to_size(value)
			var low: Vector2i = definition["min"]
			var high: Vector2i = definition["max"]
			if size.x >= low.x and size.y >= low.y and size.x <= high.x and size.y <= high.y:
				return size
	return null


## Lee una resolución guardada como `Vector2i`, `Vector2` o texto «1280x720». Sin formato
## reconocible devuelve `Vector2i.ZERO`.
static func to_size(value: Variant) -> Vector2i:
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_VECTOR2:
			var vector: Vector2 = value
			if vector.x == floorf(vector.x) and vector.y == floorf(vector.y):
				return Vector2i(vector)
		TYPE_STRING, TYPE_STRING_NAME:
			var parts := String(value).to_lower().replace("×", "x").split("x")
			if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
				return Vector2i(parts[0].strip_edges().to_int(), parts[1].strip_edges().to_int())
	return Vector2i.ZERO


## Valores del formato anterior (versión 1), con sus claves actuales y sin validar todavía.
static func migrate_legacy(config: ConfigFile) -> Dictionary:
	var found := {}
	if config.has_section("volumen"):
		for bus: String in config.get_section_keys("volumen"):
			found["audio/" + bus] = config.get_value("volumen", bus)
	if config.has_section_key("pantalla", "completa"):
		var full: Variant = config.get_value("pantalla", "completa")
		if typeof(full) == TYPE_BOOL:
			found["graficos/modo_ventana"] = "pantalla_completa" if full else "ventana"
	if config.has_section_key("pantalla", "vsync"):
		found["graficos/vsync"] = config.get_value("pantalla", "vsync")
	return found
