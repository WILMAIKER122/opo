extends Control
## Menú de Pausa: Volver al juego / Opciones / Menú Principal / Salir.
## Se maneja solo con teclado o mando (el foco de los botones hace todo el trabajo).
##
## Se abre con MenuManager.open_menu("pausa", <ruta de esta escena>, true) y se cierra SIEMPRE
## a través de MenuManager.close_current_menu(): así el gestor queda libre y se pueden abrir
## otros menús (comer, cocinar...) después de pausar.

## Escena del menú principal (para volver desde la pausa)
@export_file("*.tscn") var escena_menu_principal: String = "res://menu/menu_principal.tscn"

const RUTA_OPCIONES := "user://opciones.cfg"

# Frame en que se abrió el menú: el Esc que lo abre NO tiene que cerrarlo en ese mismo frame
var _frame_apertura: int = -1

@onready var panel_menu: Control = $PanelMenu
@onready var panel_opciones: Control = $PanelOpciones
@onready var boton_volver_juego: Button = $PanelMenu/VBoxMenu/BotonVolverJuego
@onready var boton_opciones: Button = $PanelMenu/VBoxMenu/BotonOpciones
@onready var boton_menu_principal: Button = $PanelMenu/VBoxMenu/BotonMenuPrincipal
@onready var boton_salir: Button = $PanelMenu/VBoxMenu/BotonSalir
@onready var slider_volumen: HSlider = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/FilaVolumen/SliderVolumen
@onready var check_pantalla_completa: CheckButton = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/CheckPantallaCompleta
@onready var boton_volver: Button = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/BotonVolver


func _ready() -> void:
	# ALWAYS (no WHEN_PAUSED): tiene que responder tanto en pausa como con el juego corriendo
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame_apertura = Engine.get_process_frames()

	boton_volver_juego.pressed.connect(_reanudar_juego)
	boton_opciones.pressed.connect(_abrir_opciones)
	boton_menu_principal.pressed.connect(_al_menu_principal)
	boton_salir.pressed.connect(_al_salir)
	boton_volver.pressed.connect(_cerrar_opciones)
	slider_volumen.value_changed.connect(_aplicar_volumen)
	check_pantalla_completa.toggled.connect(_aplicar_pantalla_completa)

	slider_volumen.min_value = 0.0
	slider_volumen.max_value = 1.0
	slider_volumen.step = 0.05

	# En la versión web no se puede salir del juego
	if OS.has_feature("web"):
		boton_salir.hide()

	# Foco en bucle entre los botones del menú de pausa
	var botones_visibles: Array[Button] = [boton_volver_juego, boton_opciones, boton_menu_principal]
	if boton_salir.visible:
		botones_visibles.append(boton_salir)
	var primero: Button = botones_visibles[0]
	var ultimo: Button = botones_visibles[botones_visibles.size() - 1]
	primero.focus_neighbor_top = primero.get_path_to(ultimo)
	ultimo.focus_neighbor_bottom = ultimo.get_path_to(primero)

	_cargar_opciones()

	# Abierto por MenuManager: se muestra directo y es el gestor quien maneja la pausa.
	# Si en cambio es un nodo fijo en la escena (sin gestor), arranca oculto y con el juego corriendo.
	if MenuManager.get_current_menu() == self:
		_mostrar_menu(boton_volver_juego)
	else:
		hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# El mismo Esc que abrió el menú llega acá en el mismo frame: se ignora
	if Engine.get_process_frames() == _frame_apertura:
		return
	get_viewport().set_input_as_handled()

	if visible:
		# Dentro de Opciones, Esc primero cierra Opciones
		if panel_opciones.visible:
			_cerrar_opciones()
		else:
			_reanudar_juego()
	elif MenuManager.get_current_menu() != self:
		# Solo en el modo "nodo fijo": Esc lo abre
		_pausar_juego()


# ==============================================================================
# CONTROL DE PAUSA
# ==============================================================================

## Solo para el modo "nodo fijo" (sin MenuManager)
func _pausar_juego() -> void:
	show()
	get_tree().paused = true
	_mostrar_menu(boton_volver_juego)


func _reanudar_juego() -> void:
	if MenuManager.get_current_menu() == self:
		# El gestor libera el menú y quita la pausa (si la puso él)
		MenuManager.close_current_menu({"accion": "reanudar"})
	else:
		hide()
		get_tree().paused = false


# ==============================================================================
# NAVEGACIÓN
# ==============================================================================

func _mostrar_menu(foco: Button) -> void:
	panel_opciones.hide()
	panel_menu.show()
	foco.grab_focus.call_deferred()


func _abrir_opciones() -> void:
	panel_menu.hide()
	panel_opciones.show()
	slider_volumen.grab_focus.call_deferred()


func _cerrar_opciones() -> void:
	_guardar_opciones()
	_mostrar_menu(boton_opciones)


func _al_menu_principal() -> void:
	if CodigoGlobal.en_run:
		CodigoGlobal.abandonar_run()
	# Primero se libera el gestor (y se quita la pausa) y DESPUÉS se cambia de escena
	if MenuManager.get_current_menu() == self:
		MenuManager.close_current_menu({"accion": "menu_principal"})
	else:
		get_tree().paused = false

	if CodigoGlobal.has_method("cambiar_escena"):
		CodigoGlobal.cambiar_escena(escena_menu_principal)
	else:
		get_tree().change_scene_to_file(escena_menu_principal)


func _al_salir() -> void:
	get_tree().quit()


# ==============================================================================
# OPCIONES (se guardan en user://opciones.cfg)
# ==============================================================================

func _aplicar_volumen(valor: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, valor <= 0.001)
	if valor > 0.001:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor))


func _aplicar_pantalla_completa(activa: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if activa else DisplayServer.WINDOW_MODE_WINDOWED)


func _cargar_opciones() -> void:
	var volumen := 1.0
	var pantalla_completa := false

	var config := ConfigFile.new()
	if config.load(RUTA_OPCIONES) == OK:
		volumen = float(config.get_value("audio", "volumen", 1.0))
		pantalla_completa = bool(config.get_value("video", "pantalla_completa", false))

	slider_volumen.set_value_no_signal(volumen)
	check_pantalla_completa.set_pressed_no_signal(pantalla_completa)
	_aplicar_volumen(volumen)
	_aplicar_pantalla_completa(pantalla_completa)


func _guardar_opciones() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volumen", slider_volumen.value)
	config.set_value("video", "pantalla_completa", check_pantalla_completa.button_pressed)
	config.save(RUTA_OPCIONES)
