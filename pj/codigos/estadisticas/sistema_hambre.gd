class_name SistemaHambre
extends Resource
@export_group("Penalización Hambre en 0")
@export var reduccion_dano_hambre_cero: float = 30.0   # % de reducción al daño mientras hambre esté en 0

@export var hambre_maxima: float = 100.0
@export var hambre_actual: float = 100.0

@export_group("Decaimiento por Tick")
@export var intervalo_decaimiento: float = 60.0        # Cada cuántos segundos se descuenta
@export_range(0.0, 100.0) var porcentaje_decaimiento: float = 10.0   # % de la hambre MÁXIMA que se pierde por tick

@export var dano_por_segundo_hambre_cero: float = 2.0

@export_group("Gasto por Acción")
@export var costo_dash: float = 3.0
@export var costo_ataque: float = 1.5

var _tiempo_acumulado: float = 0.0

func actualizar(delta: float, en_run: bool, velocidad_decaimiento: float = 1.0) -> float:
	# Solo el decaimiento se acelera; el daño por hambre en 0 sigue usando el delta real
	_tiempo_acumulado += delta * velocidad_decaimiento
	
	while _tiempo_acumulado >= intervalo_decaimiento:
		_tiempo_acumulado -= intervalo_decaimiento
		var cantidad = hambre_maxima * (porcentaje_decaimiento / 100.0)
		hambre_actual = max(0.0, hambre_actual - cantidad)
	
	var dano_vida := 0.0
	if hambre_actual <= 0.0 and en_run:
		dano_vida = dano_por_segundo_hambre_cero * delta
	
	return dano_vida

func comer(cantidad: float) -> void:
	hambre_actual = min(hambre_maxima, hambre_actual + cantidad)

func gastar(cantidad: float) -> void:
	hambre_actual = max(0.0, hambre_actual - cantidad)

func esta_en_cero() -> bool:
	return hambre_actual <= 0.0
