extends Node3D

@export var datos_zeta:Zeta_datos
@onready var pj_zeta: MeshInstance3D = $Armature/Skeleton3D/pj_zeta





var delite:bool
func _ready() -> void:
	#pj_zeta.albe =datos_zeta.textura
	$AnimationPlayer.play("caida")
	cambiar_textura_mesh()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player and delite:
		#body.estadisticas.con_zeta=true
		body.estadisticas.poner_quitar_zeta()
		body.zeta_func(true)
		$".".queue_free()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name:
		delite = true
		
func cambiar_textura_mesh() -> void:
	# 2. Obtener o crear el material_override en el mesh referenciado
	var mat = pj_zeta.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		pj_zeta.material_override = mat

	# 3. Asignar la nueva textura
	mat.albedo_texture = datos_zeta.textura
	print("¡Textura cambiada con éxito desde otro script!")
	
	
	
