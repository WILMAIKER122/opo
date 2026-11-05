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
		var n := mini(mini(int(seleccion[clave]), item.cantidad), est.max_por_item_bolsillo())
		if n <= 0:
			continue
		var copia: ItemData = item.duplicate()
		copia.cantidad = n
		bolsillo[clave] = copia
		item.cantidad -= n
		if item.cantidad <= 0:
			origen.erase(clave)
	# En la base, lo equipado pasa a ser la plantilla del autorelleno
	if est._en_base():
		var plantilla := {}
		for clave in bolsillo:
			plantilla[clave] = (bolsillo[clave] as ItemData).cantidad
		CodigoGlobal.plantilla_bolsillo = plantilla
	est.indice_bolsillo = clampi(est.indice_bolsillo, 0, maxi(bolsillo.size() - 1, 0))
	est.bolsillo_cambiado.emit()
	est.emit_changed()
## Autorelleno: gestiona SOLO los primeros slots_autorelleno() ítems de la plantilla (un slot cada uno).
## Por slot: si su ítem puede llegar al tope, se completa. Si no, se busca un ítem que llegue más
## alto (el de mayor cantidad) y el slot pasa a ese. Si nadie mejora, se queda como está (ej. en 3).
static func autorellenar(est: estadisticas_player, origen: Dictionary) -> void:
	var n_max := est.slots_autorelleno()
	if n_max <= 0:
		return
	var tope := est.max_por_item_bolsillo()
	var bolsillo := est.bolsillo
	var claves: Array = CodigoGlobal.plantilla_bolsillo.keys().slice(0, n_max)
	var reservados := {}   # ítems que ya pertenecen a un slot gestionado
	for c in claves:
		reservados[c] = true

	var cambio := false
	for i in n_max:
		var clave: String = claves[i] if i < claves.size() else ""
		var actual := _alcanzable(bolsillo, origen, clave, tope)
		if actual < tope:
			var libera := clave != "" and bolsillo.has(clave)
			var alt := _mejor_alternativa(est, origen, reservados, tope, libera)
			if alt != "" and _alcanzable(bolsillo, origen, alt, tope) > actual:
				if libera:
					_devolver(bolsillo, origen, clave)   # el slot cambia de ítem
				clave = alt
				reservados[alt] = true
				cambio = true
		if clave == "":
			continue
		if _mover(est, origen, clave, tope - _cantidad_en(bolsillo, clave)) > 0:
			cambio = true

	if cambio:
		est.indice_bolsillo = clampi(est.indice_bolsillo, 0, maxi(bolsillo.size() - 1, 0))
		est.bolsillo_cambiado.emit()
		est.emit_changed()
		if est._en_base():
			CodigoGlobal.inventario_base_actualizado.emit()


## Hasta cuánto podría llegar el slot de `clave` (equipado + disponible en origen), máx. tope
static func _alcanzable(bolsillo: Dictionary, origen: Dictionary, clave: String, tope: int) -> int:
	if clave == "":
		return 0
	var disponible := 0
	if origen.has(clave):
		var item: ItemData = origen[clave]
		if item.tipo == ItemData.TipoItem.COMESTIBLE:
			disponible = item.cantidad
	return mini(tope, _cantidad_en(bolsillo, clave) + disponible)


## Ítem (no reservado por otro slot) que llegue más alto; empate: el de más cantidad en origen
static func _mejor_alternativa(est: estadisticas_player, origen: Dictionary, reservados: Dictionary, tope: int, libera_slot: bool) -> String:
	var mejor := ""
	var mejor_alcance := 0
	var mejor_cant := 0
	for clave in origen:
		if reservados.has(clave):
			continue
		var item: ItemData = origen[clave]
		if item.tipo != ItemData.TipoItem.COMESTIBLE or item.cantidad <= 0:
			continue
		if not est.bolsillo.has(clave) and est.bolsillo.size() >= est.stats.slots_bolsillo and not libera_slot:
			continue
		var alcance := mini(tope, _cantidad_en(est.bolsillo, clave) + item.cantidad)
		if alcance > mejor_alcance or (alcance == mejor_alcance and item.cantidad > mejor_cant):
			mejor = clave
			mejor_alcance = alcance
			mejor_cant = item.cantidad
	return mejor


## Devuelve lo equipado en `clave` al origen y libera el slot
static func _devolver(bolsillo: Dictionary, origen: Dictionary, clave: String) -> void:
	var item: ItemData = bolsillo[clave]
	if origen.has(clave):
		(origen[clave] as ItemData).cantidad += item.cantidad
	else:
		origen[clave] = item
	bolsillo.erase(clave)


static func _cantidad_en(bolsillo: Dictionary, clave: String) -> int:
	return (bolsillo[clave] as ItemData).cantidad if bolsillo.has(clave) else 0


## Mueve hasta `pedido` unidades de origen al bolsillo (respeta tope por ítem y slots). Devuelve lo movido.
static func _mover(est: estadisticas_player, origen: Dictionary, clave: String, pedido: int) -> int:
	if pedido <= 0 or not origen.has(clave):
		return 0
	var bolsillo := est.bolsillo
	var fuente: ItemData = origen[clave]
	if fuente.tipo != ItemData.TipoItem.COMESTIBLE:
		return 0
	var n := mini(mini(pedido, est.max_por_item_bolsillo() - _cantidad_en(bolsillo, clave)), fuente.cantidad)
	if n <= 0:
		return 0
	if not bolsillo.has(clave):
		if bolsillo.size() >= est.stats.slots_bolsillo:
			return 0
		var copia: ItemData = fuente.duplicate()
		copia.cantidad = 0
		bolsillo[clave] = copia
	(bolsillo[clave] as ItemData).cantidad += n
	fuente.cantidad -= n
	if fuente.cantidad <= 0:
		origen.erase(clave)
	return n
