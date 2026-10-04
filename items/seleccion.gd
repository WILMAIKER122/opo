extends CanvasLayer

@onready var grid: GridContainer = $Control/PanelPrincipal/MarginContainer/VBoxContainer/ContenedorGrid/GridContainer
@onready var cursor: TextureRect = $Control/PanelPrincipal/MarginContainer/VBoxContainer/ContenedorGrid/Cursor
@onready var vista_previa: HBoxContainer =$Control/PanelPrincipal/MarginContainer/VBoxContainer/VistaPrevia

const ITEM_SLOT_SCENE := preload("res://items/ItemSlot.tscn")

var slots: Array = []
var indice_actual: int = 0
var tween: Tween

func construir(items_comestibles: Dictionary) -> void:
	for child in grid.get_children():
		child.queue_free()
	for child in vista_previa.get_children():
		child.queue_free()
	slots.clear()
	
	for clave in items_comestibles:
		var item: ItemData = items_comestibles[clave]
		var slot = ITEM_SLOT_SCENE.instantiate()
		grid.add_child(slot)
		slot.configurar(clave, item)
		slots.append(slot)
	
	indice_actual = 0
	
	# Esperamos un frame para que el GridContainer calcule tamaños/posiciones reales
	await get_tree().process_frame
	_mover_cursor_instantaneo()

func _mover_cursor_instantaneo() -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]
	cursor.global_position = slot.global_position
	cursor.size = slot.size

func _mover_cursor_animado() -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]
	
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cursor, "global_position", slot.global_position, 0.15)
	tween.parallel().tween_property(cursor, "size", slot.size, 0.15)

func mover_seleccion(direccion: Vector2i) -> void:
	if slots.is_empty():
		return
	
	var columnas: int = grid.columns
	var total: int = slots.size()
	var filas: int = ceili(float(total) / columnas)
	
	var col := (indice_actual % columnas) + direccion.x
	var fila := int(indice_actual / columnas) + direccion.y
	
	col = clampi(col, 0, columnas - 1)
	fila = clampi(fila, 0, filas - 1)
	
	var nuevo_indice := fila * columnas + col
	if nuevo_indice >= total:
		nuevo_indice = total - 1
	
	if nuevo_indice == indice_actual:
		return
	
	indice_actual = nuevo_indice
	_mover_cursor_animado()

func confirmar_seleccion_actual() -> void:
	if slots.is_empty():
		return
	
	var slot = slots[indice_actual]
	if slot.incrementar_seleccion():
		_actualizar_vista_previa()

func _actualizar_vista_previa() -> void:
	for child in vista_previa.get_children():
		child.queue_free()
	
	for slot in slots:
		if slot.veces_seleccionado <= 0:
			continue
		
		var contenedor := VBoxContainer.new()
		contenedor.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var mini_icono := TextureRect.new()
		mini_icono.texture = slot.item_data.icono
		mini_icono.custom_minimum_size = Vector2(32, 32)
		mini_icono.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		mini_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var mini_label := Label.new()
		mini_label.text = "x%d" % slot.veces_seleccionado
		mini_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		contenedor.add_child(mini_icono)
		contenedor.add_child(mini_label)
		vista_previa.add_child(contenedor)

func obtener_seleccion() -> Dictionary:
	var resultado := {}
	for slot in slots:
		if slot.veces_seleccionado > 0:
			resultado[slot.clave_item] = slot.veces_seleccionado
	return resultado

func restar_seleccion_actual() -> void:
	if slots.is_empty():
		return
	slots[indice_actual].decrementar_seleccion()
