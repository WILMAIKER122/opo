class_name Zeta_datos
extends Resource

@export_group("Información Básica")
@export var nombre: String = "Casco Zeta"
@export_multiline var descripcion: String = "Un casco modular versátil."
@export var textura: Texture2D

@export_group("Estadisticas")
@export var estadisticas: ZetaPasivaEstadisticas

@export_group("Resistencias")
@export var resistencias: ZetaPasivaResistencias

@export_group("Efectos unicos")
@export var EfectosUnicos: ZetaPasivaEfectosUnicos
@export var gustos: Array[ItemData.TagComida] = []
@export var odios: Array[ItemData.TagComida] = []

@export var desbloqueada: bool = false

@export_group("Mutación")
@export var tag_mutacion: ItemData.TagComida
@export var umbral_mutacion: int = 10
@export var posibles_mutaciones: Array[MutacionPosible] = []

enum ComportamientoSuelta { CAE, BOOMERANG, FIJA }

@export_group("Al soltarse (dash)")
@export var comportamiento_suelta: ComportamientoSuelta = ComportamientoSuelta.CAE
## Segundos hasta que vuela sola de vuelta al jugador (0 = solo se recoge pisándola)
@export var segundos_retorno: float = 1.2
@export var velocidad_retorno: float = 14.0
## BOOMERANG: multiplica el daño del jugador, y velocidad y duración de la ida
@export var multiplicador_dano_suelta: float = 1.0
@export var velocidad_ida: float = 16.0
@export var segundos_ida: float = 0.35
## FIJA: multiplica la duración del dash (la Zeta no se suelta, pero el dash es más corto)
@export var multiplicador_dash_fija: float = 0.6
