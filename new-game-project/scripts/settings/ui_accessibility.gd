class_name UiAccessibility
extends RefCounted
## Opciones de accesibilidad de la interfaz: tamaño de letra, contraste aumentado, subtítulos y
## movimiento reducido. Las aplica `Settings`; las pantallas sólo consultan lo que les afecta.
##
## **Tamaño de letra.** Toda la interfaz se dibuja en un lienzo lógico de 1920 × 1080 que se escala
## con la ventana. «Grande» y «Muy grande» amplían ese escalado (`Window.content_scale_factor`): las
## letras crecen y, con ellas, los recuadros que las contienen, así que nada se recorta ni se monta
## encima de otra cosa. Las pantallas se maquetan con el tamaño lógico que queda (1670 × 939 y
## 1477 × 831 en una ventana 16:9) y ya se adaptaban a él: lo comprueban las pruebas y las capturas.
## La escena 3D no cambia.

## Escala de la interfaz de cada tamaño de letra.
const TEXT_SCALES := {"normal": 1.0, "grande": 1.15, "muy_grande": 1.3}


## Escala de la interfaz para un tamaño de letra («normal», «grande» o «muy_grande»).
static func text_scale(size_id: Variant = null) -> float:
	var key := String(size_id) if size_id != null else String(Settings.get_value("accesibilidad/tamano_letra"))
	return float(TEXT_SCALES.get(key, 1.0))


## Aplica el tamaño de letra a la ventana principal; la interfaz se vuelve a maquetar sola.
static func apply_text_scale(tree: SceneTree, size_id: String) -> void:
	if tree != null:
		tree.root.content_scale_factor = text_scale(size_id)


## Si el jugador pidió reducir las animaciones decorativas (deslizamientos, latidos, respiración de
## las siluetas). Los fundidos y lo que informa del estado del juego se mantienen.
static func reduced_motion() -> bool:
	return bool(Settings.get_value("accesibilidad/movimiento_reducido"))


## Multiplicador de los desplazamientos decorativos: 0 con el movimiento reducido.
static func motion() -> float:
	return 0.0 if reduced_motion() else 1.0


static func high_contrast() -> bool:
	return bool(Settings.get_value("accesibilidad/contraste_alto"))


static func subtitles_enabled() -> bool:
	return bool(Settings.get_value("accesibilidad/subtitulos"))
