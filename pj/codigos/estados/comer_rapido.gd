extends State
## Estado "ComerRapido": come la provisión seleccionada del bolsillo. El personaje queda quieto
## `duracion` segundos y recién al terminar consume la unidad (X = dash cancela sin gastar nada).

@export var duracion: float = 0.3

var _timer: float = 0.0


func enter() -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	_timer = 0.0
	if character.estadisticas.bolsillo.is_empty():
		state_machine.transition_to("idle")
		return
	character.playback.travel("idle")   # cambiala por la animación de comer cuando la tengas


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("x"):
		state_machine.transition_to("Dash")


func update_physics(delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	_timer += delta
	if _timer >= duracion:
		character.estadisticas.comer_del_bolsillo()
		state_machine.transition_to("idle")
