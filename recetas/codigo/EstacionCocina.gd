extends Area3D
class_name EstacionCocina
## Estación de cocina de la base. Es un Area3D (con su CollisionShape3D) que se pone
## cerca de la olla. Cuando el jugador está dentro aparece un aviso y, al apretar
## la acción "interactuar", el jugador pasa al estado Cocinar.
##
## Hace falta crear la acción "interactuar" en Proyecto > Configuración > Mapa de entrada.

@export var accion_interactuar: StringName = &"interactuar"
@export var texto_aviso: String = "Cocinar"
@export var altura_aviso: float = 1.8

var _jugador: Player = null
var _aviso: Label3D


func _ready() -> void:
	# Se conectan por código solo si no están ya conectadas desde el panel Nodo del editor
	if not body_entered.is_connected(_al_entrar):
		body_entered.connect(_al_entrar)
	if not body_exited.is_connected(_al_salir):
		body_exited.connect(_al_salir)

	_aviso = Label3D.new()
	_aviso.text = "[%s] %s" % [_nombre_tecla(), texto_aviso]
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.position = Vector3(0.0, altura_aviso, 0.0)
	_aviso.visible = false
	add_child(_aviso)

	if not InputMap.has_action(accion_interactuar):
		push_warning("EstacionCocina: no existe la acción '%s' en el Mapa de entrada." % accion_interactuar)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	# Sin jugador dentro del área (o con otro menú abierto) no hace nada
	if not is_instance_valid(_jugador) or MenuManager.is_menu_open():
		return
	if event.is_action_pressed(accion_interactuar):
		get_viewport().set_input_as_handled()
		_jugador.state_machine.transition_to("cocinar")


func _al_entrar(body: Node3D) -> void:
	if body is Player:
		_jugador = body as Player
		_aviso.visible = true


func _al_salir(body: Node3D) -> void:
	if body == _jugador:
		_jugador = null
		_aviso.visible = false


func _nombre_tecla() -> String:
	if InputMap.has_action(accion_interactuar):
		for evento in InputMap.action_get_events(accion_interactuar):
			return evento.as_text().replace(" (Physical)", "")
	return "?"
