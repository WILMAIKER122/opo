class_name SistemaCocina
extends RefCounted
## Utilidades de cocina (todo estático, no hace falta instanciarlo ni crear un autoload).
## Las recetas se cargan solas desde la carpeta res://recetas/

const CARPETA_RECETAS := "res://recetas/recursos/"


static var _recetas: Array[RecetaCocina] = []
static var _cargadas: bool = false


static func obtener_recetas() -> Array[RecetaCocina]:
	if not _cargadas:
		_cargar_recetas()
	return _recetas


static func _cargar_recetas() -> void:
	_recetas.clear()
	_cargadas = true
	for archivo in DirAccess.get_files_at(CARPETA_RECETAS):
		# En un juego exportado los recursos aparecen como "nombre.tres.remap"
		var nombre_archivo := archivo.trim_suffix(".remap")
		if not (nombre_archivo.ends_with(".tres") or nombre_archivo.ends_with(".res")):
			continue
		var receta := load(CARPETA_RECETAS + "/" + nombre_archivo) as RecetaCocina
		if receta:
			_recetas.append(receta)
	if _recetas.is_empty():
		push_warning("SistemaCocina: no hay recetas en %s" % CARPETA_RECETAS)


## Un ingrediente es una parte comestible que tiene al menos un tag
## (los platos cocinados no llevan tags, así que no se vuelven a cocinar).
static func es_ingrediente(item: ItemData) -> bool:
	return item != null \
		and item.tipo == ItemData.TipoItem.COMESTIBLE \
		and not item.tags.is_empty()


## olla: { clave : unidades }  ->  { tag : unidades totales de ese tag }
static func contar_tags(olla: Dictionary, inventario: Dictionary) -> Dictionary:
	var conteo := {}
	for clave in olla:
		if not inventario.has(clave):
			continue
		var item: ItemData = inventario[clave]
		for tag in item.tags:
			conteo[tag] = int(conteo.get(tag, 0)) + int(olla[clave])
	return conteo


## Devuelve la receta que encaja con la mezcla (la de mayor prioridad) o null
static func buscar_receta(conteo: Dictionary) -> RecetaCocina:
	var mejor: RecetaCocina = null
	for receta in obtener_recetas():
		if not receta.coincide(conteo):
			continue
		if mejor == null or receta.prioridad > mejor.prioridad:
			mejor = receta
	return mejor


static func nombre_tag(tag: int) -> String:
	return ItemData.TagComida.keys()[tag]

## Arma la olla más barata para una receta usando partes de UN solo tag (las de varios tags
## quedan para la mezcla manual). Gasta primero lo más común.
## Devuelve { "olla": { clave: unidades }, "faltan": { tag: unidades que faltan } }
static func armar_olla(receta: RecetaCocina, inventario: Dictionary) -> Dictionary:
	var olla := {}
	var faltan := {}
	for requisito in receta.requisitos:
		if requisito == null:
			continue
		var necesita := maxi(requisito.cantidad_minima, 1)
		var candidatos: Array = []
		for clave in inventario:
			var item: ItemData = inventario[clave]
			if es_ingrediente(item) and item.cantidad > 0 and item.tags.size() == 1 and item.tags[0] == requisito.tag:
				candidatos.append(clave)
		candidatos.sort_custom(func(a, b): return (inventario[a] as ItemData).rareza < (inventario[b] as ItemData).rareza)
		for clave in candidatos:
			if necesita <= 0:
				break
			var tomar := mini(necesita, (inventario[clave] as ItemData).cantidad)
			olla[clave] = int(olla.get(clave, 0)) + tomar
			necesita -= tomar
		if necesita > 0:
			faltan[requisito.tag] = necesita
	return {"olla": olla, "faltan": faltan}
