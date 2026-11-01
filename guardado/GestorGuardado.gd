class_name GestorGuardado
extends RefCounted
## Guardar / cargar la partida. El estado vive en CodigoGlobal (g); acá solo está la lógica.
## Destino: res://guardado/GestorGuardado.gd

const RUTA := "res://guardado/datos_guardado.tres"


static func guardar(g: Node) -> void:
	if not g.carga_ok:
		push_warning("Guardado bloqueado: la partida todavía no se cargó.")
		return

	var carpeta := RUTA.get_base_dir()
	if not DirAccess.dir_exists_absolute(carpeta):
		DirAccess.make_dir_recursive_absolute(carpeta)
	if FileAccess.file_exists(RUTA):
		DirAccess.copy_absolute(RUTA, carpeta.path_join("datos_guardado.bak"))

	var datos := DatosGuardado.new()
	datos.inventario_base = g.inventario_base
	datos.recetas_descubiertas = g.recetas_descubiertas.duplicate()
	datos.conocimientos = g.conocimientos.duplicate()
	datos.vistos = g.vistos.duplicate()
	datos.derrotas = g.derrotas.duplicate()
	datos.bolsillo = g.bolsillo
	datos.run_en_curso = g.run_en_curso
	var error := ResourceSaver.save(datos, RUTA)
	if error == OK:
		print("Partida guardada en: ", RUTA)
	else:
		push_warning("Error al guardar la partida: %s" % error_string(error))


static func cargar(g: Node) -> void:
	if not FileAccess.file_exists(RUTA):
		print("No hay partida guardada todavía. Inventario de base inicia vacío.")
		g.carga_ok = true
		return

	var datos := ResourceLoader.load(RUTA, "", ResourceLoader.CACHE_MODE_IGNORE) as DatosGuardado
	if datos == null:
		push_error("No se pudo cargar la partida: se bloquea el guardado para no pisar el archivo.")
		return
	g.carga_ok = true

	g.inventario_base = datos.inventario_base
	g.recetas_descubiertas.assign(datos.recetas_descubiertas)
	g.conocimientos.assign(datos.conocimientos)
	g.vistos.assign(datos.vistos)
	g.derrotas = datos.derrotas.duplicate()
	g.marcar_inventario_base_como_visto()
	g.bolsillo = datos.bolsillo
	if datos.run_en_curso:
		# El juego se cerró en plena run: se pierde lo que se llevaba
		g.bolsillo = {}
		g.run_en_curso = false
		guardar(g)
	print("Partida cargada. Items en inventario de base: ", g.inventario_base.size())
	g.inventario_base_actualizado.emit()
