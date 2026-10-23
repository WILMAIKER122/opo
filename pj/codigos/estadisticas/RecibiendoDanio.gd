extends State
class_name EstadoDanioJugador
## Estado "recibiendo daño" del jugador: pierde el control un instante y sale
## empujado (igual que EstadoRecibiendoDanio en los enemigos).
## En la escena va como hijo del nodo StateMachine, con el nombre "RecibiendoDanio".

## Segundos sin control del jugador tras el golpe
@export var duracion_stun: float = 0.25
## Qué tan rápido se frena el empuje
@export var frenado_knockback: float = 30.0
## Nombre del estado al que vuelve cuando termina el stun
@export var estado_al_terminar: String = "Idle"

var vector_knockback: Vector3 = Vector3.ZERO
var _tiempo_restante: float = 0.0


## Lo llama Player.recibir_dano() justo después de entrar al estado
func aplicar_knockback(origen_impacto: Vector3, fuerza: float) -> void:
	var direccion := character.global_position - origen_impacto
	direccion.y = 0.0
	if direccion.length() > 0.01:
		vector_knockback = direccion.normalized() * fuerza
	else:
		vector_knockback = Vector3.ZERO
	_tiempo_restante = duracion_stun


func update_physics(delta: float) -> void:
	vector_knockback = vector_knockback.move_toward(Vector3.ZERO, frenado_knockback * delta)
	character.velocity.x = vector_knockback.x
	character.velocity.z = vector_knockback.z

	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		state_machine.transition_to(estado_al_terminar)


func handle_input(_event: InputEvent) -> void:
	pass # sin control mientras dura el stun
