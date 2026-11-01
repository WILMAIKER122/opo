class_name OpsVida
extends RefCounted
## Daño, curación y robo de vida (con escudo de Zeta). Datos en estadisticas_player (est).
## Destino: res://pj/codigos/estadisticas/ops_vida.gd


static func recibir_dano(est: estadisticas_player, cantidad: float) -> void:
	if cantidad <= 0.0:
		return
	# El escudo de la Zeta absorbe primero (solo mientras la llevás puesta)
	var absorbido := minf(est.escudo_zeta(), cantidad)
	est.dano_escudo_zeta += absorbido
	cantidad -= absorbido
	if cantidad > 0.0:
		est.buffs.agregar_buff("vida", -cantidad, false, -1.0)
	est.emit_changed()


static func curar(est: estadisticas_player, cantidad: float) -> void:
	if cantidad <= 0.0:
		return
	est.buffs.agregar_buff("vida", cantidad, false, -1.0)
	est.emit_changed()


## Robo de vida: repara primero el escudo de la Zeta (si la llevás puesta) y después la
## vida base, sin pasar de su tope (la vida no tiene máximo, así que sin esto crecería sin límite)
static func curar_robo(est: estadisticas_player, cantidad: float) -> void:
	if cantidad <= 0.0:
		return
	if est.con_zeta and est.dano_escudo_zeta > 0.0:
		var reparado := minf(est.dano_escudo_zeta, cantidad)
		est.dano_escudo_zeta -= reparado
		cantidad -= reparado
	if cantidad > 0.0:
		var faltante := maxf(0.0, est.stats.vida_base - est._calcular("vida", est.stats.vida_base))
		var curado := minf(cantidad, faltante)
		if curado > 0.0:
			est.buffs.agregar_buff("vida", curado, false, -1.0)
	est.emit_changed()
