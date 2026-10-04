extends CharacterBody3D

@export var items_posibles: Array[ItemData] # <--- Cambiado de Texture2D a archivos .tres de los ítems
@export var collection_delay: float = 0.5
@export var magnet_speed: float = 12.0

@export var rotation_speed: float = 2.5  
@export var bob_amplitude: float = 0.2  
@export var bob_speed: float = 4.0        
@export var min_height: float = 0.3      

var player: Node3D = null
var can_be_collected: bool = false
var is_being_collected: bool = false
var has_landed: bool = false

var item_seleccionado: ItemData = null # <--- Guardará el ítem específico que tocó este objeto en el mundo

var time_passed: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var fall_timer: float = 0.0  

@onready var sprite: Sprite3D = $Sprite3D
@onready var collection_area: Area3D = $Area3D

func _ready() -> void:
	if not items_posibles.is_empty():
		# Elegimos un índice aleatorio seguro
		var indice_aleatorio = randi() % items_posibles.size()
		
		# Guardamos el ítem seleccionado
		item_seleccionado = items_posibles[indice_aleatorio]
		
		# Si el ítem tiene un icono asignado, se lo ponemos al Sprite3D automáticamente
		if item_seleccionado and item_seleccionado.icono:
			sprite.texture = item_seleccionado.icono
	
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Impulso inicial de salto
	velocity = Vector3(
		randf_range(-2.5, 2.5),
		randf_range(3.5, 5.5),
		randf_range(-2.5, 2.5)
	)

	await get_tree().create_timer(collection_delay).timeout
	can_be_collected = true
	
	if not collection_area.body_entered.is_connected(_on_area_3d_body_entered):
		collection_area.body_entered.connect(_on_area_3d_body_entered)

func _physics_process(delta: float) -> void:
	if is_being_collected and player:
		velocity = Vector3.ZERO
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)
		sprite.position.y = min_height 
		
		if global_position.distance_to(player.global_position) < 0.5:
			_collect()
		return

	if not has_landed:
		fall_timer += delta
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		move_and_slide()
		
		if is_on_floor() or (fall_timer > 3.0 and abs(velocity.y) < 0.2):
			velocity = Vector3.ZERO
			has_landed = true
			sprite.position.y = min_height
	else:
		time_passed += delta
		sprite.rotation.y += rotation_speed * delta
		var bob_offset = abs(sin(time_passed * bob_speed)) * bob_amplitude
		sprite.position.y = min_height + bob_offset


func _collect() -> void:
	if item_seleccionado and player and "estadisticas" in player and player.estadisticas:
		# Llamamos directamente a la función de agregar_item del recurso del jugador
		player.estadisticas.agregar_item(item_seleccionado)
		print("¡Ítem recolectada y añadido al inventario: ", item_seleccionado.nombre)
		
	queue_free()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if can_be_collected and body is Player:
		player = body
		is_being_collected = true
