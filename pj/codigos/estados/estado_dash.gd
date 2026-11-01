extends State

@export var dash_cooldown: float = 0.5   # Segundos de espera tras terminar un dash
@export var personaje: Player
@export var rotation_speed: float = 15.0

var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var target_scale_x: float = 1.0

## true solo si el dash se ejecutó de verdad (no si estaba en cooldown)
var _dasheando: bool = false
## Z durante el dash: el golpe sale apenas termina
var _ataque_en_cola: bool = false


func _puede_dashear() -> bool:
	if character.estadisticas.sinergias.tiene_efecto(SinergiaSabor.EfectoEspecial.DASH_BLOQUEADO):
		return false
	return Time.get_ticks_msec() >= character.estadisticas.tiempo_dash_disponible


func enter() -> void:
	if not _puede_dashear():
		# En cooldown: no hace nada, vuelve al estado apropiado sin ejecutar el dash
		_dasheando = false
		var input_dir_cd := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir_cd != Vector2.ZERO:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
		return

	# A partir de acá el dash SÍ se ejecuta
	_dasheando = true
	_ataque_en_cola = false
	character.dash_sin_cooldown = false

	if not character.estadisticas.sinergias.tiene_efecto(SinergiaSabor.EfectoEspecial.DASH_GRATIS):
		character.estadisticas.hambre.gastar(character.estadisticas.hambre.costo_dash)	
		character.playback.travel("dash")
	dash_timer = character.estadisticas.dash_duraccion

	# 1) Dirección del dash
	var dir_x: float = 0.0
	var dir_z: float = 0.0
	if Input.is_action_pressed("ui_right"): dir_x += 1.0
	if Input.is_action_pressed("ui_up"):    dir_z -= 1.0
	if Input.is_action_pressed("ui_left"):  dir_x -= 1.0
	if Input.is_action_pressed("ui_down"):  dir_z += 1.0

	var dash_vector := Vector3(dir_x, 0.0, dir_z)
	if dash_vector != Vector3.ZERO:
		dash_direction = dash_vector.normalized()
	else:
		dash_direction = character.last_movement_direction.normalized()

	if dash_direction.x != 0:
		target_scale_x = 1.0 if dash_direction.x > 0 else -1.0

	# 2) Según la Zeta actual: se suelta, se lanza (boomerang) o se queda puesta (dash más corto)
	var zeta = character.estadisticas.zeta_actual
	if zeta and character.estadisticas.con_zeta \
			and zeta.comportamiento_suelta == Zeta_datos.ComportamientoSuelta.FIJA:
		dash_timer *= zeta.multiplicador_dash_fija
	personaje.soltar_zeta(dash_direction)


func exit() -> void:
	# Anota cuándo terminó: el ataque que arranca justo después lo detecta como "ataque veloz"
	if _dasheando:
		character.ultimo_dash_fin_ms = Time.get_ticks_msec()
	_dasheando = false


func handle_input(event: InputEvent) -> void:
	# El ataque ya no cancela el dash: se guarda y sale apenas termina
	if event.is_action_pressed("z"):
		_ataque_en_cola = true


func update_physics(delta: float) -> void:
	dash_timer -= delta
	character.velocity.x = dash_direction.x * character.estadisticas.dash_velociadad
	character.velocity.z = dash_direction.z * character.estadisticas.dash_velociadad

	if character.pj:
		character.pj.scale.x = move_toward(character.pj.scale.x, target_scale_x, rotation_speed * delta)

	if dash_timer <= 0.0:
		character.velocity.x = 0.0
		character.velocity.z = 0.0

		# El cooldown arranca justo ahora, salvo que haya sido un esquive perfecto
		if character.dash_sin_cooldown:
			character.dash_sin_cooldown = false
		else:
			character.estadisticas.tiempo_dash_disponible = Time.get_ticks_msec() + int(dash_cooldown * 1000)

		# Si apretaste atacar durante el dash, el golpe sale ahora (como ataque veloz)
		if _ataque_en_cola:
			state_machine.transition_to("ataque")
			return

		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
