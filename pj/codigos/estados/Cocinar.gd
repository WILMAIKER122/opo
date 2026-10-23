extends State
## Estado "Cocinar" del jugador. El menú de cocina lo abre y maneja MenuManager (con el juego
## en pausa); cuando se cierra con Esc, el jugador vuelve a idle. Solo funciona en la base.

@export var popup_scene: PackedScene   # Asignar popup_cocina.tscn en el Inspector


func enter() -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0

	# Solo se cocina en la base
	if CodigoGlobal.en_run:
		state_machine.transition_to("idle")
		return

	if popup_scene == null:
		push_warning("Cocinar: falta asignar popup_scene (popup_cocina.tscn) en el Inspector.")
		state_machine.transition_to("idle")
		return

	MenuManager.menu_closed.connect(_al_cerrar_menu, CONNECT_ONE_SHOT)
	if not MenuManager.open_menu("cocinar", popup_scene.resource_path, true):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
		state_machine.transition_to("idle")


func exit() -> void:
	# Si salimos del estado con el menú todavía abierto, lo cerramos sin que nos avise
	if MenuManager.menu_closed.is_connected(_al_cerrar_menu):
		MenuManager.menu_closed.disconnect(_al_cerrar_menu)
	if MenuManager.is_menu_open() and MenuManager.current_menu_name == "cocinar":
		MenuManager.close_current_menu()


func _al_cerrar_menu(_nombre: String, _resultado: Dictionary) -> void:
	state_machine.transition_to("idle")


func update_physics(_delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
