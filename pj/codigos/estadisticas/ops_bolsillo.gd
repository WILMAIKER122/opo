class_name OpsBolsillo
extends RefCounted
## Lógica del bolsillo (provisiones equipadas). Los datos viven en estadisticas_player (est).
## Destino: res://pj/codigos/estadisticas/ops_bolsillo.gd


static func limpiar(est: estadisticas_player) -> void:
	est.bolsillo.clear()
	est.indice_bolsillo = 0
	est.bolsillo_cambiado.emit()


## Cambia la provisión seleccionada (da la vuelta al llegar al final)
static func ciclar(est: estadisticas_player, paso: int = 1) -> void:
	if est.bolsillo.size() < 2:
		return
	est.indice_bolsillo = wrapi(est.indice_bolsillo + paso, 0, est.bolsillo.size())
	est.bolsillo_cambiado.emit()


## Come UNA unidad de la provisión seleccionada. Devuelve false si el bolsillo está vacío.
static func comer(est: estadisticas_player) -> bool:
	if est.bolsillo.is_empty():
		return false
	est.indice_bolsillo = clampi(est.indice_bolsillo, 0, est.bolsillo.size() - 1)
	var clave: String = est.bolsillo.keys()[est.indice_bolsillo]
	var item: ItemData = est.bolsillo[clave]

	est.comer_item(item, 1)

	item.cantidad -= 1
	if item.cantidad <= 0:
		est.bolsillo.erase(clave)
		est.indice_bolsillo = clampi(est.indice_bolsillo, 0, maxi(est.bolsillo.size() - 1, 0))

	if est._en_base():
		CodigoGlobal.guardar_partida()
	est.bolsillo_cambiado.emit()
	return true


## Rearma el bolsillo con la composición final `seleccion` {clave: unidades}.
## Todo lo equipado vuelve primero a `origen` y de ahí se toma lo nuevo,
## respetando slots_bolsillo y max_por_item_bolsillo.
static func reequipar(est: estadisticas_player, seleccion: Dictionary, origen: Dictionary) -> void:
	var bolsillo := est.bolsillo
	for clave in bolsillo:
		var item: ItemData = bolsillo[clave]
		if origen.has(clave):
			(origen[clave] as ItemData).cantidad += item.cantidad
		else:
			origen[clave] = item
	bolsillo.clear()

	for clave in seleccion:
		if bolsillo.size() >= est.stats.slots_bolsillo:
			break
		if not origen.has(clave):
			continue
		var item: ItemData = origen[clave]
		var n := mini(mini(int(seleccion[clave]), item.cantidad), est.stats.max_por_item_bolsillo)
		if n <= 0:
			continue
		var copia: ItemData = item.duplicate()
		copia.cantidad = n
		bolsillo[clave] = copia
		item.cantidad -= n
		if item.cantidad <= 0:
			origen.erase(clave)

	est.indice_bolsillo = clampi(est.indice_bolsillo, 0, maxi(bolsillo.size() - 1, 0))
	est.bolsillo_cambiado.emit()
	est.emit_changed()
