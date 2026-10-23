class_name ZetaPasivaEfectosUnicos
extends Resource

@export_group("Curación al Recibir Daño")
@export var probabilidad_curacion: float = 0.25 # 25%
@export var cantidad_curacion: float = 5.0

@export_group("Efecto de Esquive")
@export var lanzar_chispas_al_esquivar: bool = true
@export var escena_chispas: PackedScene

@export_group("Costos de Recursos (Multiplicador, ej: 0.8 = 20% menos)")
@export var multiplicador_costo_correr: float = 1.0
@export var multiplicador_costo_sigilo: float = 1.0
