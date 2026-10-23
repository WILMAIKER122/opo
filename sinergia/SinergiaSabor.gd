class_name SinergiaSabor
extends Resource
## Define una sinergia de sabores (positiva o negativa). Se crea como .tres.
## IMPORTANTE: "nombre" tiene que ser único entre todas las sinergias (se usa para guardar
## cuáles ya conoce el jugador).
##
## Ejemplos:
##  - COMBO positivo:   tags_combo = [DULCE, PICANTE], efectos_stats = buff de velocidad de ataque
##  - CANTIDAD negativo (abuso): tag_acumulado = BESTIA, cantidad_a_acumular = 5, ventana 60 s,
##    efectos_stats = buff con valor NEGATIVO en velocidad, consumir_tags = false

enum TipoSinergia {
	COMBO,     ## Varios tags distintos (ej. DULCE + PICANTE)
	CANTIDAD,  ## Muchas veces el mismo tag (ej. 5 x BESTIA)
}

## Efectos especiales. Los últimos dos son NEGATIVOS.
## (Los valores nuevos van siempre AL FINAL para no romper los .tres existentes.)
enum EfectoEspecial {
	NINGUNO,
	VENENO_ON_HIT,    ## + valor = daño de veneno por segundo
	ROBO_DE_VIDA,     ## + valor = % del daño que se recupera
	DASH_GRATIS,      ## + el dash no gasta hambre
	HAMBRE_VORAZ,     ## - valor = % más rápido que baja el hambre
	DASH_BLOQUEADO,   ## - no se puede dashear
}

## Cuáles de los especiales son negativos (para el aviso de "sube / baja")
const ESPECIALES_NEGATIVOS: Array = [
	EfectoEspecial.HAMBRE_VORAZ,
	EfectoEspecial.DASH_BLOQUEADO,
]

@export var nombre: String = ""
@export_multiline var descripcion: String = ""
## Ícono para el HUD (opcional)
@export var icono: Texture2D
@export var tipo: TipoSinergia = TipoSinergia.COMBO

@export_group("Requisitos")
## Solo COMBO: cada tag de la lista necesita su propia entrada en el historial
@export var tags_combo: Array[ItemData.TagComida] = []
## Solo CANTIDAD: qué tag se acumula y cuántas veces
@export var tag_acumulado: ItemData.TagComida = ItemData.TagComida.BESTIA
@export var cantidad_a_acumular: int = 3
## Segundos hacia atrás en los que cuentan los tags comidos
@export var ventana_segundos: float = 60.0
## true: al activarse gasta los tags que la formaron.
## false: los deja contando (útil para las negativas por abuso, que miden "cuánto comiste").
@export var consumir_tags: bool = true

@export_group("Efecto")
## Segundos que dura el efecto. -1 = toda la run.
@export var duracion_segundos: float = 30.0
## Buffs/debuffs de stats. Valores NEGATIVOS = efecto negativo. Los que tengan duracion != 0
## usan la duración de la sinergia; los instantáneos (duracion = 0, ej. curación) se aplican una vez.
@export var efectos_stats: Array[EfectoItem] = []
@export var efecto_especial: EfectoEspecial = EfectoEspecial.NINGUNO
@export var valor_efecto_especial: float = 0.0


# Nombres viejos -> nombres nuevos: los .tres que ya tenías se siguen leyendo bien
# (al volver a guardarlos quedan con los nombres nuevos).
const _NOMBRES_ANTIGUOS := {
	&"tags_requeridos": &"tags_combo",
	&"tag_cantidad": &"tag_acumulado",
	&"cantidad_requerida": &"cantidad_a_acumular",
	&"ventana_tiempo": &"ventana_segundos",
	&"duracion_efecto": &"duracion_segundos",
	&"efectos": &"efectos_stats",
	&"valor_especial": &"valor_efecto_especial",
}

