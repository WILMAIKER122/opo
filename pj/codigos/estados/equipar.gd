extends State
## Estado "Equipar" del jugador: selector de provisiones antes de partir a la run.
## Se activa al apretar Enter en la base (lo llama Player). El menú lo abre y maneja MenuManager
## (modo "equipar": hasta stats.capacidad_provisiones unidades en total). Al confirmar,
## inicia la run llevando lo elegido; al cancelar, vuelve a idle.

@export var popup_scene: PackedScene   # PopupEquipo.tscn


func enter() -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0

	# Solo se prepara el viaje desde la base
	if CodigoGlobal.en_run:
		state_machine.transition_to("idle")
		return

	var comestibles := _obtener_comestibles_de_la_base()

	# Sin nada que llevar no hace falta elegir: parte directo
	if comestibles.is_empty():
		CodigoGlobal.iniciar_run(character.estadisticas)
		return

	if popup_scene == null:
		push_warning("Equipar: falta asignar popup_scene (PopupEquipo.tscn) en el Inspector.")
		state_machine.transition_to("idle")
		return

	MenuManager.menu_closed.connect(_al_cerrar_menu, CONNECT_ONE_SHOT)
	var datos := {
		"modo": "equipar",
		"items": comestibles,
		"capacidad": character.estadisticas.stats.capacidad_provisiones,
	}
	if not MenuManager.open_menu("equipar", popup_scene.resource_path, true, datos):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
		state_machine.transition_to("idle")


func exit() -> void:
	# Si salimos del estado con el menú todavía abierto, lo cerramos sin que nos avise
	if MenuManager.menu_closed.is_connected(_al_cerrar_menu):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
	if MenuManager.is_menu_open() and MenuManager.current_menu_name == "equipar":
		MenuManager.close_current_menu()


## MenuManager ya quitó la pausa antes de avisar, así que es seguro cambiar de escena acá
func _al_cerrar_menu(_nombre: String, resultado: Dictionary) -> void:
	if resultado.get("accion", "cancelar") == "confirmar":
		CodigoGlobal.iniciar_run(character.estadisticas, resultado.get("seleccion", {}))
	else:
		state_machine.transition_to("idle")


func update_physics(_delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0


func _obtener_comestibles_de_la_base() -> Dictionary:
	var resultado := {}
	for clave in CodigoGlobal.inventario_base:
		var item: ItemData = CodigoGlobal.inventario_base[clave]
		if item.tipo == ItemData.TipoItem.COMESTIBLE and item.cantidad > 0:
			resultado[clave] = item
	return resultado
