class_name GeneradorPuertas
extends RefCounted
## Opciones de puertas (gratis / pago / escindida), costos, cobro y pool de ítems de recompensa.
## Todo estático y sin estado de CodigoGlobal: recibe lo que necesita por parámetro.
## Destino: res://niveles/codigo/GeneradorPuertas.gd

const SALAS_POR_RUN := 5   # salas normales; la siguiente es el jefe
const CARPETA_ITEMS := "res://items/partes/"

## Lo último que cobró una puerta: [{nombre, icono, cantidad, restante}]. Lo lee el HUD.
static var aviso_pago: Array = []
static var _items_cache: Array[ItemData] = []


# ==============================================================================
# OPCIONES DE PUERTAS
# ==============================================================================

## Salidas de la sala actual: [{"tipo","tag","puerta","nivel",...}] o [{"salida": true}]
static func opciones(sala_numero: int, tipo_sala_actual: int, max_puertas: int = 2) -> Array:
	if sala_numero >= SALAS_POR_RUN:
		return [{"salida": true}]
	if sala_numero == SALAS_POR_RUN - 1:
		return [_con_puerta({"tipo": Sala.Tipo.JEFE, "tag": -1}, false, sala_numero)]
	var n := randi_range(1, clampi(max_puertas, 1, 3))
	var lista: Array = []
	var excluir := -1
	var hay_libre := false
	for i in n:
		var tipo := Sala.Tipo.COMBATE
		if randf() < 0.2 and tipo_sala_actual != Sala.Tipo.CAMPAMENTO:
			tipo = Sala.Tipo.CAMPAMENTO
		var op := _con_puerta(_opcion(tipo, excluir), i == n - 1 and not hay_libre, sala_numero)
		excluir = op["tag"]
		if op["puerta"] != "pago":
			hay_libre = true
		lista.append(op)
	return lista


static func _opcion(tipo: int, excluir_tag: int = -1) -> Dictionary:
	var tag := -1
	if tipo == Sala.Tipo.COMBATE:
		var tags := tags_con_items()
		if tags.size() > 1:
			tags.erase(excluir_tag)
		if not tags.is_empty():
			tag = tags.pick_random()
	return {"tipo": tipo, "tag": tag}


## puerta: "gratis" | "pago" | "escindida". libre = fuerza que NO sea de pago (garantiza salida)
static func _con_puerta(opcion: Dictionary, libre: bool, sala_numero: int) -> Dictionary:
	opcion["puerta"] = "gratis"
	opcion["nivel"] = 0
	if opcion["tipo"] != Sala.Tipo.COMBATE:
		return opcion
	var r := randf()
	if libre:
		r = 0.5 + r * 0.5
	if r < 0.5:
		opcion["puerta"] = "pago"
		opcion["costo"] = _costo_aleatorio(sala_numero)
		var c: Dictionary = opcion["costo"]
		opcion["nivel"] = 1 + c["rareza"] + (1 if c["cantidad"] >= 4 else 0)
	elif r >= 0.8:
		opcion["puerta"] = "escindida"
		opcion["nivel"] = 1
	return opcion


static func _costo_aleatorio(sala_numero: int) -> Dictionary:
	var extra := floori(sala_numero / 2.0)
	var tags := tags_con_items()
	if not tags.is_empty() and randf() < 0.5:
		return {"modo": "tag", "tag": tags.pick_random(), "cantidad": randi_range(2, 5) + extra, "rareza": 0}
	var rareza := ItemData.Rareza.RARO if randf() < 0.3 else ItemData.Rareza.COMUN
	return {"modo": "rareza", "rareza": rareza, "cantidad": randi_range(1, 3) + extra, "tag": -1}


static func texto_costo(costo: Dictionary) -> String:
	if costo["modo"] == "tag":
		return "%dx %s" % [costo["cantidad"], ItemData.TagComida.keys()[costo["tag"]]]
	return "%dx %s+" % [costo["cantidad"], ItemData.Rareza.keys()[costo["rareza"]]]


# ==============================================================================
# COBRO
# ==============================================================================

## Partes que sirven para pagar, ordenadas: más común primero, inventario antes que bolsillo
static func _candidatos_pago(costo: Dictionary, est: estadisticas_player) -> Array:
	var lista: Array = []
	for par in [[est.inventario, 0], [est.bolsillo, 1]]:
		var origen: Dictionary = par[0]
		for clave in origen:
			var item: ItemData = origen[clave]
			if item.cantidad <= 0 or item.tipo != ItemData.TipoItem.COMESTIBLE:
				continue
			var vale: bool = item.tags.has(costo["tag"]) if costo["modo"] == "tag" else item.rareza >= costo["rareza"]
			if vale:
				lista.append({"origen": origen, "clave": clave, "item": item, "peso": item.rareza * 2 + par[1]})
	lista.sort_custom(func(a, b): return a["peso"] < b["peso"])
	return lista


## Devuelve lo cobrado (ya descontado) o [] si no alcanza (no toca nada)
static func pagar(costo: Dictionary, est: estadisticas_player) -> Array:
	var cand := _candidatos_pago(costo, est)
	var falta: int = costo["cantidad"]
	var total := 0
	for c in cand:
		total += (c["item"] as ItemData).cantidad
	if total < falta:
		return []
	var pagos: Array = []
	for c in cand:
		if falta <= 0:
			break
		var item: ItemData = c["item"]
		var n := mini(item.cantidad, falta)
		item.cantidad -= n
		falta -= n
		pagos.append({"nombre": item.nombre, "icono": item.icono, "cantidad": n, "restante": item.cantidad})
		if item.cantidad <= 0:
			(c["origen"] as Dictionary).erase(c["clave"])
	est.indice_bolsillo = clampi(est.indice_bolsillo, 0, maxi(est.bolsillo.size() - 1, 0))
	est.bolsillo_cambiado.emit()
	est.emit_changed()
	aviso_pago = pagos
	return pagos


## Ítem que se cobraría primero (para mostrar su ícono en la puerta)
static func vista_previa(costo: Dictionary, est: estadisticas_player) -> ItemData:
	var cand := _candidatos_pago(costo, est)
	if not cand.is_empty():
		return cand[0]["item"]
	if costo["modo"] == "tag":
		return item_con_tag(costo["tag"])
	return null


# ==============================================================================
# POOL DE ÍTEMS DE RECOMPENSA
# ==============================================================================

static func _items_recompensa() -> Array[ItemData]:
	if _items_cache.is_empty():
		for archivo in DirAccess.get_files_at(CARPETA_ITEMS):
			var nombre := archivo.trim_suffix(".remap")
			if nombre.ends_with(".tres"):
				var item := load(CARPETA_ITEMS.path_join(nombre)) as ItemData
				if item and item.tipo == ItemData.TipoItem.COMESTIBLE and not item.tags.is_empty():
					_items_cache.append(item)
	return _items_cache


static func tags_con_items() -> Array:
	var tags := {}
	for item in _items_recompensa():
		for tag in item.tags:
			tags[tag] = true
	return tags.keys()


static func item_con_tag(tag: int, rareza_min: int = 0) -> ItemData:
	var todos := _items_recompensa().filter(func(i): return i.tags.has(tag))
	var buenos := todos.filter(func(i): return i.rareza >= rareza_min)
	var lista := buenos if not buenos.is_empty() else todos
	return lista.pick_random() if not lista.is_empty() else null
