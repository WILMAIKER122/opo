extends Node
class_name StateMachine_enemi

@export var estado_inicial: EstadoEnemigo

var estado_actual: EstadoEnemigo
var estados: Dictionary = {}

func inicializar(enemigo: Enemigo) -> void:
	for hijo in get_children():
		if hijo is EstadoEnemigo:
			estados[hijo.name.to_lower()] = hijo
			hijo.enemigo = enemigo
	
	if estado_inicial:
		cambiar_estado(estado_inicial.name.to_lower())

func actualizar(delta: float) -> void:
	if estado_actual:
		estado_actual.actualizar(delta)

func actualizar_fisicas(delta: float) -> void:
	if estado_actual:
		estado_actual.actualizar_fisicas(delta)

func cambiar_estado(nombre_nuevo_estado: String) -> void:
	var nuevo_estado = estados.get(nombre_nuevo_estado.to_lower())
	if not nuevo_estado:
		return
		
	if estado_actual:
		estado_actual.salir()
		
	estado_actual = nuevo_estado
	estado_actual.entrar()
