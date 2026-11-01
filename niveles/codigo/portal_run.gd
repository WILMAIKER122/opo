extends Area3D
class_name PortalRun
## Salida de la base. Dentro del área, E (interactuar) parte a la run.

@export var texto_aviso: String = "Partir"

var _jugador: Player
var _aviso: Label3D


func _ready() -> void:
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_aviso = Label3D.new()
	_aviso.text = "[E] %s" % texto_aviso
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.position = Vector3(0.0, 1.8, 0.0)
	_aviso.visible = false
	add_child(_aviso)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_jugador) or MenuManager.is_menu_open():
		return
	if event.is_action_pressed(&"interactuar"):
		get_viewport().set_input_as_handled()
		_jugador._partir_a_la_run()


func _al_entrar(body: Node3D) -> void:
	if body is Player:
		_jugador = body
		_aviso.visible = true


func _al_salir(body: Node3D) -> void:
	if body == _jugador:
		_jugador = null
		_aviso.visible = false
