extends Node

const RUTA_BASE := "res://base.tscn"
const RUTA_RUN := "res://suelo_2.tscn"
const RUTA_GUARDADO := "res://base/datos_guardado.tres"


var en_run: bool = false
var vida_inicial_run: float = -1.0

@export var penalizacion_vida_inicial: float = 0.3
@export var porcentaje_perdida_muerte: float = 12.0

var inventario_base: Dictionary = {}

func _ready() -> void:
	var escena_actual = get_tree().current_scene.scene_file_path
	en_run = (escena_actual == RUTA_RUN)
	print("CodigoGlobal iniciado. Escena actual: ", escena_actual, " | en_run: ", en_run)
	
	cargar_partida()

func iniciar_run(estadisticas: estadisticas_player) -> void:
	en_run = true
	
	if estadisticas.hambre.esta_en_cero():
		vida_inicial_run = estadisticas.stats.vida_base * penalizacion_vida_inicial
		print("¡Hambre en 0! Iniciando la run con vida reducida: ", vida_inicial_run)
	else:
		vida_inicial_run = -1.0
	
	estadisticas.inventario.clear()
	
	get_tree().change_scene_to_file(RUTA_RUN)

func finalizar_run(estadisticas: estadisticas_player) -> void:
	en_run = false
	_transferir_inventario_a_base(estadisticas)
	estadisticas.buffs.limpiar_run()
	get_tree().change_scene_to_file(RUTA_BASE)

func morir(estadisticas: estadisticas_player) -> void:
	en_run = false
	_aplicar_penalizacion_muerte(estadisticas)
	_transferir_inventario_a_base(estadisticas)
	estadisticas.buffs.limpiar_run()
	get_tree().change_scene_to_file(RUTA_BASE)

func _aplicar_penalizacion_muerte(estadisticas: estadisticas_player) -> void:
	for clave in estadisticas.inventario.keys():
		var item: ItemData = estadisticas.inventario[clave]
		var perdida := int(ceil(item.cantidad * (porcentaje_perdida_muerte / 100.0)))
		item.cantidad = max(0, item.cantidad - perdida)
		print("Penalización por muerte: ", item.nombre, " perdió ", perdida, " unidades (quedan ", item.cantidad, ")")
		
		if item.cantidad <= 0:
			estadisticas.inventario.erase(clave)

func _transferir_inventario_a_base(estadisticas: estadisticas_player) -> void:
	for clave in estadisticas.inventario:
		var item: ItemData = estadisticas.inventario[clave]
		
		if inventario_base.has(clave):
			var item_en_base: ItemData = inventario_base[clave]
			item_en_base.cantidad = min(item_en_base.cantidad + item.cantidad, item_en_base.max_cantidad)
		else:
			inventario_base[clave] = item.duplicate()
	
	estadisticas.inventario.clear()
	print("Inventario transferido a la base.")
	
	guardar_partida()

# ==============================================================================
# GUARDADO Y CARGA
# ==============================================================================

func guardar_partida() -> void:
	var carpeta := RUTA_GUARDADO.get_base_dir()
	if not DirAccess.dir_exists_absolute(carpeta):
		DirAccess.make_dir_recursive_absolute(carpeta)
	
	var datos := DatosGuardado.new()
	datos.inventario_base = inventario_base
	
	var error = ResourceSaver.save(datos, RUTA_GUARDADO)
	if error == OK:
		print("Partida guardada en: ", RUTA_GUARDADO)
	else:
		push_warning("Error al guardar la partida: ", error)

func cargar_partida() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		print("No hay partida guardada todavía. Inventario de base inicia vacío.")
		return
	
	var datos: DatosGuardado = ResourceLoader.load(RUTA_GUARDADO)
	if datos:
		inventario_base = datos.inventario_base
		print("Partida cargada. Items en inventario de base: ", inventario_base.size())
	else:
		push_warning("No se pudo cargar el archivo de guardado.")
