class_name StateMachine
extends Node

@export var initial_state: Node
var current_state: State
var states: Dictionary = {}

func init(character: CharacterBody3D) -> void:
	# Recorre todos los nodos hijos y los guarda en el diccionario
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.character = character
			child.state_machine = self
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func update_physics(delta: float) -> void:
	if current_state:
		current_state.update_physics(delta)

func transition_to(target_state_name: String) -> void:
	
	var key = target_state_name.to_lower()
	
	if not states.has(key):
		push_warning("El estado " + target_state_name + " no existe.")
		return

	if current_state:
		current_state.exit()

	current_state = states[key]
	current_state.enter()
