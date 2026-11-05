class_name MejoraPermanente
extends Resource
## Mejora permanente que otorga una receta. Se crea como .tres y se asigna a RecetaCocina.mejora.

enum Tipo {
	STAT,          ## suma `valor` al stat elegido
	ZETA_INICIAL,  ## la Zeta con la que arranca cada run
}

@export var nombre: String = ""
@export_multiline var descripcion: String = ""
@export var icono: Texture2D
@export var tipo: Tipo = Tipo.STAT

@export_group("Stat")
@export_enum("vida", "dano", "velocidad_ataque", "velocidad_max", "aceleracion", "dash_duraccion", "dash_velociadad", "hambre_max", "max_por_slot_bolsillo", "slots_autorelleno") var stat: String = "vida"
@export var valor: float = 10.0
## true: valor es % (ej. 10 = +10%). Para hambre_max, max_por_slot_bolsillo y slots_autorelleno usá valor fijo.
@export var es_porcentaje: bool = false

@export_group("Zeta inicial")
@export var zeta: Zeta_datos


## Texto corto del efecto: "vida +10" / "dano +15%" / "Zeta inicial: magico"
func texto_efecto() -> String:
	if tipo == Tipo.ZETA_INICIAL:
		return "Zeta inicial: %s" % (zeta.nombre if zeta else "?")
	var signo := "+" if valor >= 0.0 else ""
	return "%s %s%s%s" % [stat, signo, str(valor), "%" if es_porcentaje else ""]
