extends PaginaMenu
class_name PaginaBolsillo
## Equipar el bolsillo (composición final). Origen: despensa en la base, botín en la run.
## Z/X eligen unidades, A confirma. Con datos["partir"] (Enter en la base con el bolsillo vacío)
## confirmar también parte a la run.

@onready var grilla: GrillaSeleccion = %Grilla
@onready var contenedor_bolsillo: Container = %ContenedorBolsillo
@onready var label_capacidad: Label = %LabelCapacidad
@onready var label_vacio: Label = %LabelVacio
@onready var label_mensaje: Label = %LabelMensaje
@onready var label_ayuda: Label = %LabelAyuda
@onready var icono_detalle: TextureRect = %IconoDetalle
@onready var titulo_detalle: Label = %TituloDetalle
@onready var texto_detalle: RichTextLabel = %TextoDetalle

var estadisticas: estadisticas_player
var _partir: bool = false
var _en_run: bool = false


func _ready() -> void:
	texto_detalle.bbcode_enabled = true
	grilla.cursor_movido.connect(_actualizar_detalle)
	grilla.seleccion_cambiada.connect(_al_cambiar_seleccion)
	grilla.tope_alcanzado.connect(_avisar_lleno)


func configurar(datos: Dictionary) -> void:
	estadisticas = datos.get("estadisticas")
	_en_run = CodigoGlobal.en_run
	_partir = datos.get("partir", false) and not _en_run
	var accion := "A: Partir a la run" if _partir else "A: Equipar"
	label_ayuda.text = "Flechas: mover · Z/X: ±1 (Shift ±5) · %s · Q/E: pestañas · Esc: cerrar" % accion
	_recargar()


func manejar_input(event: InputEvent) -> bool:
	if grilla.manejar_input(event):
		return true
	if event.is_action_pressed("comer_confirmar"):
		_confirmar()
		return true
	return false


func _confirmar() -> void:
	estadisticas.reequipar_bolsillo(grilla.obtener_seleccion(), _origen())
	if not _en_run:
		CodigoGlobal.guardar_partida()
		CodigoGlobal.inventario_base_actualizado.emit()
	if _partir:
		hub.cerrar({"accion": "partir"})
		return
	_recargar()
	label_mensaje.text = "Bolsillo actualizado."


func _recargar() -> void:
	grilla.tope_slots = estadisticas.stats.slots_bolsillo
	grilla.tope_por_slot = estadisticas.stats.max_por_item_bolsillo
	grilla.cargar(_armar_pool())
	var equipado := {}
	for clave in estadisticas.bolsillo:
		equipado[clave] = (estadisticas.bolsillo[clave] as ItemData).cantidad
	grilla.preseleccionar(equipado)


func _origen() -> Dictionary:
	return estadisticas.inventario if _en_run else CodigoGlobal.inventario_base


## Comestibles del origen + lo ya equipado (copias con la cantidad sumada)
func _armar_pool() -> Dictionary:
	var pool := {}
	var origen := _origen()
	for clave in origen:
		var item: ItemData = origen[clave]
		if item.tipo == ItemData.TipoItem.COMESTIBLE and item.cantidad > 0:
			pool[clave] = item.duplicate()
	for clave in estadisticas.bolsillo:
		var equipado: ItemData = estadisticas.bolsillo[clave]
		if pool.has(clave):
			(pool[clave] as ItemData).cantidad += equipado.cantidad
		else:
			pool[clave] = equipado.duplicate()
	return pool


func _al_cambiar_seleccion() -> void:
	label_mensaje.text = ""
	_actualizar_bolsillo()
	_actualizar_capacidad()


func _actualizar_bolsillo() -> void:
	for hijo in contenedor_bolsillo.get_children():
		contenedor_bolsillo.remove_child(hijo)
		hijo.queue_free()
	for slot in grilla.slots:
		if slot.veces_seleccionado <= 0:
			continue
		var fila := HBoxContainer.new()
		var icono := TextureRect.new()
		icono.texture = slot.item_data.icono
		icono.custom_minimum_size = Vector2(32, 32)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var etiqueta := Label.new()
		etiqueta.text = "%s  x%d" % [slot.item_data.nombre, slot.veces_seleccionado]
		etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(icono)
		fila.add_child(etiqueta)
		contenedor_bolsillo.add_child(fila)
	label_vacio.visible = grilla.total_seleccionado() == 0


func _actualizar_capacidad() -> void:
	label_capacidad.text = "Ranuras: %d / %d   (máx. %d por ítem)" % [
		grilla.slots_usados(), grilla.tope_slots, grilla.tope_por_slot]


func _avisar_lleno(_motivo: String = "") -> void:
	label_capacidad.modulate = Color(1.0, 0.35, 0.35)
	var destello := label_capacidad.create_tween()
	destello.tween_property(label_capacidad, "modulate", Color.WHITE, 0.4)


func _actualizar_detalle(slot) -> void:
	if slot == null:
		titulo_detalle.text = ""
		icono_detalle.texture = null
		texto_detalle.text = "[i]No tenés nada para elegir.[/i]"
		return
	titulo_detalle.text = slot.item_data.nombre
	icono_detalle.texture = slot.item_data.icono
	texto_detalle.text = texto_item(slot.item_data)
