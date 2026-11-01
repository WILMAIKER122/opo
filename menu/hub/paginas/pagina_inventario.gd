extends PaginaMenu
class_name PaginaInventario
## Inventario activo (despensa en la base, botín en la run). Z/X eligen unidades,
## A come lo elegido (sin elegir nada: 1 del ítem resaltado). Cierra el hub con "comer".

@onready var grilla: GrillaSeleccion = %Grilla
@onready var icono_detalle: TextureRect = %IconoDetalle
@onready var titulo_detalle: Label = %TituloDetalle
@onready var texto_detalle: RichTextLabel = %TextoDetalle
@onready var label_seleccion: Label = %LabelSeleccion

var estadisticas: estadisticas_player


func _ready() -> void:
	texto_detalle.bbcode_enabled = true
	grilla.cursor_movido.connect(_actualizar_detalle)
	grilla.seleccion_cambiada.connect(_actualizar_seleccion)


func configurar(datos: Dictionary) -> void:
	estadisticas = datos.get("estadisticas")
	grilla.cargar(estadisticas.obtener_inventario_activo())
	_actualizar_seleccion()


func manejar_input(event: InputEvent) -> bool:
	if grilla.manejar_input(event):
		return true
	if event.is_action_pressed("comer_confirmar"):
		_comer()
		return true
	return false


func _comer() -> void:
	var seleccion := {}
	var elegido := grilla.obtener_seleccion()
	for clave in elegido:
		if _es_comestible(clave):
			seleccion[clave] = elegido[clave]

	# Sin nada elegido: 1 unidad del ítem resaltado
	if seleccion.is_empty():
		var slot = grilla.slot_actual()
		if slot and slot.item_data.tipo == ItemData.TipoItem.COMESTIBLE:
			seleccion[slot.clave_item] = 1
	if seleccion.is_empty():
		return
	hub.cerrar({"accion": "comer", "seleccion": seleccion})


func _es_comestible(clave: String) -> bool:
	var inventario := estadisticas.obtener_inventario_activo()
	return inventario.has(clave) and (inventario[clave] as ItemData).tipo == ItemData.TipoItem.COMESTIBLE


func _actualizar_seleccion() -> void:
	var total := grilla.total_seleccionado()
	label_seleccion.text = "Para comer: %d" % total if total > 0 else ""


func _actualizar_detalle(slot) -> void:
	if slot == null:
		titulo_detalle.text = ""
		icono_detalle.texture = null
		texto_detalle.text = "[i]No tenés nada.[/i]"
		return
	titulo_detalle.text = slot.item_data.nombre
	icono_detalle.texture = slot.item_data.icono
	texto_detalle.text = texto_item(slot.item_data)
