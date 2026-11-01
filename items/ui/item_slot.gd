extends Panel

@onready var icono: TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var label_cantidad: Label = $MarginContainer/VBoxContainer/Label

var clave_item: String = ""
var item_data: ItemData
var veces_seleccionado: int = 0

func configurar(clave: String, item: ItemData) -> void:
	clave_item = clave
	item_data = item
	veces_seleccionado = 0
	if item.icono != null:
		icono.texture = item.icono
	_actualizar_texto()

func _actualizar_texto() -> void:
	if veces_seleccionado > 0:
		label_cantidad.text = "x%d  (%d -)" % [item_data.cantidad, veces_seleccionado]
	else:
		label_cantidad.text = " x%d" % [ item_data.cantidad]

# Devuelve false si ya llegó al máximo disponible (no puede comer más de lo que hay)
func incrementar_seleccion() -> bool:
	if veces_seleccionado >= item_data.cantidad:
		return false
	veces_seleccionado += 1
	_actualizar_texto()
	return true

func set_foco(activo: bool) -> void:
	modulate = Color(1.3, 1.3, 0.7) if activo else Color(1, 1, 1)

func decrementar_seleccion() -> bool:
	if veces_seleccionado <= 0:
		return false
	veces_seleccionado -= 1
	_actualizar_texto()
	return true
func fijar_seleccion(n: int) -> void:
	veces_seleccionado = clampi(n, 0, item_data.cantidad)
	_actualizar_texto()
