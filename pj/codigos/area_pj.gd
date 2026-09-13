extends Area3D
@onready var estados: StateMachine = $"../estados"
@export var camara:PhantomCamera3D
const TEMBLOR_HACER_DAÑO = preload("uid://dlhtjgeccwn53")
@onready var collision: CollisionShape3D = $CollisionShape3D

var enemigos_detectados:int = 0
func activar_desactivar_area(valor:bool):
	collision.disabled = valor



func _on_body_entered(body: Node3D) -> void:
	if body is Enemigo:
		var attack_state = estados.get_node_or_null("ataque")
		if attack_state and estados.current_state == attack_state:
			hacer_temblor(0.1)
			attack_state.apply_recoil()			
		if body.has_method("recibir_danio"):
			body.recibir_danio(25, global_position, 15.0, 0.5)
func hacer_temblor(duracion: float):
	if not camara:
		return
	
	# 1. Cargamos el recurso de ruido desde la carpeta
	var noise_resource = TEMBLOR_HACER_DAÑO
	if noise_resource:
		# 2. Se lo asignamos a la propiedad de ruido de la Phantom Camera
		camara.noise = noise_resource
		
		# 3. Esperamos el tiempo que dura el golpe/efecto
		await get_tree().create_timer(duracion).timeout
		
		# 4. Al terminar el tiempo, dejamos la propiedad vacía (null)
		camara.noise = null


func _on_area_camara_com_body_entered(body: Node3D) -> void:
	if body is Enemigo:
		enemigos_detectados += 1
		camara.priority = 2
		camara.follow_targets.append(body)


func _on_area_camara_com_body_exited(body: Node3D) -> void:
	if body is Enemigo:
		enemigos_detectados -= 1
		if enemigos_detectados ==0:		
			camara.priority = 0
			
			
			
			
