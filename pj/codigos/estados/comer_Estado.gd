extends State
## Estado "Comer" del jugador. El menú de selección lo abre y maneja MenuManager (con el juego
## en pausa); cuando se cierra, este estado sigue con la animación de comer.

@export var eat_duration: float = 1.2
@export var popup_scene: PackedScene   # Asigna popup_comer.tscn en el Inspector

var timer: float = 0.0
var is_eating: bool = false
var en_seleccion: bool = false
var seleccion_final: Dictionary = {}

func enter() -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	is_eating = false
	en_seleccion = false
	timer = 0.0
	seleccion_final.clear()

	if popup_scene == null:
		push_warning("Comer: falta asignar popup_scene (popup_comer.tscn) en el Inspector.")
		state_machine.transition_to("idle")
		return

	var comestibles := _obtener_items_comestibles()

	# Sin items comestibles no hay nada que elegir: vuelve a idle
	if comestibles.is_empty():
		state_machine.transition_to("idle")
		return

	MenuManager.menu_closed.connect(_al_cerrar_menu, CONNECT_ONE_SHOT)
	var datos := {"modo": "comer", "items": comestibles}
	if not MenuManager.open_menu("comer", popup_scene.resource_path, true, datos):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
		state_machine.transition_to("idle")
		return

	en_seleccion = true

func exit() -> void:
	is_eating = false
	en_seleccion = false
	# Si salimos del estado con el menú todavía abierto, lo cerramos sin que nos avise
	if MenuManager.menu_closed.is_connected(_al_cerrar_menu):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
	if MenuManager.is_menu_open() and MenuManager.current_menu_name == "comer":
		MenuManager.close_current_menu()

## Toma los comestibles del inventario ACTIVO: el de la base si estás en la base,
## el de la run si estás en la run.
func _obtener_items_comestibles() -> Dictionary:
	var resultado := {}
	var inventario: Dictionary = character.estadisticas.obtener_inventario_activo()
	for clave in inventario:
		var item: ItemData = inventario[clave]
		if item.tipo == ItemData.TipoItem.COMESTIBLE:
			resultado[clave] = item
	return resultado

## El menú se cerró: confirmó (empieza a comer) o canceló (vuelve a idle)
func _al_cerrar_menu(_nombre: String, resultado: Dictionary) -> void:
	en_seleccion = false
	seleccion_final = resultado.get("seleccion", {})

	if resultado.get("accion", "cancelar") != "confirmar" or seleccion_final.is_empty():
		state_machine.transition_to("idle")
		return

	is_eating = true
	timer = 0.0

func handle_input(event: InputEvent) -> void:
	# El menú maneja sus propios controles; acá solo se puede cancelar mientras se come
	if is_eating and event.is_action_pressed("x"):
		state_machine.transition_to("Dash")

func update_physics(delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0

	if en_seleccion or not is_eating:
		return

	timer += delta
	if timer >= eat_duration:
		_procesar_conversion()
		state_machine.transition_to("idle")

func _procesar_conversion() -> void:
	var inventario: Dictionary = character.estadisticas.obtener_inventario_activo()

	for clave in seleccion_final:
		var cantidad_a_comer: int = seleccion_final[clave]

		if not inventario.has(clave):
			continue

		var item: ItemData = inventario[clave]

		character.estadisticas.comer_item(item, cantidad_a_comer)
		character.estadisticas.quitar_item_activo(clave, cantidad_a_comer)

	if character.has_method("actualizar_hud"):
		character.actualizar_hud()

	seleccion_final.clear()
