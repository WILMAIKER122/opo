class_name EfectosCombate
extends RefCounted
## Efectos visuales de combate. Todo estático: no hace falta instanciarlo.


## Número que sube y se desvanece. padre: normalmente get_tree().current_scene
static func numero_flotante(padre: Node, posicion: Vector3, texto: String,
		color: Color = Color.WHITE, escala: float = 1.0) -> void:
	if padre == null:
		return
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.modulate = color
	etiqueta.outline_modulate = Color.BLACK
	etiqueta.outline_size = 12
	etiqueta.font_size = 48
	etiqueta.pixel_size = 0.008 * escala
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	padre.add_child(etiqueta)
	etiqueta.global_position = posicion + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)

	var altura := etiqueta.global_position.y + 1.0
	var tween := etiqueta.create_tween()
	tween.set_ignore_time_scale(true)   # que el hitstop no los congele
	tween.set_parallel(true)
	tween.tween_property(etiqueta, "global_position:y", altura, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(etiqueta, "modulate:a", 0.0, 0.35).set_delay(0.25)
	tween.tween_property(etiqueta, "outline_modulate:a", 0.0, 0.35).set_delay(0.25)
	tween.chain().tween_callback(etiqueta.queue_free)
