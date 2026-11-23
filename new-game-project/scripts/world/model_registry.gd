class_name ModelRegistry
extends RefCounted
## Modelos de Blender registrados. La clave es el id estable del modelo: también es el nombre de su
## GLB (`assets/modelos/<categoria>/<id>.glb`), de su fuente (`blender/fuentes/<categoria>/<id>.blend`),
## de su referencia y de su registro de exportación. Ningún id se guarda en las partidas.
##   categoria  atrezo, mobiliario, arquitectura, escenario o personajes
##   objeto     nombre del objeto de Blender; cada variante es otro objeto, «<objeto>_<variante>»
##   fiel       true: el GLB reproduce la pieza procedural y las pruebas lo comparan polígono a
##              polígono. "optimizado": sólo le faltan caras que la cámara no ve. false: retocado
##              en Blender (sólo se comparan su caja y las colisiones)
## Para añadir uno: docs/blender/09-sistema-de-modelos.md.

const MODELS := {
	# Atrezo (PropsKit)
	"buzon": {"categoria": "atrezo", "objeto": "Buzon", "fiel": true},
}
