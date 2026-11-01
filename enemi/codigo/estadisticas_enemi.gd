extends Resource
class_name EnemigoStats

@export_group("Estadísticas")
@export var vida_maxima: float = 100.0

@export_group("Velocidades")
@export var velocidad_patrulla: float = 2.5
@export var velocidad_persecucion: float = 4.0
@export var velocidad_embestida: float = 12.0

@export_group("Comportamiento Estilo Cult of the Lamb")
@export var distancia_mantenida: float = 3.5 # Radio alrededor del jugador para acechar
@export var tiempo_cooldown_ataque: float = 2.0

@export var danio_ataque: float = 10.0
@export var knockback_ataque: float = 8.0

@export_group("Registro (Tomo)")
## Único por tipo de enemigo. Si queda vacío se usa el nombre del archivo .tres
@export var id: String = ""
@export var nombre: String = "Bestia"
@export_multiline var descripcion: String = ""
@export var icono: Texture2D
## Solo informativo: las partes que suelta, para mostrarlas en el Tomo

@export_group("Botín")
## Partes que puede soltar al morir (el Tomo muestra esta misma lista).
## La rareza del ítem decide qué tan seguido sale: común > raro > único.
## Vacía = usa la lista por defecto de la escena de botín.
@export var partes: Array[ItemData] = []
@export var cantidad_drop_min: int = 1
@export var cantidad_drop_max: int = 5


func id_registro() -> String:
	if id != "":
		return id
	if resource_path != "":
		return resource_path.get_file().get_basename()
	return nombre


const PESO_RAREZA := {
	ItemData.Rareza.COMUN: 10.0,
	ItemData.Rareza.RARO: 3.0,
	ItemData.Rareza.UNICO: 1.0,
}


## Sortea una parte de la tabla según su rareza. null si no hay partes asignadas.
func elegir_parte() -> ItemData:
	var total := 0.0
	for parte in partes:
		if parte != null:
			total += PESO_RAREZA.get(parte.rareza, 1.0)
	if total <= 0.0:
		return null
	var sorteo := randf() * total
	var ultima: ItemData = null
	for parte in partes:
		if parte == null:
			continue
		ultima = parte
		sorteo -= PESO_RAREZA.get(parte.rareza, 1.0)
		if sorteo <= 0.0:
			return parte
	return ultima
