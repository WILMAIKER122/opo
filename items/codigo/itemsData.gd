class_name ItemData
extends Resource

enum TipoItem { OTRO, COMESTIBLE }
enum Rareza { COMUN, RARO, UNICO }

enum TagComida {
	BESTIA, INSECTO, NOCTURNO, DULCE, VISCOSO,
	PICANTE, MISTICO, TOXICO, PODRIDO, MALDITO
}

@export var nombre: String = "Ítem"
@export var apilable: bool = true
@export var cantidad: int = 1
@export var max_cantidad: int = 99
@export_multiline var descripcion: String = ""
@export var icono: Texture2D
@export var tipo: TipoItem = TipoItem.OTRO
@export var efectos: Array[EfectoItem] = []

@export var tags: Array[TagComida] = []
@export var rareza: Rareza = Rareza.COMUN
@export var hambre_restaurada: float = 0.0
