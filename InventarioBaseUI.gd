extends PanelContainer

@onready var grid: GridContainer = $controlador

const ITEM_SLOT_SCENE := preload("res://items/ItemSlot.tscn")

func _ready() -> void:
	_actualizar_grid()
	CodigoGlobal.inventario_base_actualizado.connect(_actualizar_grid)

func _actualizar_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for clave in CodigoGlobal.inventario_base:
		var item: ItemData = CodigoGlobal.inventario_base[clave]
		_instanciar_slot(clave, item)

func _instanciar_slot(clave: String, item: ItemData) -> void:
	var slot = ITEM_SLOT_SCENE.instantiate()
	grid.add_child(slot)
	slot.configurar(clave, item)
