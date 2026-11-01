extends Node
## Gestor central de menús/popups. Se registra como AUTOLOAD con el nombre "MenuManager":
## Proyecto > Configuración del proyecto > Autoload > ruta de este archivo, nombre MenuManager.
##
## - Solo hay un menú abierto a la vez.
## - Los menús se abren con el juego en pausa (opcional) y FUNCIONAN en pausa: se les pone
##   process_mode = ALWAYS, así que cada menú maneja sus propios controles.
## - Si un menú tiene un método configurar(datos: Dictionary), se llama apenas se abre.
## - Un menú se cierra llamando MenuManager.close_current_menu(resultado). Ese resultado le
##   llega a quien lo abrió por la señal menu_closed.
## - Si la escena cambia con un menú abierto, se cierra solo y se quita la pausa.

signal menu_opened(menu_name: String)
## Se intentó abrir un menú que no se puede abrir en combate (para mostrar un aviso en el HUD)
signal menu_bloqueado(menu_name: String)
## resultado: lo que mandó el menú al cerrarse, ej. {"accion": "confirmar", "seleccion": {...}}
signal menu_closed(menu_name: String, resultado: Dictionary)

var current_menu: Node = null
var current_menu_name: String = ""

## En la run, con enemigos vivos en la sala, SOLO se pueden abrir estos menús
## (en minúsculas). Todo lo demás (tomo, inventario, cocina...) queda bloqueado.
var menus_permitidos_en_combate: Array[String] = ["pausa"]

# Solo se quita la pausa si FUE ESTE gestor quien la puso
var _pauso_el_juego: bool = false
var _id_escena_origen: int = 0

const RUTA_PAUSA := "res://menu/menu_opciones.tscn"
## Escenas donde Esc NO abre la pausa
const ESCENAS_SIN_PAUSA: Array[String] = ["res://menu/menu_principal.tscn"]

var _envoltorio: CanvasLayer = null


func _ready() -> void:
	# El gestor tiene que seguir funcionando con el juego en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if current_menu == null:
		return
	# Si la escena cambió con el menú abierto (Enter, muerte, etc.), se cierra solo
	var escena := get_tree().current_scene
	if escena == null or escena.get_instance_id() != _id_escena_origen:
		close_current_menu({"accion": "cancelar"})


## Abre un menú. Retorna true si se abrió con éxito, false si ya había uno abierto o falló.
## datos: se le pasan al menú mediante su método configurar(datos), si lo tiene.
func open_menu(menu_name: String, menu_scene_path: String, pause_game: bool = true, datos: Dictionary = {}) -> bool:
	_limpiar_si_obsoleto()
	if current_menu != null:
		print("MenuManager: Ya hay un menú abierto ('%s')." % current_menu_name)
		return false

	if en_combate() and not menus_permitidos_en_combate.has(menu_name.to_lower()):
		print("MenuManager: '%s' está bloqueado mientras hay enemigos en la sala." % menu_name)
		menu_bloqueado.emit(menu_name)
		return false

	if not ResourceLoader.exists(menu_scene_path):
		push_warning("MenuManager: no existe la escena: %s" % menu_scene_path)
		return false

	var scene_resource := load(menu_scene_path) as PackedScene
	if scene_resource == null:
		push_warning("MenuManager: no se pudo cargar la escena: %s" % menu_scene_path)
		return false

	var menu_instance := scene_resource.instantiate()
	if menu_instance == null:
		push_warning("MenuManager: no se pudo instanciar el menú: %s" % menu_name)
		return false

	# Los menús tienen que responder aunque el juego esté en pausa
	menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS

	current_menu = menu_instance
	current_menu_name = menu_name
	var escena := get_tree().current_scene
	_id_escena_origen = escena.get_instance_id() if escena else 0

	var a_agregar: Node = menu_instance
	_envoltorio = null
	if menu_instance is Control:
		# Los Control sueltos se dibujan debajo de los CanvasLayer (HUD): se envuelve en uno alto
		_envoltorio = CanvasLayer.new()
		_envoltorio.layer = 100
		_envoltorio.process_mode = Node.PROCESS_MODE_ALWAYS
		_envoltorio.add_child(menu_instance)
		a_agregar = _envoltorio
	get_tree().root.add_child(a_agregar)

	if menu_instance.has_method("configurar"):
		menu_instance.configurar(datos)

	if pause_game and not get_tree().paused:
		get_tree().paused = true
		_pauso_el_juego = true

	menu_opened.emit(menu_name)
	print("MenuManager: Menú abierto -> ", menu_name)
	return true


## Devuelve el nodo del menú actual para poder interactuar con él
func get_current_menu() -> Node:
	return current_menu


## Cierra el menú actual. El resultado se manda por la señal menu_closed.
func close_current_menu(resultado: Dictionary = {}) -> void:
	if current_menu == null:
		return

	var closed_name := current_menu_name
	if is_instance_valid(_envoltorio):
		_envoltorio.queue_free()   # libera también al menú
	elif is_instance_valid(current_menu):
		current_menu.queue_free()
	_envoltorio = null
	current_menu = null
	current_menu_name = ""

	# Primero se quita la pausa y DESPUÉS se avisa: así quien reaccione (ej. cambiar de
	# escena o seguir comiendo) ya encuentra el juego andando.
	if _pauso_el_juego:
		get_tree().paused = false
		_pauso_el_juego = false

	menu_closed.emit(closed_name, resultado)
	print("MenuManager: Menú cerrado -> ", closed_name)


## true si estás en la run y queda al menos un enemigo vivo en la sala.
## Los enemigos tienen que estar en el grupo "enemigos" (add_to_group en su _ready).
func en_combate() -> bool:
	if not CodigoGlobal.en_run:
		return false
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if is_instance_valid(enemigo) and not enemigo.is_queued_for_deletion():
			return true
	return false


func is_menu_open() -> bool:
	_limpiar_si_obsoleto()
	return current_menu != null


## Red de seguridad: si un menú se ocultó o se liberó SIN pasar por close_current_menu(),
## el gestor quedaría "ocupado" para siempre y no dejaría abrir ningún otro. Acá se detecta
## ese caso y se limpia (quitando también la pausa si la había puesto el gestor).
func _limpiar_si_obsoleto() -> void:
	if current_menu == null:
		return
	var obsoleto := not is_instance_valid(current_menu) or not current_menu.is_inside_tree()
	if not obsoleto and current_menu is CanvasItem and not (current_menu as CanvasItem).visible:
		obsoleto = true # un menú oculto ya no está abierto
	if obsoleto:
		push_warning("MenuManager: el menú '%s' quedó oculto/liberado sin cerrarse bien; se limpia." % current_menu_name)
		close_current_menu({"accion": "cancelar"})

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_menu_open():
		return # cada menú abierto maneja su propio Esc
	var escena := get_tree().current_scene
	if escena == null or ESCENAS_SIN_PAUSA.has(escena.scene_file_path):
		return
	if open_menu("pausa", RUTA_PAUSA, true):
		get_viewport().set_input_as_handled()
