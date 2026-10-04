class_name SistemaMejorasPermanentes
extends Resource

enum Origen { ARBOL_HABILIDADES, ITEM_UNICO, OTRO }

# Cada entrada: {"stat": String, "valor": float, "es_porcentaje": bool, "origen": Origen}
@export var mejoras: Array[Dictionary] = []

func agregar_mejora(stat: String, valor: float, es_porcentaje: bool, origen: Origen) -> void:
	mejoras.append({
		"stat": stat,
		"valor": valor,
		"es_porcentaje": es_porcentaje,
		"origen": origen
	})
	emit_changed()

func bonus_flat(stat: String) -> float:
	var total := 0.0
	for m in mejoras:
		if m["stat"] == stat and not m["es_porcentaje"]:
			total += m["valor"]
	return total

func bonus_porcentaje(stat: String) -> float:
	var total := 0.0
	for m in mejoras:
		if m["stat"] == stat and m["es_porcentaje"]:
			total += m["valor"]
	return total
