class_name estadisticas_player
extends Resource
## Datos y stats del jugador. La lógica pesada vive en OpsBolsillo, OpsComida y OpsVida;
## los métodos de abajo son wrappers para que el resto del código no cambie.

@export var stats: StatsBase
@export var mejoras_permanentes: SistemaMejorasPermanentes
@export var buffs: SistemaBuffs
@export var afinidad: SistemaAfinidad
var tiempo_dash_disponible: int = 1
@export var zeta_actual: Zeta_datos: set = set_zeta_actual
@export var con_zeta: bool = false

@export var inventario: Dictionary = {}

@export var mutaciones: SistemaMutaciones
@export var hambre: SistemaHambre
@export var zeta_inicial: Zeta_datos

@export var sinergias: SistemaSinergias = SistemaSinergias.new()

signal bolsillo_cambiado
signal zeta_cambiada(nueva_zeta: Zeta_datos)

## Provisiones equipadas para la run (acceso rápido). Solo se llena al partir desde la base:
## lo que se recoge durante la run va a `inventario` y no entra acá.
var bolsillo: Dictionary:
	get:
		return CodigoGlobal.bolsillo
var indice_bolsillo: int = 0
## Cuánto del bono de vida de la Zeta ya se gastó (escudo de Zeta)
var dano_escudo_zeta: float = 0.0

## Sabores activos: tag (int) -> segundos restantes. Imbuyen los golpes (ver SaboresCombate).
var sabores_activos: Dictionary = {}


func _init() -> void:
	if not stats: stats = StatsBase.new()
	if not mejoras_permanentes: mejoras_permanentes = SistemaMejorasPermanentes.new()
	if not buffs: buffs = SistemaBuffs.new()
	if not afinidad: afinidad = SistemaAfinidad.new()
	if not mutaciones: mutaciones = SistemaMutaciones.new()
	if not hambre: hambre = SistemaHambre.new()


func inicializar() -> void:
	if zeta_actual and zeta_actual.generar_al_iniciar:
		self.zeta_actual = zeta_actual.crear_instancia_con_stats_random()


# ==============================================================================
# STATS CALCULADOS
# ==============================================================================
func _en_base() -> bool:
	var escena_actual = Engine.get_main_loop().current_scene
	if escena_actual == null:
		return false
	return escena_actual.has_meta("es_base") and escena_actual.get_meta("es_base") == true

var vida: float:
	get:
		if _en_base():
			return stats.vida_base
		return _calcular("vida", stats.vida_base) + _bonus_zeta_vida()

var velocidad_max: float:
	get:
		if _en_base():
			return stats.velocidad_max_base
		return _calcular("velocidad_max", stats.velocidad_max_base) - _bonus_zeta_peso()

var aceleracion: float:
	get:
		if _en_base():
			return stats.aceleracion_base
		return _calcular("aceleracion", stats.aceleracion_base)

var dash_duraccion: float:
	get:
		if _en_base():
			return stats.dash_duraccion_base
		return _calcular("dash_duraccion", stats.dash_duraccion_base)

var dash_velociadad: float:
	get:
		if _en_base():
			return stats.dash_velociadad_base
		return _calcular("dash_velociadad", stats.dash_velociadad_base)

var dano: float:
	get:
		if _en_base():
			return stats.dano_base
		var valor = _calcular("dano", stats.dano_base) + _bonus_zeta_fuerza()
		if hambre.esta_en_cero():
			valor *= (1.0 - hambre.reduccion_dano_hambre_cero / 100.0)
		return valor

var velocidad_ataque: float:
	get:
		if _en_base():
			return stats.velocidad_ataque_base
		return _calcular("velocidad_ataque", stats.velocidad_ataque_base)

func _calcular(nombre_stat: String, base: float) -> float:
	var flat = mejoras_permanentes.bonus_flat(nombre_stat) + buffs.bonus_flat(nombre_stat)
	var porcentaje = mejoras_permanentes.bonus_porcentaje(nombre_stat) + buffs.bonus_porcentaje(nombre_stat)
	return (base + flat) * (1.0 + porcentaje / 100.0)


# ==============================================================================
# ZETA
# ==============================================================================

func set_zeta_actual(nueva_zeta: Zeta_datos) -> void:
	zeta_actual = nueva_zeta
	dano_escudo_zeta = 0.0
	zeta_cambiada.emit(nueva_zeta)
	if nueva_zeta: CodigoGlobal.aprender("zeta:" + nueva_zeta.nombre)

	emit_changed()

func cambiar_zeta(nueva_zeta: Zeta_datos) -> void:
	self.zeta_actual = nueva_zeta

