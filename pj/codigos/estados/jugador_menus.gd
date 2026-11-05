class_name ControlMenusJugador
extends RefCounted
## Atajos de menús (A inventario, B bolsillo, T tomo), comer rápido (C), cambiar provisión (V)
## y partir a la run. Datos en Player (_p).
## Destino: res://pj/codigos/estados/jugador_menus.gd

var _p: Player


func _init(jugador: Player) -> void:
	_p = jugador


## Devuelve true si consumió el evento
func manejar_input(event: InputEvent) -> bool:
	return _manejar_atajos_menu(event) or _manejar_bolsillo(event)


## Con el bolsillo vacío (y algo para llevar) se abre el hub en el Bolsillo para equiparse antes de salir
func partir_a_la_run() -> void:
	# El bolsillo se rellena solo con la plantilla; si sigue vacío se abre el hub para equiparse
	OpsBolsillo.autorellenar(_p.estadisticas, CodigoGlobal.inventario_base)
	if _p.estadisticas.bolsillo.is_empty() and CodigoGlobal.hay_comestibles_en_base():
		abrir_hub(&"bolsillo", true)
	else:
		CodigoGlobal.iniciar_run(_p.estadisticas)


func abrir_hub(pestana: StringName, partir: bool = false) -> bool:
	MenuManager.menu_closed.connect(_al_cerrar_hub, CONNECT_ONE_SHOT)
	var datos := {"estadisticas": _p.estadisticas, "pestana": pestana, "partir": partir}
	if MenuManager.open_menu("hub", "res://menu/hub/menu_hub.tscn", true, datos):
		_p.get_viewport().set_input_as_handled()
		return true
	MenuManager.menu_closed.disconnect(_al_cerrar_hub)
	return false


# ==============================================================================
# INTERNO
# ==============================================================================

func _libre_para_actuar() -> bool:
	var actual := _p.state_machine.current_state
	return actual != null and actual.name.to_lower() in ["idle", "run"]


## A = Inventario, B = Bolsillo, T = Tomo. Todos abren el mismo hub en su pestaña.
func _manejar_atajos_menu(event: InputEvent) -> bool:
	if _p.muerto or MenuManager.is_menu_open():
		return false
	var pestana := &""
	if event.is_action_pressed("abrir_tomo"):
		pestana = &"tomo"
	elif event.is_action_pressed("comer"):
		pestana = &"inventario"
	elif event.is_action_pressed("bolsillo_equipar"):
		pestana = &"bolsillo"
	else:
		return false
	if not _libre_para_actuar():
		return false
	return abrir_hub(pestana)


func _al_cerrar_hub(_nombre: String, resultado: Dictionary) -> void:
	match resultado.get("accion", "cancelar"):
		"comer":
			var comer := _p.state_machine.states["comer"] as EstadoComer
			comer.seleccion_pendiente = resultado.get("seleccion", {})
			_p.state_machine.transition_to("Comer")
		"partir":
			CodigoGlobal.iniciar_run(_p.estadisticas)


## C come la provisión seleccionada y V cambia de provisión (en la run y en la base)
func _manejar_bolsillo(event: InputEvent) -> bool:
	if _p.muerto or MenuManager.is_menu_open():
		return false
	if event.is_action_pressed("bolsillo_cambiar"):
		_p.estadisticas.ciclar_bolsillo(1)
	elif event.is_action_pressed("bolsillo_usar"):
		if not _libre_para_actuar():
			return false
		_p.state_machine.transition_to("ComerRapido")
	else:
		return false
	_p.get_viewport().set_input_as_handled()
	return true
