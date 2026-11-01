extends PanelContainer

@onready var grid: GridContainer = $controlador

const ITEM_SLOT_SCENE := preload("res://items/ui/ItemSlot.tscn")

@export var player: CharacterBody3D

func _ready() -> void:
	if player == null:
		push_warning("InventarioUI: no se encontró referencia al player")
		return
	_actualizar_grid()
	player.estadisticas.bolsillo_cambiado.connect(_actualizar_grid)

func _actualizar_grid() -> void:
	for hijo in grid.get_children():
		grid.remove_child(hijo)
		hijo.queue_free()

	var est: estadisticas_player = player.estadisticas
	var claves := est.bolsillo.keys()
	for i in claves.size():
		var slot = ITEM_SLOT_SCENE.instantiate()
		grid.add_child(slot)
		slot.configurar(claves[i], est.bolsillo[claves[i]])
		slot.set_foco(i == est.indice_bolsillo)   # ya existía en ItemSlot, resalta el seleccionado
