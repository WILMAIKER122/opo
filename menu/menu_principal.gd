extends Control
## Menú de inicio: Jugar / Opciones / Salir. Se maneja solo con teclado o mando
## (el foco de los botones hace todo el trabajo, no hace falta el mouse).
## Los nodos se buscan por nombre único (%): en cada nodo marcado con % hay que hacer
## clic derecho > "Acceder como nombre único".

## Escena a la que lleva "Jugar"
@export_file("*.tscn") var escena_juego: String = "res://base.tscn"

const RUTA_OPCIONES := "user://opciones.cfg"

@onready var panel_menu: Control = $PanelMenu
@onready var panel_opciones: Control = $PanelOpciones
@onready var boton_jugar: Button = $PanelMenu/VBoxMenu/BotonJugar
@onready var boton_opciones: Button = $PanelMenu/VBoxMenu/BotonOpciones
@onready var boton_salir: Button = $PanelMenu/VBoxMenu/BotonSalir
@onready var slider_volumen: HSlider = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/FilaVolumen/SliderVolumen
@onready var check_pantalla_completa: CheckButton = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/CheckPantallaCompleta
@onready var boton_volver: Button = $PanelOpciones/PanelContainer/MarginContainer/VBoxOpciones/BotonVolver


func _ready() -> void:
	boton_jugar.pressed.connect(_al_jugar)
	boton_opciones.pressed.connect(_abrir_opciones)
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

	# El foco da la vuelta: bajar desde el último botón vuelve al primero y viceversa
	var ultimo: Button = boton_salir if boton_salir.visible else boton_opciones
	boton_jugar.focus_neighbor_top = boton_jugar.get_path_to(ultimo)
	ultimo.focus_neighbor_bottom = ultimo.get_path_to(boton_jugar)

	_cargar_opciones()
	_mostrar_menu(boton_jugar)


func _unhandled_input(event: InputEvent) -> void:
	# Esc / botón B dentro de Opciones = volver
	if panel_opciones.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cerrar_opciones()


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


func _al_jugar() -> void:
	CodigoGlobal.cambiar_escena(escena_juego)

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
