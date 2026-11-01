extends Node3D
class_name Sala

enum Tipo { COMBATE, CAMPAMENTO, JEFE }


@export var tipo: Tipo = Tipo.COMBATE
## Una puerta por cada salida posible (se abren al limpiar la sala)
@export var puertas: Array[PuertaSala] = []
## Campamento: cura al entrar
@export var curacion_al_entrar: float = 30.0
@export var piezas_de_recompensa: int = 3

var _abierta: bool = false
## Distancia desde el centro de la sala (X, Z) a la que aparece el jugador al entrar
@export var distancia_aparicion: Vector2 = Vector2(8.0, 8.0)

func _ready() -> void:
	for puerta in puertas:
		puerta.cerrar()
	var jugador := _jugador()
	if jugador:
		_colocar_jugador(jugador)
		if tipo == Tipo.CAMPAMENTO:
			jugador.estadisticas.curar_robo(curacion_al_entrar)
	if tipo == Tipo.CAMPAMENTO:
		_abrir()

func _jugador() -> Player:
	for nodo in find_children("*", "", true, false):
		if nodo is Player:
			return nodo
	return null
	
func _process(_delta: float) -> void:
	if _abierta:
		return
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if is_instance_valid(enemigo) and not enemigo.is_queued_for_deletion():
			return
	_abrir()


func _abrir() -> void:
	_abierta = true
	var opciones = GeneradorPuertas.opciones(CodigoGlobal.sala_numero, CodigoGlobal.tipo_sala_actual, puertas.size())
	var slots := puertas.duplicate()
	slots.shuffle()
	for i in mini(opciones.size(), slots.size()):
		slots[i].abrir(opciones[i])
	_soltar_recompensa()

## El ingrediente anunciado en la puerta por la que se entró
func _soltar_recompensa() -> void:
	var tag := CodigoGlobal.tag_recompensa
	if tipo != Tipo.COMBATE or tag < 0:
		return
	CodigoGlobal.tag_recompensa = -1
	var botin := load("res://enemi/escenas/partes_enemigo.tscn") as PackedScene
	var nivel := CodigoGlobal.nivel_sala
	for i in piezas_de_recompensa + nivel:
		var item =GeneradorPuertas.item_con_tag(tag, nivel - 1)
		if item == null:
			return
		var pieza = botin.instantiate()
		pieza.configurar(item)
		add_child(pieza)
		pieza.global_position = global_position + Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0))
## Sale por una pared y aparece en la pared opuesta de la sala nueva
func _colocar_jugador(jugador: Player) -> void:
	var dir := CodigoGlobal.direccion_entrada
	CodigoGlobal.direccion_entrada = Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	var y := jugador.global_position.y
	jugador.global_position = Vector3(
		global_position.x - dir.x * distancia_aparicion.x,
		y,
		global_position.z - dir.z * distancia_aparicion.y)
	# Que la cámara no "viaje" desde el punto anterior
	var cam := jugador.get_node_or_null("camara_pj")
	if cam and cam.has_method("teleport_position"):
		cam.call_deferred("teleport_position")