func _set(property: StringName, value: Variant) -> bool:
	if _NOMBRES_ANTIGUOS.has(property):
		set(_NOMBRES_ANTIGUOS[property], value)
		return true
	return false


## Lista plana de tags que hacen falta (se repite el tag en CANTIDAD)
func lista_de_tags() -> Array:
	if tipo == TipoSinergia.CANTIDAD:
		var lista: Array = []
		for i in cantidad_a_acumular:
			lista.append(tag_acumulado)
		return lista
	return tags_combo.duplicate()


# ==============================================================================
# POSITIVA / NEGATIVA (se deduce de los efectos)
# ==============================================================================

## Cambio real que produce un efecto sobre su stat (COSTO_VIDA resta aunque su valor sea positivo)
static func cambio_de(efecto: EfectoItem) -> float:
	if efecto.tipo == EfectoItem.TipoEfecto.COSTO_VIDA:
		return -efecto.valor
	return efecto.valor


## true si ese efecto SUBE el stat, false si lo BAJA
static func efecto_sube(efecto: EfectoItem) -> bool:
	return cambio_de(efecto) > 0.0


## true si, en conjunto, sube más de lo que baja (en empate gana positiva).
## Para el detalle stat por stat usá info_para_ui()["efectos"][i]["sube"].
func es_positiva() -> bool:
	var suben := 0
	var bajan := 0
	for efecto in efectos_stats:
		if efecto == null:
			continue
		if efecto_sube(efecto):
			suben += 1
		else:
			bajan += 1
	if efecto_especial != EfectoEspecial.NINGUNO:
		if ESPECIALES_NEGATIVOS.has(efecto_especial):
			bajan += 1
		else:
			suben += 1
	return suben >= bajan


# ==============================================================================
# INFO PARA LA UI (respeta lo que el jugador ya conoce)
# ==============================================================================

## conocida = false: solo se entregan las ventanas de tiempo; el resto sale oculto ("???").
## conocida = true: se entrega todo.
func info_para_ui(conocida: bool) -> Dictionary:
	var info := {
		"conocida": conocida,
		"nombre": nombre if conocida else "???",
		"descripcion": descripcion if conocida else "",
		"icono": icono if conocida else null,
		"es_positiva": es_positiva() if conocida else null,
		"ventana": ventana_segundos,   # segundos en los que cuentan los tags
		"duracion": duracion_segundos, # segundos que dura el efecto
		"efectos": [],
	}
	if conocida:
		info["efectos"] = _lista_de_efectos()
	return info


## [{ "stat", "valor" (con signo), "es_porcentaje", "sube", "especial" }]
func _lista_de_efectos() -> Array:
	var lista: Array = []
	for efecto in efectos_stats:
		if efecto == null:
			continue
		lista.append({
			"stat": efecto.stat_afectado,
			"valor": cambio_de(efecto),
			"es_porcentaje": efecto.es_porcentaje,
			"sube": efecto_sube(efecto),
			"especial": false,
		})
	if efecto_especial != EfectoEspecial.NINGUNO:
		lista.append({
			"stat": EfectoEspecial.keys()[efecto_especial],
			"valor": valor_efecto_especial,
			"es_porcentaje": false,
			"sube": not ESPECIALES_NEGATIVOS.has(efecto_especial),
			"especial": true,
		})
	return lista


## Clave con la que el jugador "conoce" esta sinergia (CodigoGlobal.conoce / aprender)
func clave_conocimiento() -> String:
	return "sinergia:" + nombre


## Texto de los requisitos, ej. "DULCE + PICANTE" o "BESTIA x5"
func texto_requisitos() -> String:
	if tipo == TipoSinergia.CANTIDAD:
		return "%s x%d" % [ItemData.TagComida.keys()[tag_acumulado], cantidad_a_acumular]
	var partes := PackedStringArray()
	for tag in tags_combo:
		partes.append(ItemData.TagComida.keys()[tag])
	return " + ".join(partes)
