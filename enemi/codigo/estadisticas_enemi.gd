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
