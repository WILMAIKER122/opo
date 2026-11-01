extends Node3D
class_name ZetaSuelta
## Zeta suelta tras un dash. Según datos_zeta.comportamiento_suelta:
##  CAE: cae al piso; a los segundos_retorno vuela de vuelta al jugador (pisarla antes la recoge).
##  BOOMERANG: sale disparada en la dirección del dash, daña lo que toca y vuelve.
## Un esquive perfecto la hace volver al instante (grupo "zeta_suelta" > volver_ya()).

@export var datos_zeta: Zeta_datos

@onready var pj_zeta: MeshInstance3D = $Armature/Skeleton3D/pj_zeta

## Los pone Player antes de agregarla a la escena
var jugador: Player
var direccion: Vector3 = Vector3.ZERO

enum Fase { ESPERANDO, LANZADA, VOLVIENDO }
var _fase: Fase = Fase.ESPERANDO
var _tiempo: float = 0.0
var _recogible: bool = false
var _multiplicador_velocidad: float = 1.0
var _golpeados: Array = []
var _recogida: bool = false


func _ready() -> void:
	add_to_group("zeta_suelta")
	cambiar_textura_mesh()

	if datos_zeta and datos_zeta.comportamiento_suelta == Zeta_datos.ComportamientoSuelta.BOOMERANG:
		_fase = Fase.LANZADA
	else:
		$AnimationPlayer.play("caida")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jugador):
		return
	_tiempo += delta

	match _fase:
		Fase.LANZADA:
			rotation.y += 14.0 * delta
			global_position += direccion * datos_zeta.velocidad_ida * delta
			if _tiempo >= datos_zeta.segundos_ida:
				_empezar_a_volver()

		Fase.ESPERANDO:
			if datos_zeta.segundos_retorno > 0.0 and _tiempo >= datos_zeta.segundos_retorno:
				_empezar_a_volver()

		Fase.VOLVIENDO:
			rotation.y += 8.0 * delta
			var destino := jugador.global_position + Vector3(0.0, -0.5, 0.0)
			global_position = global_position.move_toward(
				destino, datos_zeta.velocidad_retorno * _multiplicador_velocidad * delta)
			var plano := Vector2(destino.x - global_position.x, destino.z - global_position.z)
			if plano.length() < 0.7:
				_recoger()


## Esquive perfecto: vuelve ya, al doble de velocidad
func volver_ya() -> void:
	_multiplicador_velocidad = 2.0
	_empezar_a_volver()


func _empezar_a_volver() -> void:
	_fase = Fase.VOLVIENDO
	_recogible = true


func _recoger() -> void:
	if _recogida:
		return
	_recogida = true
	if is_instance_valid(jugador):
		jugador.recoger_zeta()
	queue_free()


func _dano() -> float:
	return jugador.estadisticas.dano * datos_zeta.multiplicador_dano_suelta


# ==============================================================================
# SEÑALES (ya conectadas desde zeta.tscn)
# ==============================================================================

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		if _recogible and _fase != Fase.LANZADA:
			_recoger()
	elif body is Enemigo and _fase == Fase.LANZADA and not _golpeados.has(body):
		_golpeados.append(body)
		body.recibir_danio(_dano(), global_position, 6.0, 0.3)


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	_recogible = true


func cambiar_textura_mesh() -> void:
	if datos_zeta == null:
		return
	var mat := pj_zeta.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		pj_zeta.material_override = mat
	mat.albedo_texture = datos_zeta.textura