func poner_quitar_zeta() -> void:
	if not zeta_actual or not zeta_actual.estadisticas:
		return
	con_zeta = not con_zeta
	emit_changed()

func _bonus_zeta_peso() -> float:
	if con_zeta and zeta_actual and zeta_actual.estadisticas:
		return zeta_actual.estadisticas.peso
	return 0.0

func _bonus_zeta_fuerza() -> float:
	if con_zeta and zeta_actual and zeta_actual.estadisticas:
		return zeta_actual.estadisticas.bonus_fuerza_ataque
	return 0.0

func escudo_zeta() -> float:
	if con_zeta and zeta_actual and zeta_actual.estadisticas:
		return maxf(0.0, zeta_actual.estadisticas.bonus_vida_max - dano_escudo_zeta)
	return 0.0

func _bonus_zeta_vida() -> float:
	return escudo_zeta()


# ==============================================================================
# INVENTARIO DE LA RUN
# ==============================================================================

func agregar_item(item: ItemData) -> bool:
	if not item: return false
	var clave = item.nombre
	CodigoGlobal.marcar_visto("item:" + item.nombre)
	for tag in item.tags:
		CodigoGlobal.marcar_visto("tag:%d" % tag)
	if inventario.has(clave):
		var item_en_inventario = inventario[clave]
		if item_en_inventario.apilable and item_en_inventario.cantidad < item_en_inventario.max_cantidad:
			item_en_inventario.cantidad += 1
			emit_changed()
			return true

	var nueva_instancia_item = item.duplicate()
	var clave_nueva = clave
	if not nueva_instancia_item.apilable or inventario.has(clave_nueva):
		clave_nueva += "_" + str(randi())

	inventario[clave_nueva] = nueva_instancia_item
	emit_changed()
	return true

func quitar_item(clave: String, cantidad_a_quitar: int) -> void:
	if not inventario.has(clave):
		return
	var item: ItemData = inventario[clave]
	item.cantidad -= cantidad_a_quitar
	if item.cantidad <= 0:
		inventario.erase(clave)
	emit_changed()

## Inventario desde el que se come: el de la base si estás en la base, si no el de la run
func obtener_inventario_activo() -> Dictionary:
	if _en_base():
		return CodigoGlobal.inventario_base
	return inventario

func quitar_item_activo(clave: String, cantidad_a_quitar: int) -> void:
	if _en_base():
		CodigoGlobal.quitar_item_base(clave, cantidad_a_quitar)
	else:
		quitar_item(clave, cantidad_a_quitar)


# ==============================================================================
# CICLO DE RUN
# ==============================================================================

func actualizar(delta: float, en_run: bool) -> void:
	if buffs.actualizar(delta):
		emit_changed()

	# HAMBRE_VORAZ: el hambre baja más rápido (valor = % extra)
	var vel_hambre := 1.0 + sinergias.valor_efecto(SinergiaSabor.EfectoEspecial.HAMBRE_VORAZ) / 100.0
	var dano_hambre = hambre.actualizar(delta, en_run, vel_hambre)
	if dano_hambre > 0.0:
		recibir_dano(dano_hambre)

	for tag in sabores_activos.keys():
		sabores_activos[tag] -= delta
		if sabores_activos[tag] <= 0.0:
			sabores_activos.erase(tag)
			emit_changed()   # solo cuando un sabor termina

	sinergias.actualizar(delta)

func terminar_run() -> void:
	buffs.limpiar_run()
	emit_changed()


# ==============================================================================
# WRAPPERS (la lógica está en OpsComida / OpsBolsillo / OpsVida)
# ==============================================================================

func aplicar_efecto(efecto: EfectoItem) -> void: OpsComida.aplicar_efecto(self, efecto)
func comer_item(item: ItemData, veces: int) -> void: OpsComida.comer(self, item, veces)
func activar_sabor(tag: int) -> void: OpsComida.activar_sabor(self, tag)

func limpiar_bolsillo() -> void: OpsBolsillo.limpiar(self)
func ciclar_bolsillo(paso: int = 1) -> void: OpsBolsillo.ciclar(self, paso)
func comer_del_bolsillo() -> bool: return OpsBolsillo.comer(self)
func reequipar_bolsillo(seleccion: Dictionary, origen: Dictionary) -> void: OpsBolsillo.reequipar(self, seleccion, origen)

func recibir_dano(cantidad: float) -> void: OpsVida.recibir_dano(self, cantidad)
func curar(cantidad: float) -> void: OpsVida.curar(self, cantidad)
func curar_robo(cantidad: float) -> void: OpsVida.curar_robo(self, cantidad)
