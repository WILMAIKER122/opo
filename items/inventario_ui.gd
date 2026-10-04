extends PanelContainer

@onready var grid: GridContainer = $controlador

const ITEM_SLOT_SCENE := preload("res://items/ItemSlot.tscn")

@export var player: CharacterBody3D

func _ready() -> void:
	if player == null:
		push_warning("InventarioUI: no se encontró referencia al player")
		return
	
	_actualizar_grid()
	
	player.estadisticas.changed.connect(_actualizar_grid)

func _actualizar_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for clave in player.estadisticas.inventario:
		var item: ItemData = player.estadisticas.inventario[clave]
		_instanciar_slot(clave, item)

func _instanciar_slot(clave: String, item: ItemData) -> void:
	var slot = ITEM_SLOT_SCENE.instantiate()
	grid.add_child(slot)
	slot.configurar(clave, item)
