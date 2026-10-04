extends Node

const CARPETA_ITEMS := "res://data/items"

var _items: Dictionary = {}   # id -> ItemData

func _ready() -> void:
	_cargar_carpeta(CARPETA_ITEMS)
	print("Database: %d items cargados" % _items.size())

func _cargar_carpeta(ruta: String) -> void:
	var dir := DirAccess.open(ruta)
	if dir == null:
		push_error("Database: no se pudo abrir " + ruta)
		return
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if dir.current_is_dir():
			if not archivo.begins_with("."):
				_cargar_carpeta(ruta.path_join(archivo))   # subcarpetas
		else:
			# En la build exportada los archivos terminan en ".remap"
			archivo = archivo.trim_suffix(".remap")
			if archivo.ends_with(".tres"):
				var recurso = load(ruta.path_join(archivo))
				if recurso is ItemData:
					_registrar(recurso, archivo)
		archivo = dir.get_next()
	dir.list_dir_end()

func _registrar(item: ItemData, archivo: String) -> void:
	if item.id == &"":
		push_warning("Database: %s no tiene id, se ignora" % archivo)
		return
	if _items.has(item.id):
		push_error("Database: id duplicado '%s' (%s)" % [item.id, archivo])
		return
	_items[item.id] = item

# --- Consultas ---

func get_item(id: StringName) -> ItemData:
	if not _items.has(id):
		push_error("Database: no existe el item '%s'" % id)
		return null
	return _items[id]

func get_todos() -> Array:
	return _items.values()

func get_por_tipo(tipo: ItemData.TipoItem) -> Array:
	return _items.values().filter(func(i): return i.tipo == tipo)

# Copia propia, para que puedas cambiar la cantidad sin tocar el .tres original
func crear_instancia(id: StringName, cantidad: int = 1) -> ItemData:
	var base := get_item(id)
	if base == null:
		return null
	var copia: ItemData = base.duplicate()
	copia.cantidad = cantidad
	return copia
