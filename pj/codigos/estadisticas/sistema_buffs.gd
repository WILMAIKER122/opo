class_name SistemaBuffs
extends Resource

# Temporales: cuentan regresiva y desaparecen solos
var buffs_temporales: Array[Dictionary] = []   # {"stat", "valor", "es_porcentaje", "tiempo_restante"}

# De run: duran hasta que termina/reinicia la run (duracion == -1 en el EfectoItem)
var buffs_run: Array[Dictionary] = []          # {"stat", "valor", "es_porcentaje"}

func agregar_buff(stat: String, valor: float, es_porcentaje: bool, duracion: float) -> void:
	if duracion < 0.0:
		buffs_run.append({"stat": stat, "valor": valor, "es_porcentaje": es_porcentaje})
	else:
		buffs_temporales.append({
			"stat": stat,
			"valor": valor,
			"es_porcentaje": es_porcentaje,
			"tiempo_restante": duracion
		})
	emit_changed()

# Devuelve true si algún buff expiró (útil para saber si hay que refrescar HUD)
func actualizar(delta: float) -> bool:
	if buffs_temporales.is_empty():
		return false
	
	var hubo_cambio := false
	for i in range(buffs_temporales.size() - 1, -1, -1):
		buffs_temporales[i]["tiempo_restante"] -= delta
		if buffs_temporales[i]["tiempo_restante"] <= 0.0:
			buffs_temporales.remove_at(i)
			hubo_cambio = true
	
	if hubo_cambio:
		emit_changed()
	return hubo_cambio

func limpiar_run() -> void:
	buffs_run.clear()
	buffs_temporales.clear()
	emit_changed()

func bonus_flat(stat: String) -> float:
	var total := 0.0
	for b in buffs_temporales:
		if b["stat"] == stat and not b["es_porcentaje"]:
			total += b["valor"]
	for b in buffs_run:
		if b["stat"] == stat and not b["es_porcentaje"]:
			total += b["valor"]
	return total

func bonus_porcentaje(stat: String) -> float:
	var total := 0.0
	for b in buffs_temporales:
		if b["stat"] == stat and b["es_porcentaje"]:
			total += b["valor"]
	for b in buffs_run:
		if b["stat"] == stat and b["es_porcentaje"]:
			total += b["valor"]
	return total
