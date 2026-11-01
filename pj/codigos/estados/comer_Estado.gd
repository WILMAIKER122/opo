extends State
class_name EstadoComer
## Estado "Comer": el hub (pestaña Inventario) elige qué comer y Player lo deja en
## seleccion_pendiente antes de entrar. Acá solo se ejecuta: quieto eat_duration segundos
## y recién al terminar se consume (X = dash cancela sin gastar nada).

@export var eat_duration: float = 1.2

## { clave: unidades }. Lo pone Player antes de transicionar a este estado.
var seleccion_pendiente: Dictionary = {}

var timer: float = 0.0
var seleccion_final: Dictionary = {}


func enter() -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	timer = 0.0
	seleccion_final = seleccion_pendiente.duplicate()
	seleccion_pendiente = {}
	if seleccion_final.is_empty():
		state_machine.transition_to("idle")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("x"):
		seleccion_final.clear()
		state_machine.transition_to("Dash")


func update_physics(delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	timer += delta
	if timer >= eat_duration:
		_procesar_conversion()
		state_machine.transition_to("idle")


func _procesar_conversion() -> void:
	var inventario: Dictionary = character.estadisticas.obtener_inventario_activo()
	for clave in seleccion_final:
		if not inventario.has(clave):
			continue
		var item: ItemData = inventario[clave]
		character.estadisticas.comer_item(item, seleccion_final[clave])
		character.estadisticas.quitar_item_activo(clave, seleccion_final[clave])
	seleccion_final.clear()
