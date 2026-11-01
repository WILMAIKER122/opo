class_name PaginaMenu
extends Control
## Contrato de las páginas del hub. Cada página es una escena independiente: el hub solo
## la instancia, la configura y le pasa las teclas. Para cerrar el hub: hub.cerrar({...}).

var hub: MenuHub

## Datos del hub: {"estadisticas": estadisticas_player, "partir": bool, ...}
func configurar(_datos: Dictionary) -> void:
	pass

## Devuelve true si consumió el evento (el hub no lo procesa)
func manejar_input(_event: InputEvent) -> bool:
	return false


## Texto de detalle de un ítem (BBCode), compartido por Inventario y Bolsillo
static func texto_item(item: ItemData) -> String:
	var texto := item.descripcion
	if item.hambre_restaurada > 0.0:
		texto += "\n\n[b]Hambre:[/b] +%s" % item.hambre_restaurada
	if not item.tags.is_empty():
		var nombres := PackedStringArray()
		for tag in item.tags:
			nombres.append(ItemData.TagComida.keys()[tag])
		texto += "\n[b]Tags:[/b] " + ", ".join(nombres)
	return texto
