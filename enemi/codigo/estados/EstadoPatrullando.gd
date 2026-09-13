extends EstadoEnemigo
class_name EstadoPatrullando

var direccion_patrulla: Vector3 = Vector3.ZERO

func entrar() -> void:
	generar_nueva_direccion()
	
	# Usamos la referencia del Timer desde el propio enemigo
	if enemigo and enemigo.timer_patrulla:
		if not enemigo.timer_patrulla.timeout.is_connected(_on_timer_timeout):
			enemigo.timer_patrulla.timeout.connect(_on_timer_timeout)
		
		# Verificamos que el Timer esté dentro del árbol de la escena antes de iniciar
		if enemigo.timer_patrulla.is_inside_tree():
			enemigo.timer_patrulla.start(randf_range(2.0, 4.0))


func salir() -> void:
	if enemigo and enemigo.timer_patrulla:
		enemigo.timer_patrulla.stop()
		if enemigo.timer_patrulla.timeout.is_connected(_on_timer_timeout):
			enemigo.timer_patrulla.timeout.disconnect(_on_timer_timeout)


func actualizar_fisicas(_delta: float) -> void:
	enemigo.velocity.x = direccion_patrulla.x * enemigo.stats.velocidad_patrulla
	enemigo.velocity.z = direccion_patrulla.z * enemigo.stats.velocidad_patrulla
	
	if direccion_patrulla != Vector3.ZERO:
		enemigo.look_at(enemigo.global_position + direccion_patrulla, Vector3.UP)


func generar_nueva_direccion() -> void:
	var angulo = randf_range(0, TAU)
	direccion_patrulla = Vector3(cos(angulo), 0, sin(angulo)).normalized()


func _on_timer_timeout() -> void:
	if randf() > 0.5:
		generar_nueva_direccion()
	else:
		direccion_patrulla = Vector3.ZERO
