extends Node
class_name EstadoEnemigo

# Referencia al enemigo dueño de este estado
var enemigo: Enemigo

# Se ejecuta cuando el enemigo ENTRA a este estado
func entrar() -> void:
	pass

# Se ejecuta cuando el enemigo SALE de este estado
func salir() -> void:
	pass

# Equivale a _process/physics_process mientras el estado está activo
func actualizar(_delta: float) -> void:
	pass

func actualizar_fisicas(_delta: float) -> void:
	pass
