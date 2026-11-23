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
	"barril": {"categoria": "atrezo", "objeto": "Barril", "fiel": true},
	"caja": {"categoria": "atrezo", "objeto": "Caja", "fiel": true},
	"mesa_cafe": {"categoria": "atrezo", "objeto": "MesaCafe", "fiel": true},
	# Mobiliario (InteriorKit)
	"silla": {"categoria": "mobiliario", "objeto": "Silla", "fiel": true},
	"sillon": {"categoria": "mobiliario", "objeto": "Sillon", "fiel": true},
	"sofa": {"categoria": "mobiliario", "objeto": "Sofa", "fiel": true},
	"mesa": {"categoria": "mobiliario", "objeto": "Mesa", "fiel": true},
	"escritorio": {"categoria": "mobiliario", "objeto": "Escritorio", "fiel": true},
	"estanteria": {"categoria": "mobiliario", "objeto": "Estanteria", "fiel": true},
	"archivador": {"categoria": "mobiliario", "objeto": "Archivador", "fiel": true},
	"chimenea": {"categoria": "mobiliario", "objeto": "Chimenea", "fiel": true},
	"lampara_pie": {"categoria": "mobiliario", "objeto": "LamparaPie", "fiel": true},
	"lampara_techo": {"categoria": "mobiliario", "objeto": "LamparaTecho", "fiel": true},
	"cama": {"categoria": "mobiliario", "objeto": "Cama", "fiel": true},
	"comoda": {"categoria": "mobiliario", "objeto": "Comoda", "fiel": true},
	"cuadro": {"categoria": "mobiliario", "objeto": "Cuadro", "fiel": true},
	"ventana_interior": {"categoria": "mobiliario", "objeto": "VentanaInterior", "fiel": true},
	"planta": {"categoria": "mobiliario", "objeto": "Planta", "fiel": true},
	"reloj_pie": {"categoria": "mobiliario", "objeto": "RelojPie", "fiel": true},
	# Piezas propias de los interiores (café, mansión, archivo)
	"barra_cafe": {"categoria": "escenario", "objeto": "BarraCafe", "fiel": true},
	"taburete": {"categoria": "escenario", "objeto": "Taburete", "fiel": true},
	"botellero_cafe": {"categoria": "escenario", "objeto": "BotelleroCafe", "fiel": true},
	"telefono": {"categoria": "escenario", "objeto": "Telefono", "fiel": true},
	"mesilla": {"categoria": "escenario", "objeto": "Mesilla", "fiel": true},
	"papeles": {"categoria": "escenario", "objeto": "Papeles", "fiel": true},
	"libro": {"categoria": "escenario", "objeto": "Libro", "fiel": true},
	"tintero": {"categoria": "escenario", "objeto": "Tintero", "fiel": true},
	"copa": {"categoria": "escenario", "objeto": "Copa", "fiel": true},
	"reloj_caido": {"categoria": "escenario", "objeto": "RelojCaido", "fiel": true},
	"huellas_betun": {"categoria": "escenario", "objeto": "HuellasBetun", "fiel": true},
	"foto": {"categoria": "escenario", "objeto": "Foto", "fiel": true},
	"tablero_llaves": {"categoria": "escenario", "objeto": "TableroLlaves", "fiel": true},
	"mostrador_archivo": {"categoria": "escenario", "objeto": "MostradorArchivo", "fiel": true},
}
