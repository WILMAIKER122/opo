class_name OrientacionEnemigo
extends RefCounted
## Orientación izquierda/derecha del enemigo: gira la malla (scale.x) y espeja las áreas de golpe.
## NUNCA escales el CharacterBody3D ni sus áreas (Jolt no soporta escala no uniforme en formas físicas).
## Destino: res://enemi/codigo/orientacion_enemigo.gd

var mirando_derecha: bool = true

var _visual: Node3D
var _invertir_lado: bool
var _velocidad_giro: float
var _areas: Array[Node3D] = []
var _pos_base_x: Dictionary = {}   # área -> position.x mirando a la derecha
var _escala_base_x: float = 1.0
var _escala_objetivo_x: float = 1.0


func _init(visual: Node3D, areas: Array[Node3D], invertir_lado: bool, velocidad_giro: float) -> void:
	_visual = visual
	_invertir_lado = invertir_lado
	_velocidad_giro = velocidad_giro
	if _visual:
		_escala_base_x = absf(_visual.scale.x)
		_escala_objetivo_x = _visual.scale.x
	# Posición X de cada área tal como quedó en el editor (mirando a la derecha)
	for area in areas:
		if area:
			_areas.append(area)
			_pos_base_x[area] = area.position.x


## Define hacia qué lado mira según el signo de direccion_x (eje X del mundo).
## Si el valor es casi 0 mantiene el lado actual.
func mirar_hacia(direccion_x: float) -> void:
	if absf(direccion_x) < 0.05:
		return
	var lado_anterior := mirando_derecha
	mirando_derecha = direccion_x > 0.0
	if _invertir_lado:
		mirando_derecha = not mirando_derecha
	if mirando_derecha != lado_anterior:
		_aplicar_lado_a_areas()
	_escala_objetivo_x = _escala_base_x if mirando_derecha else -_escala_base_x


## Gira suave la malla hacia el lado objetivo (llamar cada frame desde _process)
func actualizar_giro(delta: float) -> void:
	if _visual == null:
		return
	var nueva := move_toward(_visual.scale.x, _escala_objetivo_x, _velocidad_giro * delta)
	# Evita quedar en escala 0 exacta
	if absf(nueva) < 0.02:
		nueva = 0.02 * signf(_escala_objetivo_x)
	_visual.scale.x = nueva


## Mueve un área a la posición X dada (mirando a la derecha); el espejado posterior la respeta
func fijar_x(area: Node3D, x: float) -> void:
	if area == null:
		return
	_pos_base_x[area] = x
	area.position.x = x * (1.0 if mirando_derecha else -1.0)


func _aplicar_lado_a_areas() -> void:
	var signo := 1.0 if mirando_derecha else -1.0
	for area in _areas:
		if area and _pos_base_x.has(area):
			area.position.x = _pos_base_x[area] * signo
