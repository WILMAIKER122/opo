class_name AlteracionesEnemigo
extends RefCounted
## Estados alterados del enemigo (veneno, quemadura, lentitud...). No toca la vida:
## actualizar() devuelve el daño a aplicar y el Enemigo decide qué hacer con él.
## Destino: res://enemi/codigo/alteraciones_enemigo.gd

## Multiplicador de velocidad actual (1 = normal)
var factor_velocidad: float = 1.0
## Color del último estado que hace daño (para el número flotante)
var color_dot: Color = Color.WHITE

var _estados: Dictionary = {}   # id -> {"dps", "restante", "lentitud", "color"}
var _acum_dot: float = 0.0
var _tiempo_tick: float = 0.0


## Aplica (o renueva) un estado: daño por segundo y/o lentitud durante `segundos`
func aplicar(id: StringName, dps: float, segundos: float, lentitud: float = 0.0, color: Color = Color.WHITE) -> void:
	_estados[id] = {"dps": dps, "restante": segundos, "lentitud": lentitud, "color": color}


## Llamar cada frame de física. Devuelve el daño de este frame: 0 casi siempre,
## y el daño acumulado cada 0.5 s (un número por tick, sin spamear).
func actualizar(delta: float) -> float:
	if _estados.is_empty():
		factor_velocidad = 1.0
		return 0.0

	var dps_total := 0.0
	var lentitud := 0.0
	for id in _estados.keys():
		var e: Dictionary = _estados[id]
		e["restante"] -= delta
		if e["restante"] <= 0.0:
			_estados.erase(id)
			continue
		dps_total += e["dps"]
		lentitud = maxf(lentitud, e["lentitud"])
		if e["dps"] > 0.0:
			color_dot = e["color"]
	factor_velocidad = 1.0 - lentitud

	if dps_total <= 0.0:
		return 0.0
	_acum_dot += dps_total * delta
	_tiempo_tick += delta
	if _tiempo_tick >= 0.5:
		_tiempo_tick = 0.0
		var danio := _acum_dot
		_acum_dot = 0.0
		return danio
	return 0.0
