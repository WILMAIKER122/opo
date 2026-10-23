class_name EfectoItem
extends Resource

enum TipoEfecto {
	CURACION,
	COSTO_VIDA,
	BUFF_TEMPORAL,
}

@export var tipo: TipoEfecto = TipoEfecto.CURACION
@export var stat_afectado: String = "vida"
@export var valor: float = 5.0
@export var es_porcentaje: bool = false   # Si true, 'valor' se interpreta como % (ej. 10.0 = +10%)

@export var duracion: float = 0.0   # 0 = instantáneo, -1 = dura toda la run, >0 = segundos

@export_range(0.0, 1.0) var probabilidad: float = 1.0
