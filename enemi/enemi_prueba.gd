extends CharacterBody3D

@export var partes: Array[Texture2D]
@export var collection_delay: float = 0.5
@export var magnet_speed: float = 12.0

@export var rotation_speed: float = 2.5  
@export var bob_amplitude: float = 0.15  
@export var bob_speed: float = 4.0       

var player: Node3D = null
var can_be_collected: bool = false
var is_being_collected: bool = false
var has_landed: bool = false

var initial_y_sprite: float = 0.0
var time_passed: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var fall_timer: float = 0.0  # Temporizador de seguridad

@onready var sprite: Sprite3D = $Sprite3D
@onready var collection_area: Area3D = $Area3D

func _ready() -> void:
	if not partes.is_empty():
		sprite.texture = partes[randi() % partes.size()]
	
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Impulso inicial de salto al aparecer
	velocity = Vector3(
		randf_range(-2.5, 2.5),
		randf_range(3.5, 5.5),
		randf_range(-2.5, 2.5)
	)

	await get_tree().create_timer(collection_delay).timeout
	can_be_collected = true
	
	if not collection_area.body_entered.is_connected(_on_player_entered):
		collection_area.body_entered.connect(_on_player_entered)

func _physics_process(delta: float) -> void:
	if is_being_collected and player:
		velocity = Vector3.ZERO
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)
		
		if global_position.distance_to(player.global_position) < 0.5:
			_collect()
		return

	if not has_landed:
		fall_timer += delta
		
		# Aplicar gravedad mientras cae
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		move_and_slide()
		
		# CONDICIÓN DE ATERRIZAJE: 
		# O toca el suelo normalmente, o si pasan más de 3 segundos y ya casi no se mueve, lo forzamos a aterrizar
		if is_on_floor() or (fall_timer > 3.0 and abs(velocity.y) < 0.2):
			velocity = Vector3.ZERO
			has_landed = true
			# Tomamos la posición Y exacta del sprite en el momento de tocar el suelo
			initial_y_sprite = sprite.position.y
	else:
		# Efecto estilo Minecraft (Girar y flotar desde su posición de suelo)
		time_passed += delta
		sprite.rotation.y += rotation_speed * delta
		
		var bob_offset = sin(time_passed * bob_speed) * bob_amplitude
		sprite.position.y = initial_y_sprite + bob_offset

func _on_player_entered(body: Node3D) -> void:
	if can_be_collected and body.is_in_group("Player"):
		player = body
		is_being_collected = true

func _collect() -> void:
	print("¡Parte de enemigo recolectada!")
	queue_free()
