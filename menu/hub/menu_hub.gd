extends CanvasLayer
class_name MenuHub
## Menú con pestañas (estilo Moonlighter). Lo abre MenuManager con
## open_menu("hub", <ruta>, true, {"estadisticas": est, "pestana": &"inventario", "partir": false}).
## Q/E (acciones tomo_pestana_*) cambian de pestaña, Esc cierra. Cada pestaña es una página
## (PaginaMenu) que se instancia al entrar y se libera al salir.

## Registro de pestañas, en orden. Se asignan en el Inspector.
@export var paginas: Array[PaginaHubData] = []

@export_group("Animación")
@export var segundos_deslizamiento: float = 0.2
@export var distancia_deslizamiento: float = 80.0

@onready var fila_pestanas: Container = %Pestanas
@onready var contenedor: Control = %ContenedorPagina

var datos_base: Dictionary = {}

var _visibles: Array[PaginaHubData] = []
var _botones: Array[Button] = []
var _indice: int = -1
var _pagina: PaginaMenu
var _tween: Tween
var _frame_apertura: int = -1


func _ready() -> void:
	layer = 100
	_frame_apertura = Engine.get_process_frames()


## Lo llama MenuManager apenas se abre
func configurar(datos: Dictionary) -> void:
	datos_base = datos
	_construir_pestanas()
	var inicial := 0
	for i in _visibles.size():
		if _visibles[i].id == datos.get("pestana", &""):
			inicial = i
	_mostrar_pestana(inicial)


## Cierra el hub; el resultado le llega a quien lo abrió (Player)
func cerrar(resultado: Dictionary = {"accion": "cancelar"}) -> void:
	MenuManager.close_current_menu(resultado)


# ==============================================================================
# CONTROLES
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _frame_apertura:
		return
	# La página tiene prioridad (flechas, Z/X, A...)
	if is_instance_valid(_pagina) and _pagina.manejar_input(event):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tomo_pestana_anterior"):
		_mostrar_pestana(_indice - 1, -1)
	elif event.is_action_pressed("tomo_pestana_siguiente"):
		_mostrar_pestana(_indice + 1, 1)
	elif event.is_action_pressed("ui_cancel"):
		cerrar()
	elif not _atajo(event):
		return
	get_viewport().set_input_as_handled()


## El atajo de una pestaña la abre; si ya estás en ella, cierra el hub
func _atajo(event: InputEvent) -> bool:
	for i in _visibles.size():
		var accion := _visibles[i].accion_atajo
		if accion == &"" or not InputMap.has_action(accion):
			continue
		if event.is_action_pressed(accion):
			if i == _indice:
				cerrar()
			else:
				_mostrar_pestana(i, signi(i - _indice))
			return true
	return false


# ==============================================================================
# PESTAÑAS
# ==============================================================================

func _construir_pestanas() -> void:
	for hijo in fila_pestanas.get_children():
		fila_pestanas.remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	_visibles.clear()

	for datos in paginas:
		if datos == null or datos.escena == null:
			continue
		if (CodigoGlobal.en_run and not datos.en_run) or (not CodigoGlobal.en_run and not datos.en_base):
			continue
		_visibles.append(datos)

	for i in _visibles.size():
		var boton := Button.new()
		boton.text = _visibles[i].titulo
		boton.focus_mode = Control.FOCUS_NONE   # el foco queda siempre en la página
		boton.toggle_mode = true
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.pressed.connect(_mostrar_pestana.bind(i))
		fila_pestanas.add_child(boton)
		_botones.append(boton)


## direccion: -1 / 1 = la página entra deslizándose desde ese lado; 0 = sin animación
func _mostrar_pestana(indice: int, direccion: int = 0) -> void:
	if _visibles.is_empty():
		return
	var nuevo := wrapi(indice, 0, _visibles.size())
	if nuevo == _indice and is_instance_valid(_pagina):
		_botones[_indice].set_pressed_no_signal(true)
		return
	_indice = nuevo
	for i in _botones.size():
		_botones[i].set_pressed_no_signal(i == _indice)

	if is_instance_valid(_pagina):
		contenedor.remove_child(_pagina)
		_pagina.queue_free()

	_pagina = _visibles[_indice].escena.instantiate() as PaginaMenu
	_pagina.hub = self
	contenedor.add_child(_pagina)
	_pagina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pagina.configurar(datos_base)

	if direccion != 0:
		_animar_cambio(direccion)


func _animar_cambio(direccion: int) -> void:
	if _tween:
		_tween.kill()
	_pagina.offset_left = distancia_deslizamiento * direccion
	_pagina.offset_right = distancia_deslizamiento * direccion
	_pagina.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pagina, "offset_left", 0.0, segundos_deslizamiento)
	_tween.tween_property(_pagina, "offset_right", 0.0, segundos_deslizamiento)
	_tween.tween_property(_pagina, "modulate:a", 1.0, segundos_deslizamiento)
