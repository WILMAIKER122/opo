extends Area3D
@onready var estados: StateMachine = $"../estados"
@export var camara:PhantomCamera3D
const TEMBLOR_HACER_DAÑO = preload("uid://dlhtjgeccwn53")
@onready var collision: CollisionShape3D = $CollisionShape3D
@export var esta:CharacterBody3D
var enemigos_detectados:int = 0
@export var duracion_veneno: float = 3.0
func activar_desactivar_area(activo: bool) -> void:
	collision.disabled = not activo



func _on_body_entered(body: Node3D) -> void:
	if body.has_meta("puerta_escindida"):
		(body.get_meta("puerta_escindida") as PuertaSala).golpear(esta)
		return
	if not (body is Enemigo):
		return

	var efectos := {"danio": 1.0, "empuje": 5.0, "stun": 0.5, "hitstop": 0.05,
			"temblor": 0.1, "etiqueta": "", "color": Color.WHITE}
	var ataque = estados.get_node_or_null("ataque")
	if ataque and estados.current_state == ataque:
		efectos = ataque.efectos_golpe()
		ataque.apply_recoil()
		hacer_temblor(efectos["temblor"])

	var pos_etiqueta: Vector3 = body.global_position + Vector3(0.0, 2.1, 0.0)
	var danio: float = esta.estadisticas.dano * efectos["danio"]

	CodigoGlobal.hitstop(efectos["hitstop"])
	if body.has_method("recibir_danio"):
		body.recibir_danio(danio, global_position, efectos["empuje"], efectos["stun"])
		if body.vida_actual <= 0.0:
			CodigoGlobal.hitstop(0.12)

	_aplicar_efectos_de_comida(body as Enemigo, danio)

	if efectos["etiqueta"] != "":
		EfectosCombate.numero_flotante(get_tree().current_scene, pos_etiqueta,
				efectos["etiqueta"], efectos["color"], 0.8)


## Sinergias activas (veneno, robo de vida) y sabores activos (tags imbuidos)
func _aplicar_efectos_de_comida(enemigo: Enemigo, danio: float) -> void:
	var est = esta.estadisticas
	var robo: float = est.sinergias.valor_efecto(SinergiaSabor.EfectoEspecial.ROBO_DE_VIDA)
	if robo > 0.0:
		est.curar_robo(danio * robo / 100.0)

	if enemigo.vida_actual <= 0.0:
		return

	var veneno: float = est.sinergias.valor_efecto(SinergiaSabor.EfectoEspecial.VENENO_ON_HIT)
	if veneno > 0.0:
		enemigo.aplicar_estado(&"veneno_sinergia", veneno, duracion_veneno, 0.0, Color(0.5, 1.0, 0.4))

	for tag in est.sabores_activos:
		var fx = SaboresCombate.EFECTOS.get(tag)
		if fx:
			enemigo.aplicar_estado(fx["id"], fx["dps"], fx["segundos"], fx["lentitud"], fx["color"])
			
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
			
			
			
			
