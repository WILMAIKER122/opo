class_name State
extends Node

# Referencias asignadas automáticamente por la StateMachine
var character: CharacterBody3D
var state_machine: StateMachine

# Se ejecuta al entrar al estado
func enter() -> void:
	pass

# Se ejecuta al salir del estado
func exit() -> void:
	pass

# Procesa entradas del teclado/control
func handle_input(_event: InputEvent) -> void:
	pass

# Procesa físicas en cada frame (reemplaza a _physics_process)
func update_physics(_delta: float) -> void:
	pass
