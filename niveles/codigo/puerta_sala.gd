extends Area3D
class_name PuertaSala

@export var vida_escindida: int = 4
@export var enemigos_al_romper: int = 2
@export var escena_enemigo: PackedScene = preload("res://enemi/enemigo_normal.tscn")

var _opcion: Dictionary = {}
var _abierta: bool = false
var _roto: bool = false
var _vida: int = 0
var _cuerpo: StaticBody3D
var _jugador: Player
var _etiqueta: Label3D
var _icono: Sprite3D

func _ready() -> void:
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_etiqueta = Label3D.new()
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.no_depth_test = true
	_etiqueta.position = Vector3(0.0, 2.2, 0.0)
	add_child(_etiqueta)
	_icono = Sprite3D.new()
	_icono.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icono.no_depth_test = true
	_icono.position = Vector3(0.0, 3.2, 0.0)
	_icono.visible = false
	add_child(_icono)

func cerrar() -> void:
	_abierta = false
	visible = false
	_quitar_cuerpo()
	set_deferred("monitoring", false)


func abrir(opcion: Dictionary) -> void:
	_opcion = opcion
	_abierta = true
	_roto = false
	_vida = vida_escindida
	_actualizar_vista()
	visible = true
	set_deferred("monitoring", true)
	if opcion.get("puerta", "gratis") == "escindida":
		_crear_cuerpo()


func _unhandled_input(event: InputEvent) -> void:
	if not _abierta or _opcion.get("puerta", "") != "pago":
		return
	if not is_instance_valid(_jugador) or MenuManager.is_menu_open():
		return
	if event.is_action_pressed(&"interactuar"):
		get_viewport().set_input_as_handled()
		if not GeneradorPuertas.pagar(_opcion["costo"], _jugador.estadisticas).is_empty():
			_pasar()	
		else:
			_etiqueta.modulate = Color(1.0, 0.35, 0.35)
			create_tween().tween_property(_etiqueta, "modulate", Color.WHITE, 0.5)


func _physics_process(_delta: float) -> void:
	# Escindida ya rota: pasa si el jugador está dentro del área
	if _abierta and _roto and is_instance_valid(_jugador) and overlaps_body(_jugador):
		_pasar()


func _al_entrar(body: Node3D) -> void:
	if not _abierta or not (body is Player):
		return
	_jugador = body
	_actualizar_vista()
	if _opcion.get("puerta", "gratis") == "gratis":
		_pasar()


func _al_salir(body: Node3D) -> void:
	if body == _jugador:
		_jugador = null


func _pasar() -> void:
	if not _abierta or not is_instance_valid(_jugador):
		return
	_abierta = false
	_opcion["dir_salida"] = _direccion_salida()
	CodigoGlobal.call_deferred("siguiente_sala", _opcion, _jugador.estadisticas)


## Lado de la sala donde está esta puerta, ajustado a un eje (N/S/E/O)
func _direccion_salida() -> Vector3:
	var centro := (get_parent() as Node3D).global_position
	var d := global_position - centro
	if absf(d.x) > absf(d.z):
		return Vector3(signf(d.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(d.z))


# ------------------------------------------------------------ ESCINDIDA

func _crear_cuerpo() -> void:
	_cuerpo = StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2.0, 2.0, 1.0)
	forma.shape = caja
	_cuerpo.add_child(forma)
	_cuerpo.set_meta("puerta_escindida", self)
	add_child(_cuerpo)


func _quitar_cuerpo() -> void:
	if is_instance_valid(_cuerpo):
		_cuerpo.queue_free()
	_cuerpo = null


## Lo llama area_pj.gd cuando el ataque del jugador toca el cuerpo de la puerta
func golpear(atacante: Node3D) -> void:
	if not _abierta or _roto:
		return
	_vida -= 1
	_etiqueta.text = "%s\n%d" % [_texto(_opcion), maxi(_vida, 0)]
	if _vida > 0:
		return
	_roto = true
	_quitar_cuerpo()
	_etiqueta.text = _texto(_opcion)
	for i in enemigos_al_romper + int(_opcion.get("nivel", 0)):
		var e := escena_enemigo.instantiate() as Enemigo
		e.jugador = atacante as CharacterBody3D
		get_parent().add_child(e)
		e.global_position = global_position + Vector3(randf_range(-2.0, 2.0), 1.0, randf_range(-2.0, 2.0))


func _texto(opcion: Dictionary) -> String:
	if opcion.get("salida", false):
		return "Volver a la base"
	match opcion["tipo"]:
		Sala.Tipo.CAMPAMENTO:
			return "Campamento"
		Sala.Tipo.JEFE:
			return "Jefe"
	var tag: int = opcion["tag"]
	var nombre := String(ItemData.TagComida.keys()[tag]).capitalize() if tag >= 0 else "Combate"
	match opcion.get("puerta", "gratis"):
		"pago":
			return "%s  Nv.%d\n[E] %s" % [nombre, opcion["nivel"], GeneradorPuertas.texto_costo(opcion["costo"])]
		"escindida":
			return "%s  Nv.%d\nRomper (¡enemigos!)" % [nombre, opcion["nivel"]]
	return nombre

func _actualizar_vista() -> void:
	_icono.visible = false
	_etiqueta.text = _texto(_opcion)
	if _opcion.get("puerta", "") != "pago":
		return
	var est := _est()
	var item: ItemData = GeneradorPuertas.vista_previa(_opcion["costo"], est) if est else null
	if item and item.icono:
		_icono.texture = item.icono
		_icono.pixel_size = 0.9 / maxf(item.icono.get_width(), item.icono.get_height())
		_icono.visible = true


func _est() -> estadisticas_player:
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if n is Player:
			return (n as Player).estadisticas
	return null
