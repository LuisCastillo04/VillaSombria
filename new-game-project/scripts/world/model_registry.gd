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
	"farola": {"categoria": "atrezo", "objeto": "Farola", "fiel": true},
	"banco": {"categoria": "atrezo", "objeto": "Banco", "fiel": true},
	"arbol": {"categoria": "atrezo", "objeto": "Arbol", "fiel": true},
	"jardinera": {"categoria": "atrezo", "objeto": "Jardinera", "fiel": true},
	"coche": {"categoria": "atrezo", "objeto": "Coche", "fiel": true},
	"quiosco": {"categoria": "atrezo", "objeto": "Quiosco", "fiel": true},
	"poste_indicador": {"categoria": "atrezo", "objeto": "PosteIndicador", "fiel": true},
	# Detalles de fachada (BuildingKit). El cuerpo de los edificios sigue procedural (huella del mapa).
	"ventana": {"categoria": "arquitectura", "objeto": "Ventana", "fiel": true},
	"puerta": {"categoria": "arquitectura", "objeto": "Puerta", "fiel": true},
	"toldo": {"categoria": "arquitectura", "objeto": "Toldo", "fiel": true},
	"chimenea_tejado": {"categoria": "arquitectura", "objeto": "ChimeneaTejado", "fiel": true},
	"columna": {"categoria": "arquitectura", "objeto": "Columna", "fiel": true},
	# Mobiliario (InteriorKit)
	"silla": {"categoria": "mobiliario", "objeto": "Silla", "fiel": true},
	"sillon": {"categoria": "mobiliario", "objeto": "Sillon", "fiel": true},
	"sofa": {"categoria": "mobiliario", "objeto": "Sofa", "fiel": true},
	"mesa": {"categoria": "mobiliario", "objeto": "Mesa", "fiel": true},
	"escritorio": {"categoria": "mobiliario", "objeto": "Escritorio", "fiel": true},
	# Sin las caras que la cámara no ve (bases y traseras interiores): optimizar_ocultas.py.
	"estanteria": {"categoria": "mobiliario", "objeto": "Estanteria", "fiel": "optimizado"},
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
	# Piezas propias de los exteriores (plaza, estación)
	"escaparate_cafe": {"categoria": "escenario", "objeto": "EscaparateCafe", "fiel": true},
	"rotulo_cafe": {"categoria": "escenario", "objeto": "RotuloCafe", "fiel": true},
	"portico_archivo": {"categoria": "escenario", "objeto": "PorticoArchivo", "fiel": true},
	"torre_reloj": {"categoria": "escenario", "objeto": "TorreReloj", "fiel": true},
	"mansion_fondo": {"categoria": "escenario", "objeto": "MansionFondo", "fiel": true},
	"verja_mansion": {"categoria": "escenario", "objeto": "VerjaMansion", "fiel": true},
	"rotulo_banco": {"categoria": "escenario", "objeto": "RotuloBanco", "fiel": true},
	"fuente": {"categoria": "escenario", "objeto": "Fuente", "fiel": true},
	"locomotora": {"categoria": "escenario", "objeto": "Locomotora", "fiel": true},
	"vagon": {"categoria": "escenario", "objeto": "Vagon", "fiel": true},
	"taquilla": {"categoria": "escenario", "objeto": "Taquilla", "fiel": true},
	"marquesina": {"categoria": "escenario", "objeto": "Marquesina", "fiel": true},
	"reloj_anden": {"categoria": "escenario", "objeto": "RelojAnden", "fiel": true},
	# Personajes (CharacterModel): un GLB por personaje con un objeto por pivote
	# («<Objeto>_PiernaIzq», …, «<Objeto>_Cabeza»), cada uno con el origen en su pivote.
	"personaje_detective": {"categoria": "personajes", "objeto": "Detective", "fiel": true},
	"personaje_elena": {"categoria": "personajes", "objeto": "Elena", "fiel": true},
	"personaje_marcos": {"categoria": "personajes", "objeto": "Marcos", "fiel": true},
	"personaje_lucia": {"categoria": "personajes", "objeto": "Lucia", "fiel": true},
	"personaje_anselmo": {"categoria": "personajes", "objeto": "Anselmo", "fiel": true},
	"personaje_irene": {"categoria": "personajes", "objeto": "Irene", "fiel": true},
	"personaje_ortega": {"categoria": "personajes", "objeto": "Ortega", "fiel": true},
	"personaje_rosa": {"categoria": "personajes", "objeto": "Rosa", "fiel": true},
	"personaje_eusebio": {"categoria": "personajes", "objeto": "Eusebio", "fiel": true},
	"personaje_hilario": {"categoria": "personajes", "objeto": "Hilario", "fiel": true},
}
