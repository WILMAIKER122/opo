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
